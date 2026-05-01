
part of 'ui/journey.dart';

extension _JourneyData on _AddJourneyPageState {
  Future<void> _loadStations() async {
    setState(() => _loadingStations = true);
    try {
      final stationsList = await DataFileHelper.loadStations();

      final Map<String, String> nameMap = {};
      for (var station in stationsList) {
        final telecode = station['telecode'];
        final name = station['name'];
        if (telecode != null && name != null) {
          nameMap[telecode] = name;
        }
      }

      setState(() {
        _allStations = stationsList;
        _stationNameMap = nameMap;
      });
    } catch (e) {
      _showSnack('加载站点数据失败: $e');
    } finally {
      setState(() => _loadingStations = false);
    }
  }

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

    setState(() {
      _loading = true;
      _trainResults.clear();
      _trainDetails.clear();
      _trainLoading.clear();
      _sharyouCache.clear();
      _expandedIndex = null;
      if (_animCtrl.isAnimating) _animCtrl.reset();
    });

    try {
      final url =
          'https://search.12306.cn/search/v1/train/search?keyword=$trainNumber&date=$_formattedDate';
      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        if (data['status'] == true) {
          final allResults = data['data'] ?? [];
          final limitedResults = allResults.length > 15
              ? allResults.sublist(0, 15)
              : allResults;

          setState(() => _trainResults = limitedResults);

          // ==================== 自动展开逻辑（关键修复） ====================
          if (widget.autoSearchAndExpand && limitedResults.isNotEmpty) {
            if (limitedResults.length == 1) {
              // 只有一条结果时：自动展开 + 加载详情 + 禁止收回
              setState(() => _expandedIndex = 0);
              _animCtrl.forward();
              await _fetchDetails(0, false); // 加载停站信息
            } else {
              // 多条结果时：只自动展开第一条（可选），不强制禁止收回
              setState(() => _expandedIndex = 0);
              _animCtrl.forward();
              await _fetchDetails(0, false);
            }
          }
          // =================================================================

          _showSnack(
            _trainResults.isEmpty
                ? '未找到相关车次信息'
                : '找到 ${_trainResults.length} 条结果',
          );
        } else {
          _showSnack('搜索失败: ${data['errorMsg'] ?? '未知错误'}');
        }
      } else {
        _showSnack('网络请求失败: ${response.statusCode}');
      }
    } catch (e) {
      _showSnack('发生错误: $e');
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<String> _getBenWu(String trainCode, String date) async {
    if (!RegExp(r'^[GDCS]', caseSensitive: false).hasMatch(trainCode)) {
      return '';
    }

    // 优先从缓存取
    if (_sharyouCache.containsKey(trainCode)) {
      return _extractTrainModel(_sharyouCache[trainCode]!['trainModel']);
    }

    // 缓存未命中时，走完整 sharyou 流程并缓存结果
    try {
      await _fetchAndCacheSharyou(trainCode, date);
      if (_sharyouCache.containsKey(trainCode)) {
        return _extractTrainModel(_sharyouCache[trainCode]!['trainModel']);
      }
    } catch (_) {}
    return '未知';
  }

  String _extractTrainModel(dynamic trainModel) {
    if (trainModel == null) return '未知';
    String model = trainModel.toString();
    if (model.isEmpty) return '未知';
    String result = model.substring(0, model.length > 14 ? 14 : model.length);
    final commaIndex = result.indexOf(',');
    final chineseCommaIndex = result.indexOf('，');
    if (commaIndex != -1) {
      result = result.substring(0, commaIndex);
    } else if (chineseCommaIndex != -1) {
      result = result.substring(0, chineseCommaIndex);
    }
    return result.isNotEmpty ? result : '未知';
  }

  Future<void> _fetchAndCacheSharyou(String trainCode, String date) async {
    const baseUrl = 'https://sharyou.moefactory.com/api/trainNumber/query';
    final headers = {
      'Content-Type': 'application/x-www-form-urlencoded',
      'Accept': 'application/json, text/plain, */*',
      'User-Agent':
          'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
          '(KHTML, like Gecko) Chrome/147.0.0.0 Safari/537.36 Edg/147.0.0.0',
    };

    final resp1 = await http
        .post(
          Uri.parse(baseUrl),
          headers: headers,
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
          headers: headers,
          body: 'trainIndex=$trainIndex&includeCheckoutNames=true&date=$date',
        )
        .timeout(const Duration(seconds: 10));

    if (resp2.statusCode != 200) return;
    final data2 = json.decode(resp2.body);
    if (data2['code'] != 200) return;

    final routing = data2['data']['routing'] as Map<String, dynamic>? ?? {};
    _sharyouCache[trainCode] = {
      'trainModel': routing['trainModel'],
      'routingItems': routing['routingItems'] ?? [],
      'viaStations': data2['data']['viaStations'] ?? [],
    };
  }

  Future<void> _searchStation() async {
    if (_selectedDate == null) {
      _showSnack('请先选择日期');
      return;
    }
    if (_fromCode == null || _toCode == null) {
      _showSnack('请选择起始站和终点站');
      return;
    }

    setState(() {
      _loading = true;
      _stationResults.clear();
      _stationDetails.clear();
      _stationLoading.clear();
      _stationExpandedIndex = null;
      if (_animCtrl.isAnimating) _animCtrl.reset();
    });

    try {
      final stationDay =
          '${_formattedDate.substring(0, 4)}-${_formattedDate.substring(4, 6)}-${_formattedDate.substring(6, 8)}';

      // 同时请求余票查询和价格查询
      final ticketFuture = http.get(
        Uri.parse(
          'https://kyfw.12306.cn/otn/leftTicket/queryG?leftTicketDTO.train_date=$stationDay&leftTicketDTO.from_station=$_fromCode&leftTicketDTO.to_station=$_toCode&purpose_codes=ADULT',
        ),
        headers: _getApiHeaders(),
      );

      final priceFuture = http.get(
        Uri.parse(
          'https://kyfw.12306.cn/otn/leftTicketPrice/queryAllPublicPrice?leftTicketDTO.train_date=$stationDay&leftTicketDTO.from_station=$_fromCode&leftTicketDTO.to_station=$_toCode&purpose_codes=ADULT',
        ),
        headers: _getApiHeaders(),
      );

      // 等待两个请求完成
      final responses = await Future.wait([ticketFuture, priceFuture]);
      final ticketResponse = responses[0];
      final priceResponse = responses[1];

      if (ticketResponse.statusCode == 200 && priceResponse.statusCode == 200) {
        final ticketData = json.decode(ticketResponse.body);
        final priceData = json.decode(priceResponse.body);

        if (ticketData['status'] == true && priceData['status'] == true) {
          final ticketResultData = ticketData['data'] as Map<String, dynamic>?;
          final priceList = priceData['data'] as List<dynamic>? ?? [];

          if (ticketResultData != null &&
              ticketResultData.containsKey('result')) {
            final results = ticketResultData['result'] as List<dynamic>?;
            final stationMap =
                ticketResultData['map'] as Map<String, dynamic>? ?? {};

            // 将价格数据转换为便于查询的 Map
            final priceMap = _buildPriceMap(priceList);

            // 解析车次数据并合并价格信息
            final List<Map<String, dynamic>> parsedTrains = [];
            for (final trainStr in results ?? []) {
              if (trainStr is String) {
                final trainInfo = _parseTrainString(trainStr, stationMap);
                if (trainInfo != null) {
                  // 合并价格信息
                  final mergedInfo = _mergePriceData(trainInfo, priceMap);
                  parsedTrains.add(mergedInfo);
                }
              }
            }

            setState(() => _stationResults = parsedTrains);

            _showSnack(
              _stationResults.isEmpty
                  ? '未找到相关车次信息'
                  : '找到 ${_stationResults.length} 条结果',
            );
          }
        } else {
          _showSnack('数据获取失败');
        }
      } else {
        _showSnack('网络请求失败');
      }
    } catch (e) {
      _showSnack('发生错误: $e');
    } finally {
      setState(() => _loading = false);
    }
  }

  Map<String, String> _getApiHeaders() {
    return {
      'User-Agent':
          'Mozilla/5.0 (iPhone; CPU iPhone OS 17_2 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.2 Mobile/15E148 Safari/604.1',
      'Accept': 'application/json, text/plain, */*',
      'Accept-Language': 'zh-CN,zh;q=0.9,en;q=0.8',
      'Accept-Encoding': 'gzip, deflate, br',
      'Connection': 'keep-alive',
      'Referer': 'https://kyfw.12306.cn/otn/leftTicket/init',
      'Cookie':
          '_jc_save_fromStation=$_fromCode; _jc_save_toStation=$_toCode; _jc_save_fromDate=$_formattedDate; _jc_save_toDate=$_formattedDate;',
    };
  }

  Map<String, Map<String, dynamic>> _buildPriceMap(List<dynamic> priceList) {
    final Map<String, Map<String, dynamic>> priceMap = {};

    for (final item in priceList) {
      final dto = item['queryLeftNewDTO'] as Map<String, dynamic>?;
      if (dto != null) {
        final trainCode = dto['station_train_code'] as String?;
        if (trainCode != null) {
          priceMap[trainCode] = dto;
        }
      }
    }

    return priceMap;
  }

  Map<String, dynamic> _mergePriceData(
    Map<String, dynamic> trainInfo,
    Map<String, Map<String, dynamic>> priceMap,
  ) {
    final trainCode = trainInfo['station_train_code'] as String?;
    final priceInfo = trainCode != null ? priceMap[trainCode] : null;

    if (priceInfo != null) {
      // 合并价格信息
      trainInfo['price_info'] = priceInfo;

      trainInfo['swz_price'] = _formatPrice(
        priceInfo['swz_price'],
        priceInfo['tz_price'],
      );
      trainInfo['zy_price'] = _formatPrice(
        priceInfo['zy_price'],
        priceInfo['zy_price'],
      );
      trainInfo['ze_price'] = _formatPrice(
        priceInfo['ze_price'],
        priceInfo['wz_price'],
      );
      trainInfo['gr_price'] = _formatPrice(
        priceInfo['gr_price'],
        priceInfo['gr_price'],
      );
      trainInfo['rw_price'] = _formatPrice(
        priceInfo['rw_price'],
        priceInfo['srrb_price'],
      );
      trainInfo['yw_price'] = _formatPrice(
        priceInfo['yw_price'],
        priceInfo['yw_price'],
      );
      trainInfo['rz_price'] = _formatPrice(
        priceInfo['rz_price'],
        priceInfo['rz_price'],
      );
      trainInfo['yz_price'] = _formatPrice(
        priceInfo['yz_price'],
        priceInfo['yz_price'],
      );
      trainInfo['wz_price'] = _formatPrice(
        priceInfo['ze_price'],
        priceInfo['yz_price'],
      );
      trainInfo['tz_price'] = _formatPrice(
        priceInfo['tz_price'],
        priceInfo['swz_price'],
      );
      trainInfo['qt_price'] = _formatPrice(
        priceInfo['qt_price'],
        priceInfo['qt_price'],
      );
      trainInfo['gg_price'] = _formatPrice(
        priceInfo['gg_price'],
        priceInfo['gg_price'],
      );
      trainInfo['srrb_price'] = _formatPrice(
        priceInfo['srrb_price'],
        priceInfo['rw_price'],
      );
      trainInfo['yb_price'] = _formatPrice(
        priceInfo['yb_price'],
        priceInfo['yb_price'],
      );
    }

    return trainInfo;
  }

  String _formatPrice(dynamic priceValue, dynamic priceValueBa) {
    if (priceValue == null) {
      if (priceValueBa == null) {
        return '--';
      }
      priceValue = priceValueBa;
    }

    try {
      final priceStr = priceValue.toString().trim();
      if (priceStr.isEmpty || priceStr == '0') return '--';

      final priceInt = int.tryParse(priceStr) ?? 0;
      if (priceInt == 0) return '--';

      final priceYuan = priceInt / 10.0;

      return priceYuan.toStringAsFixed(1);
    } catch (e) {
      return '--';
    }
  }

  Map<String, dynamic>? _parseTrainString(
    String trainStr,
    Map<String, dynamic> stationMap,
  ) {
    try {
      // 多重解码处理
      String decodedStr = trainStr;

      // 尝试多次解码，直到没有可解码的内容
      bool hasEncodedContent = true;
      int maxAttempts = 5;

      while (hasEncodedContent && maxAttempts > 0) {
        try {
          String temp = Uri.decodeComponent(decodedStr);
          // 如果解码后内容不变，说明没有编码内容了
          if (temp == decodedStr) {
            hasEncodedContent = false;
          } else {
            decodedStr = temp;
          }
        } catch (e) {
          // 解码失败，停止尝试
          hasEncodedContent = false;
        }
        maxAttempts--;
      }

      final fields = decodedStr.split('|');

      // 使用与Python代码完全一致的座位字段索引映射
      final Map<int, String> seatFields = {
        20: 'gg_num', // 优选一等座
        21: 'gr_num', // 高级软卧
        22: 'qt_num', // 其他
        23: 'rw_num', // 软卧
        24: 'rz_num', // 软座
        25: 'tz_num', // 特等座
        26: 'wz_num', // 无座
        27: 'yb_num', // 预留
        28: 'yw_num', // 硬卧
        29: 'yz_num', // 硬座
        30: 'ze_num', // 二等座
        31: 'zy_num', // 一等座
        32: 'swz_num', // 商务座
        33: 'srrb_num', // 动卧
      };

      // 解析座位信息
      final Map<String, String> seatInfo = {};

      for (final entry in seatFields.entries) {
        final value = fields[entry.key];
        final cleanedValue = _cleanSeatValue(value);
        seatInfo[entry.value] = cleanedValue;
      }

      // 构建车次信息
      return {
        'station_train_code': fields[3],
        'from_station_code': fields[4],
        'to_station_code': fields[5],
        'from_station': _cleanStationName(stationMap[fields[4]] ?? fields[4]),
        'to_station': _cleanStationName(stationMap[fields[5]] ?? fields[5]),
        'start_time': fields[8],
        'arrive_time': fields[9],
        'run_time': fields[10],
        'can_web_buy': fields[11] == 'Y' ? '是' : '否',
        '座位信息': seatInfo,
      };
    } catch (e) {
      return null;
    }
  }

  String _cleanSeatValue(String value) {
    if (value.isEmpty || value == '--' || value == '无' || value == 'NULL') {
      return '无票';
    } else if (value == '有') {
      return '有票';
    } else if (value.isNotEmpty && int.tryParse(value) != null) {
      return '$value张';
    } else {
      return value;
    }
  }

  Future<void> _fetchDetails(int index, bool isStation) async {
    if (isStation) {
      if (_stationDetails.containsKey(index)) return;
      final trainInfo = _stationResults[index];
      final trainNumber = trainInfo['station_train_code']?.toString() ?? '';
      if (trainNumber.isEmpty) return;
      setState(() => _stationLoading[index] = true);
      try {
        final stopData = await _fetchStopInfoSharyou(trainNumber);
        setState(() {
          _stationDetails[index] = stopData;
          _stationLoading[index] = false;
        });
      } catch (e) {
        _showSnack('获取停站信息失败: $e');
        setState(() => _stationLoading[index] = false);
      }
    } else {
      if (_trainDetails.containsKey(index)) return;
      final trainInfo = _trainResults[index];
      final trainNumber = trainInfo['station_train_code']?.toString() ?? '';
      if (trainNumber.isEmpty) return;
      setState(() => _trainLoading[index] = true);
      try {
        final stopData = await _fetchStopInfo(trainNumber);
        setState(() {
          _trainDetails[index] = stopData;
          _trainLoading[index] = false;
        });
      } catch (e) {
        _showSnack('获取停站信息失败: $e');
        setState(() => _trainLoading[index] = false);
      }
    }
  }

  Future<List<dynamic>> _fetchStopInfo(String trainNumber) async {
    final settings = Provider.of<AppSettings>(context);
    switch (settings.dataStationSource) {
      case TrainStationDataSource.moeFactory:
        return await _fetchStopInfoSharyou(trainNumber);
      default:
        return await _fetchStopInfoCtrip(trainNumber);
    }
  }

  Future<List<dynamic>> _fetchStopInfoSharyou(String trainNumber) async {
    // 如果缓存中已有 viaStations，直接使用
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
            'API返回失败: RetCode=${data['RetCode']}, Ack=${data['ResponseStatus']?['Ack']}',
          );
        } else {
          return [];
        }
      } else {
        throw Exception('HTTP请求失败: ${response.statusCode}');
      }
    } catch (e) {
      rethrow;
    }
  }

}
