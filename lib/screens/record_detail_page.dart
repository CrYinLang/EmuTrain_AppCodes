// screens/record_detail_page.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';

import '../models/record_model.dart';
import '../providers/record_provider.dart';
import 'function/gps.dart';

class RecordDetailPage extends StatelessWidget {
  final TrainRecord record;
  const RecordDetailPage({super.key, required this.record});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final provider = context.watch<RecordProvider>();
    final latest = provider.records.where((r) => r.id == record.id).firstOrNull ?? record;

    return Scaffold(
      appBar: AppBar(title: Text('${latest.trainCode} 次')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 基本信息卡片
            Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(children: [
                  Row(children: [
                    Text(latest.trainCode, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: cs.primary)),
                    const Spacer(),
                    Text(latest.getFormattedDate(), style: TextStyle(color: cs.onSurfaceVariant)),
                  ]),
                  const SizedBox(height: 16),
                  Row(children: [
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('出发', style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
                      Text(latest.fromStation, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w600)),
                      Text(latest.departureTime, style: TextStyle(fontSize: 16, color: cs.onSurfaceVariant)),
                    ])),
                    Column(children: [
                      Icon(Icons.train, color: cs.primary),
                      Text(latest.getTotalDuration(), style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
                    ]),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                      Text('到达', style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
                      Text(latest.toStation, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w600)),
                      Text(latest.arrivalTime, style: TextStyle(fontSize: 16, color: cs.onSurfaceVariant)),
                    ])),
                  ]),
                ]),
              ),
            ),
            const SizedBox(height: 16),

            // 操作按钮
            Row(children: [
              Expanded(child: _ActionCard(
                icon: Icons.map_outlined, label: '线路走向图',
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('线路走向图功能开发中')));
                },
              )),
              const SizedBox(width: 12),
              Expanded(child: _ActionCard(
                icon: Icons.speed, label: '开始测速',
                onTap: () {
                  Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const SpeedometerPage()));
                },
                color: Colors.green,
              )),
            ]),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(child: _ActionCard(
                icon: Icons.link, label: '关联测速记录',
                onTap: () => _linkTrackRecord(context, latest),
              )),
              const SizedBox(width: 12),
              Expanded(child: _ActionCard(
                icon: Icons.image_outlined, label: '导入图片',
                onTap: () => _pickImages(context, latest),
              )),
            ]),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(child: _ActionCard(
                icon: Icons.delete_outline, label: '删除记录',
                onTap: () {
                  showDialog(context: context, builder: (ctx) => AlertDialog(
                    title: const Text('确认删除'),
                    content: const Text('确定要删除这条记录吗？'),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
                      ElevatedButton(
                        onPressed: () {
                          provider.removeRecord(latest.id);
                          Navigator.pop(ctx);
                          Navigator.pop(context);
                        },
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.red[300]),
                        child: const Text('删除'),
                      ),
                    ],
                  ));
                },
                color: Colors.red,
              )),
              const SizedBox(width: 12),
              const Expanded(child: SizedBox()), // 占位
            ]),
            const SizedBox(height: 20),

            // 关联的测速记录列表
            if (latest.speedRecordIds.isNotEmpty) ...[
              Text('测速记录', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: cs.primary)),
              const SizedBox(height: 8),
              ...latest.speedRecordIds.map((trackId) => _LinkedTrackCard(
                trackId: trackId,
                onRemove: () {
                  final updated = TrainRecord(
                    id: latest.id, trainCode: latest.trainCode,
                    fromStation: latest.fromStation, toStation: latest.toStation,
                    fromStationCode: latest.fromStationCode, toStationCode: latest.toStationCode,
                    departureTime: latest.departureTime, arrivalTime: latest.arrivalTime,
                    travelDate: latest.travelDate, stations: latest.stations,
                    seatType: latest.seatType, seatInfo: latest.seatInfo,
                    speedRecordIds: latest.speedRecordIds.where((id) => id != trackId).toList(),
                    imagePaths: latest.imagePaths,
                  );
                  provider.updateRecord(updated);
                },
              )),
              const SizedBox(height: 16),
            ],

            // 图片列表
            if (latest.imagePaths.isNotEmpty) ...[
              Text('记录图片', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: cs.primary)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: latest.imagePaths.map((path) =>
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.asset(path, width: 100, height: 100, fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        width: 100, height: 100,
                        color: cs.surfaceContainerHighest,
                        child: Icon(Icons.broken_image, color: cs.onSurfaceVariant),
                      ),
                    ),
                  ),
                ).toList(),
              ),
            ],

            // 站点列表
            if (latest.stations.isNotEmpty) ...[
              const SizedBox(height: 20),
              Text('途经站点', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: cs.primary)),
              const SizedBox(height: 8),
              ...latest.stations.asMap().entries.map((entry) => ListTile(
                dense: true,
                leading: CircleAvatar(radius: 14,
                  backgroundColor: entry.value.isStart ? Colors.green : entry.value.isEnd ? Colors.red : cs.surfaceContainerHighest,
                  child: Text('${entry.key + 1}', style: TextStyle(fontSize: 11,
                    color: entry.value.isStart || entry.value.isEnd ? Colors.white : cs.onSurface))),
                title: Text(entry.value.stationName),
                subtitle: Text('${entry.value.arrivalTime} / ${entry.value.departureTime}'),
              )),
            ],
          ],
        ),
      ),
    );
  }

  // 关联已有测速记录
  Future<void> _linkTrackRecord(BuildContext context, TrainRecord record) async {
    final allTracks = await TrackRecord.loadAllMeta();
    if (allTracks.isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('没有可用的测速记录，请先进行测速')));
      }
      return;
    }

    // 过滤掉已关联的
    final available = allTracks.where((t) => !record.speedRecordIds.contains(t.id)).toList();
    if (available.isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('所有测速记录都已关联')));
      }
      return;
    }

    if (!context.mounted) return;
    final selected = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.3,
        maxChildSize: 0.9,
        expand: false,
        builder: (ctx, scrollCtrl) => Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text('选择要关联的测速记录',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold,
                  color: Theme.of(ctx).colorScheme.primary)),
            ),
            Expanded(
              child: ListView.builder(
                controller: scrollCtrl,
                itemCount: available.length,
                itemBuilder: (ctx, i) {
                  final track = available[i];
                  final dateStr = '${track.startTime.month}/${track.startTime.day} '
                      '${track.startTime.hour.toString().padLeft(2, '0')}:'
                      '${track.startTime.minute.toString().padLeft(2, '0')}';
                  final distKm = (track.totalDistanceM / 1000).toStringAsFixed(2);
                  return ListTile(
                    leading: Icon(Icons.speed, color: Colors.green[600]),
                    title: Text('最高速度 ${track.maxSpeedKmh.toStringAsFixed(1)} km/h'),
                    subtitle: Text('$dateStr | $distKm km | ${track.avgSpeedKmh.toStringAsFixed(1)} km/h 均速'),
                    onTap: () => Navigator.pop(ctx, track.id),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );

    if (selected != null && context.mounted) {
      final provider = context.read<RecordProvider>();
      provider.addSpeedRecordToRecord(record.id, selected);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('已关联测速记录')));
    }
  }

  Future<void> _pickImages(BuildContext context, TrainRecord record) async {
    final picker = ImagePicker();
    final images = await picker.pickMultiImage();
    if (images.isNotEmpty) {
      final provider = context.read<RecordProvider>();
      for (final img in images) {
        provider.addImageToRecord(record.id, img.path);
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('已添加 ${images.length} 张图片')));
    }
  }
}

