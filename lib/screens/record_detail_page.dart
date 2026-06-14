// record_detail_page.dart — 记录详情（复用旅途详情页风格）

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';

import 'dart:io';

import '../models/record_model.dart';
import '../providers/record_provider.dart';
import 'function/gps.dart';
import 'linemap.dart';

class RecordDetailPage extends StatelessWidget {
  final TrainRecord record;
  const RecordDetailPage({super.key, required this.record});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${record.trainCode} 次记录详情'),
        backgroundColor: Theme.of(context).colorScheme.surface,
        foregroundColor: Theme.of(context).colorScheme.onSurface,
      ),
      body: _RecordDetailContent(record: record),
    );
  }
}

class _RecordDetailContent extends StatefulWidget {
  final TrainRecord record;
  const _RecordDetailContent({required this.record});

  @override
  State<_RecordDetailContent> createState() => __RecordDetailContentState();
}

class __RecordDetailContentState extends State<_RecordDetailContent>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final provider = context.watch<RecordProvider>();
    final latest = provider.records.where((r) => r.id == widget.record.id).firstOrNull ?? widget.record;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 基本信息卡片（复用旅途详情风格）
          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  // 车次和日期
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: cs.primaryContainer,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(latest.trainCode, style: TextStyle(
                          fontSize: 20, fontWeight: FontWeight.bold, color: cs.onPrimaryContainer)),
                      ),
                      const Spacer(),
                      Text(latest.getFormattedDate(),
                        style: TextStyle(fontSize: 14, color: cs.onSurfaceVariant)),
                    ],
                  ),
                  const SizedBox(height: 20),
                  // 站点信息
                  Row(
                    children: [
                      Expanded(child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(latest.departureTime,
                            style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 4),
                          Text('${latest.fromStation}站',
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.blue)),
                        ],
                      )),
                      Column(
                        children: [
                          Icon(Icons.arrow_forward, color: cs.onSurfaceVariant, size: 28),
                          const SizedBox(height: 4),
                          Text(latest.getTotalDuration(),
                            style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant)),
                        ],
                      ),
                      Expanded(child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(latest.arrivalTime,
                            style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 4),
                          Text('${latest.toStation}站',
                            style: TextStyle(fontSize: 14, color: cs.onSurfaceVariant),
                            textAlign: TextAlign.end),
                        ],
                      )),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // 功能按钮区
          Row(children: [
            Expanded(child: _buildActionCard(context, Icons.map_outlined, '线路走向图', () {
              // 直接调用现有线路图
              final journey = latest.toJourney();
              Navigator.push(context, MaterialPageRoute(
                builder: (_) => Scaffold(
                  appBar: AppBar(title: Text('线路走向图  ${latest.trainCode}')),
                  body: LineMapContent(journey: journey),
                ),
              ));
            })),
            const SizedBox(width: 12),
            Expanded(child: _buildActionCard(context, Icons.speed, '开始测速', () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => const SpeedometerPage()));
            }, color: Colors.green)),
          ]),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(child: _buildActionCard(context, Icons.link, '关联测速记录', () {
              _linkTrackRecord(context, latest);
            })),
            const SizedBox(width: 12),
            Expanded(child: _buildActionCard(context, Icons.image_outlined, '导入图片', () {
              _pickImages(context, latest);
            })),
          ]),
          const SizedBox(height: 20),

          // 关联的测速记录
          if (latest.speedRecordIds.isNotEmpty) ...[
            Text('测速记录', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: cs.primary)),
            const SizedBox(height: 8),
            ...latest.speedRecordIds.map((trackId) => _LinkedTrackCard(
              trackId: trackId,
              onRemove: () {
                provider.removeSpeedRecordFromRecord(latest.id, trackId);
              },
            )),
            const SizedBox(height: 16),
          ],

          // 记录图片
          if (latest.imagePaths.isNotEmpty) ...[
            Text('记录图片', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: cs.primary)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: latest.imagePaths.asMap().entries.map((entry) =>
                GestureDetector(
                  onTap: () {
                    Navigator.push(context, MaterialPageRoute(
                      builder: (_) => _ImageViewer(
                        imagePaths: latest.imagePaths,
                        initialIndex: entry.key,
                        onDelete: (idx) {
                          final path = latest.imagePaths[idx];
                          provider.removeImageFromRecord(latest.id, path);
                        },
                      ),
                    ));
                  },
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.file(File(entry.value), width: 100, height: 100, fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        width: 100, height: 100, color: cs.surfaceContainerHighest,
                        child: Icon(Icons.broken_image, color: cs.onSurfaceVariant),
                      ),
                    ),
                  ),
                ),
              ).toList(),
            ),
            const SizedBox(height: 16),
          ],

          // 途经站点
          if (latest.stations.isNotEmpty) ...[
            Text('途经站点', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: cs.primary)),
            const SizedBox(height: 8),
            AnimatedBuilder(
              animation: _animationController,
              builder: (context, child) {
                return FadeTransition(
                  opacity: _animationController,
                  child: child,
                );
              },
              child: Card(
                elevation: 1,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Column(
                    children: latest.stations.asMap().entries.map((entry) {
                      final idx = entry.key;
                      final station = entry.value;
                      final isStart = station.isStart;
                      final isEnd = station.isEnd;
                      return ListTile(
                        dense: true,
                        leading: SizedBox(
                          width: 30,
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                width: 12, height: 12,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: isStart ? Colors.green : isEnd ? Colors.red : cs.primary,
                                  border: Border.all(color: Colors.white, width: 2),
                                ),
                              ),
                              if (!isEnd)
                                Container(width: 2, height: 16, color: cs.outlineVariant),
                            ],
                          ),
                        ),
                        title: Text(station.stationName,
                          style: TextStyle(
                            fontWeight: isStart || isEnd ? FontWeight.bold : FontWeight.normal,
                            fontSize: 14,
                          )),
                        subtitle: Text(
                          '${station.arrivalTime} / ${station.departureTime}',
                          style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
                        ),
                        trailing: isStart
                            ? Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(color: Colors.green[50], borderRadius: BorderRadius.circular(4)),
                                child: Text('出发', style: TextStyle(fontSize: 10, color: Colors.green[700])))
                            : isEnd
                                ? Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(color: Colors.red[50], borderRadius: BorderRadius.circular(4)),
                                    child: Text('到达', style: TextStyle(fontSize: 10, color: Colors.red[700])))
                                : null,
                      );
                    }).toList(),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildActionCard(BuildContext context, IconData icon, String label, VoidCallback onTap, {Color? color}) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(children: [
            Icon(icon, size: 28, color: color ?? cs.primary),
            const SizedBox(height: 6),
            Text(label, style: TextStyle(fontSize: 13, color: color ?? cs.onSurface)),
          ]),
        ),
      ),
    );
  }

  Future<void> _linkTrackRecord(BuildContext context, TrainRecord record) async {
    final allTracks = await TrackRecord.loadAllMeta();
    if (allTracks.isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('没有可用的测速记录，请先进行测速')));
      }
      return;
    }
    final available = allTracks.where((t) => !record.speedRecordIds.contains(t.id)).toList();
    if (available.isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('所有测速记录都已关联')));
      }
      return;
    }
    if (!context.mounted) return;
    final selected = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.6, minChildSize: 0.3, maxChildSize: 0.9, expand: false,
        builder: (ctx, scrollCtrl) => Column(children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text('选择要关联的测速记录',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Theme.of(ctx).colorScheme.primary)),
          ),
          Expanded(child: ListView.builder(
            controller: scrollCtrl,
            itemCount: available.length,
            itemBuilder: (ctx, i) {
              final track = available[i];
              final dateStr = '${track.startTime.month}/${track.startTime.day} '
                  '${track.startTime.hour.toString().padLeft(2, '0')}:${track.startTime.minute.toString().padLeft(2, '0')}';
              final distKm = (track.totalDistanceM / 1000).toStringAsFixed(2);
              return ListTile(
                leading: Icon(Icons.speed, color: Colors.green[600]),
                title: Text('最高速度 ${track.maxSpeedKmh.toStringAsFixed(1)} km/h'),
                subtitle: Text('$dateStr | $distKm km | ${track.avgSpeedKmh.toStringAsFixed(1)} km/h 均速'),
                onTap: () => Navigator.pop(ctx, track.id),
              );
            },
          )),
        ]),
      ),
    );
    if (selected != null && context.mounted) {
      context.read<RecordProvider>().addSpeedRecordToRecord(record.id, selected);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('已关联测速记录')));
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
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('已添加 ${images.length} 张图片')));
    }
  }
}

