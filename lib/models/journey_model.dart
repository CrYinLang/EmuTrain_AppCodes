// journey_model.dart
import 'dart:async';

import '../widgets/error.dart';

class Journey {
  final String id;
  final String trainCode;
  final String fromStation;
  final String toStation;
  final String fromStationCode;
  final String toStationCode;
  final String departureTime;
  final String arrivalTime;
  final DateTime travelDate;
  final List<StationDetail> stations;
  final bool isStation;

  // 座位相关字段
  String seatType;
  String seatInfo;

  Journey({
    required this.id,
    required this.trainCode,
    required this.fromStation,
    required this.toStation,
    required this.fromStationCode,
    required this.toStationCode,
    required this.departureTime,
    required this.arrivalTime,
    required this.travelDate,
    required this.stations,
    this.isStation = false,
    this.seatType = '',
    this.seatInfo = '',
  });

  factory Journey.fromMapWithStations({
    required Map<String, dynamic> trainInfo,
    required DateTime date,
    required List<dynamic> stationList,
    required bool isStation,
    String? fromStation,
    String? toStation,
    String seatType = '',
    String seatInfo = '',
  }) {
    try {
      final allStations = stationList.map((s) {
        return StationDetail(
          stationName: s['stationName']?.toString() ?? '',
          arrivalTime: s['arriveTime']?.toString() ?? '--:--',
          departureTime: s['departTime']?.toString() ?? '--:--',
          stayTime: int.tryParse(s['stayTime']?.toString() ?? '0') ?? 0,
          dayDifference:
              int.tryParse(s['DayDifference']?.toString() ?? '0') ?? 0,
          isStart: s['isFirst'] == true,
          isEnd: s['isLast'] == true,
        );
      }).toList();

      String actualFromStation = fromStation ?? '';
      String actualToStation = toStation ?? '';
      String actualDepartureTime = '';
      String actualArrivalTime = '';

      if (fromStation != null && toStation != null) {
        if (fromStation == toStation && allStations.isNotEmpty) {
          // 环线列车
          final first = allStations.first;
          final last = allStations.last;
          actualFromStation = first.stationName;
          actualToStation = last.stationName;
          actualDepartureTime = first.departureTime;
          actualArrivalTime = last.arrivalTime;
        } else {
          final fromData = allStations.firstWhere(
            (s) => s.stationName == fromStation,
            orElse: () => allStations.first,
          );
          final toData = allStations.firstWhere(
            (s) => s.stationName == toStation,
            orElse: () => allStations.last,
          );

          actualFromStation = fromData.stationName;
          actualToStation = toData.stationName;
          actualDepartureTime = fromData.departureTime;
          actualArrivalTime = toData.arrivalTime;
        }
      } else {
        actualFromStation = trainInfo['from_station']?.toString() ?? '';
        actualToStation = trainInfo['to_station']?.toString() ?? '';
        actualDepartureTime = trainInfo['start_time']?.toString() ?? '';
        actualArrivalTime = trainInfo['arrive_time']?.toString() ?? '';
      }

      // 兜底处理
      if (actualFromStation.isEmpty && allStations.isNotEmpty) {
        actualFromStation = allStations.first.stationName;
      }
      if (actualToStation.isEmpty && allStations.isNotEmpty) {
        actualToStation = allStations.last.stationName;
      }

      return Journey(
        id: '${trainInfo['station_train_code']}_${date.millisecondsSinceEpoch}',
        trainCode: trainInfo['station_train_code']?.toString() ?? '',
        fromStation: actualFromStation,
        toStation: actualToStation,
        fromStationCode: trainInfo['from_station_code']?.toString() ?? '',
        toStationCode: trainInfo['to_station_code']?.toString() ?? '',
        departureTime: actualDepartureTime,
        arrivalTime: actualArrivalTime,
        travelDate: date,
        stations: allStations,
        isStation: isStation,
        seatType: seatType,
        seatInfo: seatInfo,
      );
    } catch (e) {
      logError(from: 'journey_model/unknown', error: e.toString());
      unawaited(
        logError(
          from: 'Journey.fromMapWithStations',
          error: '创建行程模型失败 trainCode=${trainInfo["station_train_code"]}: $e',
          level: 4,
        ),
      );
      // 返回一个安全的错误对象
      return Journey(
        id: 'error_${DateTime.now().millisecondsSinceEpoch}',
        trainCode: trainInfo['station_train_code']?.toString() ?? '未知车次',
        fromStation: fromStation ?? '未知',
        toStation: toStation ?? '未知',
        fromStationCode: '',
        toStationCode: '',
        departureTime: '--:--',
        arrivalTime: '--:--',
        travelDate: date,
        stations: [],
        isStation: isStation,
      );
    }
  }

