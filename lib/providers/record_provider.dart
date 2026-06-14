// providers/record_provider.dart
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import '../models/record_model.dart';
import '../screens/function/error.dart';

class RecordProvider extends ChangeNotifier {
  final List<TrainRecord> _records = [];
  final List<SpeedRecord> _speedRecords = [];
  String? _dataDir;

  List<TrainRecord> get records => List.unmodifiable(_records);
  List<SpeedRecord> get speedRecords => List.unmodifiable(_speedRecords);

  RecordProvider() {
    _init();
  }

  Future<void> _init() async {
    final dir = await getApplicationDocumentsDirectory();
    _dataDir = '${dir.path}/train_records';
    await Directory(_dataDir!).create(recursive: true);
    await _loadRecords();
    await _loadSpeedRecords();
  }

  String get _recordsFile => '$_dataDir/train_record.json';
  String get _speedFile => '$_dataDir/speed_records.json';

  Future<void> _loadRecords() async {
    try {
      final file = File(_recordsFile);
      if (await file.exists()) {
        final jsonStr = await file.readAsString();
        final List<dynamic> list = json.decode(jsonStr);
        _records.clear();
        _records.addAll(list.map((m) => TrainRecord.fromMap(m as Map<String, dynamic>)));
        notifyListeners();
      }
    } catch (e, stack) {
      await logError(from: 'RecordProvider._loadRecords', error: e.toString(), level: 3);
      if (kDebugMode) print('loadRecords error: $e\n$stack');
    }
  }

  Future<void> _saveRecords() async {
    try {
      final file = File(_recordsFile);
      await file.writeAsString(json.encode(_records.map((r) => r.toMap()).toList()));
    } catch (e) {
      await logError(from: 'RecordProvider._saveRecords', error: e.toString(), level: 3);
    }
  }

  Future<void> _loadSpeedRecords() async {
    try {
      final file = File(_speedFile);
      if (await file.exists()) {
        final jsonStr = await file.readAsString();
        final List<dynamic> list = json.decode(jsonStr);
        _speedRecords.clear();
        _speedRecords.addAll(list.map((m) => SpeedRecord.fromMap(m as Map<String, dynamic>)));
        notifyListeners();
      }
    } catch (e) {
      await logError(from: 'RecordProvider._loadSpeedRecords', error: e.toString(), level: 3);
    }
  }

  Future<void> _saveSpeedRecords() async {
    try {
      final file = File(_speedFile);
      await file.writeAsString(json.encode(_speedRecords.map((r) => r.toMap()).toList()));
    } catch (e) {
      await logError(from: 'RecordProvider._saveSpeedRecords', error: e.toString(), level: 3);
    }
  }

  void addRecord(TrainRecord record) {
    _records.add(record);
    _saveRecords();
    notifyListeners();
  }

  void removeRecord(String id) {
    _records.removeWhere((r) => r.id == id);
    _speedRecords.removeWhere((s) => s.recordId == id);
    _saveRecords();
    _saveSpeedRecords();
    notifyListeners();
  }

  void updateRecord(TrainRecord record) {
    final idx = _records.indexWhere((r) => r.id == record.id);
    if (idx >= 0) {
      _records[idx] = record;
      _saveRecords();
      notifyListeners();
    }
  }

  void addSpeedRecord(SpeedRecord record) {
    _speedRecords.add(record);
    final idx = _records.indexWhere((r) => r.id == record.recordId);
    if (idx >= 0) {
      final r = _records[idx];
      final updated = TrainRecord(
        id: r.id, trainCode: r.trainCode,
        fromStation: r.fromStation, toStation: r.toStation,
        fromStationCode: r.fromStationCode, toStationCode: r.toStationCode,
        departureTime: r.departureTime, arrivalTime: r.arrivalTime,
        travelDate: r.travelDate, stations: r.stations,
        seatType: r.seatType, seatInfo: r.seatInfo,
        speedRecordIds: [...r.speedRecordIds, record.id],
        imagePaths: r.imagePaths,
      );
      _records[idx] = updated;
      _saveRecords();
    }
    _saveSpeedRecords();
    notifyListeners();
  }

  List<SpeedRecord> getSpeedRecordsForRecord(String recordId) {
    return _speedRecords.where((s) => s.recordId == recordId).toList();
  }

  void addImageToRecord(String recordId, String imagePath) {
    final idx = _records.indexWhere((r) => r.id == recordId);
    if (idx >= 0) {
      final r = _records[idx];
      final updated = TrainRecord(
        id: r.id, trainCode: r.trainCode,
        fromStation: r.fromStation, toStation: r.toStation,
        fromStationCode: r.fromStationCode, toStationCode: r.toStationCode,
        departureTime: r.departureTime, arrivalTime: r.arrivalTime,
        travelDate: r.travelDate, stations: r.stations,
        seatType: r.seatType, seatInfo: r.seatInfo,
        speedRecordIds: r.speedRecordIds,
        imagePaths: [...r.imagePaths, imagePath],
      );
      _records[idx] = updated;
      _saveRecords();
      notifyListeners();
    }
  }

  void addSpeedRecordToRecord(String recordId, String trackId) {
    final idx = _records.indexWhere((r) => r.id == recordId);
    if (idx >= 0) {
      final r = _records[idx];
      if (r.speedRecordIds.contains(trackId)) return;
      final updated = TrainRecord(
        id: r.id, trainCode: r.trainCode,
        fromStation: r.fromStation, toStation: r.toStation,
        fromStationCode: r.fromStationCode, toStationCode: r.toStationCode,
        departureTime: r.departureTime, arrivalTime: r.arrivalTime,
        travelDate: r.travelDate, stations: r.stations,
        seatType: r.seatType, seatInfo: r.seatInfo,
        speedRecordIds: [...r.speedRecordIds, trackId],
        imagePaths: r.imagePaths,
      );
      _records[idx] = updated;
      _saveRecords();
      notifyListeners();
    }
  }

  void removeSpeedRecordFromRecord(String recordId, String trackId) {
    final idx = _records.indexWhere((r) => r.id == recordId);
    if (idx >= 0) {
      final r = _records[idx];
      final updated = TrainRecord(
        id: r.id, trainCode: r.trainCode,
        fromStation: r.fromStation, toStation: r.toStation,
        fromStationCode: r.fromStationCode, toStationCode: r.toStationCode,
        departureTime: r.departureTime, arrivalTime: r.arrivalTime,
        travelDate: r.travelDate, stations: r.stations,
        seatType: r.seatType, seatInfo: r.seatInfo,
        speedRecordIds: r.speedRecordIds.where((id) => id != trackId).toList(),
        imagePaths: r.imagePaths,
      );
      _records[idx] = updated;
      _saveRecords();
      notifyListeners();
    }
  }

  void clearAll() {
    _records.clear();
    _speedRecords.clear();
    _saveRecords();
    _saveSpeedRecords();
    notifyListeners();
  }
}
