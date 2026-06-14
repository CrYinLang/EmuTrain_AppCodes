// screens/record_screen.dart
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
            builder: (context, provider, _) {
              if (provider.records.isEmpty) return const SizedBox();
              return PopupMenuButton<String>(
                onSelected: (v) {
                  if (v == 'clear') {
                    showDialog(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const Text('确认清空'),
                        content: const Text('确定要清空所有记录吗？'),
                        actions: [
                          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
                          ElevatedButton(
                            onPressed: () { provider.clearAll(); Navigator.pop(ctx); },
                            style: ElevatedButton.styleFrom(backgroundColor: Colors.red[300]),
                            child: const Text('清空'),
                          ),
                        ],
                      ),
                    );
                  }
                },
                itemBuilder: (_) => [
                  const PopupMenuItem(value: 'clear', child: Row(
                    children: [
                      Icon(Icons.delete_outline, color: Colors.red),
                      SizedBox(width: 8),
                      Text('清空所有', style: TextStyle(color: Colors.red)),
                    ],
                  )),
                ],
              );
            },
          ),
        ],
      ),
      body: Consumer<RecordProvider>(
        builder: (context, provider, _) {
          if (provider.records.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.bookmark_border, size: 80, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  Text('还没有记录', style: TextStyle(fontSize: 18, color: Colors.grey[600])),
                  const SizedBox(height: 8),
                  Text('点击右下角按钮添加', style: TextStyle(fontSize: 14, color: Colors.grey[500])),
                ],
              ),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: provider.records.length,
            itemBuilder: (context, index) {
              final record = provider.records[index];
              return RecordCard(record: record);
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => Navigator.push(context,
          MaterialPageRoute(builder: (_) => const AddRecordPage())),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Theme.of(context).colorScheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: const Icon(Icons.add, size: 28),
      ),
    );
  }
}

class RecordCard extends StatelessWidget {
  final TrainRecord record;
  const RecordCard({super.key, required this.record});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: () => Navigator.push(context,
          MaterialPageRoute(builder: (_) => RecordDetailPage(record: record))),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: cs.primaryContainer,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(record.trainCode, style: TextStyle(
                      fontWeight: FontWeight.bold, color: cs.onPrimaryContainer)),
                  ),
                  const Spacer(),
                  Text(record.getFormattedDate(),
                    style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant)),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(child: Text(record.fromStation,
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                    overflow: TextOverflow.ellipsis)),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Icon(Icons.arrow_forward, color: cs.onSurfaceVariant, size: 20),
                  ),
                  Expanded(child: Text(record.toStation,
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                    textAlign: TextAlign.right,
                    overflow: TextOverflow.ellipsis)),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Text(record.departureTime, style: TextStyle(fontSize: 14, color: cs.onSurfaceVariant)),
                  const SizedBox(width: 8),
                  Text(record.getTotalDuration(),
                    style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
                  const Spacer(),
                  Text(record.arrivalTime, style: TextStyle(fontSize: 14, color: cs.onSurfaceVariant)),
                ],
              ),
              if (record.speedRecordIds.isNotEmpty || record.imagePaths.isNotEmpty) ...[
                const Divider(height: 16),
                Row(
                  children: [
                    if (record.speedRecordIds.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: Chip(
                          label: Text('${record.speedRecordIds.length} 条测速', style: const TextStyle(fontSize: 11)),
                          visualDensity: VisualDensity.compact,
                          padding: EdgeInsets.zero,
                        ),
                      ),
                    if (record.imagePaths.isNotEmpty)
                      Chip(
                        label: Text('${record.imagePaths.length} 张图片', style: const TextStyle(fontSize: 11)),
                        visualDensity: VisualDensity.compact,
                        padding: EdgeInsets.zero,
                      ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class AddRecordPage extends StatefulWidget {
  const AddRecordPage({super.key});
  @override
  State<AddRecordPage> createState() => _AddRecordPageState();
}

class _AddRecordPageState extends State<AddRecordPage> {
  final _trainCodeCtrl = TextEditingController();
  final _fromCtrl = TextEditingController();
  final _toCtrl = TextEditingController();
  DateTime _selectedDate = DateTime.now();
  TimeOfDay _depTime = const TimeOfDay(hour: 8, minute: 0);
  TimeOfDay _arrTime = const TimeOfDay(hour: 12, minute: 0);

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final dateStr = '${_selectedDate.year}-${_selectedDate.month.toString().padLeft(2, '0')}-${_selectedDate.day.toString().padLeft(2, '0')}';
    return Scaffold(
      appBar: AppBar(title: const Text('添加记录')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(controller: _trainCodeCtrl,
              decoration: const InputDecoration(labelText: '车次', border: OutlineInputBorder())),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(child: TextField(controller: _fromCtrl,
                decoration: const InputDecoration(labelText: '出发站', border: OutlineInputBorder()))),
              const SizedBox(width: 12),
              Expanded(child: TextField(controller: _toCtrl,
                decoration: const InputDecoration(labelText: '到达站', border: OutlineInputBorder()))),
            ]),
            const SizedBox(height: 12),
            ListTile(
              title: Text('日期: $dateStr'),
              trailing: const Icon(Icons.calendar_today),
              onTap: () async {
                final d = await showDatePicker(context: context,
                  initialDate: _selectedDate, firstDate: DateTime(2020), lastDate: DateTime(2030));
                if (d != null) setState(() => _selectedDate = d);
              },
            ),
            Row(children: [
              Expanded(child: ListTile(
                title: Text('出发: ${_depTime.format(context)}'),
                onTap: () async {
                  final t = await showTimePicker(context: context, initialTime: _depTime);
                  if (t != null) setState(() => _depTime = t);
                },
              )),
              Expanded(child: ListTile(
                title: Text('到达: ${_arrTime.format(context)}'),
                onTap: () async {
                  final t = await showTimePicker(context: context, initialTime: _arrTime);
                  if (t != null) setState(() => _arrTime = t);
                },
              )),
            ]),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: cs.primary, foregroundColor: cs.onPrimary,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('保存', style: TextStyle(fontSize: 16)),
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
      travelDate: _selectedDate,
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
