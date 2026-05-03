// lib/speed_service.dart
import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'ui/function/gps.dart';

/// 轨迹点：经纬度 + 对应速度
class TrackPoint {
  final double latitude;
  final double longitude;
  final double speedKmh;

  const TrackPoint({
    required this.latitude,
    required this.longitude,
    required this.speedKmh,
  });
}

class SpeedService extends ChangeNotifier {
  // ── 单例 ──────────────────────────────────────────────────────
  static final SpeedService _instance = SpeedService._internal();

  factory SpeedService() => _instance;

  SpeedService._internal();

  // ── 状态数据 ──────────────────────────────────────────────────
  double speedKmh = 0.0;
  double maxSpeedKmh = 0.0;
  double totalDistanceM = 0.0;
  double avgSpeedKmh = 0.0;
  double _speedAccumulator = 0.0;
  int _speedSampleCount = 0;

  final List<TrackPoint> trackPoints = [];

  Position? _lastPosition;
  bool isTracking = false;
  bool hasPermission = false;
  String statusMsg = '点击开始测速';
  String debugInfo = '';
  int _updateCount = 0;

  bool? lastSaveResult;
  DateTime? _trackingStartTime;

  // 当前是否实际运行在轮询模式（流失败降级后为 true）
  bool _usingPollFallback = false;
  bool get usingPollFallback => _usingPollFallback;

  StreamSubscription<Position>? _positionStream;
  Timer? _pollTimer;

