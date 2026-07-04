// journey_utils_ext.dart
// AddJourneyPage 的工具函数相关 extension

part of 'journey.dart';

extension JourneyUtilsExt on _AddJourneyPageState {
  void _formatInput(String value) {
    if (value.isEmpty) return;
    String uppercase = value.toUpperCase();
    const allowed = 'GDCSKZTWPQ';
    String result = '';
    for (int i = 0; i < uppercase.length; i++) {
      String char = uppercase[i];
      if (i == 0) {
        if (RegExp(r'[0-9]').hasMatch(char) || allowed.contains(char)) {
          result += char;
        }
      } else {
        if (RegExp(r'[0-9]').hasMatch(char)) result += char;
      }
    }
    if (result != _trainNumberCtrl.text) {
      _trainNumberCtrl.value = _trainNumberCtrl.value.copyWith(
        text: result,
        selection: TextSelection.collapsed(offset: result.length),
      );
    }
  }

  String _getTrainType(String trainCode) {
    if (trainCode.isEmpty) return '数字';
    final first = trainCode[0].toUpperCase();
    return _trainTypeNames.containsKey(first) ? first : '数字';
  }

  void _updateTrainTypeFilters(List<dynamic> results) {
    final Set<String> types = {};
    final Map<String, String> fromStations = {};
    final Map<String, String> toStations = {};
    for (final item in results) {
      final code = item['station_train_code']?.toString() ?? '';
      if (code.isNotEmpty) types.add(_getTrainType(code));
      final fromCode = item['from_station']?.toString() ?? '';
      final toCode = item['to_station']?.toString() ?? '';
      if (fromCode.isNotEmpty) {
        final name = _getStationName(fromCode);
        fromStations[name] = name;
      }
      if (toCode.isNotEmpty) {
        final name = _getStationName(toCode);
        toStations[name] = name;
      }
    }
    final Map<String, bool> newFilters = {};
    for (final type in types) {
      newFilters[type] = _trainTypeFilters[type] ?? true;
    }
    setState(() {
      _trainTypeFilters..clear()..addAll(newFilters);
      _filterFromStation = null;
      _filterToStation = null;
    });
    _fromStationOptions = fromStations.keys.toList()..sort();
    _toStationOptions = toStations.keys.toList()..sort();
  }

  String _resolveStationName(String code) {
    return _stationNameMap[code] ?? code;
  }

  String _extractTrainModel(dynamic trainModel) {
    if (trainModel == null) return '';
    final modelStr = trainModel.toString();
    if (modelStr.contains('CR400AF')) return 'CR400AF';
    if (modelStr.contains('CR400BF')) return 'CR400BF';
    if (modelStr.contains('CRH380A')) return 'CRH380A';
    if (modelStr.contains('CRH380B')) return 'CRH380B';
    if (modelStr.contains('CRH2A')) return 'CRH2A';
    if (modelStr.contains('CRH3C')) return 'CRH3C';
    if (modelStr.contains('CRH5A')) return 'CRH5A';
    return modelStr;
  }

  Future<String> _getBenWu(String trainCode, String date) async {
    if (!RegExp(r'^[GDCS]', caseSensitive: false).hasMatch(trainCode)) {
      return '';
    }
    if (_sharyouCache.containsKey(trainCode)) {
      return _extractTrainModel(_sharyouCache[trainCode]!['trainModel']);
    }
    try {
      await _fetchAndCacheSharyou(trainCode, date);
      if (_sharyouCache.containsKey(trainCode)) {
        return _extractTrainModel(_sharyouCache[trainCode]!['trainModel']);
      }
    } catch (e) {
      logError(from: 'journey/_getBenWu', error: e.toString());
    }
    return '未知';
  }

  String _formatPrice(dynamic priceValue, dynamic priceValueBa) {
    if (priceValue == null && priceValueBa == null) return '--';
    final price = priceValue?.toString() ?? '';
    final priceBa = priceValueBa?.toString() ?? '';
    if (price.isNotEmpty && priceBa.isNotEmpty) {
      return '$price / 候补$priceBa';
    }
    if (price.isNotEmpty) return price;
    if (priceBa.isNotEmpty) return '候补$priceBa';
    return '--';
  }

