// record_screen.dart — 旅途记录（独立模块，数据不与行程管理混合）

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/record_model.dart';
import '../providers/record_provider.dart';
import '../journey/journey.dart';
import '../journey/custom_journey_page.dart';
import 'record_detail_page.dart';

class RecordScreen extends StatelessWidget {
  const RecordScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('旅途记录'),
        actions: [
          Consumer<RecordProvider>(
            builder: (context, provider, child) {
              if (provider.records.isEmpty) return const SizedBox();
              return PopupMenuButton<String>(
                onSelected: (value) {
                  if (value == 'sort') {
                    provider.sortByDateTime();
                    ScaffoldMessenger.of(
                      context,
                    ).showSnackBar(const SnackBar(content: Text('已按出发时间排序')));
                  } else if (value == 'clear') {
                    showDialog(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: const Text('确认清空'),
                        content: const Text('确定要清空所有记录吗？'),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text('取消'),
                          ),
                          ElevatedButton(
                            onPressed: () {
                              provider.clearAll();
                              Navigator.pop(context);
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red[300],
                            ),
                            child: const Text('清空'),
                          ),
                        ],
                      ),
                    );
                  }
                },
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: 'sort',
                    child: Row(
                      children: [
                        Icon(Icons.sort),
                        SizedBox(width: 8),
                        Text('按日期排序'),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'clear',
                    child: Row(
                      children: [
                        Icon(Icons.delete_outline, color: Colors.red),
                        SizedBox(width: 8),
                        Text('清空所有', style: TextStyle(color: Colors.red)),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
      body: Consumer<RecordProvider>(
        builder: (context, provider, child) {
          if (provider.records.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.train_outlined, size: 80, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  Text(
                    '还没有添加记录',
                    style: TextStyle(
                      fontSize: 18,
                      color: Colors.grey[600],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '点击右下角按钮添加',
                    style: TextStyle(fontSize: 14, color: Colors.grey[500]),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: provider.records.length,
            itemBuilder: (context, index) {
              final record = provider.records[index];
              return RecordCard(
                record: record,
                onDelete: () => provider.removeRecord(record.id),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          // 弹出选择菜单：搜索添加 或 自定义记录
          final choice = await showModalBottomSheet<String>(
            context: context,
            builder: (ctx) => SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ListTile(
                      leading: const Icon(Icons.search, color: Colors.blue),
                      title: const Text('搜索添加'),
                      subtitle: const Text('通过车次或车站查询添加记录'),
                      onTap: () => Navigator.pop(ctx, 'search'),
                    ),
                    ListTile(
                      leading: const Icon(Icons.edit_location_alt, color: Colors.purple),
                      title: const Text('自定义记录'),
                      subtitle: const Text('手动添加非标准线路或临时记录'),
                      onTap: () => Navigator.pop(ctx, 'custom'),
                    ),
                  ],
                ),
              ),
            ),
          );

          if (choice == 'search') {
            await Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => AddJourneyPage(
                  title: '添加记录',
                  onSave: ({
                    required trainInfo,
                    required date,
                    required stationList,
                    required isStation,
                    required fromStation,
                    required toStation,
                    required seatType,
                    required seatInfo,
                  }) {
                    final record = TrainRecord.fromSearchResult(
                      trainInfo: trainInfo,
                      date: date,
                      stationList: stationList,
                      isStation: isStation,
                      fromStation: fromStation,
                      toStation: toStation,
                      seatType: seatType,
                      seatInfo: seatInfo,
                    );
                    context.read<RecordProvider>().addRecord(record);
                  },
                ),
              ),
            );
          } else if (choice == 'custom') {
            await Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => CustomJourneyPage(
                  onSave: (journey) {
                    context.read<RecordProvider>().addRecord(
                      TrainRecord.fromJourney(journey),
                    );
                  },
                ),
              ),
            );
          }
        },
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Theme.of(context).colorScheme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16.0),
        ),
        child: const Icon(Icons.add, size: 28),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
    );
  }
}

// 记录卡片（复用旅途卡片风格，去掉状态、日期改为普通颜色、去掉"上车"）
class RecordCard extends StatelessWidget {
  final TrainRecord record;
  final VoidCallback onDelete;

  const RecordCard({super.key, required this.record, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => RecordDetailPage(record: record),
            ),
          );
        },
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 头部：车次（无状态标签）
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: isDark
                              ? Colors.blue.shade900
                              : Colors.blue.shade50,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          record.trainCode,
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: isDark
                                ? Colors.blue.shade200
                                : Colors.blue.shade700,
                          ),
                        ),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline),
                    color: Colors.red,
                    onPressed: () {
                      showDialog(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: const Text('确认删除'),
                          content: Text('确定要删除 ${record.trainCode} 次记录吗？'),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context),
                              child: const Text('取消'),
                            ),
                            ElevatedButton(
                              onPressed: () {
                                onDelete();
                                Navigator.pop(context);
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.red[300],
                              ),
                              child: const Text('删除'),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // 中间：站点和时间
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          record.departureTime,
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${record.fromStation}站',
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.blue,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Column(
                      children: [
                        Icon(
                          Icons.arrow_forward,
                          color: Theme.of(context).hintColor,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          record.getTotalDuration(),
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 12,
                            color: Theme.of(context).hintColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          record.arrivalTime,
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${record.toStation}站',
                          style: TextStyle(
                            fontSize: 14,
                            color: Theme.of(context).hintColor,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.end,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // 底部：日期（普通颜色，无"上车"）和关联数据
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.calendar_today,
                        size: 14,
                        color: Theme.of(context).hintColor,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        record.getFormattedDate(),
                        style: TextStyle(
                          fontSize: 13,
                          color: Theme.of(context).hintColor,
                        ),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      if (record.speedRecordIds.isNotEmpty) ...[
                        Icon(Icons.speed, size: 14, color: Colors.green[600]),
                        const SizedBox(width: 4),
                        Text(
                          '${record.speedRecordIds.length}条测速',
                          style: TextStyle(fontSize: 12, color: Colors.green[600]),
                        ),
                        const SizedBox(width: 12),
                      ],
                      if (record.imagePaths.isNotEmpty) ...[
                        Icon(Icons.image, size: 14, color: Theme.of(context).hintColor),
                        const SizedBox(width: 4),
                        Text(
                          '${record.imagePaths.length}张图片',
                          style: TextStyle(fontSize: 12, color: Theme.of(context).hintColor),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

