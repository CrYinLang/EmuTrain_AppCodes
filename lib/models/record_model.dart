// models/record_model.dart
import 'journey_model.dart';

class TrainRecord {
  final String id;
  final String trainCode;
  final String fromStation;
  final String toStation;
  final String fromStationCode;
  final String toStationCode;
  final String departureTime;
  final String arrivalTime;
  final DateTime travelDate;
  final List<RecordStation> stations;
  String seatType;
  String seatInfo;

  // 关联数据
  final List<String> speedRecordIds; // 关联的测速记录ID
  final List<String> imagePaths;     // 关联的图片路径

  TrainRecord({
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
    this.seatType = '',
    this.seatInfo = '',
    this.speedRecordIds = const [],
    this.imagePaths = const [],
  });

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
      'seatType': seatType,
      'seatInfo': seatInfo,
      'speedRecordIds': speedRecordIds,
      'imagePaths': imagePaths,
    };
  }

  factory TrainRecord.fromMap(Map<String, dynamic> map) {
    return TrainRecord(
      id: map['id']?.toString() ?? '',
      trainCode: map['trainCode']?.toString() ?? '',
      fromStation: map['fromStation']?.toString() ?? '',
      toStation: map['toStation']?.toString() ?? '',
      fromStationCode: map['fromStationCode']?.toString() ?? '',
      toStationCode: map['toStationCode']?.toString() ?? '',
      departureTime: map['departureTime']?.toString() ?? '',
      arrivalTime: map['arrivalTime']?.toString() ?? '',
      travelDate: DateTime.tryParse(map['travelDate']?.toString() ?? '') ?? DateTime.now(),
      stations: (map['stations'] as List<dynamic>? ?? [])
          .map((s) => RecordStation.fromMap(s as Map<String, dynamic>))
          .toList(),
      seatType: map['seatType']?.toString() ?? '',
      seatInfo: map['seatInfo']?.toString() ?? '',
      speedRecordIds: (map['speedRecordIds'] as List<dynamic>? ?? [])
          .map((e) => e.toString()).toList(),
      imagePaths: (map['imagePaths'] as List<dynamic>? ?? [])
          .map((e) => e.toString()).toList(),
    );
  }

  // 转换为 Journey 对象（用于调用 LineMapContent）
  Journey toJourney() {
    return Journey(
      id: id,
      trainCode: trainCode,
      fromStation: fromStation,
      toStation: toStation,
      fromStationCode: fromStationCode,
      toStationCode: toStationCode,
      departureTime: departureTime,
      arrivalTime: arrivalTime,
      travelDate: travelDate,
      stations: stations.map((s) => StationDetail(
        stationName: s.stationName,
        arrivalTime: s.arrivalTime,
        departureTime: s.departureTime,
        stayTime: s.stayTime,
        dayDifference: s.dayDifference,
        isStart: s.isStart,
        isEnd: s.isEnd,
      )).toList(),
    );
  }

  /// 从搜索结果直接创建 TrainRecord（不经过 Journey）
  factory TrainRecord.fromSearchResult({
    required Map<String, dynamic> trainInfo,
    required DateTime date,
    required List<dynamic> stationList,
    required bool isStation,
    required String fromStation,
    required String toStation,
    required String seatType,
    required String seatInfo,
  }) {
    // 构建站点列表
    final allStations = stationList.map((s) {
      return RecordStation(
        stationName: s['stationName']?.toString() ?? '',
        arrivalTime: s['arriveTime']?.toString() ?? '--:--',
        departureTime: s['departTime']?.toString() ?? '--:--',
        stayTime: int.tryParse(s['stayTime']?.toString() ?? '0') ?? 0,
        dayDifference: int.tryParse(s['DayDifference']?.toString() ?? '0') ?? 0,
        isStart: s['isFirst'] == true,
        isEnd: s['isLast'] == true,
      );
    }).toList();

    // 确定实际上下车站和时间
    String actualFromStation = fromStation;
    String actualToStation = toStation;
    String actualDepartureTime = '';
    String actualArrivalTime = '';

    if (fromStation == toStation && allStations.isNotEmpty) {
      actualFromStation = allStations.first.stationName;
      actualToStation = allStations.last.stationName;
      actualDepartureTime = allStations.first.departureTime;
      actualArrivalTime = allStations.last.arrivalTime;
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

    if (actualFromStation.isEmpty && allStations.isNotEmpty) {
      actualFromStation = allStations.first.stationName;
    }
    if (actualToStation.isEmpty && allStations.isNotEmpty) {
      actualToStation = allStations.last.stationName;
    }

    return TrainRecord(
      id: 'rec_${DateTime.now().millisecondsSinceEpoch}',
      trainCode: trainInfo['station_train_code']?.toString() ?? '',
      fromStation: actualFromStation,
      toStation: actualToStation,
      fromStationCode: trainInfo['from_station_code']?.toString() ?? '',
      toStationCode: trainInfo['to_station_code']?.toString() ?? '',
      departureTime: actualDepartureTime,
      arrivalTime: actualArrivalTime,
      travelDate: date,
      stations: allStations,
      seatType: seatType,
      seatInfo: seatInfo,
    );
  }

  // 从 Journey 创建 TrainRecord
  factory TrainRecord.fromJourney(Journey j) {
    return TrainRecord(
      id: 'rec_${DateTime.now().millisecondsSinceEpoch}',
      trainCode: j.trainCode,
      fromStation: j.fromStation,
      toStation: j.toStation,
      fromStationCode: j.fromStationCode,
      toStationCode: j.toStationCode,
      departureTime: j.departureTime,
      arrivalTime: j.arrivalTime,
      travelDate: j.travelDate,
      stations: j.stations.map((s) => RecordStation(
        stationName: s.stationName,
        arrivalTime: s.arrivalTime,
        departureTime: s.departureTime,
        stayTime: s.stayTime,
        dayDifference: s.dayDifference,
        isStart: s.isStart,
        isEnd: s.isEnd,
      )).toList(),
    );
  }

  String getFormattedDate() {
    return '${travelDate.year}-${travelDate.month.toString().padLeft(2, '0')}-${travelDate.day.toString().padLeft(2, '0')}';
  }

  String getTotalDuration() {
    if (departureTime.isEmpty || arrivalTime.isEmpty) return '--';
    final depParts = departureTime.split(':');
    final arrParts = arrivalTime.split(':');
    if (depParts.length < 2 || arrParts.length < 2) return '--';
    final depMin = (int.tryParse(depParts[0]) ?? 0) * 60 + (int.tryParse(depParts[1]) ?? 0);
    final arrMin = (int.tryParse(arrParts[0]) ?? 0) * 60 + (int.tryParse(arrParts[1]) ?? 0);
    var diff = arrMin - depMin;
    if (diff < 0) diff += 1440;
    final h = diff ~/ 60;
    final m = diff % 60;
    return '${h}h${m.toString().padLeft(2, '0')}m';
  }
}

