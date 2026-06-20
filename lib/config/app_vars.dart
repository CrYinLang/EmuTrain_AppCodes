// config/app_vars.dart
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../widgets/error.dart';

class Vars {
  static const String lastUpdate = '260620';
  static const String version = '1.2.5.1';
  static const String build = '1251';
  static const String updateDescription ='';

  static String getUpdateDescription(Map<String, dynamic>? versionInfo) {
    final remoteDescribe = versionInfo?['describe']?.toString().trim() ?? '';
    return remoteDescribe.isNotEmpty ? remoteDescribe : updateDescription;
  }

  static String defaultStationBuild = '202606200';
  static String defaultTrainBuild = '202606200';
  static String defaultCoachTrainBuild = '202605230';
  static String defaultLocoBuild = '202605230';

  // ---------- stationBuild ----------
  static String _stationBuild = defaultStationBuild;
  static bool _isStationBuildInitialized = false;

  static String get stationBuild => _stationBuild;

  static Future<void> initStationBuild() async {
    if (_isStationBuildInitialized) return;
    final prefs = await SharedPreferences.getInstance();
    _stationBuild = prefs.getString('stationBuild') ?? defaultStationBuild;
    _isStationBuildInitialized = true;
  }

  static Future<void> setStationBuild(String value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('stationBuild', value);
    _stationBuild = value;
    _isStationBuildInitialized = true;
  }

  // ---------- trainBuild ----------
  static String _trainBuild = defaultTrainBuild;
  static bool _isTrainBuildInitialized = false;

  static String get trainBuild => _trainBuild;

  static Future<void> initTrainBuild() async {
    if (_isTrainBuildInitialized) return;
    final prefs = await SharedPreferences.getInstance();
    _trainBuild = prefs.getString('trainBuild') ?? defaultTrainBuild;
    _isTrainBuildInitialized = true;
  }

  static Future<void> setTrainBuild(String value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('trainBuild', value);
    _trainBuild = value;
    _isTrainBuildInitialized = true;
  }

  // ---------- coachTrainBuild ----------
  static String _coachTrainBuild = defaultCoachTrainBuild;
  static bool _isCoachTrainBuildInitialized = false;

  static String get coachTrainBuild => _coachTrainBuild;

  static Future<void> initCoachTrainBuild() async {
    if (_isCoachTrainBuildInitialized) return;
    final prefs = await SharedPreferences.getInstance();
    _coachTrainBuild =
        prefs.getString('coachTrainBuild') ?? defaultCoachTrainBuild;
    _isCoachTrainBuildInitialized = true;
  }

  static Future<void> setCoachTrainBuild(String value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('coachTrainBuild', value);
    _coachTrainBuild = value;
    _isCoachTrainBuildInitialized = true;
  }

  // ---------- locoBuild ----------
  static String _locoBuild = defaultLocoBuild;
  static bool _isLocoBuildInitialized = false;

  static String get locoBuild => _locoBuild;

  static Future<void> initLocoBuild() async {
    if (_isLocoBuildInitialized) return;
    final prefs = await SharedPreferences.getInstance();
    _locoBuild = prefs.getString('locoBuild') ?? defaultLocoBuild;
    _isLocoBuildInitialized = true;
  }

  static Future<void> setLocoBuild(String value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('locoBuild', value);
    _locoBuild = value;
    _isLocoBuildInitialized = true;
  }

  // ---------- mirrorSource ----------
  // 可选值: 'Mirror' | 'Gitee' | 'GitHub'
  static String _mirrorSource = 'Mirror';
  static bool _isMirrorSourceInitialized = false;

  static const String _mirrorSourceKey = 'mirror_source';

  static String get mirrorSource => _mirrorSource;

  /// 根据当前优先镜像源返回完整的数据文件前缀（含尾部斜杠）
  static String get mirrorBaseUrl => _mirrorFallbackOrder(_mirrorSource).first;

  static Future<void> initMirrorSource() async {
    if (_isMirrorSourceInitialized) return;
    final prefs = await SharedPreferences.getInstance();
    _mirrorSource = prefs.getString(_mirrorSourceKey) ?? 'Mirror';
    _isMirrorSourceInitialized = true;
  }

  static Future<void> setMirrorSource(String value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_mirrorSourceKey, value);
    _mirrorSource = value;
    _isMirrorSourceInitialized = true;
  }

  static Map<String, dynamic>? _cachedVersionInfo;

  /// 是否正在进行中的请求（防止并发重复请求）
  static Future<Map<String, dynamic>?>? _pendingFetch;

  static Future<Map<String, dynamic>?> fetchVersionCommand() async {
    // 已有缓存直接返回
    if (_cachedVersionInfo != null) return _cachedVersionInfo;

    // 有进行中的请求则共享同一 Future，避免并发重复网络请求
    _pendingFetch ??= _doFetch().then((result) {
      if (result != null) _cachedVersionInfo = result;
      _pendingFetch = null;
      return result;
    });

    return _pendingFetch;
  }

  static Future<Map<String, dynamic>?> _doFetch() async {
    // 按优先级排列的 base URL 列表：优先选用户设置，失败依次回退
    final ordered = _mirrorFallbackOrder(_mirrorSource);
    for (final base in ordered) {
      final url = '${base}version.json';
      try {
        final response = await http
            .get(Uri.parse(url))
            .timeout(const Duration(seconds: 10));
        if (response.statusCode == 200) {
          return json.decode(response.body);
        } else {
          await logError(
            from: 'Vars._doFetch',
            error: '版本信息请求失败 ($base)，HTTP ${response.statusCode}',
            level: 4,
          );
        }
      } catch (e, stack) {
        logError(from: 'app_vars/setMirrorSource', error: e.toString());
        await logError(
          from: 'Vars._doFetch',
          error: '获取版本信息异常 ($base): $e',
          level: 4,
        );
        debugPrint('fetchVersion error ($base): $e\n$stack');
      }
    }
    return null;
  }

  /// 返回以 [preferred] 为首的 base URL 回退顺序
  /// 默认回退顺序（从次选到最终）：Gitee → Mirror → GitHub
  static List<String> _mirrorFallbackOrder(String preferred) {
    const gitee =
        'https://raw.giteeusercontent.com/CrYinLang/EmuTrain/raw/master/';
    const github =
        'https://raw.githubusercontent.com/CrYinLang/EmuTrain/refs/heads/main/';
    const mirror =
        'https://gh-proxy.com/https://raw.githubusercontent.com/CrYinLang/EmuTrain/refs/heads/main/';

    final String preferredUrl;
    switch (preferred) {
      case 'Gitee':
        preferredUrl = gitee;
        break;
      case 'GitHub':
        preferredUrl = github;
        break;
      case 'Mirror':
      default:
        preferredUrl = mirror;
    }

    final fallbacks = [
      gitee,
      mirror,
      github,
    ].where((u) => u != preferredUrl).toList();
    return [preferredUrl, ...fallbacks];
  }

  static void clearVersionCache() {
    _cachedVersionInfo = null;
    _pendingFetch = null;
  }
}

// ==================== 数据文件 ====================