  // 转换为 Map（用于持久化存储）
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'trainCode': trainCode,
      'fromStation': fromStation,
      'toStation': toStation,
      'fromStationCode': fromStationCode,
      'toStationCode': toStationCode,
      'departureTime': departureTime,
      'arrivalTime': arrivalTime,
      'travelDate': travelDate.toIso8601String(),
      'stations': stations.map((s) => s.toMap()).toList(),
      'isStation': isStation,
      'seatType': seatType,
      'seatInfo': seatInfo,
    };
  }

  // 从 Map 还原 Journey（用于从持久化存储读取）
  factory Journey.fromStorageMap(Map<String, dynamic> map) {
    try {
      final stationsData = map['stations'] as List<dynamic>? ?? [];
      final stations = stationsData
          .map((s) => StationDetail.fromMap(s as Map<String, dynamic>))
          .toList();

      DateTime travelDate;
      try {
        travelDate = DateTime.parse(map['travelDate'] as String);
      } catch (e) {
        logError(from: 'journey_model/unknown', error: e.toString());
        travelDate = DateTime.now();
      }

      return Journey(
        id: map['id']?.toString() ?? '',
        trainCode: map['trainCode']?.toString() ?? '',
        fromStation: map['fromStation']?.toString() ?? '',
        toStation: map['toStation']?.toString() ?? '',
        fromStationCode: map['fromStationCode']?.toString() ?? '',
        toStationCode: map['toStationCode']?.toString() ?? '',
        departureTime: map['departureTime']?.toString() ?? '',
        arrivalTime: map['arrivalTime']?.toString() ?? '',
        travelDate: travelDate,
        stations: stations,
        isStation: map['isStation'] as bool? ?? false,
        seatType: map['seatType']?.toString() ?? '',
        seatInfo: map['seatInfo']?.toString() ?? '',
      );
    } catch (e) {
      logError(from: 'journey_model/unknown', error: e.toString());
      unawaited(
        logError(
          from: 'Journey.fromStorageMap',
          error: '从存储恢复行程失败: $e',
          level: 4,
        ),
      );

      return Journey(
        id: 'error_${DateTime.now().millisecondsSinceEpoch}',
        trainCode: '解析错误',
        fromStation: '未知',
        toStation: '未知',
        fromStationCode: '',
        toStationCode: '',
        departureTime: '--:--',
        arrivalTime: '--:--',
        travelDate: DateTime.now(),
        stations: [],
      );
    }
  }

  // 计算总行程时间
  String getTotalDuration() {
    if (stations.isEmpty) return '--';

    try {
      if (fromStation == toStation) {
        final firstStation = stations.first;
        final lastStation = stations.last;

        final startTime = _parseTime(firstStation.departureTime);
        final endTime = _parseTime(lastStation.arrivalTime);

        if (startTime == null || endTime == null) return '--';

        // 计算天数差
        final dayDiff = lastStation.dayDifference - firstStation.dayDifference;

        int minutes = endTime.difference(startTime).inMinutes;
        minutes += dayDiff * 24 * 60; // 加上跨天的时间

        if (minutes < 0) return '--';

        final hours = minutes ~/ 60;
        final mins = minutes % 60;

        if (hours > 0) {
          if (dayDiff > 0) return '$hours小时$mins分\n跨$dayDiff天\n环线';
          return '$hours小时$mins分\n环线';
        } else {
          return '$mins分钟\n环线';
        }
      }

      // 普通列车的原有逻辑
      final fromIndex = stations.indexWhere(
        (s) => s.stationName == fromStation,
      );
      final toIndex = stations.indexWhere((s) => s.stationName == toStation);

      if (fromIndex == -1 || toIndex == -1) return '--';

      final fromStationData = stations[fromIndex];
      final toStationData = stations[toIndex];

      final startTime = _parseTime(fromStationData.departureTime);
      final endTime = _parseTime(toStationData.arrivalTime);

      if (startTime == null || endTime == null) return '--';

      // 计算天数差
      final dayDiff =
          toStationData.dayDifference - fromStationData.dayDifference;

      int minutes = endTime.difference(startTime).inMinutes;
      minutes += dayDiff * 24 * 60; // 加上跨天的时间

      if (minutes < 0) return '--';

      final hours = minutes ~/ 60;
      final mins = minutes % 60;

      if (hours > 0) {
        if (dayDiff > 0) return '$hours小时$mins分\n跨$dayDiff天';
        return '$hours小时$mins分';
      } else {
        return '$mins分钟';
      }
    } catch (e) {
      logError(from: 'journey_model/unknown', error: e.toString());
      return '--';
    }
  }

  DateTime? _parseTime(String timeStr) {
    if (timeStr.isEmpty || timeStr == '--:--') return null;
    final parts = timeStr.split(':');
    if (parts.length < 2) return null;
    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);
    if (hour == null || minute == null) return null;
    return DateTime(2000, 1, 1, hour, minute);
  }

  // 获取行程的简要信息（用于调试和日志）
  Map<String, dynamic> toDebugMap() {
    return {
      'id': id,
      'trainCode': trainCode,
      'fromStation': fromStation,
      'toStation': toStation,
      'departureTime': departureTime,
      'arrivalTime': arrivalTime,
      'travelDate': travelDate.toIso8601String(),
      'stationCount': stations.length,
      'isStation': isStation,
      'seatType': seatType,
      'seatInfo': seatInfo,
    };
  }

  // 重写 toString 方法用于调试
  @override
  String toString() {
    return 'Journey{id: $id, trainCode: $trainCode, fromStation: $fromStation, toStation: $toStation, travelDate: $travelDate, stations: ${stations.length}, seatType: $seatType, seatInfo: $seatInfo}';
  }

  // 重写 equals 和 hashCode 用于比较
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Journey && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;

  // 复制方法，用于创建修改后的副本
  Journey copyWith({
    String? id,
    String? trainCode,
    String? fromStation,
    String? toStation,
    String? fromStationCode,
    String? toStationCode,
    String? departureTime,
    String? arrivalTime,
    DateTime? travelDate,
    List<StationDetail>? stations,
    bool? isStation,
    String? seatType,
    String? seatInfo,
  }) {
    return Journey(
      id: id ?? this.id,
      trainCode: trainCode ?? this.trainCode,
      fromStation: fromStation ?? this.fromStation,
      toStation: toStation ?? this.toStation,
      fromStationCode: fromStationCode ?? this.fromStationCode,
      toStationCode: toStationCode ?? this.toStationCode,
      departureTime: departureTime ?? this.departureTime,
      arrivalTime: arrivalTime ?? this.arrivalTime,
      travelDate: travelDate ?? this.travelDate,
      stations: stations ?? this.stations,
      isStation: isStation ?? this.isStation,
      seatType: seatType ?? this.seatType,
      seatInfo: seatInfo ?? this.seatInfo,
    );
  }

  // 检查行程是否已过期
  bool get isExpired {
    final now = DateTime.now();
    return travelDate.isBefore(DateTime(now.year, now.month, now.day));
  }

  // 获取行程状态
  String get status {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final travelDay = DateTime(
      travelDate.year,
      travelDate.month,
      travelDate.day,
    );

    if (travelDay.isBefore(today)) {
      return '已过期';
    } else if (travelDay == today) {
      return '今天';
    } else {
      final difference = travelDay.difference(today).inDays;
      if (difference == 1) {
        return '明天';
      } else {
        return '$difference天后';
      }
    }
  }
}

