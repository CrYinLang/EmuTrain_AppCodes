// config/data_file_helper.dart
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import '../widgets/error.dart';
import '../models/coach_record.dart';

class DataFileHelper {
  /// 加载客车配属数据
  static Future<List<CoachRecord>> loadCoaches() async {
    try {
      String? jsonString;

      // Web 平台直接使用 assets
      if (!kIsWeb) {
        try {
          final directory = await getApplicationDocumentsDirectory();
          final file = File('${directory.path}/coach.json');
          if (await file.exists()) {
            jsonString = await file.readAsString();
            json.decode(jsonString);
            debugPrint('[DataFileHelper] 已加载下载版本 coach.json');
          }
        } catch (e, stack) {
          logError(from: 'data_file_helper/unknown', error: e.toString());
          await logError(
            from: 'DataFileHelper.loadCoaches',
            error: 'coach.json 文件损坏或解析失败，回退到 assets: $e',
            level: 3,
          );
          debugPrint('coach.json 损坏: $e\n$stack');
          jsonString = null;
        }
      }

      // 如果本地文件不存在或损坏，则加载 assets 默认数据
      jsonString ??= await rootBundle.loadString('assets/coach.json');
      debugPrint('[DataFileHelper] 已加载 assets/coach.json');

      final Map<String, dynamic> dataJson = json.decode(jsonString);
      final List<CoachRecord> result = [];

      for (final model in dataJson.keys) {
        for (final record in dataJson[model]) {
          result.add(CoachRecord.fromJson(Map<String, dynamic>.from(record)));
        }
      }
      return result;
    } catch (e, stack) {
      logError(from: 'data_file_helper/unknown', error: e.toString());
      await logError(
        from: 'DataFileHelper.loadCoaches',
        error: '加载客车配属数据失败: $e',
        level: 4,
      );
      debugPrint('loadCoaches 严重错误: $e\n$stack');
      rethrow; // 让上层捕获处理
    }
  }

  /// 读取列车数据（Map 结构），并展开为带 type_code 的 List
  static Future<List<Map<String, dynamic>>> loadTrains() async {
    try {
      String? jsonString;

      // Web 平台直接使用 assets
      if (!kIsWeb) {
        try {
          final directory = await getApplicationDocumentsDirectory();
          final file = File('${directory.path}/train.json');
          if (await file.exists()) {
            jsonString = await file.readAsString();
            json.decode(jsonString);
            debugPrint('[DataFileHelper] 已加载下载版本 train.json');
          }
        } catch (e, stack) {
          logError(from: 'data_file_helper/unknown', error: e.toString());
          await logError(
            from: 'DataFileHelper.loadTrains',
            error: 'train.json 文件损坏或解析失败，回退到 assets: $e',
            level: 3,
          );
          debugPrint('train.json 损坏: $e\n$stack');
          jsonString = null;
        }
      }

      jsonString ??= await rootBundle.loadString('assets/train.json');
      debugPrint('[DataFileHelper] 已加载 assets/train.json');

      final Map<String, dynamic> dataJson = json.decode(jsonString);
      final List<Map<String, dynamic>> result = [];

      for (var model in dataJson.keys) {
        for (var record in dataJson[model]) {
          final r = Map<String, dynamic>.from(record);
          r['type_code'] = model;
          result.add(r);
        }
      }
      return result;
    } catch (e, stack) {
      logError(from: 'data_file_helper/unknown', error: e.toString());
      await logError(
        from: 'DataFileHelper.loadTrains',
        error: '加载列车数据失败: $e',
        level: 4,
      );
      debugPrint('loadTrains 严重错误: $e\n$stack');
      rethrow;
    }
  }

  /// 加载机车配属数据
  static Future<List<Map<String, dynamic>>> loadLocos() async {
    try {
      String? jsonString;

      // Web 平台直接使用 assets
      if (!kIsWeb) {
        try {
          final directory = await getApplicationDocumentsDirectory();
          final file = File('${directory.path}/loco.json');
          if (await file.exists()) {
            jsonString = await file.readAsString();
            json.decode(jsonString);
            debugPrint('[DataFileHelper] 已加载下载版本 loco.json');
          }
        } catch (e, stack) {
          logError(from: 'data_file_helper/unknown', error: e.toString());
          await logError(
            from: 'DataFileHelper.loadLocos',
            error: 'loco.json 文件损坏或解析失败，回退到 assets: $e',
            level: 3,
          );
          debugPrint('loco.json 损坏: $e\n$stack');
          jsonString = null;
        }
      }

      jsonString ??= await rootBundle.loadString('assets/loco.json');
      debugPrint('[DataFileHelper] 已加载 assets/loco.json');

      final Map<String, dynamic> dataJson = json.decode(jsonString);
      final List<Map<String, dynamic>> result = [];

      for (final model in dataJson.keys) {
        for (final record in dataJson[model]) {
          result.add({
            'model': model,
            'number': (record['车组号'] ?? '').toString(),
            'depot': (record['配属段'] ?? '').toString(),
          });
        }
      }
      return result;
    } catch (e, stack) {
      logError(from: 'data_file_helper/unknown', error: e.toString());
      await logError(
        from: 'DataFileHelper.loadLocos',
        error: '加载机车配属数据失败: $e',
        level: 4,
      );
      debugPrint('loadLocos 严重错误: $e\n$stack');
      rethrow;
    }
  }
}

// ==================== 数据源枚举 ====================

