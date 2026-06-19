// lib/speed_service.dart
import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../widgets/error.dart';
import '../gps/gps.dart';

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
  static final SpeedService _instance = SpeedService._internal();

  factory SpeedService() => _instance;

  SpeedService._internal();

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

  bool _usingPollFallback = false;

  bool get usingPollFallback => _usingPollFallback;

  StreamSubscription<Position>? _positionStream;
  Timer? _pollTimer;

  // ── 权限检查 ──────────────────────────────────────────────────
  Future<void> checkPermission() async {
    try {
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

      if (!kIsWeb && Platform.isAndroid) {
        // 尝试请求后台权限
        if (permission == LocationPermission.whileInUse) {
          await Geolocator.requestPermission();
        }
      }

      hasPermission = true;
      statusMsg = isTracking ? '正在测速' : '点击开始测速';
      notifyListeners();
    } catch (e, stack) {
      logError(from: 'speed_service/checkPermission', error: e.toString());
      await logError(
        from: 'SpeedService.checkPermission',
        error: '位置权限检查失败: $e',
        level: 4,
      );
      debugPrint('checkPermission error: $e\n$stack');
      statusMsg = '权限检查异常';
      hasPermission = false;
      notifyListeners();
    }
  }

  // ── 开始追踪 ──────────────────────────────────────────────────
  Future<void> startTracking() async {
    try {
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

      // 使用上次缓存位置快速显示
      try {
        final last = await Geolocator.getLastKnownPosition();
        if (last != null && isTracking) {
          debugInfo = '使用上次缓存位置';
          _onPosition(last);
        }
      } catch (e) { logError(from: 'speed_service/startTracking', error: e.toString()); }

      final settings = SettingsModel();

      if (!kIsWeb && Platform.isAndroid && settings.forcePolling) {
        _startPolling();
      } else {
        _startStream();
      }
    } catch (e) {
      logError(from: 'speed_service/startTracking', error: e.toString());
      await logError(
        from: 'SpeedService.startTracking',
        error: '启动测速失败: $e',
        level: 4,
      );
      isTracking = false;
      statusMsg = '启动失败';
      notifyListeners();
    }
  }

  // ── 持续流模式 ────────────────────────────────────────────────
  void _startStream() {
    _positionStream?.cancel();

    final locationSettings = _buildStreamLocationSettings();

    _positionStream =
        Geolocator.getPositionStream(locationSettings: locationSettings).listen(
          (position) {
            if (isTracking) _onPosition(position);
          },
          onError: (Object e, StackTrace stack) {
            if (!isTracking) return;
            logError(
              from: 'SpeedService._startStream',
              error: '位置流出错，准备降级: $e',
              level: 4,
            );
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

  // ── 轮询模式 ──────────────────────────────────────────────────
  void _startPolling() {
    _scheduleNextPoll();
  }

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
        logError(from: 'speed_service/_scheduleNextPoll', error: e.toString());
        await logError(
          from: 'SpeedService._scheduleNextPoll',
          error: '轮询获取位置失败: $e',
          level: 3,
        );
        if (isTracking) {
          debugInfo = '定位错误: $e';
          notifyListeners();
        }
      }

      _scheduleNextPoll();
    });
  }

  // ── 处理新位置 ────────────────────────────────────────────────
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
    debugInfo =
        '[$modeTag] 更新#$_updateCount | ${speedMs.toStringAsFixed(2)} m/s';

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

  // ── 构建流模式定位参数 ──────────────────────────────────────
  LocationSettings _buildStreamLocationSettings() {
    final settings = SettingsModel();
    if (!kIsWeb && Platform.isAndroid) {
      return AndroidSettings(
        accuracy: LocationAccuracy.high,
        intervalDuration: const Duration(seconds: 1),
        forceLocationManager: settings.forceLocationManager,
      );
    } else if (!kIsWeb && (Platform.isIOS || Platform.isMacOS)) {
      return AppleSettings(
        accuracy: LocationAccuracy.high,
        activityType: ActivityType.fitness,
        pauseLocationUpdatesAutomatically: false,
      );
    }
    return const LocationSettings(accuracy: LocationAccuracy.high);
  }

  // ── 构建轮询模式定位参数 ──────────────────────────────────────
  LocationSettings _buildPollLocationSettings() {
    final settings = SettingsModel();
    if (!kIsWeb && Platform.isAndroid) {
      return AndroidSettings(
        accuracy: LocationAccuracy.high,
        forceLocationManager: settings.forceLocationManager,
      );
    } else if (!kIsWeb && (Platform.isIOS || Platform.isMacOS)) {
      return AppleSettings(
        accuracy: LocationAccuracy.high,
        activityType: ActivityType.fitness,
        pauseLocationUpdatesAutomatically: false,
      );
    }
    return const LocationSettings(accuracy: LocationAccuracy.high);
  }

  // ── 停止追踪 ──────────────────────────────────────────────────
  Future<void> stopTracking() async {
    try {
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
    } catch (e) {
      logError(from: 'speed_service/stopTracking', error: e.toString());
      await logError(
        from: 'SpeedService.stopTracking',
        error: '停止测速失败: $e',
        level: 4,
      );
      statusMsg = '停止时发生错误';
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
  bool _forcePolling = false;

  bool get forceLocationManager => _forceLocationManager;

  double get pollIntervalSeconds => _pollIntervalSeconds;

  bool get forcePolling => _forcePolling;

  Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _forceLocationManager = prefs.getBool('forceLocationManager') ?? false;
      _pollIntervalSeconds = prefs.getDouble('pollIntervalSeconds') ?? 1.0;
      _forcePolling = prefs.getBool('forcePolling') ?? false;
      notifyListeners();
    } catch (e) {
      logError(from: 'speed_service/load', error: e.toString());
      await logError(
        from: 'SettingsModel.load',
        error: '加载测速设置失败: $e',
        level: 3,
      );
    }
  }

  Future<void> setForceLocationManager(bool value) async {
    try {
      _forceLocationManager = value;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('forceLocationManager', value);
      notifyListeners();
    } catch (e) {
      logError(from: 'speed_service/setForceLocationManager', error: e.toString());
      await logError(
        from: 'SettingsModel.setForceLocationManager',
        error: '保存 forceLocationManager 失败: $e',
        level: 4,
      );
    }
  }

  Future<void> setPollIntervalSeconds(double value) async {
    try {
      _pollIntervalSeconds = value.clamp(0.1, 5.0);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble('pollIntervalSeconds', _pollIntervalSeconds);
      notifyListeners();
    } catch (e) {
      logError(from: 'speed_service/setPollIntervalSeconds', error: e.toString());
      await logError(
        from: 'SettingsModel.setPollIntervalSeconds',
        error: '保存 pollIntervalSeconds 失败: $e',
        level: 4,
      );
    }
  }

  Future<void> setForcePolling(bool value) async {
    try {
      _forcePolling = value;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('forcePolling', value);
      notifyListeners();
    } catch (e) {
      logError(from: 'speed_service/setForcePolling', error: e.toString());
      await logError(
        from: 'SettingsModel.setForcePolling',
        error: '保存 forcePolling 失败: $e',
        level: 4,
      );
    }
  }
}