class RecordStation {
  final String stationName;
  final String arrivalTime;
  final String departureTime;
  final int stayTime;
  final int dayDifference;
  final bool isStart;
  final bool isEnd;

  RecordStation({
    required this.stationName,
    required this.arrivalTime,
    required this.departureTime,
    this.stayTime = 0,
    this.dayDifference = 0,
    this.isStart = false,
    this.isEnd = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'stationName': stationName,
      'arrivalTime': arrivalTime,
      'departureTime': departureTime,
      'stayTime': stayTime,
      'dayDifference': dayDifference,
      'isStart': isStart,
      'isEnd': isEnd,
    };
  }

  factory RecordStation.fromMap(Map<String, dynamic> map) {
    return RecordStation(
      stationName: map['stationName']?.toString() ?? '',
      arrivalTime: map['arrivalTime']?.toString() ?? '--:--',
      departureTime: map['departureTime']?.toString() ?? '--:--',
      stayTime: int.tryParse(map['stayTime']?.toString() ?? '0') ?? 0,
      dayDifference: int.tryParse(map['dayDifference']?.toString() ?? '0') ?? 0,
      isStart: map['isStart'] == true,
      isEnd: map['isEnd'] == true,
    );
  }
}

class SpeedRecord {
  final String id;
  final String recordId;     // 关联的 TrainRecord ID
  final DateTime startTime;
  final DateTime endTime;
  final double maxSpeed;     // km/h
  final double totalDistance; // km
  final int durationSeconds;
  final List<SpeedPoint> points;

  SpeedRecord({
    required this.id,
    required this.recordId,
    required this.startTime,
    required this.endTime,
    required this.maxSpeed,
    required this.totalDistance,
    required this.durationSeconds,
    required this.points,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'recordId': recordId,
      'startTime': startTime.toIso8601String(),
      'endTime': endTime.toIso8601String(),
      'maxSpeed': maxSpeed,
      'totalDistance': totalDistance,
      'durationSeconds': durationSeconds,
      'points': points.map((p) => p.toMap()).toList(),
    };
  }

  factory SpeedRecord.fromMap(Map<String, dynamic> map) {
    return SpeedRecord(
      id: map['id']?.toString() ?? '',
      recordId: map['recordId']?.toString() ?? '',
      startTime: DateTime.tryParse(map['startTime']?.toString() ?? '') ?? DateTime.now(),
      endTime: DateTime.tryParse(map['endTime']?.toString() ?? '') ?? DateTime.now(),
      maxSpeed: (map['maxSpeed'] as num?)?.toDouble() ?? 0,
      totalDistance: (map['totalDistance'] as num?)?.toDouble() ?? 0,
      durationSeconds: map['durationSeconds'] as int? ?? 0,
      points: (map['points'] as List<dynamic>? ?? [])
          .map((p) => SpeedPoint.fromMap(p as Map<String, dynamic>))
          .toList(),
    );
  }

  String getFormattedDuration() {
    final h = durationSeconds ~/ 3600;
    final m = (durationSeconds % 3600) ~/ 60;
    final s = durationSeconds % 60;
    if (h > 0) return '${h}h${m.toString().padLeft(2, '0')}m${s.toString().padLeft(2, '0')}s';
    if (m > 0) return '${m}m${s.toString().padLeft(2, '0')}s';
    return '${s}s';
  }
}

class SpeedPoint {
  final double latitude;
  final double longitude;
  final double speed; // km/h
  final DateTime timestamp;

  SpeedPoint({
    required this.latitude,
    required this.longitude,
    required this.speed,
    required this.timestamp,
  });

  Map<String, dynamic> toMap() {
    return {
      'latitude': latitude,
      'longitude': longitude,
      'speed': speed,
      'timestamp': timestamp.toIso8601String(),
    };
  }

  factory SpeedPoint.fromMap(Map<String, dynamic> map) {
    return SpeedPoint(
      latitude: (map['latitude'] as num?)?.toDouble() ?? 0,
      longitude: (map['longitude'] as num?)?.toDouble() ?? 0,
      speed: (map['speed'] as num?)?.toDouble() ?? 0,
      timestamp: DateTime.tryParse(map['timestamp']?.toString() ?? '') ?? DateTime.now(),
    );
  }
}
