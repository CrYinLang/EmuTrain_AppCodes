// journey_search_ext.dart
// AddJourneyPage 的搜索相关 extension

part of 'journey.dart';

extension JourneySearchExt on _AddJourneyPageState {
  Future<void> _searchTrain() async {
    if (_selectedDate == null) {
      _showSnack('请先选择日期');
      return;
    }
    final trainNumber = _trainNumberCtrl.text.trim();
    if (trainNumber.isEmpty) {
      _showSnack('请输入车次');
      return;
    }

    setState(() => _loading = true);
    _trainResults.clear();
    _trainDetails.clear();
    _trainLoading.clear();
    _expandedIndex = null;
    if (_animCtrl.isAnimating) _animCtrl.reset();

    try {
      final settings = Provider.of<AppSettings>(context, listen: false);
      final dataSource = settings.dataSource;

      List<dynamic> results;
      if (dataSource == TrainDataSource.railRe) {
        results = await _searchTrainRailRe(trainNumber);
      } else {
        results = await _searchTrain12306(trainNumber);
      }

      if (!mounted) return;

      setState(() {
        _trainResults = results;
        _loading = false;
        _trainCurrentPage = 1;
        _trainPageCtrl.text = '1';
      });

      if (results.isEmpty) {
        _showSnack('未找到车次 $trainNumber 的信息');
      }
    } catch (e) {
      logError(from: 'journey/_searchTrain', error: e.toString());
      if (mounted) {
        setState(() => _loading = false);
        _showSnack('查询失败: $e');
      }
    }
  }

