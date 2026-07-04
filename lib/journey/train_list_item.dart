// train_list_item.dart
// 车次列表项组件

import 'package:flutter/material.dart';
import 'journey_utils.dart';

/// 车次列表项
class TrainListItem extends StatelessWidget {
  final Map<String, dynamic> item;
  final bool expanded;
  final bool loading;
  final bool expired;
  final VoidCallback onToggle;
  final VoidCallback? onToolbox;

  const TrainListItem({
    super.key,
    required this.item,
    required this.expanded,
    required this.loading,
    required this.expired,
    required this.onToggle,
    this.onToolbox,
  });

  @override
  Widget build(BuildContext context) {
    final trainCode = item['station_train_code']?.toString() ?? '';
    final startStation = item['start_station_name']?.toString() ?? '';
    final endStation = item['end_station_name']?.toString() ?? '';
    final startTime = item['start_time']?.toString() ?? '--:--';
    final endTime = item['end_time']?.toString() ?? '--:--';
    final runTime = calcRunTime(startTime, endTime, item['day_difference']?.toString() ?? '0');

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: expired ? 0 : 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onToggle,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      trainCode,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '$startTime - $endTime',
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          runTime,
                          style: TextStyle(
                            fontSize: 12,
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    expanded ? Icons.expand_less : Icons.expand_more,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  _buildStationItem(context, startStation, true),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Container(
                      height: 2,
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(2),
                      ),
                      child: CustomPaint(
                        painter: _TrainLinePainter(
                          color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.3),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  _buildStationItem(context, endStation, false),
                ],
              ),
              if (expired) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.orange.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.info_outline, size: 14, color: Colors.orange.shade700),
                      const SizedBox(width: 4),
                      Text(
                        '行程已过期',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.orange.shade700,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStationItem(BuildContext context, String stationName, bool isStart) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          isStart ? Icons.circle : Icons.location_on,
          size: isStart ? 12 : 20,
          color: isStart ? Colors.green : Colors.red,
        ),
        const SizedBox(height: 4),
        SizedBox(
          width: 80,
          child: Text(
            stationName,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

class _TrainLinePainter extends CustomPainter {
  final Color color;

  _TrainLinePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    canvas.drawLine(Offset(0, size.height / 2), Offset(size.width, size.height / 2), paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