class StationDetail {
  final String stationName;
  final String arrivalTime;
  final String departureTime;
  final int stayTime;
  final int dayDifference;
  final bool isStart;
  final bool isEnd;
  final double? distance; // 至下站里程（km）

  StationDetail({
    required this.stationName,
    required this.arrivalTime,
    required this.departureTime,
    required this.stayTime,
    required this.dayDifference,
    required this.isStart,
    required this.isEnd,
    this.distance,
  });

  // 从 Map 创建 StationDetail
  factory StationDetail.fromMap(Map<String, dynamic> map) {
    return StationDetail(
      stationName: map['stationName']?.toString() ?? '',
      arrivalTime: map['arrivalTime']?.toString() ?? '--:--',
      departureTime: map['departureTime']?.toString() ?? '--:--',
      stayTime: (map['stayTime'] as num?)?.toInt() ?? 0,
      dayDifference: (map['dayDifference'] as num?)?.toInt() ?? 0,
      isStart: map['isStart'] as bool? ?? false,
      isEnd: map['isEnd'] as bool? ?? false,
      distance: (map['distance'] as num?)?.toDouble(),
    );
  }

  // 转换为 Map（用于持久化存储）
  Map<String, dynamic> toMap() {
    return {
      'stationName': stationName,
      'arrivalTime': arrivalTime,
      'departureTime': departureTime,
      'stayTime': stayTime,
      'dayDifference': dayDifference,
      'isStart': isStart,
      'isEnd': isEnd,
      if (distance != null) 'distance': distance,
    };
  }

