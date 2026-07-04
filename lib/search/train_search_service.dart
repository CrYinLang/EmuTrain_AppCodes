// train_search_service.dart
// 动车组查询服务层

import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../widgets/error.dart';

/// 动车组查询结果
class TrainSearchResult {
  final String model;
  final String number;
  final String bureau;
  final String bureauFullName;
  final String? depot;
  final String? manufacturer;
  final String? remarks;
  final String? routeInfo;
  final String queryTime;

  const TrainSearchResult({
    required this.model,
    required this.number,
    required this.bureau,
    required this.bureauFullName,
    this.depot,
    this.manufacturer,
    this.remarks,
    this.routeInfo,
    required this.queryTime,
  });

  factory TrainSearchResult.fromMap(Map<String, dynamic> map) {
    return TrainSearchResult(
      model: map['model'] ?? '',
      number: map['number'] ?? '',
      bureau: map['bureau'] ?? '',
      bureauFullName: map['bureauFullName'] ?? '',
      depot: map['depot'],
      manufacturer: map['manufacturer'],
      remarks: map['remarks'],
      routeInfo: map['routeInfo'],
      queryTime: map['queryTime'] ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'model': model,
      'number': number,
      'bureau': bureau,
      'bureauFullName': bureauFullName,
      'depot': depot,
      'manufacturer': manufacturer,
      'remarks': remarks,
      'routeInfo': routeInfo,
      'queryTime': queryTime,
    };
  }
}

/// 动车组查询服务
class TrainSearchService {
  /// 从本地数据查询动车组
  static Future<List<Map<String, dynamic>>> searchLocalTrainData({
    required List<Map<String, dynamic>> trainData,
    required String input,
  }) async {
    final cleanedInput = _cleanString(input);
    final inputDigits = cleanedInput.replaceAll(RegExp(r'[^0-9]'), '');
    final hasFourDigits = inputDigits.length >= 4;

    // 粗筛
    List<Map<String, dynamic>> matches = trainData.where((record) {
      final trainNum = _cleanString(record['车组号'] ?? '');
      return trainNum.contains(cleanedInput) || cleanedInput.contains(trainNum);
    }).toList();

    if (matches.isEmpty) return [];

    // 精确评分 + 末四位过滤
    final scored = <Map<String, dynamic>, double>{};
    for (final record in matches) {
      final model = record['type_code'] ?? '';
      final number = record['车组号'] ?? '';
      final score = _calculateMatchScore(input, number, model);

      if (hasFourDigits) {
        final inputLastFour = inputDigits.substring(inputDigits.length - 4);
        final recordLastFour = _extractLastFour(number);
        if (recordLastFour != inputLastFour) continue;
      }
      scored[record] = score;
    }

    if (scored.isEmpty) return [];

    final sortedEntries = scored.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    final topScore = sortedEntries.first.value;

    if (topScore >= 0.9) {
      return sortedEntries.where((e) => e.value >= topScore - 0.05).map((e) => e.key).toList();
    } else {
      return sortedEntries.take(5).map((e) => e.key).toList();
    }
  }

  /// 查询车次交路信息
  static Future<Map<String, dynamic>?> queryTrainRouting({
    required String trainCode,
    required String date,
  }) async {
    try {
      final url = Uri.parse('https://sharyou.api.rail.re/train/$trainCode');
      final response = await http.get(url);

      if (response.statusCode == 200) {
        return json.decode(response.body);
      }
      return null;
    } catch (e) {
      logError(from: 'train_search/queryTrainRouting', error: e.toString());
      return null;
    }
  }

  static String _cleanString(String input) => input.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '').toUpperCase();

  static String? _extractLastFour(String? text) {
    if (text == null || text.isEmpty) return null;
    final digits = text.replaceAll(RegExp(r'[^0-9]'), '');
    return digits.length >= 4 ? digits.substring(digits.length - 4) : null;
  }

  static double _calculateMatchScore(String input, String trainNumber, String modelCode) {
    final cleanedInput = _cleanString(input);
    final cleanedTrainNumber = _cleanString(trainNumber);
    final cleanedModelCode = _cleanString(modelCode);

    final fullTrainNumber = '$cleanedModelCode$cleanedTrainNumber';
    if (cleanedInput == fullTrainNumber) return 1.0;

    double numberScore = 0.0;
    if (cleanedTrainNumber.isNotEmpty) {
      if (cleanedInput.endsWith(cleanedTrainNumber)) {
        numberScore = 1.0;
      } else if (cleanedTrainNumber.length >= 4) {
        final trainLastFour = cleanedTrainNumber.substring(cleanedTrainNumber.length - 4);
        if (cleanedInput.contains(trainLastFour)) numberScore = 0.8;
      }
    }

    double modelScore = 0.0;
    if (cleanedInput.startsWith(cleanedModelCode)) {
      modelScore = 1.0;
    } else if (cleanedModelCode.startsWith(cleanedInput)) {
      modelScore = cleanedInput.length / cleanedModelCode.length;
    } else {
      int commonPrefix = 0;
      final minLength = cleanedInput.length < cleanedModelCode.length ? cleanedInput.length : cleanedModelCode.length;
      for (var i = 0; i < minLength && cleanedInput[i] == cleanedModelCode[i]; i++) {
        commonPrefix++;
      }
      if (commonPrefix >= 4) {
        modelScore = commonPrefix / cleanedModelCode.length;
      } else if (commonPrefix >= 2) {
        modelScore = commonPrefix / cleanedModelCode.length * 0.6;
      }
    }

    double finalScore = 0.0;
    if (numberScore > 0 && modelScore > 0) {
      finalScore = numberScore * 0.7 + modelScore * 0.3;
    } else if (numberScore > 0) {
      finalScore = numberScore * 0.5;
    } else if (modelScore > 0) {
      finalScore = modelScore * 0.4;
    }

    return finalScore.clamp(0.0, 1.0);
  }
}
