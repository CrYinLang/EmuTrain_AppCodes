// journey_builders_ext.dart
// AddJourneyPage 的 UI 构建相关 extension

part of 'journey.dart';

extension JourneyBuildersExt on _AddJourneyPageState {
  Widget _buildTrainList() {
    if (_trainResults.isEmpty && !_loading) {
      return const SizedBox.shrink();
    }
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    final totalItems = _trainResults.length;
    final totalPages = (totalItems / _journeyPageSize).ceil();
    if (_trainCurrentPage > totalPages) _trainCurrentPage = totalPages;
    final start = (_trainCurrentPage - 1) * _journeyPageSize;
    final end = (start + _journeyPageSize).clamp(0, totalItems);
    final pageItems = _trainResults.sublist(start, end);

    return Column(
      children: [
        if (totalPages > 1) ...[
          buildPaginationControls(
            context: context,
            currentPage: _trainCurrentPage,
            totalPages: totalPages,
            totalResults: totalItems,
            loadingPage: false,
            pageController: _trainPageCtrl,
            onGoToPage: (p) => setState(() {
              _trainCurrentPage = p;
              _trainPageCtrl.text = p.toString();
              _expandedIndex = null;
            }),
            padding: const EdgeInsets.symmetric(vertical: 8),
          ),
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              '共 $totalItems 条结果',
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
        for (int i = 0; i < pageItems.length; i++)
          _buildItem(start + i, false),
        if (totalPages > 1)
          buildPaginationControls(
            context: context,
            currentPage: _trainCurrentPage,
            totalPages: totalPages,
            totalResults: totalItems,
            loadingPage: false,
            pageController: _trainPageCtrl,
            onGoToPage: (p) => setState(() {
              _trainCurrentPage = p;
              _trainPageCtrl.text = p.toString();
              _expandedIndex = null;
            }),
            padding: const EdgeInsets.symmetric(vertical: 8),
          ),
      ],
    );
  }

  Widget _buildStationList() {
    if (_stationResults.isEmpty && !_loading) {
      return const SizedBox.shrink();
    }
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    final filteredResults = _getFilteredStationResults();
    final totalItems = filteredResults.length;
    final totalPages = (totalItems / _journeyPageSize).ceil();
    if (_stationCurrentPage > totalPages) _stationCurrentPage = totalPages;
    final start = (_stationCurrentPage - 1) * _journeyPageSize;
    final end = (start + _journeyPageSize).clamp(0, totalItems);
    final pageItems = filteredResults.sublist(start, end);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildCombinedFilter(),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            children: [
              Text(
                '共找到 ',
                style: TextStyle(
                  fontSize: 13,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              Text(
                '${_stationResults.length}',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
              Text(
                ' 个车次',
                style: TextStyle(
                  fontSize: 13,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              if (filteredResults.length != _stationResults.length) ...[
                Text(
                  '，筛选显示 ',
                  style: TextStyle(
                    fontSize: 13,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                Text(
                  '${filteredResults.length}',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
                Text(
                  ' 个',
                  style: TextStyle(
                    fontSize: 13,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ],
          ),
        ),
        if (totalPages > 1)
          buildPaginationControls(
            context: context,
            currentPage: _stationCurrentPage,
            totalPages: totalPages,
            totalResults: totalItems,
            loadingPage: false,
            pageController: _stationPageCtrl,
            onGoToPage: (p) => setState(() {
              _stationCurrentPage = p;
              _stationPageCtrl.text = p.toString();
              _stationExpandedIndex = null;
            }),
            padding: const EdgeInsets.symmetric(vertical: 8),
          ),
        if (filteredResults.isEmpty)
          const Padding(
            padding: EdgeInsets.all(32),
            child: Text(
              '当前筛选条件下无车次结果',
              style: TextStyle(fontSize: 14, color: Colors.grey),
            ),
          )
        else
          ...List.generate(
            pageItems.length,
            (index) => _buildFilteredItem(start + index, filteredResults),
          ),
        if (totalPages > 1)
          buildPaginationControls(
            context: context,
            currentPage: _stationCurrentPage,
            totalPages: totalPages,
            totalResults: totalItems,
            loadingPage: false,
            pageController: _stationPageCtrl,
            onGoToPage: (p) => setState(() {
              _stationCurrentPage = p;
              _stationPageCtrl.text = p.toString();
              _stationExpandedIndex = null;
            }),
            padding: const EdgeInsets.symmetric(vertical: 8),
          ),
      ],
    );
  }

  List<dynamic> _getFilteredStationResults() {
    return _stationResults.where((item) {
      final code = item['station_train_code']?.toString() ?? '';
      final type = _getTrainType(code);
      if (_trainTypeFilters.containsKey(type) && _trainTypeFilters[type] == false) {
        return false;
      }
      if (_filterFromStation != null) {
        final fromCode = item['from_station']?.toString() ?? '';
        final fromName = _getStationName(fromCode);
        if (fromName != _filterFromStation) return false;
      }
      if (_filterToStation != null) {
        final toCode = item['to_station']?.toString() ?? '';
        final toName = _getStationName(toCode);
        if (toName != _filterToStation) return false;
      }
      return true;
    }).toList();
  }

  Widget _buildCombinedFilter() {
    final hasTypeFilter = _trainTypeFilters.isNotEmpty;
    final hasStationFilter =
        _fromStationOptions.length > 1 || _toStationOptions.length > 1;

    if (!hasTypeFilter && !hasStationFilter) {
      return const SizedBox.shrink();
    }

    return AnimatedSize(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeInOut,
      child: GestureDetector(
        onTap: () => setState(() => _filterExpanded = !_filterExpanded),
        child: Container(
          width: double.infinity,
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: Theme.of(context)
                .colorScheme
                .surfaceContainerHighest
                .withValues(alpha: 0.4),
            borderRadius: BorderRadius.circular(12),
          ),
          child: _filterExpanded
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.tune,
                            size: 16,
                            color: Theme.of(context).colorScheme.primary),
                        const SizedBox(width: 6),
                        Text('筛选器',
                            style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color:
                                    Theme.of(context).colorScheme.primary)),
                        const Spacer(),
                        Icon(Icons.expand_less,
                            size: 20,
                            color: Theme.of(context)
                                .colorScheme
                                .onSurfaceVariant),
                      ],
                    ),
                    const SizedBox(height: 10),
                    if (hasTypeFilter) ...[
                      _buildTypeChips(),
                      if (hasStationFilter) const SizedBox(height: 10),
                    ],
                    if (hasStationFilter) ...[
                      if (_fromStationOptions.length > 1)
                        _buildStationChipRow(
                          label: '出发站',
                          color: Colors.green,
                          options: _fromStationOptions,
                          selected: _filterFromStation,
                          onSelected: (v) =>
                              setState(() => _filterFromStation = v),
                        ),
                      if (_toStationOptions.length > 1)
                        _buildStationChipRow(
                          label: '到达站',
                          color: Colors.red,
                          options: _toStationOptions,
                          selected: _filterToStation,
                          onSelected: (v) =>
                              setState(() => _filterToStation = v),
                        ),
                    ],
                  ],
                )
              : Row(
                  children: [
                    Icon(Icons.tune,
                        size: 16,
                        color: Theme.of(context).colorScheme.primary),
                    const SizedBox(width: 6),
                    Text('筛选器',
                        style: TextStyle(
                            fontSize: 13,
                            color: Theme.of(context).colorScheme.primary)),
                    const Spacer(),
                    Icon(Icons.expand_more,
                        size: 20,
                        color:
                            Theme.of(context).colorScheme.onSurfaceVariant),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _buildTypeChips() {
    final Map<String, int> typeCounts = {};
    for (final item in _stationResults) {
      final code = item['station_train_code']?.toString() ?? '';
      final type = _getTrainType(code);
      typeCounts[type] = (typeCounts[type] ?? 0) + 1;
    }

    return Wrap(
      spacing: 8,
      runSpacing: 4,
      children: _trainTypeFilters.entries.map((entry) {
        final type = entry.key;
        final selected = entry.value;
        final count = typeCounts[type] ?? 0;
        final typeName = _trainTypeNames[type] ?? type;
        final label = type == '数字'
            ? '$typeName($count)'
            : '$type「$typeName」($count)';

        return FilterChip(
          label: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              color: selected
                  ? Theme.of(context).colorScheme.onPrimary
                  : Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          selected: selected,
          onSelected: (v) =>
              setState(() => _trainTypeFilters[type] = v),
          selectedColor: Theme.of(context).colorScheme.primary,
          backgroundColor: Theme.of(context).colorScheme.surface,
          checkmarkColor: Theme.of(context).colorScheme.onPrimary,
          padding: const EdgeInsets.symmetric(horizontal: 4),
          visualDensity: VisualDensity.compact,
        );
      }).toList(),
    );
  }

  Widget _buildStationChipRow({
    required String label,
    required Color color,
    required List<String> options,
    required String? selected,
    required ValueChanged<String?> onSelected,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Wrap(
        spacing: 8,
        runSpacing: 4,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(label,
                style: const TextStyle(color: Colors.white, fontSize: 12)),
          ),
          FilterChip(
            label: Text(
              '全部',
              style: TextStyle(
                fontSize: 13,
                color: selected == null
                    ? Theme.of(context).colorScheme.onPrimary
                    : Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            selected: selected == null,
            onSelected: (_) => onSelected(null),
            selectedColor: Theme.of(context).colorScheme.primary,
            backgroundColor: Theme.of(context).colorScheme.surface,
            checkmarkColor: Theme.of(context).colorScheme.onPrimary,
            padding: const EdgeInsets.symmetric(horizontal: 4),
            visualDensity: VisualDensity.compact,
          ),
          ...options.where((opt) => opt != '全部').map((opt) {
            return FilterChip(
              label: Text(
                opt,
                style: TextStyle(
                  fontSize: 13,
                  color: selected == opt
                      ? Theme.of(context).colorScheme.onPrimary
                      : Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              selected: selected == opt,
              onSelected: (_) => onSelected(opt),
              selectedColor: Theme.of(context).colorScheme.primary,
              backgroundColor: Theme.of(context).colorScheme.surface,
              checkmarkColor: Theme.of(context).colorScheme.onPrimary,
              padding: const EdgeInsets.symmetric(horizontal: 4),
              visualDensity: VisualDensity.compact,
            );
          }),
        ],
      ),
    );
  }

  Widget _buildFilteredItem(int filteredIndex, List<dynamic> filteredResults) {
    final item = filteredResults[filteredIndex];
    final originalIndex = _stationResults.indexOf(item);
    return _buildItem(originalIndex, true);
  }

  Widget _buildItem(int index, bool isStation) {
    final item = isStation ? _stationResults[index] : _trainResults[index];
    return _buildExpanded(index, item, isStation);
  }

  Widget _buildExpanded(int index, Map<String, dynamic> item, bool isStation) {
    final loading = isStation
        ? (_stationLoading[index] ?? false)
        : (_trainLoading[index] ?? false);
    final stopData = isStation
        ? (_stationDetails[index] ?? [])
        : (_trainDetails[index] ?? []);

    final trainCode = item['station_train_code']?.toString() ?? '';

    String depTime = item['start_time']?.toString() ?? '--:--';
    String arrTime = item['arrive_time']?.toString() ?? '--:--';
    String runTime = item['run_time']?.toString() ?? '--';

    bool isCircularLine =
        _getStationName(item['from_station']) ==
        _getStationName(item['to_station']);

    if (isStation && stopData.isNotEmpty) {
      final fromStationName = _fromName;
      final toStationName = _toName;

      if (fromStationName != null && toStationName != null) {
        if (isCircularLine && fromStationName == toStationName) {
          final firstStop = stopData.first as Map<String, dynamic>?;
          final lastStop = stopData.last as Map<String, dynamic>?;

          if (firstStop != null && lastStop != null) {
            final firstDep = firstStop['departTime'] as String?;
            final lastArr = lastStop['arriveTime'] as String?;

            if (firstDep != null && lastArr != null) {
              final firstDayDiff = _parseDayDifference(firstStop['DayDifference']);
              final lastDayDiff = _parseDayDifference(lastStop['DayDifference']);
              final totalDayDiff = lastDayDiff - firstDayDiff;

              depTime = firstDep;
              arrTime = lastArr;
              runTime = _calcRunTime(firstDep, lastArr, totalDayDiff.toString());
            }
          }
        } else {
          Map<String, dynamic>? fromStation;
          Map<String, dynamic>? toStation;

          for (final stop in stopData) {
            final station = stop as Map<String, dynamic>;
            final stationName = station['stationName'] as String?;

            if (stationName == fromStationName) fromStation = station;
            if (stationName == toStationName) toStation = station;
            if (fromStation != null && toStation != null) break;
          }

          if (fromStation != null && toStation != null) {
            final fromDep = fromStation['departTime'] as String?;
            final fromArr = fromStation['arriveTime'] as String?;
            final toArr = toStation['arriveTime'] as String?;
            final toDep = toStation['departTime'] as String?;

            final selectedDepTime = fromDep ?? fromArr ?? '--:--';
            final selectedArrTime = toArr ?? toDep ?? '--:--';

            final fromDayDiff =
                int.tryParse(fromStation['DayDifference']?.toString() ?? '0') ?? 0;
            final toDayDiff =
                int.tryParse(toStation['DayDifference']?.toString() ?? '0') ?? 0;
            final dayOffset = (toDayDiff - fromDayDiff).abs();

            if (selectedDepTime != '--:--' && selectedArrTime != '--:--') {
              depTime = selectedDepTime;
              arrTime = selectedArrTime;
              runTime = _calcRunTime(selectedDepTime, selectedArrTime, dayOffset.toString());
            }
          }
        }
      }
    } else if (stopData.isNotEmpty) {
      final firstStop = stopData.cast<Map<String, dynamic>?>().firstWhere(
            (stop) => stop?['isFirst'] == true,
            orElse: () => null,
          ) ??
          stopData.first as Map<String, dynamic>?;

      final lastStop = stopData.cast<Map<String, dynamic>?>().firstWhere(
            (stop) => stop?['isLast'] == true,
            orElse: () => null,
          ) ??
          stopData.last as Map<String, dynamic>?;

      if (firstStop != null) {
        final firstArr = firstStop['arriveTime'] as String?;
        final firstDep = firstStop['departTime'] as String?;
        depTime = firstDep ?? firstArr ?? depTime;
      }
      if (lastStop != null) {
        final lastArr = lastStop['arriveTime'] as String?;
        final lastDep = lastStop['departTime'] as String?;
        arrTime = lastArr ?? lastDep ?? arrTime;
      }
      if (firstStop != null && lastStop != null) {
        final firstDep = firstStop['departTime'] as String?;
        final lastArr = lastStop['arriveTime'] as String?;
        if (firstDep != null && lastArr != null) {
          final firstDayDiff = _parseDayDifference(firstStop['DayDifference']);
          final lastDayDiff = _parseDayDifference(lastStop['DayDifference']);
          final totalDayDiff = lastDayDiff - firstDayDiff;
          runTime = _calcRunTime(firstDep, lastArr, totalDayDiff.toString());
        }
      }
    }

    final bool expired = _isExpired(index, item, isStation);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final referencePrice =
        item['ze_price'] ?? item['zy_price'] ?? item['swz_price'];
    final bool isExpanded = isStation
        ? _stationExpandedIndex == index
        : _expandedIndex == index;

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onTap: () => _toggleExpand(index, isStation),
            child: Card(
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: Colors.grey.shade200),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    '${item['station_train_code'] ?? '--'}${isCircularLine ? ' (环线)' : ''}',
                                    style: TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                      color: expired
                                          ? Colors.grey
                                          : Theme.of(context).colorScheme.primary,
                                    ),
                                  ),
                                  if (expired) ...[
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: Colors.grey,
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: const Text('已过期', style: TextStyle(fontSize: 12, color: Colors.white)),
                                    ),
                                  ],
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                item['train_class_name'] ?? '',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: expired ? Colors.grey.shade500 : Colors.grey.shade600,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.schedule, size: 16, color: expired ? Colors.grey : Theme.of(context).colorScheme.primary),
                                const SizedBox(width: 4),
                                Text(depTime, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: expired ? Colors.grey : (isDark ? Colors.white : Colors.black))),
                                const SizedBox(width: 8),
                                Icon(Icons.arrow_forward, size: 16, color: expired ? Colors.grey.shade400 : (isDark ? Colors.grey.shade300 : Colors.grey)),
                                const SizedBox(width: 8),
                                Text(arrTime, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: expired ? Colors.grey : (isDark ? Colors.white : Colors.black))),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Text(
                                  isStation ? '区间时长: $runTime' : '运行时长: $runTime',
                                  style: TextStyle(fontSize: 13, color: expired ? Colors.grey.shade400 : (isDark ? Colors.grey.shade300 : Colors.grey.shade600)),
                                ),
                                if (isStation && referencePrice != null && referencePrice != '--') ...[
                                  const SizedBox(width: 12),
                                  Text('参考价: ¥$referencePrice', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: expired ? Colors.grey.shade400 : Theme.of(context).colorScheme.primary)),
                                ],
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    const Divider(),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _stationRow('始发站', "${_getStationName(item['from_station'])}站", expired ? Colors.grey : Colors.green),
                              const SizedBox(height: 8),
                              _stationRow('终点站', "${_getStationName(item['to_station'])}站", expired ? Colors.grey : Colors.red),
                            ],
                          ),
                        ),
                        Icon(
                          isExpanded ? Icons.expand_less : Icons.expand_more,
                          size: 24,
                          color: expired ? Colors.grey.shade400 : Colors.blue.shade300,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),