  Future<List<dynamic>> _searchTrainRailRe(String trainNumber) async {
    final url = Uri.parse(
      'https://rail.re/api/train/${trainNumber.toUpperCase()}?date=${_formattedDate}',
    );
    final response = await http.get(url);
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      if (data is List && data.isNotEmpty) {
        return data;
      }
    }
    return [];
  }

  Future<List<dynamic>> _searchTrain12306(String trainNumber) async {
    final url =
        'https://search.12306.cn/search/v1/train/search?keyword=$trainNumber&date=$_formattedDate';
    final response = await http.get(Uri.parse(url));
    if (response.statusCode != 200) return [];

    Map<String, dynamic> data;
    try {
      data = json.decode(response.body);
    } catch (_) {
      return [];
    }

    if (data['status'] == true) {
      final allResults = data['data'] ?? [];
      return allResults.length > 15
          ? allResults.sublist(0, 15)
          : allResults;
    }
    return [];
  }

  Future<void> _searchStation() async {
    if (_fromCode == null || _toCode == null) {
      _showSnack('请选择出发站和到达站');
      return;
    }
    if (_selectedDate == null) {
      _showSnack('请先选择日期');
      return;
    }

    setState(() => _loading = true);
    _stationResults.clear();
    _stationDetails.clear();
    _stationLoading.clear();
    _stationExpandedIndex = null;
    _trainTypeFilters.clear();
    _filterFromStation = null;
    _filterToStation = null;
    _fromStationOptions.clear();
    _toStationOptions.clear();
    _filterExpanded = false;
    if (_animCtrl.isAnimating) _animCtrl.reset();

    try {
      final settings = Provider.of<AppSettings>(context, listen: false);
      final dataSource = settings.dataSource;

      List<dynamic> results;
      if (dataSource == TrainDataSource.railRe) {
        results = await _searchStationRailRe();
      } else {
        results = await _searchStation12306();
      }

      if (!mounted) return;

      setState(() {
        _stationResults = results;
        _loading = false;
        _stationCurrentPage = 1;
        _stationPageCtrl.text = '1';
        if (results.isNotEmpty) {
          _updateTrainTypeFilters(results);
        }
      });

      if (results.isEmpty) {
        _showSnack('未找到 $_fromName 到 $_toName 的车次');
      }
    } catch (e) {
      logError(from: 'journey/_searchStation', error: e.toString());
      if (mounted) {
        setState(() => _loading = false);
        _showSnack('查询失败: $e');
      }
    }
  }

  Future<List<dynamic>> _searchStationRailRe() async {
    final url = Uri.parse(
      'https://rail.re/api/station/$_fromCode/$_toCode?date=$_formattedDate',
    );
    final response = await http.get(url);
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      if (data is List && data.isNotEmpty) {
        return data;
      }
    }
    return [];
  }

  Future<List<dynamic>> _searchStation12306() async {
    final stationDay =
        '${_formattedDate.substring(0, 4)}-${_formattedDate.substring(4, 6)}-${_formattedDate.substring(6, 8)}';

    final headers = {
      'User-Agent':
          'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/147.0.0.0 Safari/537.36 Edg/147.0.0.0',
      'Referer': 'https://kyfw.12306.cn/otn/leftTicket/init',
    };

    // 优先用 query，失败再 fallback 到 queryG
    var results = await _tryTicketQuery(
      'https://kyfw.12306.cn/otn/leftTicket/query?leftTicketDTO.train_date=$stationDay&leftTicketDTO.from_station=$_fromCode&leftTicketDTO.to_station=$_toCode&purpose_codes=ADULT',
      headers,
    );
    if (results.isEmpty) {
      results = await _tryTicketQuery(
        'https://kyfw.12306.cn/otn/leftTicket/queryG?leftTicketDTO.train_date=$stationDay&leftTicketDTO.from_station=$_fromCode&leftTicketDTO.to_station=$_toCode&purpose_codes=ADULT',
        headers,
      );
    }
    return results;
  }

  Future<List<dynamic>> _tryTicketQuery(
    String ticketUrl,
    Map<String, String> headers,
  ) async {
    final stationDay =
        '${_formattedDate.substring(0, 4)}-${_formattedDate.substring(4, 6)}-${_formattedDate.substring(6, 8)}';
    final priceUrl =
        'https://kyfw.12306.cn/otn/leftTicketPrice/queryAllPublicPrice?leftTicketDTO.train_date=$stationDay&leftTicketDTO.from_station=$_fromCode&leftTicketDTO.to_station=$_toCode&purpose_codes=ADULT';

    final responses = await Future.wait([
      http.get(Uri.parse(ticketUrl), headers: headers),
      http.get(Uri.parse(priceUrl), headers: headers),
    ]);
    final ticketResponse = responses[0];
    final priceResponse = responses[1];

    if (ticketResponse.statusCode != 200) return [];

    // 确保返回的是合法 JSON 而不是 HTML 错误页面
    Map<String, dynamic> data;
    try {
      data = json.decode(ticketResponse.body);
    } catch (_) {
      return [];
    }

    if (data['httpstatus'] != 200 || data['data'] == null) return [];
    if (data['data']['result'] == null) return [];

    final List<dynamic> result = data['data']['result'];
    final Map<String, dynamic> stationMap = data['data']['map'] ?? {};

    // 解析价格信息
    Map<String, dynamic> priceMap = {};
    if (priceResponse.statusCode == 200) {
      try {
        final priceData = json.decode(priceResponse.body);
        if (priceData['data'] != null) {
          priceMap = priceData['data'];
        }
      } catch (_) {}
    }

    return result.map((item) {
      final parts = item.toString().split('|');
      if (parts.length < 32) return <String, dynamic>{};
      final trainNo = parts[2];
      final priceInfo = priceMap[trainNo] ?? {};
      return {
        'station_train_code': parts[3],
        'from_station': stationMap[parts[6]] ?? parts[6],
        'to_station': stationMap[parts[7]] ?? parts[7],
        'start_time': parts[8],
        'arrive_time': parts[9],
        'run_time': parts[10],
        'can_buy': parts[11] == 'Y',
        'train_no': trainNo,
        'from_station_code': parts[6],
        'to_station_code': parts[7],
        'ze_price': priceInfo['ze_price'] ?? parts[26],
        'zy_price': priceInfo['zy_price'] ?? parts[25],
        'swz_price': priceInfo['swz_price'] ?? parts[24],
        'yz_price': priceInfo['yz_price'] ?? parts[29],
        'rw_price': priceInfo['rw_price'] ?? parts[23],
        'yw_price': priceInfo['yw_price'] ?? parts[28],
        'wz_price': parts[30],
        'rz_price': parts[21],
        'train_class_name': parts[1],
      };
    }).toList();
  }

  Future<void> _fetchDetails(int index, bool isStation) async {
    final results = isStation ? _stationResults : _trainResults;
    if (index >= results.length) return;

    final item = results[index];
    final trainCode = item['station_train_code']?.toString() ?? '';

    setState(() {
      if (isStation) {
        _stationLoading[index] = true;
      } else {
        _trainLoading[index] = true;
      }
    });

    try {
      final stops = await _fetchStopInfo(trainCode);

      if (!mounted) return;

      setState(() {
        if (isStation) {
          _stationDetails[index] = stops;
          _stationLoading[index] = false;
        } else {
          _trainDetails[index] = stops;
          _trainLoading[index] = false;
        }
      });
    } catch (e) {
      logError(from: 'journey/_fetchDetails', error: e.toString());
      if (mounted) {
        setState(() {
          if (isStation) {
            _stationLoading[index] = false;
          } else {
            _trainLoading[index] = false;
          }
        });
      }
    }
  }

  Future<List<dynamic>> _fetchStopInfo(String trainNumber) async {
    final settings = Provider.of<AppSettings>(context, listen: false);
    switch (settings.dataStationSource) {
      case TrainStationDataSource.moeFactory:
        return await _fetchStopInfoSharyou(trainNumber);
      default:
        return await _fetchStopInfoCtrip(trainNumber);
    }
  }

  Future<List<dynamic>> _fetchStopInfoSharyou(String trainNumber) async {
    if (_sharyouCache.containsKey(trainNumber)) {
      final cached = _sharyouCache[trainNumber]!;
      final List<dynamic> viaStations =
          cached['viaStations'] as List<dynamic>? ?? [];
      return _mapViaStations(viaStations);
    }

    await _fetchAndCacheSharyou(trainNumber, _formattedDate);

    if (!_sharyouCache.containsKey(trainNumber)) return [];

    final List<dynamic> viaStations =
        _sharyouCache[trainNumber]!['viaStations'] as List<dynamic>? ?? [];
    return _mapViaStations(viaStations);
  }

  Future<void> _fetchAndCacheSharyou(String trainCode, String date) async {
    try {
      const baseUrl = 'https://sharyou.moefactory.com/api/trainNumber/query';
      final sharyouHeaders = {
        'Content-Type': 'application/x-www-form-urlencoded',
        'Accept': 'application/json, text/plain, */*',
        'User-Agent':
            'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/147.0.0.0 Safari/537.36 Edg/147.0.0.0',
      };

      final resp1 = await http
          .post(
            Uri.parse(baseUrl),
            headers: sharyouHeaders,
            body: 'date=$date&trainNumber=$trainCode&cursor=0&count=15',
          )
          .timeout(const Duration(seconds: 10));

      if (resp1.statusCode != 200) return;
      final data1 = json.decode(resp1.body);
      if (data1['code'] != 200) return;

      final List<dynamic> trainList = data1['data']['data'] ?? [];
      if (trainList.isEmpty) return;

      final int trainIndex = trainList.first['trainIndex'];

      final resp2 = await http
          .post(
            Uri.parse('https://sharyou.moefactory.com/api/trainDetails/query'),
            headers: sharyouHeaders,
            body: 'trainIndex=$trainIndex&includeCheckoutNames=true&date=$date',
          )
          .timeout(const Duration(seconds: 10));

      if (resp2.statusCode != 200) return;
      final data2 = json.decode(resp2.body);
      if (data2['code'] != 200) return;

      final routing = data2['data']['routing'] as Map<String, dynamic>? ?? {};
      if (mounted) {
        setState(() {
          _sharyouCache[trainCode] = {
            'viaStations': data2['data']['viaStations'] ?? [],
            'routingItems': routing['routingItems'] ?? [],
            'trainModel': routing['trainModel'] ?? '',
          };
        });
      }
    } catch (e) {
      logError(from: 'journey/_fetchAndCacheSharyou', error: e.toString());
    }
  }

  List<dynamic> _mapViaStations(List<dynamic> viaStations) {
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

  Future<List<dynamic>> _fetchStopInfoCtrip(String trainNumber) async {
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
    final body = {'TrainNumber': trainNumber, 'DepartDate': _formattedDate};
    try {
      final response = await http.post(
        url,
        headers: headers,
        body: json.encode(body),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['RetCode'] == 1 && data['StopList'] != null) {
          final List<dynamic> stopList = data['StopList'];
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
      logError(from: 'journey/_fetchStopInfoCtrip', error: e.toString());
      rethrow;
    }
  }
}
