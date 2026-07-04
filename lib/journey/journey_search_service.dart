// journey_search_service.dart
// 车次/车站查询服务层，封装所有 API 调用逻辑

import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../widgets/error.dart';

/// 车次查询服务
class JourneySearchService {
  /// 从 Ctrip 获取车次信息
  static Future<List<dynamic>> searchTrainByNumber({
    required String trainNumber,
    required String date,
  }) async {
    final url = Uri.parse(
      'https://m.ctrip.com/restapi/soa2/14674/json/GetTrainStopTimeInfo',
    );
    final headers = {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      'User-Agent':
          'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36',
      'Referer': 'https://m.ctrip.com/',
      'Origin': 'https://m.ctrip.com',
    };
    final body = {'TrainNumber': trainNumber, 'DepartDate': date};

    try {
      final response = await http.post(
        url,
        headers: headers,
        body: json.encode(body),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['RetCode'] == 1 && data['StopList'] != null) {
          return data['StopList'];
        } else if (data['RetCode'] != 1) {
          throw Exception(
            'API 返回失败：RetCode=${data['RetCode']}, Ack=${data['ResponseStatus']?['Ack']}',
          );
        } else {
          return [];
        }
      } else {
        throw Exception('HTTP 请求失败：${response.statusCode}');
      }
    } catch (e) {
      logError(from: 'journey_search/searchTrainByNumber', error: e.toString());
      rethrow;
    }
  }

  /// 从 Ctrip 获取车站车次列表
  static Future<List<dynamic>> searchTrainByStation({
    required String fromStation,
    required String toStation,
    required String date,
  }) async {
    final url = Uri.parse(
      'https://m.ctrip.com/restapi/soa2/12685/json/GetTrainList',
    );
    final headers = {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      'User-Agent':
          'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36',
      'Referer': 'https://m.ctrip.com/',
      'Origin': 'https://m.ctrip.com',
    };
    final body = {
      'FromStation': fromStation,
      'ToStation': toStation,
      'DepartDate': date,
    };

    try {
      final response = await http.post(
        url,
        headers: headers,
        body: json.encode(body),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['RetCode'] == 1 && data['TrainList'] != null) {
          return data['TrainList'];
        } else if (data['RetCode'] != 1) {
          throw Exception(
            'API 返回失败：RetCode=${data['RetCode']}, Ack=${data['ResponseStatus']?['Ack']}',
          );
        } else {
          return [];
        }
      } else {
        throw Exception('HTTP 请求失败：${response.statusCode}');
      }
    } catch (e) {
      logError(from: 'journey_search/searchTrainByStation', error: e.toString());
      rethrow;
    }
  }

  /// 从 Sharyou 获取交路信息
  static Future<Map<String, dynamic>?> fetchSharyouRouting({
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
      logError(from: 'journey_search/fetchSharyouRouting', error: e.toString());
      return null;
    }
  }

  /// 格式化停站信息（Ctrip 格式）
  static List<dynamic> formatCtripStops(List<dynamic> stopList) {
    return stopList
        .map(
          (stop) => {
            'stationNo': stop['StationNo'] ?? '',
            'stationName': _cleanStationName(stop['StationName']),
            'arriveTime': stop['ArriveTime'] ?? '--:--',
            'departTime': stop['DepartTime'] ?? '--:--',
            'stayTime': stop['StayWayStationTime'] ?? '0',
            'distance': stop['distance'] ?? '0',
            'DayDifference': stop['DayDifference'] ?? 0,
            'telCode': stop['TelCode'] ?? '',
            'isFirst': stop['StationNo'] == '01',
            'isLast':
                stop['StationNo'] ==
                stopList.length.toString().padLeft(2, '0'),
          },
        )
        .toList();
  }

  /// 格式化停站信息（Sharyou viaStations 格式）
  static List<dynamic> formatSharyouStops(List<dynamic> viaStations) {
    return viaStations.asMap().entries.map((entry) {
      final index = entry.key;
      final stop = entry.value;
      return {
        'stationNo': (index + 1).toString().padLeft(2, '0'),
        'stationName': stop['stationName'] ?? '',
        'arriveTime': stop['arrivalTime'] ?? '--:--',
        'departTime': stop['departureTime'] ?? '--:--',
        'stayTime': stop['stopMinutes']?.toString() ?? '0',
        'distance': stop['distance']?.toString() ?? '0',
        'DayDifference': stop['dayIndex'] ?? 0,
        'telCode': stop['stationTelegramCode'] ?? '',
        'isFirst': index == 0,
        'isLast': index == viaStations.length - 1,
      };
    }).toList();
  }

  static String _cleanStationName(String name) {
    return name.replaceAll(' ', '');
  }
}
