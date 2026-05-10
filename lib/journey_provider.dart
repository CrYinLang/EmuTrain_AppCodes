// journey_provider.dart
import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'journey_model.dart';
import 'ui/function/error.dart';

class JourneyProvider extends ChangeNotifier {
  final List<Journey> _journeys = [];
  static const String _storageKey = 'journeys_data';

  List<Journey> get journeys => List.unmodifiable(_journeys);

  JourneyProvider() {
    _loadJourneys();
  }

  // 从存储加载行程
  Future<void> _loadJourneys() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? journeysJson = prefs.getString(_storageKey);

      if (journeysJson != null && journeysJson.isNotEmpty) {
        final List<dynamic> journeysList = json.decode(journeysJson);
        _journeys.clear();
        _journeys.addAll(
          journeysList
              .map(
                (journeyMap) =>
                    Journey.fromStorageMap(journeyMap as Map<String, dynamic>),
              )
              .toList(),
        );
        notifyListeners();
      }
    } catch (e, stack) {
      await logError(
        from: 'JourneyProvider._loadJourneys',
        error: '从本地存储加载行程数据失败: $e',
        level: 4,
      );
      if (kDebugMode) {
        print('加载行程数据失败: $e');
        print(stack);
      }
      // 清空列表，避免脏数据
      _journeys.clear();
      notifyListeners();
    }
  }

  // 保存行程到存储
  Future<void> _saveJourneys() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String journeysJson = json.encode(
        _journeys.map((journey) => journey.toMap()).toList(),
      );
      await prefs.setString(_storageKey, journeysJson);
    } catch (e, stack) {
      await logError(
        from: 'JourneyProvider._saveJourneys',
        error: '保存行程数据到本地存储失败: $e',
        level: 4,
      );
      if (kDebugMode) {
        print('保存行程数据失败: $e');
        print(stack);
      }
    }
  }

  // 添加行程
  void addJourney(Journey journey) {
    try {
      // 检查是否已存在相同ID的行程
      if (!_journeys.any((j) => j.id == journey.id)) {
        _journeys.add(journey);
        _saveJourneys();
        notifyListeners();
      }
    } catch (e) {
      unawaited(logError(
        from: 'JourneyProvider.addJourney',
        error: '添加行程失败: ${journey.trainCode} - $e',
        level: 4,
      ));
      if (kDebugMode) {
        print('添加行程失败: $e');
      }
    }
  }

  // 删除行程
  void removeJourney(String id) {
    try {
      final beforeCount = _journeys.length;
      _journeys.removeWhere((j) => j.id == id);

      if (beforeCount != _journeys.length) {
        _saveJourneys();
        notifyListeners();
      }
    } catch (e) {
      unawaited(logError(
        from: 'JourneyProvider.removeJourney',
        error: '删除行程失败 id=$id: $e',
        level: 4,
      ));
      if (kDebugMode) {
        print('删除行程失败: $e');
      }
    }
  }

  // 清空所有行程
  void clearAll() {
    try {
      _journeys.clear();
      _saveJourneys();
      notifyListeners();
    } catch (e) {
      unawaited(logError(
        from: 'JourneyProvider.clearAll',
        error: '清空所有行程失败: $e',
        level: 4,
      ));
      if (kDebugMode) {
        print('清空行程失败: $e');
      }
    }
  }

  void sortByDateTime() {
    try {
      _journeys.sort((a, b) {
        final DateTime dateTimeA = _combineDateAndTime(
          a.travelDate,
          a.departureTime,
        );
        final DateTime dateTimeB = _combineDateAndTime(
          b.travelDate,
          b.departureTime,
        );
        return dateTimeA.compareTo(dateTimeB);
      });

      _saveJourneys();
      notifyListeners();
    } catch (e) {
      unawaited(logError(
        from: 'JourneyProvider.sortByDateTime',
        error: '按时间排序行程失败: $e',
        level: 3,
      ));
      if (kDebugMode) {
        print('排序失败: $e');
      }
    }
  }

  DateTime _combineDateAndTime(DateTime date, String timeStr) {
    try {
      final parts = timeStr.split(':');
      if (parts.length == 2) {
        final hour = int.parse(parts[0]);
        final minute = int.parse(parts[1]);
        return DateTime(date.year, date.month, date.day, hour, minute);
      }
    } catch (_) {}
    // 解析失败返回原始日期
    return date;
  }

  // 获取特定日期的行程
  List<Journey> getJourneysByDate(DateTime date) {
    return _journeys.where((j) {
      return j.travelDate.year == date.year &&
          j.travelDate.month == date.month &&
          j.travelDate.day == date.day;
    }).toList();
  }

  // 更新行程
  void updateJourney(Journey updatedJourney) {
    try {
      final index = _journeys.indexWhere((j) => j.id == updatedJourney.id);
      if (index != -1) {
        _journeys[index] = updatedJourney;
        _saveJourneys();
        notifyListeners();
      }
    } catch (e) {
      unawaited(logError(
        from: 'JourneyProvider.updateJourney',
        error: '更新行程失败 id=${updatedJourney.id}: $e',
        level: 4,
      ));
      if (kDebugMode) {
        print('更新行程失败: $e');
      }
    }
  }
}