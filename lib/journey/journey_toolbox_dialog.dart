// screens/journey_toolbox_dialog.dart
import 'package:flutter/material.dart';
import '../models/journey_model.dart';
import '../map/linemap.dart';
import '../widgets/error.dart';

typedef RoutingFetchResult = ({List<dynamic> routingItems, String trainModel});

class ToolboxDialog extends StatefulWidget {
  final Journey journey;
  final String trainCode;
  final String date;
  final List<dynamic> routingItems;
  final String trainModel;
  final Future<RoutingFetchResult> Function() onFetchRouting;

  const ToolboxDialog({
    required this.journey,
    required this.trainCode,
    required this.date,
    required this.routingItems,
    required this.trainModel,
    required this.onFetchRouting,
  });

  @override
  State<ToolboxDialog> createState() => ToolboxDialogState();
}

class ToolboxDialogState extends State<ToolboxDialog>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<dynamic> _routingItems = [];
  String _trainModel = '';
  bool _loadingRouting = false;
  String? _routingError;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _routingItems = widget.routingItems;
    _trainModel = widget.trainModel;

    // 切换到交路表标签时才加载数据
    _tabController.addListener(() {
      if (_tabController.index == 1 &&
          _routingItems.isEmpty &&
          !_loadingRouting) {
        _loadRouting();
      }
    });

    // 如果切入时就是第一页，交路数据若为空先不加载
    // 仅当已有缓存时直接显示
  }

  Future<void> _loadRouting() async {
    if (_loadingRouting) return;
    setState(() {
      _loadingRouting = true;
      _routingError = null;
    });
    try {
      final result = await widget.onFetchRouting();
      if (mounted) {
        setState(() {
          _routingItems = result.routingItems;
          _trainModel = result.trainModel;
          _loadingRouting = false;
        });
      }
    } catch (e) {
      logError(from: 'journey_toolbox_dialog/_loadRouting', error: e.toString());
      if (mounted) {
        setState(() {
          _routingError = '加载失败: $e';
          _loadingRouting = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      children: [
        // 标题栏 + Tab
        Container(
          decoration: BoxDecoration(
            color: isDark ? Colors.black : Colors.white,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(12),
              topRight: Radius.circular(12),
            ),
          ),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.build_circle_outlined,
                      color: cs.onSurface,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '工具箱  ${widget.trainCode}',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: cs.onSurface,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.close, color: cs.onSurface),
                      onPressed: () => Navigator.of(context).pop(),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
              ),
              TabBar(
                controller: _tabController,
                labelColor: cs.onSurface,
                unselectedLabelColor: cs.onSurface.withAlpha(160),
                indicatorColor: cs.onSurface,
                tabs: const [
                  Tab(icon: Icon(Icons.map, size: 18), text: '线路走向图'),
                  Tab(icon: Icon(Icons.swap_horiz, size: 18), text: '交路表'),
                ],
              ),
            ],
          ),
        ),

        // Tab 内容 — 仅响应按钮切换，禁止滑动
        Expanded(
          child: TabBarView(
            controller: _tabController,
            physics: const NeverScrollableScrollPhysics(),
            children: [
              // 线路走向图：直接用 LineMapContent，避免嵌套 Scaffold
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    // 路线摘要卡片
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Row(
                          children: [
                            Icon(Icons.train, color: cs.onSurface),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '${widget.journey.trainCode}次 • ${widget.journey.fromStation} → ${widget.journey.toStation}',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  Text(
                                    '全程${widget.journey.getTotalDuration()} • ${widget.journey.stations.length}个站点',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey.shade600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Expanded(child: LineMapContent(journey: widget.journey)),
                  ],
                ),
              ),
              _buildRoutingTab(),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildRoutingTab() {
    if (_loadingRouting) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_routingError != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.red),
            const SizedBox(height: 12),
            Text(
              _routingError!,
              style: const TextStyle(color: Colors.red),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _loadRouting,
              icon: const Icon(Icons.refresh),
              label: const Text('重试'),
            ),
          ],
        ),
      );
    }

    if (_routingItems.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.swap_horiz, size: 64, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            Text(
              '暂无交路信息',
              style: TextStyle(fontSize: 16, color: Colors.grey.shade500),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _loadRouting,
              icon: const Icon(Icons.refresh),
              label: const Text('重新加载'),
            ),
          ],
        ),
      );
    }

    return _buildRoutingTable();
  }

  Widget _buildRoutingTable() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = Theme.of(context).colorScheme.primary;

    // 找到当前车次在交路中的位置
    final currentCode = widget.trainCode;

    return ColoredBox(
      color: isDark ? Colors.black : Colors.white,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 车型信息
            if (_trainModel.isNotEmpty)
              Container(
                width: double.infinity,
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(10),
                  // border: Border.all(color: primary.withAlpha(60)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.train, size: 18, color: primary),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _trainModel,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          // color: primary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

            // 表头
            Container(
              decoration: BoxDecoration(
                color: isDark ? Colors.grey.shade800 : Colors.grey.shade900,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(10),
                  topRight: Radius.circular(10),
                ),
              ),
              child: _buildTableRow(
                isHeader: true,
                cells: const ['车次', '始发站', '出发', '终到站', '到达'],
              ),
            ),

            // 数据行
            Container(
              decoration: BoxDecoration(
                border: Border.all(color: Theme.of(context).dividerColor),
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(10),
                  bottomRight: Radius.circular(10),
                ),
              ),
              child: Column(
                children: _routingItems.asMap().entries.map((entry) {
                  final idx = entry.key;
                  final item = entry.value as Map<String, dynamic>;
                  final trainNumber = item['trainNumber']?.toString() ?? '--';
                  final beginStation =
                      item['beginStationName']?.toString() ?? '--';
                  final endStation = item['endStationName']?.toString() ?? '--';
                  final depTime = item['departureTime']?.toString() ?? '--:--';
                  final arrTime = item['arrivalTime']?.toString() ?? '--:--';

                  final isCurrent = trainNumber == currentCode;
                  final isLast = idx == _routingItems.length - 1;

                  // 当前车次高亮
                  final rowColor = isCurrent
                      ? (isDark ? primary.withAlpha(60) : primary.withAlpha(30))
                      : (idx.isEven
                            ? (isDark
                                  ? Colors.white.withAlpha(8)
                                  : const Color(0xFFF5F5F5))
                            : Colors.transparent);

                  return Container(
                    decoration: BoxDecoration(
                      color: rowColor,
                      border: isLast
                          ? null
                          : Border(
                              bottom: BorderSide(
                                color: Theme.of(context).dividerColor,
                                width: 0.5,
                              ),
                            ),
                      borderRadius: isLast
                          ? const BorderRadius.only(
                              bottomLeft: Radius.circular(10),
                              bottomRight: Radius.circular(10),
                            )
                          : null,
                    ),
                    child: _buildTableRow(
                      isHeader: false,
                      isCurrent: isCurrent,
                      cells: [
                        trainNumber,
                        beginStation,
                        depTime,
                        endStation,
                        arrTime,
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),

            const SizedBox(height: 12),
            Text(
              '数据来源：sharyou.moefactory.com，仅供参考',
              style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTableRow({
    required bool isHeader,
    required List<String> cells,
    bool isCurrent = false,
  }) {
    final primary = Theme.of(context).colorScheme.primary;
    // 列宽比例：车次/始发/时间/终到/时间
    final flexes = [3, 3, 2, 3, 2];

    final baseStyle = isHeader
        ? const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          )
        : TextStyle(
            fontSize: 13,
            fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
            color: isCurrent
                ? primary
                : Theme.of(context).colorScheme.onSurface,
          );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 10),
      child: Row(
        children: List.generate(cells.length, (i) {
          final isTrainCell = !isHeader && i == 0;
          return Expanded(
            flex: flexes[i],
            child: isTrainCell && isCurrent
                ? Row(
                    children: [
                      Container(
                        width: 4,
                        height: 16,
                        margin: const EdgeInsets.only(right: 4),
                        decoration: BoxDecoration(
                          color: primary,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      Expanded(
                        child: Text(
                          cells[i],
                          style: baseStyle,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  )
                : Text(
                    cells[i],
                    style: baseStyle,
                    overflow: TextOverflow.ellipsis,
                    textAlign: (i == 2 || i == 4)
                        ? TextAlign.center
                        : TextAlign.start,
                  ),
          );
        }),
      ),
    );
  }
}
