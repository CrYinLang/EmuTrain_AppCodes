// record_screen.dart — 旅途记录（复用旅途页卡片风格）

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/record_model.dart';
import '../providers/record_provider.dart';
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
        onPressed: () => Navigator.of(
          context,
        ).push(MaterialPageRoute(builder: (context) => const AddRecordPage())),
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

  String _normalizeStationName(String name) {
    return name.replaceAll('站', '').trim();
  }

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

// 添加记录页（复用 AddJourneyPage 风格）
class AddRecordPage extends StatefulWidget {
  const AddRecordPage({super.key});
  @override
  State<AddRecordPage> createState() => _AddRecordPageState();
}

class _AddRecordPageState extends State<AddRecordPage> {
  final _trainCodeCtrl = TextEditingController();
  final _fromCtrl = TextEditingController();
  final _toCtrl = TextEditingController();
  DateTime? _selectedDate;
  TimeOfDay _depTime = const TimeOfDay(hour: 8, minute: 0);
  TimeOfDay _arrTime = const TimeOfDay(hour: 12, minute: 0);

  @override
  void initState() {
    super.initState();
    _selectedDate = DateTime.now();
  }

  String get dateText => _selectedDate == null
      ? '选择日期'
      : '${_selectedDate!.year}-${_selectedDate!.month.toString().padLeft(2, '0')}-${_selectedDate!.day.toString().padLeft(2, '0')}';

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? now,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
    if (picked != null) setState(() => _selectedDate = picked);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('添加记录')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // 日期选择器（复用旅途页风格）
            Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: _pickDate,
                    child: Container(
                      height: 56,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.5),
                        ),
                        borderRadius: BorderRadius.circular(12),
                        color: Theme.of(context).colorScheme.surface,
                      ),
                      alignment: Alignment.centerLeft,
                      child: Row(
                        children: [
                          Icon(Icons.calendar_today, size: 20,
                            color: Theme.of(context).colorScheme.primary),
                          const SizedBox(width: 8),
                          Text(dateText, style: TextStyle(
                            fontSize: 16,
                            color: _selectedDate == null
                                ? Theme.of(context).colorScheme.onSurfaceVariant
                                : Theme.of(context).colorScheme.onSurface,
                          )),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            // 车次输入
            TextField(
              controller: _trainCodeCtrl,
              textCapitalization: TextCapitalization.characters,
              decoration: InputDecoration(
                labelText: '车次',
                hintText: '例如 G1234',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                prefixIcon: const Icon(Icons.train),
              ),
            ),
            const SizedBox(height: 16),
            // 起终站
            Row(children: [
              Expanded(child: TextField(
                controller: _fromCtrl,
                decoration: InputDecoration(
                  labelText: '出发站',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  prefixIcon: const Icon(Icons.location_on_outlined),
                ),
              )),
              const SizedBox(width: 12),
              Expanded(child: TextField(
                controller: _toCtrl,
                decoration: InputDecoration(
                  labelText: '到达站',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  prefixIcon: const Icon(Icons.location_on),
                ),
              )),
            ]),
            const SizedBox(height: 16),
            // 时间选择
            Row(children: [
              Expanded(child: ListTile(
                title: const Text('出发时间'),
                subtitle: Text(_depTime.format(context)),
                leading: const Icon(Icons.access_time),
                onTap: () async {
                  final t = await showTimePicker(context: context, initialTime: _depTime);
                  if (t != null) setState(() => _depTime = t);
                },
              )),
              Expanded(child: ListTile(
                title: const Text('到达时间'),
                subtitle: Text(_arrTime.format(context)),
                leading: const Icon(Icons.access_time_filled),
                onTap: () async {
                  final t = await showTimePicker(context: context, initialTime: _arrTime);
                  if (t != null) setState(() => _arrTime = t);
                },
              )),
            ]),
            const SizedBox(height: 32),
            // 保存按钮
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  foregroundColor: Theme.of(context).colorScheme.onPrimary,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('保存', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _save() {
    if (_trainCodeCtrl.text.isEmpty || _fromCtrl.text.isEmpty || _toCtrl.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('请填写完整信息')));
      return;
    }
    final depStr = '${_depTime.hour.toString().padLeft(2, '0')}:${_depTime.minute.toString().padLeft(2, '0')}';
    final arrStr = '${_arrTime.hour.toString().padLeft(2, '0')}:${_arrTime.minute.toString().padLeft(2, '0')}';
    final record = TrainRecord(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      trainCode: _trainCodeCtrl.text.trim().toUpperCase(),
      fromStation: _fromCtrl.text.trim(),
      toStation: _toCtrl.text.trim(),
      fromStationCode: '',
      toStationCode: '',
      departureTime: depStr,
      arrivalTime: arrStr,
      travelDate: _selectedDate ?? DateTime.now(),
      stations: [],
    );
    context.read<RecordProvider>().addRecord(record);
    Navigator.pop(context);
  }

  @override
  void dispose() {
    _trainCodeCtrl.dispose();
    _fromCtrl.dispose();
    _toCtrl.dispose();
    super.dispose();
  }
}