class _ActionCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color? color;

  const _ActionCard({required this.icon, required this.label, required this.onTap, this.color});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 20),
          child: Column(children: [
            Icon(icon, size: 28, color: color ?? cs.primary),
            const SizedBox(height: 8),
            Text(label, style: TextStyle(fontSize: 13, color: color ?? cs.onSurface)),
          ]),
        ),
      ),
    );
  }
}

// 关联的测速记录卡片（从 TrackRecord 加载）
class _LinkedTrackCard extends StatelessWidget {
  final String trackId;
  final VoidCallback onRemove;
  const _LinkedTrackCard({required this.trackId, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return FutureBuilder<TrackRecord?>(
      future: TrackRecord.loadFull(trackId),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return Card(
            margin: const EdgeInsets.only(bottom: 8),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(children: [
                const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
                const SizedBox(width: 12),
                Text('加载中...', style: TextStyle(color: cs.onSurfaceVariant)),
              ]),
            ),
          );
        }
        final track = snapshot.data!;
        final distKm = (track.totalDistanceM / 1000).toStringAsFixed(2);
        final dateStr = '${track.startTime.year}-${track.startTime.month.toString().padLeft(2, '0')}-${track.startTime.day.toString().padLeft(2, '0')} '
            '${track.startTime.hour.toString().padLeft(2, '0')}:${track.startTime.minute.toString().padLeft(2, '0')}';

        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(children: [
              Icon(Icons.speed, color: Colors.green[600], size: 32),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('最高速度: ${track.maxSpeedKmh.toStringAsFixed(1)} km/h',
                  style: const TextStyle(fontWeight: FontWeight.bold)),
                Text('$distKm km | 均速 ${track.avgSpeedKmh.toStringAsFixed(1)} km/h',
                  style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
                Text(dateStr, style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant)),
              ])),
              IconButton(
                icon: Icon(Icons.close, size: 18, color: cs.onSurfaceVariant),
                onPressed: onRemove,
                tooltip: '取消关联',
              ),
            ]),
          ),
        );
      },
    );
  }
}