// 关联的测速记录卡片（可点击查看轨迹）
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
          child: InkWell(
            onTap: () {
              Navigator.push(context,
                MaterialPageRoute(builder: (_) => TrackDetailPage(recordId: trackId)));
            },
            borderRadius: BorderRadius.circular(12),
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
                  onPressed: onRemove, tooltip: '取消关联',
                ),
              ]),
            ),
          ),
        );
      },
    );
  }
}

// 全屏图片查看器（双指缩放 + 删除）
class _ImageViewer extends StatefulWidget {
  final List<String> imagePaths;
  final int initialIndex;
  final ValueChanged<int> onDelete; // 回调删除的索引

  const _ImageViewer({required this.imagePaths, required this.initialIndex, required this.onDelete});

  @override
  State<_ImageViewer> createState() => _ImageViewerState();
}

class _ImageViewerState extends State<_ImageViewer> {
  late PageController _pageCtrl;
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageCtrl = PageController(initialPage: _currentIndex);
  }

  @override
  void dispose() {
    _pageCtrl.dispose();
    super.dispose();
  }

  void _deleteCurrent() {
    showDialog(context: context, builder: (ctx) => AlertDialog(
      title: const Text('删除图片'),
      content: const Text('确定要删除这张图片吗？'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
        ElevatedButton(
          onPressed: () {
            Navigator.pop(ctx);
            widget.onDelete(_currentIndex);
            if (widget.imagePaths.length <= 1) {
              Navigator.pop(context);
            } else {
              setState(() {
                if (_currentIndex >= widget.imagePaths.length - 1) {
                  _currentIndex = widget.imagePaths.length - 2;
                  _pageCtrl.jumpToPage(_currentIndex);
                }
              });
            }
          },
          style: ElevatedButton.styleFrom(backgroundColor: Colors.red[300]),
          child: const Text('删除'),
        ),
      ],
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text('${_currentIndex + 1} / ${widget.imagePaths.length}',
          style: const TextStyle(color: Colors.white)),
        actions: [
          IconButton(icon: const Icon(Icons.delete_outline, color: Colors.red),
            onPressed: _deleteCurrent),
        ],
      ),
      body: PageView.builder(
        controller: _pageCtrl,
        itemCount: widget.imagePaths.length,
        onPageChanged: (i) => setState(() => _currentIndex = i),
        itemBuilder: (ctx, i) {
          return InteractiveViewer(
            minScale: 0.5,
            maxScale: 5.0,
            child: Center(
              child: Image.file(File(widget.imagePaths[i]),
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => const Center(
                  child: Icon(Icons.broken_image, color: Colors.white38, size: 64),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
