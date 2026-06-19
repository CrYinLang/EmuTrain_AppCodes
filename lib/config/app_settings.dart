// config/app_settings.dart
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../widgets/error.dart';
import 'app_vars.dart';
import 'data_enums.dart';

class AppSettings extends ChangeNotifier {
  // ---------- 版本信息 ----------
  static const String version = Vars.version;
  static const String build = Vars.build;
  static const String lastUpdate = Vars.lastUpdate;

  // ---------- 主题 ----------
  ThemeMode _themeMode = ThemeMode.dark;
  bool _midnightMode = false;
  bool _isLoading = false;
  bool _followSystem = false;
  Color? _seedColor; // null = 莫奈 / 跟随壁纸
  static const int _randomColorSentinel = -1;
  bool _isRandomColor = false;
  bool get isRandomColor => _isRandomColor;

  /// 跟随系统时强制返回 ThemeMode.system
  ThemeMode get themeMode => _followSystem ? ThemeMode.system : _themeMode;

  bool get midnightMode => _midnightMode;

  bool get isLoading => _isLoading;

  bool get followSystem => _followSystem;

  /// null 表示使用 dynamic_color（莫奈壁纸色）
  Color? get seedColor => _seedColor;

  // ---------- 图标显示 ----------
  bool _showTrainIcons = true;
  bool _showBureauIcons = true;

  bool get showTrainIcons => _showTrainIcons;

  bool get showBureauIcons => _showBureauIcons;

  // ---------- 自动更新 ----------
  bool _showAutoUpdate = true;

  bool get showAutoUpdate => _showAutoUpdate;

  // ---------- 数据源 ----------
  TrainDataSource _dataSource = TrainDataSource.railRe;
  TrainEmuDataSource _dataEmuSource = TrainEmuDataSource.railRe;
  TrainStationDataSource _dataStationSource = TrainStationDataSource.moeFactory;

  TrainDataSource get dataSource => _dataSource;

  TrainEmuDataSource get dataEmuSource => _dataEmuSource;

  TrainStationDataSource get dataStationSource => _dataStationSource;

  String get dataSourceDisplayName {
    switch (_dataSource) {
      case TrainDataSource.railRe:
        return 'Rail.re';
      case TrainDataSource.railGo:
        return 'RailGo';
      case TrainDataSource.official12306:
        return '12306官方';
    }
  }

  String get dataEmuSourceDisplayName {
    switch (_dataEmuSource) {
      case TrainEmuDataSource.railRe:
        return 'Rail.re';
      case TrainEmuDataSource.railGo:
        return 'RailGo';
      case TrainEmuDataSource.moeFactory:
        return 'MoeFactory';
    }
  }

  String get dataSourceDescription {
    switch (_dataSource) {
      case TrainDataSource.railRe:
        return '第三方API，提供更丰富的数据，但可能缺少部分数据';
      case TrainDataSource.railGo:
        return '第三方API，提供更丰富的数据，但可能缺少部分数据';
      case TrainDataSource.official12306:
        return '官方数据源，最准确可靠，但不显示重连，城际等';
    }
  }

  String get dataEmuSourceDescription => '第三方数据源，提供更全面的车型信息';

  Future<void> setDataSource(TrainDataSource source) async {
    if (_dataSource == source) return;
    _dataSource = source;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('dataSource', source.index);
    notifyListeners();
  }

  Future<void> setEmuDataSource(TrainEmuDataSource source) async {
    if (_dataEmuSource == source) return;
    _dataEmuSource = source;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('dataEmuSource', source.index);
    notifyListeners();
  }

  Future<void> setStationDataSource(TrainStationDataSource source) async {
    if (_dataStationSource == source) return;
    _dataStationSource = source;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('dataStationSource', source.index);
    notifyListeners();
  }