  String _cleanSeatValue(String value) {
    if (value.isEmpty || value == 'null' || value == '0' || value == '--') {
      return '--';
    }
    return value;
  }

  bool _hasAvailableTickets(Map<String, dynamic> seatInfo) {
    return seatInfo.entries.any((entry) => _isSeatAvailable(entry.value));
  }

  bool _isSeatAvailable(dynamic value) {
    return value != null &&
        value != '无票' &&
        value != '无' &&
        value != '' &&
        value != '--' &&
        value != 'NULL' &&
        value != '0';
  }

  String _calcRunTime(String start, String end, String day) {
    try {
      if (start == '--:--' || end == '--:--') return '--';

      List<String> startParts = start.split(':');
      List<String> endParts = end.split(':');
      if (startParts.length != 2 || endParts.length != 2) return '--';

      int startHour = int.tryParse(startParts[0]) ?? 0;
      int startMin = int.tryParse(startParts[1]) ?? 0;
      int endHour = int.tryParse(endParts[0]) ?? 0;
      int endMin = int.tryParse(endParts[1]) ?? 0;

      int dayOffset = int.tryParse(day) ?? 0;
      int startTotal = startHour * 60 + startMin;
      int endTotal = endHour * 60 + endMin;
      endTotal += dayOffset * 24 * 60;
      if (endTotal < startTotal) endTotal += 24 * 60;

      int total = endTotal - startTotal;
      int hours = total ~/ 60;
      int minutes = total % 60;

      if (hours > 0) {
        return '$hours小时$minutes分';
      } else {
        return '$minutes分';
      }
    } catch (e) {
      logError(from: 'journey/_calcRunTime', error: e.toString());
      return '--';
    }
  }

  bool _isTimePassed(
    DateTime trainDate,
    String? timeString,
    int dayDiff,
    bool isLast,
  ) {
    if (timeString == null || timeString.isEmpty || timeString == '--:--') {
      return false;
    }

    try {
      final timeParts = timeString.split(':');
      if (timeParts.length < 2) return false;

      final hour = int.tryParse(timeParts[0]) ?? 0;
      final minute = int.tryParse(timeParts[1]) ?? 0;

      final stationDateTime = DateTime(
        trainDate.year,
        trainDate.month,
        trainDate.day + dayDiff,
        hour,
        minute,
      );

      final now = DateTime.now();
      return stationDateTime.isBefore(now);
    } catch (e) {
      logError(from: 'journey/_isTimePassed', error: e.toString());
      return false;
    }
  }

  bool _isStationPassedSection(Map<String, dynamic> stop, DateTime trainDate) {
    final first = (stop['isFirst'] as bool?) ?? false;
    final last = (stop['isLast'] as bool?) ?? false;

    final dayDiffValue = stop['DayDifference'];
    int dayDiff = 0;
    if (dayDiffValue != null) {
      if (dayDiffValue is int) {
        dayDiff = dayDiffValue;
      } else if (dayDiffValue is String) {
        dayDiff = int.tryParse(dayDiffValue) ?? 0;
      } else if (dayDiffValue is num) {
        dayDiff = dayDiffValue.toInt();
      }
    }

    if (first) {
      final dep = stop['departTime'] as String?;
      return _isTimePassed(trainDate, dep, dayDiff, last);
    } else if (last) {
      final arr = stop['arriveTime'] as String?;
      return _isTimePassed(trainDate, arr, dayDiff, last);
    } else {
      final arr = stop['arriveTime'] as String?;
      final dep = stop['departTime'] as String?;
      if (arr != null && arr != '--:--') {
        return _isTimePassed(trainDate, arr, dayDiff, last);
      } else if (dep != null && dep != '--:--') {
        return _isTimePassed(trainDate, dep, dayDiff, last);
      }
    }
    return false;
  }