  // 获取停留时间描述
  String get stayTimeDescription {
    if (stayTime <= 0) return '通过';
    return '停$stayTime分';
  }

  // 检查是否为通过站（不停车）
  bool get isPassingStation {
    return arrivalTime == '--:--' && departureTime == '--:--';
  }

  // 检查是否为营业站
  bool get isOperatingStation {
    return !isPassingStation;
  }

  // 重写 toString 方法用于调试
  @override
  String toString() {
    return 'StationDetail{stationName: $stationName, arrivalTime: $arrivalTime, departureTime: $departureTime, stayTime: $stayTime, dayDifference: $dayDifference}';
  }

  // 重写 equals 和 hashCode
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is StationDetail &&
          runtimeType == other.runtimeType &&
          stationName == other.stationName &&
          arrivalTime == other.arrivalTime &&
          departureTime == other.departureTime;

  @override
  int get hashCode =>
      stationName.hashCode ^ arrivalTime.hashCode ^ departureTime.hashCode;

  // 复制方法
  StationDetail copyWith({
    String? stationName,
    String? arrivalTime,
    String? departureTime,
    int? stayTime,
    int? dayDifference,
    bool? isStart,
    bool? isEnd,
  }) {
    return StationDetail(
      stationName: stationName ?? this.stationName,
      arrivalTime: arrivalTime ?? this.arrivalTime,
      departureTime: departureTime ?? this.departureTime,
      stayTime: stayTime ?? this.stayTime,
      dayDifference: dayDifference ?? this.dayDifference,
      isStart: isStart ?? this.isStart,
      isEnd: isEnd ?? this.isEnd,
    );
  }
}

// 行程数据验证工具类
class JourneyValidator {
  static bool isValidJourney(Map<String, dynamic> map) {
    try {
      final requiredFields = [
        'id',
        'trainCode',
        'fromStation',
        'toStation',
        'departureTime',
        'arrivalTime',
        'travelDate',
      ];

      for (final field in requiredFields) {
        if (map[field] == null || map[field].toString().isEmpty) {
          return false;
        }
      }

      // 验证日期格式
      DateTime.parse(map['travelDate'] as String);

      return true;
    } catch (e) {
      logError(from: 'journey_model/isValidJourney', error: e.toString());
      return false;
    }
  }

  static bool isValidStationDetail(Map<String, dynamic> map) {
    try {
      if (map['stationName'] == null || map['stationName'].toString().isEmpty) {
        return false;
      }
      return true;
    } catch (e) {
      logError(from: 'journey_model/isValidStationDetail', error: e.toString());
      return false;
    }
  }
}

class JourneyDataMigrator {
  static Map<String, dynamic> migrateFromV1ToV2(Map<String, dynamic> oldData) {
    return oldData;
  }
}