  // ==================== 初始化 ====================
  // ==================== 初始化 ====================
  Future<void> loadSettings() async {
    _isLoading = true;
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();

      _themeMode = (prefs.getBool('isDark') ?? true)
          ? ThemeMode.dark
          : ThemeMode.light;

      _midnightMode = prefs.getBool('midnightMode') ?? false;
      _followSystem = prefs.getBool('followSystem') ?? false;

      final seedColorValue = prefs.getInt('seedColor');
      if (seedColorValue == _randomColorSentinel) {
        _isRandomColor = true;
        _seedColor = _pickRandomColor();
      } else {
        _isRandomColor = false;
        _seedColor = seedColorValue != null ? Color(seedColorValue) : null;
      }

      _showTrainIcons = prefs.getBool('showTrainIcons') ?? true;
      _showBureauIcons = prefs.getBool('showBureauIcons') ?? true;
      _showAutoUpdate = prefs.getBool('showAutoUpdate') ?? true;

      // 数据源 - 车次查询
      final dataSourceIndex = prefs.getInt('dataSource') ?? 0;
      _dataSource = TrainDataSource
          .values[dataSourceIndex.clamp(0, TrainDataSource.values.length - 1)];

      // 数据源 - 车号/交路查询
      final dataEmuSourceIndex = prefs.getInt('dataEmuSource') ?? 0;
      _dataEmuSource =
          TrainEmuDataSource.values[dataEmuSourceIndex.clamp(
            0,
            TrainEmuDataSource.values.length - 1,
          )];

      // 数据源 - 车站查询
      final dataStationSourceIndex = prefs.getInt('dataStationSource') ?? 0;
      _dataStationSource =
          TrainStationDataSource.values[dataStationSourceIndex.clamp(
            0,
            TrainStationDataSource.values.length - 1,
          )];

      debugPrint('AppSettings: 设置加载完成');
    } catch (e, stack) {
      logError(from: 'app_settings/loadSettings', error: e.toString());
      await logError(
        from: 'AppSettings.loadSettings',
        error: '加载应用设置失败: $e',
        level: 4,
      );
      debugPrint('loadSettings 异常: $e\n$stack');

      // 发生错误时使用默认值
      _setDefaultValues();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void _setDefaultValues() {
    _themeMode = ThemeMode.dark;
    _midnightMode = false;
    _followSystem = false;
    _seedColor = null;
    _showTrainIcons = true;
    _showBureauIcons = true;
    _showAutoUpdate = true;
    _dataSource = TrainDataSource.railRe;
    _dataEmuSource = TrainEmuDataSource.railRe;
    _dataStationSource = TrainStationDataSource.moeFactory;
  }

  // ==================== 主题 ====================
  Future<void> toggleTheme(bool isDark) async {
    _themeMode = isDark ? ThemeMode.dark : ThemeMode.light;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isDark', isDark);
    notifyListeners();
  }

  Future<void> toggleMidnightMode(bool value) async {
    _midnightMode = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('midnightMode', value);
    notifyListeners();
  }

  Future<void> toggleFollowSystem(bool value) async {
    _followSystem = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('followSystem', value);
    notifyListeners();
  }

  Future<void> setSeedColor(Color? color) async {
    _isRandomColor = false;
    _seedColor = color;
    final prefs = await SharedPreferences.getInstance();
    if (color == null) {
      await prefs.remove('seedColor');
    } else {
      await prefs.setInt('seedColor', color.toARGB32());
    }
    notifyListeners();
  }

  Future<void> setRandomColor() async {
    _isRandomColor = true;
    _seedColor = _pickRandomColor();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('seedColor', _randomColorSentinel);
    notifyListeners();
  }

  static Color _pickRandomColor() {
    const colors = [
      Color(0xFF2196F3), Color(0xFF4CAF50), Color(0xFFF44336),
      Color(0xFF9C27B0), Color(0xFFFF9800), Color(0xFF00BCD4),
      Color(0xFFE91E63), Color(0xFF795548), Color(0xFF607D8B),
      Color(0xFF009688),
    ];
    return colors[Random().nextInt(colors.length)];
  }

  // ==================== 图标显示 ====================
  Future<void> toggleTrainIcons(bool value) async {
    _showTrainIcons = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('showTrainIcons', value);
    notifyListeners();
  }

  Future<void> toggleBureauIcons(bool value) async {
    _showBureauIcons = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('showBureauIcons', value);
    notifyListeners();
  }

  // ==================== 自动更新 ====================
  Future<void> toggleAutoUpdate(bool value) async {
    _showAutoUpdate = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('showAutoUpdate', value);
    notifyListeners();
  }
}