  bool _isStationPassed(Map<String, dynamic> stop, DateTime trainDate) {
    final first = (stop['isFirst'] as bool?) ?? false;
    final last = (stop['isLast'] as bool?) ?? false;
    final dayDiff = (stop['DayDifference'] as int?) ?? 0;

    if (first) {
      final dep = stop['departTime'] as String?;
      return _isTimePassed(trainDate, dep, dayDiff, last);
    } else if (last) {
      final arr = stop['arriveTime'] as String?;
      return _isTimePassed(trainDate, arr, dayDiff, last);
    } else {
      final arr = stop['arriveTime'] as String?;
      final dep = stop['departTime'] as String?;
      if (arr != null && arr != '--:--') {
        return _isTimePassed(trainDate, arr, dayDiff, last);
      } else if (dep != null && dep != '--:--') {
        return _isTimePassed(trainDate, dep, dayDiff, last);
      }
    }
    return false;
  }

  bool _isExpired(int index, Map<String, dynamic> item, bool isStation) {
    final date = _selectedDate ?? DateTime.now();
    if (isStation) {
      return _isStationExpired(index, date);
    } else {
      return _isTrainExpired(index, date);
    }
  }

  bool _isStationExpired(int index, DateTime trainDate) {
    final stopData = _stationDetails[index] ?? [];
    if (stopData.isEmpty) return false;

    final queryStop = stopData.cast<Map<String, dynamic>?>().firstWhere(
      (stop) => stop?['isCurrent'] == true,
      orElse: () => null,
    );

    if (queryStop != null) {
      return _isStationPassed(queryStop, trainDate);
    }
    return false;
  }

  bool _isTrainExpired(int index, DateTime trainDate) {
    final stopData = _trainDetails[index] ?? [];
    if (stopData.isEmpty) return false;

    final lastStop = stopData.cast<Map<String, dynamic>?>().firstWhere(
      (stop) => stop?['isLast'] == true,
      orElse: () => null,
    );

    if (lastStop != null) {
      final arriveTime = lastStop['arriveTime'] as String?;
      final dayDiff = _parseDayDifference(lastStop['DayDifference']);
      return _isTimePassed(trainDate, arriveTime, dayDiff, true);
    }
    return false;
  }

