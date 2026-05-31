// 车站大屏页面
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../../station_selector.dart';
import '../journey.dart';

class StationScreen extends StatefulWidget {
  const StationScreen({super.key});

  @override
  State<StationScreen> createState() => _StationScreenState();
}

class _StationScreenState extends State<StationScreen> {
  String? _selectedStationCode;
  String _selectedStationName = '选择车站';
  bool _loading = false;
  List<dynamic> _currentPageData = []; // 当前页数据
  bool _dataLoaded = false;

  int _currentPage = 1;
  int _totalPages = 1;
  final int _pageSize = 40;
  int _directionMode = 0;

  void _handleDirectionChange(int mode) {
    setState(() {
      _directionMode = mode;
      _currentPageData.clear();
      _dataLoaded = false;
      _currentPage = 1;
      _totalPages = 1;
    });

    if (_selectedStationCode != null) {
      _fetchPageData(1);
    }
  }

  void _showStationSelector() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => StationSelector(
        title: '选择车站',
        selectedCode: _selectedStationCode,
        crOnly: true,
        onSelected: (station) {
          setState(() {
            _selectedStationCode = station['code'];
            _selectedStationName = station['name'] ?? '选择车站';
            _currentPageData.clear();
            _dataLoaded = false;
            _currentPage = 1;
            _totalPages = 1;
          });
        },
      ),
    );
  }

  Future<void> _fetchPageData(int page) async {
    if (_selectedStationCode == null) {
      return;
    }

    setState(() {
      _loading = true;
      _currentPageData.clear();
    });

    try {
      int cursor = (page - 1) * _pageSize;

      // 只获取当前选择方向的数据
      final String direction = _directionMode == 0 ? 'D' : 'A';

      final List<dynamic> directionData = [];
      await _fetchDirectionData(direction, cursor, directionData);

      // 对数据进行排序
      directionData.sort((a, b) {
        final timeA = a['actualTime'] ?? a['scheduledTime'] ?? '';
        final timeB = b['actualTime'] ?? b['scheduledTime'] ?? '';
        return timeA.compareTo(timeB);
      });

      setState(() {
        _currentPageData = directionData;
        _dataLoaded = true;
        _currentPage = page;
      });
    } catch (e) {
      _showSnack('获取数据失败: $e');
    } finally {
      setState(() {
        _loading = false;
      });
    }
  }

  // 获取特定方向的数据
  Future<void> _fetchDirectionData(
    String direction,
    int cursor,
    List<dynamic> resultList,
  ) async {
    final url = Uri.parse(
      'https://rail.moefactory.com/api/station/getBigScreenInfo',
    );

    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
        body: {
          'direction': direction,
          'stationName': _selectedStationName,
          'cursor': cursor.toString(),
          'count': '15',
        },
      );

      if (response.statusCode == 200) {
        final jsonData = json.decode(response.body);

        if (jsonData['code'] == 200) {
          final data = jsonData['data'];
          final List<dynamic> trainList = data['data'] ?? [];
          final int totalCount = data['totalCount'] ?? 0;

          // 计算总页数（基于单方向数据量估算）
          _totalPages = (totalCount / _pageSize).ceil();

          // 为每个车次添加方向信息
          for (var train in trainList) {
            train['direction'] = direction;
            resultList.add(train);
          }
        } else {
          throw Exception('API返回错误: ${jsonData['message']}');
        }
      } else {
        throw Exception('HTTP请求失败: ${response.statusCode}');
      }
    } catch (e) {
      rethrow;
    }
  }

  Widget _buildPaginationControls() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // 上一页按钮
          ElevatedButton(
            onPressed: _currentPage <= 1
                ? null
                : () => _fetchPageData(_currentPage - 1),
            child: const Text('上一页'),
          ),
          const SizedBox(width: 20),

          // 页码显示
          Text(
            '第 $_currentPage 页 / 共 $_totalPages 页',
            style: const TextStyle(fontSize: 16),
          ),
          const SizedBox(width: 20),

          // 下一页按钮
          ElevatedButton(
            onPressed: _currentPage >= _totalPages
                ? null
                : () => _fetchPageData(_currentPage + 1),
            child: const Text('下一页'),
          ),
        ],
      ),
    );
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  // 构建车次信息卡片
  Widget _buildTrainCard(Map<String, dynamic> train) {
    final status = train['status'] ?? 0;
    final delayMinutes = train['delayMinutes'] ?? 0;

    Color statusColor = Theme.of(context).colorScheme.onSurface;
    String statusText = '正在候车';

    if (status == 2) {
      statusColor = Colors.green;
      statusText = '正在检票';
    }

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          final trainNumber = (train['trainNumber'] as String?)?.trim();
          if (trainNumber == null || trainNumber.isEmpty) return;
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => AddJourneyPage(
                initialTrainNumber: trainNumber,
                autoSearchAndExpand: true,
              ),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    train['trainNumber'] ?? '',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (_directionMode == 0)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      child: Text(
                        statusText,
                        style: TextStyle(
                          color: statusColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                '${train['beginStationName']} → ${train['endStationName']}',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(
                    Icons.schedule,
                    size: 16,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '${train['scheduledTime']}',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                  if (delayMinutes > 0) ...[
                    const SizedBox(width: 8),
                    Text(
                      '实际: ${train['actualTime']}',
                      style: const TextStyle(color: Colors.orange),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.train, size: 16, color: Colors.red),
                  const SizedBox(width: 4),
                  Text(
                    '站台: ${train['platform']}',
                    style: const TextStyle(color: Colors.red),
                  ),
                ],
              ),
              if (_directionMode == 0) const SizedBox(height: 8),
              if (_directionMode == 0)
                Row(
                  children: [
                    Icon(
                      Icons.meeting_room,
                      size: 16,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        '候车室: ${train['waitingRoom']}',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                    ),
                  ],
                ),
              if (_directionMode == 0) const SizedBox(height: 8),
              if (_directionMode == 0)
                Row(
                  children: [
                    Icon(
                      Icons.exit_to_app,
                      size: 16,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        '检票口: ${train['checkoutName']}',
                        style: const TextStyle(color: Colors.green),
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('车站大屏')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: GestureDetector(
              onTap: _showStationSelector,
              child: Container(
                height: 56,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  border: Border.all(
                    color: _selectedStationCode != null
                        ? Theme.of(context).colorScheme.primary
                        : Theme.of(context).colorScheme.outline,
                  ),
                  borderRadius: BorderRadius.circular(12),
                  color: Theme.of(context).colorScheme.surface,
                ),
                alignment: Alignment.centerLeft,
                child: Row(
                  children: [
                    Icon(
                      Icons.location_on,
                      size: 20,
                      color: _selectedStationCode != null
                          ? Theme.of(context).colorScheme.primary
                          : Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _selectedStationName,
                        style: TextStyle(
                          fontSize: 16,
                          color: _selectedStationCode != null
                              ? Theme.of(context).colorScheme.onSurface
                              : Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                    Icon(
                      Icons.arrow_drop_down,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ],
                ),
              ),
            ),
          ),

          // 显示按钮
          if (_selectedStationCode != null && !_dataLoaded)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _loading ? null : () => _fetchPageData(1),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    foregroundColor: Theme.of(context).colorScheme.onPrimary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _loading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation(Colors.white),
                          ),
                        )
                      : const Text(
                          '显示车站大屏',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ),
            ),

          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: SegmentedButton<int>(
              segments: const [
                ButtonSegment(
                  value: 0,
                  label: Text('出发/经过', style: TextStyle(fontSize: 16)),
                  icon: Icon(Icons.location_on, size: 20),
                ),
                ButtonSegment(
                  value: 1,
                  label: Text('终到/终点', style: TextStyle(fontSize: 16)),
                  icon: Icon(Icons.location_on, size: 20),
                ),
              ],
              selected: {_directionMode},
              onSelectionChanged: (Set<int> s) =>
                  _handleDirectionChange(s.first),
              style: SegmentedButton.styleFrom(
                backgroundColor: Theme.of(
                  context,
                ).colorScheme.surfaceContainerHighest,
                selectedBackgroundColor: Theme.of(context).colorScheme.primary,
                selectedForegroundColor: Theme.of(
                  context,
                ).colorScheme.onPrimary,
                visualDensity: VisualDensity.compact,
                minimumSize: const Size(0, 56),
                padding: const EdgeInsets.symmetric(vertical: 8),
              ),
            ),
          ),

          if (_dataLoaded) _buildPaginationControls(),

          // 数据展示区域
          if (_dataLoaded)
            Expanded(
              child: _currentPageData.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.train, size: 64, color: Colors.grey),
                          const SizedBox(height: 16),
                          Text(
                            '暂无车次信息',
                            style: TextStyle(
                              fontSize: 16,
                              color: Theme.of(context).hintColor,
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      itemCount: _currentPageData.length,
                      itemBuilder: (context, index) {
                        return _buildTrainCard(_currentPageData[index]);
                      },
                    ),
            ),
        ],
      ),
    );
  }
}