  // ── 权限检查 ──────────────────────────────────────────────────
  Future<void> checkPermission() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      statusMsg = '请先开启设备定位服务';
      hasPermission = false;
      notifyListeners();
      return;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.deniedForever) {
      statusMsg = '位置权限被永久拒绝，请在系统设置中开启';
      hasPermission = false;
      notifyListeners();
      return;
    }

    if (permission == LocationPermission.denied) {
      statusMsg = '需要位置权限才能测速';
      hasPermission = false;
      notifyListeners();
      return;
    }

    // Android 额外申请后台权限（Android 10+）
    if (Platform.isAndroid) {
      if (permission == LocationPermission.whileInUse) {
        permission = await Geolocator.requestPermission();
        // 用户拒绝后台权限不阻止使用，仅影响后台追踪
      }
    }

    hasPermission = true;
    statusMsg = isTracking ? '正在测速' : '点击开始测速';
    notifyListeners();
  }

  // ── 开始追踪 ──────────────────────────────────────────────────
  Future<void> startTracking() async {
    isTracking = true;
    statusMsg = '正在定位…';
    _updateCount = 0;
    debugInfo = '';
    _lastPosition = null;
    totalDistanceM = 0.0;
    avgSpeedKmh = 0.0;
    maxSpeedKmh = 0.0;
    speedKmh = 0.0;
    _speedAccumulator = 0.0;
    _speedSampleCount = 0;
    lastSaveResult = null;
    _usingPollFallback = false;
    trackPoints.clear();
    _trackingStartTime = DateTime.now();
    notifyListeners();

    await SettingsModel().load();

    // 先尝试拿上一次已知位置，让界面立刻有数据显示
    try {
      final last = await Geolocator.getLastKnownPosition();
      if (last != null && isTracking) {
        debugInfo = '使用上次缓存位置';
        _onPosition(last);
      }
    } catch (_) {}

    final settings = SettingsModel();

    // iOS 始终使用持续流
    // Android：根据设置决定，流失败自动降级到轮询
    if (Platform.isAndroid && settings.forcePolling) {
      _startPolling();
    } else {
      _startStream();
    }
  }

  // ── 持续流模式 ────────────────────────────────────────────────
  void _startStream() {
    _positionStream?.cancel();

    final locationSettings = _buildStreamLocationSettings();

    _positionStream = Geolocator.getPositionStream(
      locationSettings: locationSettings,
    ).listen(
      (position) {
        if (isTracking) _onPosition(position);
      },
      onError: (Object e) {
        if (!isTracking) return;
        // 流出错，降级到轮询
        debugInfo = '流定位失败，切换轮询: $e';
        _usingPollFallback = true;
        notifyListeners();
        _positionStream?.cancel();
        _positionStream = null;
        _startPolling();
      },
      cancelOnError: true,
    );
  }

  // ── 轮询模式（Android 专用）────────────────────────────────────
  void _startPolling() {
    _scheduleNextPoll();
  }

  // ── 构建流模式 LocationSettings ───────────────────────────────
  LocationSettings _buildStreamLocationSettings() {
    final s = SettingsModel();
    final intervalMs =
        (s.pollIntervalSeconds * 1000).round().clamp(100, 5000);

    if (Platform.isAndroid) {
      return AndroidSettings(
        accuracy: LocationAccuracy.bestForNavigation,
        forceLocationManager: s.forceLocationManager,
        intervalDuration: Duration(milliseconds: intervalMs),
        distanceFilter: 0,
      );
    } else if (Platform.isIOS) {
      return AppleSettings(
        accuracy: LocationAccuracy.bestForNavigation,
        pauseLocationUpdatesAutomatically: false,
        distanceFilter: 0,
        allowBackgroundLocationUpdates: true,
      );
    } else {
      return LocationSettings(
        accuracy: LocationAccuracy.bestForNavigation,
        distanceFilter: 0,
      );
    }
  }

  // ── 构建轮询模式 LocationSettings ─────────────────────────────
  LocationSettings _buildPollLocationSettings() {
    final s = SettingsModel();
    if (Platform.isAndroid) {
      return AndroidSettings(
        accuracy: LocationAccuracy.bestForNavigation,
        forceLocationManager: s.forceLocationManager,
      );
    } else {
      return const LocationSettings(
        accuracy: LocationAccuracy.bestForNavigation,
      );
    }
  }

  // ── 递归单次轮询 ──────────────────────────────────────────────
  void _scheduleNextPoll() {
    if (!isTracking) return;

    final intervalMs = (SettingsModel().pollIntervalSeconds * 1000)
        .round()
        .clamp(100, 5000);

    _pollTimer?.cancel();
    _pollTimer = Timer(Duration(milliseconds: intervalMs), () async {
      if (!isTracking) return;

      try {
        final timeoutSec = (SettingsModel().pollIntervalSeconds * 3)
            .ceil()
            .clamp(5, 15);

        final position = await Geolocator.getCurrentPosition(
          locationSettings: _buildPollLocationSettings(),
        ).timeout(Duration(seconds: timeoutSec));

        if (isTracking) _onPosition(position);
      } catch (e) {
        if (isTracking) {
          debugInfo = '定位错误: $e';
          notifyListeners();
        }
      }

      _scheduleNextPoll();
    });
  }

  // ── 处理新位置数据 ────────────────────────────────────────────
  void _onPosition(Position position) {
    _updateCount++;
    final speedMs = position.speed < 0 ? 0.0 : position.speed;
    final currentSpeedKmh = speedMs * 3.6;

    double deltaDistance = 0.0;
    if (_lastPosition != null) {
      deltaDistance = Geolocator.distanceBetween(
        _lastPosition!.latitude,
        _lastPosition!.longitude,
        position.latitude,
        position.longitude,
      );
      if (deltaDistance > 500) deltaDistance = 0;
    }
    _lastPosition = position;

    _speedSampleCount++;
    _speedAccumulator += currentSpeedKmh;

    speedKmh = currentSpeedKmh;
    totalDistanceM += deltaDistance;
    avgSpeedKmh = _speedAccumulator / _speedSampleCount;

    final modeTag = _usingPollFallback ? '轮询' : '流';
    debugInfo = '[$modeTag] 更新#$_updateCount | ${speedMs.toStringAsFixed(2)} m/s';

    if (currentSpeedKmh > maxSpeedKmh) maxSpeedKmh = currentSpeedKmh;
    statusMsg = '正在测速';

    trackPoints.add(
      TrackPoint(
        latitude: position.latitude,
        longitude: position.longitude,
        speedKmh: currentSpeedKmh,
      ),
    );

    notifyListeners();
  }

  // ── 停止追踪并保存 ────────────────────────────────────────────
  Future<void> stopTracking() async {
    await _positionStream?.cancel();
    _positionStream = null;
    _pollTimer?.cancel();
    _pollTimer = null;
    isTracking = false;
    speedKmh = 0.0;
    _updateCount = 0;
    _usingPollFallback = false;

    if (trackPoints.isNotEmpty && _trackingStartTime != null) {
      final record = TrackRecord(
        id: _trackingStartTime!.millisecondsSinceEpoch.toString(),
        startTime: _trackingStartTime!,
        endTime: DateTime.now(),
        maxSpeedKmh: maxSpeedKmh,
        avgSpeedKmh: avgSpeedKmh,
        totalDistanceM: totalDistanceM,
        points: List.unmodifiable(trackPoints),
      );
      lastSaveResult = await TrackRecord.save(record);
      statusMsg = lastSaveResult! ? '已停止并保存记录' : '已停止（距离不足100m，未保存）';
    } else {
      statusMsg = '已停止';
    }

    notifyListeners();
  }
}

class SettingsModel extends ChangeNotifier {
  static final SettingsModel _instance = SettingsModel._internal();

  factory SettingsModel() => _instance;

  SettingsModel._internal();

  bool _forceLocationManager = false;
  double _pollIntervalSeconds = 1.0;
  // Android 专用：强制使用轮询模式（关闭时默认用持续流）
  bool _forcePolling = false;

  bool get forceLocationManager => _forceLocationManager;
  double get pollIntervalSeconds => _pollIntervalSeconds;
  bool get forcePolling => _forcePolling;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    _forceLocationManager = prefs.getBool('forceLocationManager') ?? false;
    _pollIntervalSeconds = prefs.getDouble('pollIntervalSeconds') ?? 1.0;
    _forcePolling = prefs.getBool('forcePolling') ?? false;
    notifyListeners();
  }

  Future<void> setForceLocationManager(bool value) async {
    _forceLocationManager = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('forceLocationManager', value);
    notifyListeners();
  }

  Future<void> setPollIntervalSeconds(double value) async {
    _pollIntervalSeconds = value.clamp(0.1, 5.0);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('pollIntervalSeconds', _pollIntervalSeconds);
    notifyListeners();
  }

  Future<void> setForcePolling(bool value) async {
    _forcePolling = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('forcePolling', value);
    notifyListeners();
  }
}