  int _parseDayDifference(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is String) return int.tryParse(value) ?? 0;
    if (value is double) return value.toInt();
    if (value is num) return value.toInt();
    return 0;
  }

  Widget _stationRow(String label, String? name, Color iconColor) {
    return Row(
      children: [
        Icon(Icons.place, size: 16, color: iconColor),
        const SizedBox(width: 6),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
            Text(
              name ?? '--',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
            ),
          ],
        ),
      ],
    );
  }

  bool _hasDetails(int index, bool isStation) {
    if (isStation) {
      return _stationDetails.containsKey(index) &&
          (_stationDetails[index]?.isNotEmpty ?? false);
    } else {
      return _trainDetails.containsKey(index) &&
          (_trainDetails[index]?.isNotEmpty ?? false);
    }
  }

  void _toggleExpand(int index, bool isStation) async {
    if (widget.autoSearchAndExpand &&
        !isStation &&
        _trainResults.length == 1 &&
        _expandedIndex == index) {
      return;
    }

    if (isStation) {
      if (_stationExpandedIndex == index) {
        _animCtrl.reverse().then((_) {
          if (mounted) setState(() => _stationExpandedIndex = null);
        });
      } else {
        setState(() => _stationExpandedIndex = index);
        _animCtrl.forward();
        await _fetchDetails(index, true);
      }
    } else {
      if (_expandedIndex == index) {
        _animCtrl.reverse().then((_) {
          if (mounted) setState(() => _expandedIndex = null);
        });
      } else {
        setState(() => _expandedIndex = index);
        _animCtrl.forward();
        await _fetchDetails(index, false);
      }
    }
  }

  void _handleSelect(int index, Map<String, dynamic> train, bool isStation) async {
    if (!_hasDetails(index, isStation)) {
      await _fetchDetails(index, isStation);
    }
    if (mounted) {
      if (isStation) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('添加行程'),
            content: Text('是否添加 ${train['station_train_code']} 次列车？'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('取消'),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  _addJourney(
                    trainInfo: train,
                    date: _selectedDate ?? DateTime.now(),
                    stationList: isStation ? (_stationDetails[index] ?? []) : (_trainDetails[index] ?? []),
                    isStation: isStation,
                    fromStation: isStation ? (_fromName ?? '') : '',
                    toStation: isStation ? (_toName ?? '') : '',
                    seatType: '',
                    seatInfo: '',
                  );
                },
                child: const Text('添加'),
              ),
            ],
          ),
        );
      } else {
        _showStationRangeSelector(index, train);
      }
    }
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), duration: const Duration(seconds: 2)),
    );
  }

  void _clearResults() {
    if (_searchMode == 0) {
      setState(() {
        _trainResults.clear();
        _trainDetails.clear();
        _trainLoading.clear();
        _expandedIndex = null;
        _trainCurrentPage = 1;
        _trainPageCtrl.text = '1';
        if (_animCtrl.isAnimating) _animCtrl.reset();
      });
      _trainNumberCtrl.clear();
      _showSnack('已清除车次搜索结果');
    } else {
      setState(() {
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
        _stationCurrentPage = 1;
        _stationPageCtrl.text = '1';
        if (_animCtrl.isAnimating) _animCtrl.reset();
      });
      _showSnack('已清除站点搜索结果');
    }
  }

  void _openToolbox(Map<String, dynamic> item, bool isStation) {
    try {
      final currentIndex =
          isStation ? (_stationExpandedIndex ?? 0) : (_expandedIndex ?? 0);

      final stopData = isStation
          ? (_stationDetails[currentIndex] ?? [])
          : (_trainDetails[currentIndex] ?? []);

      if (stopData.isEmpty) {
        _showSnack('暂无站点信息，无法打开工具箱');
        return;
      }

      final journey = Journey.fromMapWithStations(
        trainInfo: item,
        date: _selectedDate ?? DateTime.now(),
        stationList: stopData,
        isStation: isStation,
        fromStation: isStation ? _fromName : null,
        toStation: isStation ? _toName : null,
      );

      final trainCode = item['station_train_code']?.toString() ?? '';

      showDialog(
        context: context,
        builder: (context) => Dialog(
          insetPadding: const EdgeInsets.all(20),
          backgroundColor: Theme.of(context).brightness == Brightness.dark
              ? Colors.black
              : Colors.white,
          child: SizedBox(
            width: MediaQuery.of(context).size.width * 0.9,
            height: MediaQuery.of(context).size.height * 0.85,
            child: ToolboxDialog(
              journey: journey,
              trainCode: trainCode,
              date: _formattedDate,
              routingItems:
                  (_sharyouCache[trainCode]?['routingItems']
                      as List<dynamic>?) ??
                  [],
              trainModel:
                  _sharyouCache[trainCode]?['trainModel']?.toString() ?? '',
              onFetchRouting: () async {
                if (!_sharyouCache.containsKey(trainCode)) {
                  await _fetchAndCacheSharyou(trainCode, _formattedDate);
                }
                return (
                  routingItems:
                      (_sharyouCache[trainCode]?['routingItems']
                          as List<dynamic>?) ??
                      [],
                  trainModel:
                      _sharyouCache[trainCode]?['trainModel']?.toString() ?? '',
                );
              },
            ),
          ),
        ),
      );
    } catch (e) {
      logError(from: 'journey/_openToolbox', error: e.toString());
      _showSnack('打开工具箱失败: $e');
    }
  }

  void _showStationRangeSelector(
    int index,
    Map<String, dynamic> train, {
    DateTime? actualTravelDate,
  }) {
    final trainCode = train['station_train_code']?.toString() ?? '';
    final stopData = _stationDetails[index] ?? _trainDetails[index] ?? [];
    final trainDate = actualTravelDate ?? _selectedDate ?? DateTime.now();
    final isRecordMode = widget.onSave != null;

    if (stopData.isEmpty) {
      _showSnack('暂无站点信息');
      return;
    }

    String? selectedFrom;
    String? selectedTo;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          void handleStationTap(int idx) {
            final station = stopData[idx] as Map<String, dynamic>;
            final stationName = station['stationName']?.toString() ?? '';

            if (!isRecordMode && _isStationPassedSection(station, trainDate)) {
              _showSnack('该车站已过期，无法选择');
              return;
            }

            setDialogState(() {
              if (selectedFrom == null) {
                selectedFrom = stationName;
                selectedTo = null;
              } else if (selectedTo == null) {
                final fromIndex = stopData.indexWhere(
                  (s) => (s as Map<String, dynamic>)['stationName'] == selectedFrom,
                );
                if (idx > fromIndex) {
                  selectedTo = stationName;
                } else {
                  _showSnack('下车站必须在上车站之后');
                }
              } else {
                selectedFrom = stationName;
                selectedTo = null;
              }
            });
          }

          bool isStationSelectable(int idx) {
            final station = stopData[idx] as Map<String, dynamic>;
            if (!isRecordMode && _isStationPassedSection(station, trainDate)) return false;
            if (selectedFrom == null) return true;
            if (selectedTo == null) {
              final fromIndex = stopData.indexWhere(
                (s) => (s as Map<String, dynamic>)['stationName'] == selectedFrom,
              );
              return idx > fromIndex;
            }
            return true;
          }

          bool isStationSelected(int idx) {
            final station = stopData[idx] as Map<String, dynamic>;
            final stationName = station['stationName']?.toString() ?? '';
            return stationName == selectedFrom || stationName == selectedTo;
          }

          bool isStationExpired(int idx) {
            final station = stopData[idx] as Map<String, dynamic>;
            if (isRecordMode) return false;
            return _isStationPassedSection(station, trainDate);
          }

          String getStationSelectionType(int idx) {
            final station = stopData[idx] as Map<String, dynamic>;
            final stationName = station['stationName']?.toString() ?? '';
            if (stationName == selectedFrom) return 'from';
            if (stationName == selectedTo) return 'to';
            return 'none';
          }

          return AlertDialog(
            title: Text('选择乘车区间 - $trainCode'),
            content: SizedBox(
              width: double.maxFinite,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (selectedFrom != null || selectedTo != null)
                      Container(
                        padding: const EdgeInsets.all(12),
                        margin: const EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          color: Theme.of(context).primaryColor.withAlpha(30),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              selectedFrom ?? '请选择上车站',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: selectedFrom != null
                                    ? Theme.of(context).colorScheme.onSurface
                                    : Colors.grey,
                              ),
                            ),
                            const Padding(
                              padding: EdgeInsets.symmetric(horizontal: 8),
                              child: Icon(Icons.arrow_forward, size: 16),
                            ),
                            Text(
                              selectedTo ?? '请选择下车站',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: selectedTo != null
                                    ? Theme.of(context).colorScheme.onSurface
                                    : Colors.grey,
                              ),
                            ),
                          ],
                        ),
                      ),
                    Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Theme.of(context).dividerColor),
                      ),
                      child: ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: stopData.length,
                        itemBuilder: (context, idx) {
                          final stop = stopData[idx] as Map<String, dynamic>;
                          final no = stop['stationNo']?.toString() ?? '';
                          final name = stop['stationName']?.toString() ?? '';
                          final arr = stop['arriveTime']?.toString() ?? '--:--';
                          final dep = stop['departTime']?.toString() ?? '--:--';
                          final stay = int.tryParse(stop['stayTime']?.toString() ?? '0') ?? 0;
                          final isSelected = isStationSelected(idx);
                          final isExpired = isStationExpired(idx);
                          final isSelectable = isStationSelectable(idx);
                          final selectionType = getStationSelectionType(idx);
                          final dayDiffValue = stop['DayDifference'];
                          int dayDiff = 0;
                          if (dayDiffValue != null) {
                            if (dayDiffValue is int) { dayDiff = dayDiffValue; }
                            else if (dayDiffValue is String) { dayDiff = int.tryParse(dayDiffValue) ?? 0; }
                            else if (dayDiffValue is num) { dayDiff = dayDiffValue.toInt(); }
                          }

                          return GestureDetector(
                            onTap: isSelectable ? () => handleStationTap(idx) : null,
                            child: Container(
                              decoration: BoxDecoration(
                                color: isExpired
                                    ? Colors.grey.withAlpha(30)
                                    : isSelected
                                        ? Colors.blue.withAlpha(30)
                                        : Colors.transparent,
                                border: idx < stopData.length - 1
                                    ? Border(bottom: BorderSide(color: Theme.of(context).dividerColor, width: 0.5))
                                    : null,
                              ),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Container(
                                      width: 30, height: 30,
                                      alignment: Alignment.center,
                                      decoration: BoxDecoration(
                                        color: isExpired ? Colors.orange : isSelected ? Theme.of(context).primaryColor : Colors.blue,
                                        shape: BoxShape.circle,
                                      ),
                                      child: Text(no, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Expanded(
                                                child: Row(
                                                  children: [
                                                    Text(name, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: isExpired ? Colors.orange[200] : isSelectable ? Theme.of(context).colorScheme.onSurface : Colors.grey)),
                                                    if (dayDiff > 0)
                                                      Container(margin: const EdgeInsets.only(left: 8), padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2), decoration: BoxDecoration(color: Colors.purple.withAlpha(76), borderRadius: BorderRadius.circular(4)), child: Text('+$dayDiff天', style: TextStyle(fontSize: 10, color: Theme.of(context).colorScheme.onSurface))),
                                                    if (isExpired)
                                                      Container(margin: const EdgeInsets.only(left: 8), padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2), decoration: BoxDecoration(color: Colors.red, borderRadius: BorderRadius.circular(4)), child: const Text('已过', style: TextStyle(color: Colors.white, fontSize: 10))),
                                                  ],
                                                ),
                                              ),
                                              if (selectionType == 'from')
                                                Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(color: Colors.green, borderRadius: BorderRadius.circular(4)), child: const Text('上车', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold))),
                                              if (selectionType == 'to')
                                                Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(color: Colors.orange, borderRadius: BorderRadius.circular(4)), child: const Text('下车', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold))),
                                            ],
                                          ),
                                          const SizedBox(height: 4),
                                          Row(
                                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                            children: [
                                              Text('到达: $arr', style: TextStyle(fontSize: 12, color: isExpired ? Colors.grey : Colors.grey.shade600)),
                                              if (stay > 0) Text('停站: $stay分', style: TextStyle(fontSize: 12, color: isExpired ? Colors.grey : Colors.grey.shade600)),
                                              Text('发车: $dep', style: TextStyle(fontSize: 12, color: isExpired ? Colors.grey : Colors.grey.shade600)),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Text(
                        selectedFrom == null
                            ? '请点击未过期的车站选择上车站'
                            : selectedTo == null
                                ? '请点击在上车站之后的未过期车站选择下车站'
                                : '确认添加 $selectedFrom → $selectedTo',
                        style: TextStyle(fontSize: 12, color: Theme.of(context).hintColor),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('取消'),
              ),
              if (selectedFrom != null)
                TextButton(
                  onPressed: () => setDialogState(() { selectedFrom = null; selectedTo = null; }),
                  child: const Text('重新选择'),
                ),
              ElevatedButton(
                onPressed: (selectedFrom != null && selectedTo != null)
                    ? () {
                        Navigator.of(context).pop();
                        _showSeatSelectionDialog(
                          trainInfo: train,
                          date: trainDate,
                          stationList: stopData,
                          isStation: true,
                          fromStation: selectedFrom!,
                          toStation: selectedTo!,
                        );
                      }
                    : null,
                child: const Text('下一步'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _addJourney({
    required Map<String, dynamic> trainInfo,
    required DateTime date,
    required List<dynamic> stationList,
    required bool isStation,
    required String fromStation,
    required String toStation,
    required String seatType,
    required String seatInfo,
  }) {
    if (widget.onSave != null) {
      widget.onSave!(
        trainInfo: trainInfo,
        date: date,
        stationList: stationList,
        isStation: isStation,
        fromStation: fromStation,
        toStation: toStation,
        seatType: seatType,
        seatInfo: seatInfo,
      );
      return;
    }

    final journey = Journey.fromMapWithStations(
      trainInfo: trainInfo,
      date: date,
      stationList: stationList,
      isStation: isStation,
      fromStation: fromStation,
      toStation: toStation,
      seatType: seatType,
      seatInfo: seatInfo,
    );

    final provider = Provider.of<JourneyProvider>(context, listen: false);
    provider.addJourney(journey);

    _showSnack('已添加行程：${journey.trainCode} $fromStation → $toStation');
    Navigator.pop(context);
  }

  void _showSeatSelectionDialog({
    required Map<String, dynamic> trainInfo,
    required DateTime date,
    required List<dynamic> stationList,
    required bool isStation,
    required String fromStation,
    required String toStation,
  }) {
    String? selectedSeatType = 'wz_num';
    String seatInfo = '';
    final TextEditingController seatInfoController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: const Text('选择座位'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  value: selectedSeatType,
                  decoration: const InputDecoration(labelText: '座位类型', border: OutlineInputBorder()),
                  items: [
                    DropdownMenuItem(value: 'swz_num', child: Text('商务座 (${trainInfo['swz_num'] ?? '--'})')),
                    DropdownMenuItem(value: 'zy_num', child: Text('一等座 (${trainInfo['zy_num'] ?? '--'})')),
                    DropdownMenuItem(value: 'ze_num', child: Text('二等座 (${trainInfo['ze_num'] ?? '--'})')),
                    DropdownMenuItem(value: 'gr_num', child: Text('高级软卧 (${trainInfo['gr_num'] ?? '--'})')),
                    DropdownMenuItem(value: 'rw_num', child: Text('软卧 (${trainInfo['rw_num'] ?? '--'})')),
                    DropdownMenuItem(value: 'yw_num', child: Text('硬卧 (${trainInfo['yw_num'] ?? '--'})')),
                    DropdownMenuItem(value: 'rz_num', child: Text('软座 (${trainInfo['rz_num'] ?? '--'})')),
                    DropdownMenuItem(value: 'yz_num', child: Text('硬座 (${trainInfo['yz_num'] ?? '--'})')),
                    DropdownMenuItem(value: 'wz_num', child: Text('无座 (${trainInfo['wz_num'] ?? '--'})')),
                    DropdownMenuItem(value: 'tz_num', child: Text('特等座 (${trainInfo['tz_num'] ?? '--'})')),
                    DropdownMenuItem(value: 'gg_num', child: Text('优选一等座 (${trainInfo['gg_num'] ?? '--'})')),
                    DropdownMenuItem(value: 'srrb_num', child: Text('动卧 (${trainInfo['srrb_num'] ?? '--'})')),
                  ],
                  onChanged: (value) {
                    setState(() {
                      selectedSeatType = value;
                      if (value == 'wz_num') {
                        seatInfo = '';
                        seatInfoController.text = '';
                      }
                    });
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: seatInfoController,
                  enabled: selectedSeatType != 'wz_num',
                  decoration: InputDecoration(
                    labelText: '座位信息',
                    hintText: '例如: 01车12F',
                    border: const OutlineInputBorder(),
                    suffixIcon: selectedSeatType != 'wz_num'
                        ? IconButton(icon: const Icon(Icons.clear), onPressed: () { setState(() { seatInfo = ''; seatInfoController.clear(); }); })
                        : null,
                  ),
                  onChanged: (value) { setState(() { seatInfo = value; }); },
                ),
                if (selectedSeatType != 'wz_num')
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text('请输入座位信息，如 01车12F、12车厢05A', style: TextStyle(fontSize: 12, color: Theme.of(context).hintColor)),
                  ),
              ],
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('取消')),
              ElevatedButton(
                onPressed: () {
                  if (selectedSeatType == null) { _showSnack('请选择座位类型'); return; }
                  if (selectedSeatType != 'wz_num' && seatInfo.isEmpty) { _showSnack('请输入座位信息'); return; }
                  Navigator.pop(context);
                  _addJourney(
                    trainInfo: trainInfo,
                    date: date,
                    stationList: stationList,
                    isStation: isStation,
                    fromStation: fromStation,
                    toStation: toStation,
                    seatType: selectedSeatType!,
                    seatInfo: seatInfo,
                  );
                },
                child: const Text('确定'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _createAndSaveJourney({
    required Map<String, dynamic> trainInfo,
    required DateTime date,
    required List<dynamic> stationList,
    required bool isStation,
    required String fromStation,
    required String toStation,
    required String seatType,
    required String seatInfo,
  }) {
    _addJourney(
      trainInfo: trainInfo,
      date: date,
      stationList: stationList,
      isStation: isStation,
      fromStation: fromStation,
      toStation: toStation,
      seatType: seatType,
      seatInfo: seatInfo,
    );
  }
}