          if (isExpanded) ...[
            const SizedBox(height: 20),

            if (isStation) _buildSeatList(item),

            if (isStation) const SizedBox(height: 20),

            Container(
              margin: const EdgeInsets.only(top: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Text(
                      '信息仅供参考 合理安排时间行程\n买票请上12306,发货请上95306',
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                    ),
                  ),
                  const SizedBox(width: 16),
                  if (trainCode.isNotEmpty && _selectedDate != null)
                    FutureBuilder<String>(
                      future: _getBenWu(trainCode, _formattedDate),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState == ConnectionState.waiting) {
                          return const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2));
                        } else if (snapshot.hasError) {
                          return Icon(Icons.error_outline, size: 16, color: Colors.red);
                        } else if (snapshot.hasData && snapshot.data != '未知') {
                          return Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            child: Text(snapshot.data!, style: TextStyle(fontSize: 16, color: Theme.of(context).colorScheme.onSurface, fontWeight: FontWeight.w500)),
                          );
                        } else {
                          return Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.grey.shade300)),
                            child: Row(mainAxisSize: MainAxisSize.min, children: [
                              Icon(Icons.train, size: 12, color: Colors.grey.shade600),
                              const SizedBox(width: 4),
                              Text('本务: 未知', style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
                            ]),
                          );
                        }
                      },
                    ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            _buildStopSection(index, stopData, loading, isStation),

            const SizedBox(height: 20),

            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: expired ? null : () => _handleSelect(index, item, isStation),
                    icon: Icon(Icons.add, color: expired ? Colors.grey.shade400 : Theme.of(context).colorScheme.surface),
                    label: Text(expired ? '车次已过期' : '添加此车次', style: TextStyle(color: expired ? Colors.grey.shade400 : Theme.of(context).colorScheme.surface)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: expired ? Colors.grey.shade300 : Theme.of(context).colorScheme.primary,
                      foregroundColor: expired ? Colors.grey.shade400 : Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _openToolbox(item, isStation),
                    icon: const Icon(Icons.build_circle_outlined, size: 20),
                    label: const Text('工具箱'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blueGrey,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSeatList(Map<String, dynamic> item) {
    final Map<String, String> seatMapping = {
      'swz_num': '商务座',
      'zy_num': '一等座',
      'ze_num': '二等座',
      'gr_num': '高级软卧',
      'rw_num': '软卧',
      'yw_num': '硬卧',
      'rz_num': '软座',
      'yz_num': '硬座',
      'wz_num': '无座',
      'tz_num': '特等座',
      'gg_num': '优选一等座',
      'srrb_num': '动卧',
      'qt_num': '其他',
      'yb_num': '预留',
    };

    final Map<String, String> priceMapping = {
      'swz_num': item['swz_price']?.toString() ?? item['tz_price']?.toString() ?? '--',
      'zy_num': item['zy_price']?.toString() ?? '--',
      'ze_num': item['ze_price']?.toString() ?? '--',
      'gr_num': item['gr_price']?.toString() ?? '--',
      'rw_num': item['rw_price']?.toString() ?? item['srrb_price']?.toString() ?? '--',
      'yw_num': item['yw_price']?.toString() ?? '--',
      'rz_num': item['rz_price']?.toString() ?? '--',
      'yz_num': item['yz_price']?.toString() ?? '--',
      'wz_num': item['wz_price']?.toString() ?? item['ze_price']?.toString() ?? '--',
      'tz_num': item['tz_price']?.toString() ?? item['swz_price']?.toString() ?? '--',
      'qt_num': item['qt_price']?.toString() ?? '--',
      'gg_num': item['gg_price']?.toString() ?? item['zy_price']?.toString() ?? '--',
      'srrb_num': item['srrb_price']?.toString() ?? item['rw_price']?.toString() ?? '--',
      'yb_num': item['yb_price']?.toString() ?? '--',
    };

    final Map<String, dynamic> seatInfo = item['座位信息'] ?? {};

    final List<Map<String, dynamic>> seatCategories = [
      {'name': '商务/特等座', 'seats': ['swz_num', 'tz_num', 'gg_num'], 'color': Colors.red},
      {'name': '一等/二等座', 'seats': ['zy_num', 'ze_num', 'wz_num'], 'color': Colors.blue},
      {'name': '卧铺', 'seats': ['gr_num', 'rw_num', 'yw_num', 'srrb_num'], 'color': Colors.orange},
      {'name': '坐席', 'seats': ['rz_num', 'yz_num'], 'color': Colors.green},
      {'name': '其他', 'seats': ['qt_num', 'yb_num'], 'color': Colors.grey},
    ];

    final bool hasAvailable = _hasAvailableTickets(seatInfo);
    final bool hasMotorSleeper = priceMapping['srrb_num'] != null && priceMapping['srrb_num'] != '--' && priceMapping['srrb_num'] != '0';

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary.withAlpha(30),
              borderRadius: const BorderRadius.only(topLeft: Radius.circular(12), topRight: Radius.circular(12)),
            ),
            child: Row(
              children: [
                Icon(Icons.event_seat, color: Theme.of(context).colorScheme.primary, size: 20),
                const SizedBox(width: 8),
                Text('坐席信息    仅供参考', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.primary)),
                if (!hasAvailable) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(color: Colors.red, borderRadius: BorderRadius.circular(4)),
                    child: const Text('无票', style: TextStyle(fontSize: 12, color: Colors.white)),
                  ),
                ],
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: seatCategories.map((category) {
                final categorySeats = category['seats'] as List<String>;
                final categoryColor = category['color'] as Color;
                final seatsWithPrice = categorySeats.where((seatCode) {
                  final price = priceMapping[seatCode];
                  return price != null && price != '--' && price != '0';
                }).toList();
                if (category['name'] == '卧铺') {
                  final hasSoft = seatsWithPrice.contains('rw_num');
                  final hasMotor = seatsWithPrice.contains('srrb_num');
                  if (hasSoft && hasMotor) seatsWithPrice.remove('rw_num');
                }
                if (seatsWithPrice.isEmpty) return const SizedBox.shrink();
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(width: 4, height: 16, color: categoryColor),
                        const SizedBox(width: 8),
                        Text(category['name'] as String, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.grey.shade700)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: seatsWithPrice.map((seatCode) {
                        final seatName = seatMapping[seatCode] ?? seatCode;
                        final seatValue = seatInfo[seatCode]?.toString() ?? '无票';
                        final seatPrice = priceMapping[seatCode] ?? '--';
                        final isAvailable = _isSeatAvailable(seatInfo[seatCode]);
                        final displayValue = isAvailable ? seatValue : '无票';
                        return Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: categoryColor.withAlpha(30),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: categoryColor.withAlpha(100)),
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(seatName, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: categoryColor)),
                              const SizedBox(height: 4),
                              Text(displayValue, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: isAvailable ? categoryColor : Colors.red[300])),
                              const SizedBox(height: 4),
                              Text('¥$seatPrice', style: TextStyle(fontSize: 12, color: categoryColor.withAlpha(150))),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 16),
                  ],
                );
              }).toList(),
            ),
          ),
          Container(
            padding: const EdgeInsets.all(12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.info_outline, size: 16, color: Colors.orange.shade700),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    hasMotorSleeper ? '动卧或部分列车有折扣，请上12306查看' : '部分列车有折扣，请上12306查看',
                    style: TextStyle(fontSize: 12, color: Colors.orange.shade700, fontWeight: FontWeight.w500),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStopSection(
    int index,
    List<dynamic> stops,
    bool loading,
    bool isStation,
  ) {
    if (loading) return const Center(child: CircularProgressIndicator());
    if (stops.isEmpty) {
      return GestureDetector(
        onTap: () => _fetchDetails(index, isStation),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.grey.shade50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: const Center(child: Text('点击加载停站信息')),
        ),
      );
    }

    final item = isStation ? _stationResults[index] : _trainResults[index];
    final trainDate = _selectedDate ?? DateTime.now();

    return _buildStopList(stops, trainDate, item);
  }

  Widget _buildStopList(
    List<dynamic> stops,
    DateTime trainDate,
    Map<String, dynamic> journey, {
    bool isSelectable = false,
    Function(int)? onStationTap,
  }) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: ListView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        padding: EdgeInsets.zero,
        itemCount: stops.length,
        itemBuilder: (context, index) {
          final stop = stops[index] as Map<String, dynamic>;
          final no = stop['stationNo']?.toString() ?? '';
          final name = stop['stationName']?.toString() ?? '';
          final arr = stop['arriveTime']?.toString() ?? '--:--';
          final dep = stop['departTime']?.toString() ?? '--:--';
          final stay =
              int.tryParse(stop['stayTime']?.toString() ?? '0') ?? 0;
          final mile =
              int.tryParse(stop['distance']?.toString() ?? '-1') ?? -1;
          final first = (stop['isFirst'] as bool?) ?? false;
          final last = (stop['isLast'] as bool?) ?? false;
          final terminal = first || last;

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

          bool passed = false;
          if (first) {
            passed = _isTimePassed(trainDate, dep, dayDiff, last);
          } else if (last) {
            passed = _isTimePassed(trainDate, arr, dayDiff, last);
          } else if (arr != '--:--') {
            passed = _isTimePassed(trainDate, arr, dayDiff, last);
          } else if (dep != '--:--') {
            passed = _isTimePassed(trainDate, dep, dayDiff, last);
          }

          bool isFromStation = false;
          bool isToStation = false;
          final currentFromStation =
              _normalizeStationName(journey['from_station']?.toString() ?? '');
          final currentToStation =
              _normalizeStationName(journey['to_station']?.toString() ?? '');
          final currentStationName = _normalizeStationName(name);

          if (currentStationName == currentFromStation) isFromStation = true;
          if (currentStationName == currentToStation) isToStation = true;

          bool isCircularLine = currentFromStation == currentToStation;
          if (isCircularLine && isFromStation && isToStation) {
            int firstOccurrenceIndex = -1;
            for (int i = 0; i < stops.length; i++) {
              final station = stops[i] as Map<String, dynamic>;
              final stationName =
                  _normalizeStationName(station['stationName']?.toString() ?? '');
              if (stationName == currentStationName) {
                firstOccurrenceIndex = i;
                break;
              }
            }
            if (firstOccurrenceIndex != -1 && index > firstOccurrenceIndex) {
              isToStation = true;
              isFromStation = false;
            } else {
              isFromStation = true;
              isToStation = false;
            }
          }

          BorderRadius? getBorderRadius() {
            if (stops.length == 1) {
              return BorderRadius.circular(12);
            } else if (index == 0) {
              return const BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              );
            } else if (index == stops.length - 1) {
              return const BorderRadius.only(
                bottomLeft: Radius.circular(12),
                bottomRight: Radius.circular(12),
              );
            }
            return null;
          }

          return GestureDetector(
            onTap: isSelectable
                ? () {
                    if (onStationTap != null) onStationTap(index);
                  }
                : null,
            child: Container(
              decoration: BoxDecoration(
                color: passed
                    ? Colors.orange.withAlpha(30)
                    : (isFromStation || isToStation
                        ? Colors.blue.withAlpha(30)
                        : terminal
                            ? Colors.green.withAlpha(30)
                            : Theme.of(context).colorScheme.surface),
                border: index < stops.length - 1
                    ? Border(
                        bottom: BorderSide(
                          color: Theme.of(context).dividerColor,
                          width: 1,
                        ),
                      )
                    : null,
                borderRadius: getBorderRadius(),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                    vertical: 12, horizontal: 16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 30,
                      height: 30,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: passed
                            ? Colors.orange
                            : (isFromStation || isToStation
                                ? Colors.blue
                                : terminal
                                    ? Colors.green
                                    : Colors.black),
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        no,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  name,
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: terminal
                                        ? FontWeight.bold
                                        : FontWeight.normal,
                                    color: passed
                                        ? Colors.grey
                                        : null,
                                    decoration: passed
                                        ? TextDecoration.lineThrough
                                        : null,
                                  ),
                                ),
                              ),
                              if (isFromStation)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.blue,
                                    borderRadius:
                                        BorderRadius.circular(4),
                                  ),
                                  child: const Text(
                                    '上',
                                    style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 11),
                                  ),
                                ),
                              if (isToStation)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.orange,
                                    borderRadius:
                                        BorderRadius.circular(4),
                                  ),
                                  child: const Text(
                                    '下',
                                    style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 11),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              if (!first)
                                _timeBlock('到', arr, passed, false),
                              if (!first && !last && stay > 0)
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8),
                                  child: Text(
                                    '停$stay分',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: passed
                                          ? Colors.grey
                                          : Theme.of(context)
                                              .colorScheme
                                              .primary,
                                    ),
                                  ),
                                ),
                              if (!last)
                                _timeBlock('发', dep, passed, false),
                              if (mile >= 0) ...[
                                const Spacer(),
                                Text(
                                  '${mile}km',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: passed
                                        ? Colors.grey
                                        : Colors.grey.shade600,
                                  ),
                                ),
                              ],
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
    );
  }

  Widget _timeBlock(
      String label, String time, bool passed, bool isTerminal) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '$label $time',
          style: TextStyle(
            fontSize: 14,
            color: passed ? Colors.grey : null,
            decoration:
                passed ? TextDecoration.lineThrough : null,
          ),
        ),
      ],
    );
  }
}
