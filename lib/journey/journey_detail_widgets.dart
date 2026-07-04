// journey_detail_widgets.dart
// 旅途详情页面的组件

import 'package:flutter/material.dart';
import '../models/journey_model.dart';

/// 旅途状态徽章
class JourneyStatusBadge extends StatelessWidget {
  final String status;

  const JourneyStatusBadge({super.key, required this.status});

  Color _getStatusColor() {
    switch (status) {
      case '已到达':
        return Colors.red;
      case '已上车':
        return Colors.green;
      case '今天':
        return Colors.orange;
      case '昨天':
        return Colors.grey;
      case '明天':
      case '后天':
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: _getStatusColor().withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _getStatusColor(), width: 1.5),
      ),
      child: Text(
        status,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: _getStatusColor(),
        ),
      ),
    );
  }
}

/// 站点列表项
class StationListItem extends StatelessWidget {
  final StationDetail station;
  final int index;
  final int totalStations;
  final bool isFrom;
  final bool isTo;
  final String status;

  const StationListItem({
    super.key,
    required this.station,
    required this.index,
    required this.totalStations,
    required this.isFrom,
    required this.isTo,
    required this.status,
  });

  Color _getStationStatusColor() {
    switch (status) {
      case '已过':
        return Colors.red;
      case '已到':
      case '停站中':
        return Colors.green;
      case '未到':
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isPassed = status == '已过';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: theme.colorScheme.outline.withValues(alpha: 0.3),
          ),
        ),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 40,
            child: Column(
              children: [
                Text(
                  '${index + 1}',
                  style: TextStyle(
                    fontSize: 12,
                    color: isPassed ? Colors.grey : theme.colorScheme.onSurface,
                  ),
                ),
                if (station.distance != null && station.distance! > 0) ...[
                  const SizedBox(height: 4),
                  Text(
                    '${station.distance}km',
                    style: TextStyle(
                      fontSize: 10,
                      color: isPassed ? Colors.grey : theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 12),
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _getStationStatusColor(),
              border: Border.all(
                color: isFrom ? Colors.green : isTo ? Colors.orange : Colors.transparent,
                width: 2,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      station.stationName,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        decoration: isPassed ? TextDecoration.lineThrough : null,
                        color: isPassed ? Colors.grey : theme.colorScheme.onSurface,
                      ),
                    ),
                    if (isFrom) ...[
                      const SizedBox(width: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                        decoration: BoxDecoration(
                          color: Colors.green,
                          borderRadius: BorderRadius.circular(3),
                        ),
                        child: const Text('上', style: TextStyle(color: Colors.white, fontSize: 10)),
                      ),
                    ],
                    if (isTo) ...[
                      const SizedBox(width: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                        decoration: BoxDecoration(
                          color: Colors.orange,
                          borderRadius: BorderRadius.circular(3),
                        ),
                        child: const Text('下', style: TextStyle(color: Colors.white, fontSize: 10)),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    if (!station.isStart)
                      Text(
                        '到 ${station.arrivalTime}',
                        style: TextStyle(
                          fontSize: 12,
                          color: isPassed ? Colors.grey : theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    if (!station.isStart && !station.isEnd && station.stayTime > 0)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 6),
                        child: Text(
                          '停${station.stayTime}分',
                          style: TextStyle(
                            fontSize: 11,
                            color: isPassed ? Colors.grey : theme.colorScheme.primary,
                          ),
                        ),
                      ),
                    if (!station.isEnd)
                      Text(
                        '发 ${station.departureTime}',
                        style: TextStyle(
                          fontSize: 12,
                          color: isPassed ? Colors.grey : theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
          if (station.dayDifference > 0)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: theme.colorScheme.tertiary.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                station.dayDifference == 1 ? '次日' : '第${station.dayDifference + 1}日',
                style: TextStyle(
                  fontSize: 11,
                  color: theme.colorScheme.tertiary,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// 座位信息显示
class SeatInfoDisplay extends StatelessWidget {
  final Journey journey;

  const SeatInfoDisplay({super.key, required this.journey});

  @override
  Widget build(BuildContext context) {
    final Map<String, String> seatTypeNames = {
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
    };

    final seatType = journey.seatType;
    final seatInfo = journey.seatInfo;

    if (seatType.isEmpty) {
      return Text(
        '未选择座位',
        style: TextStyle(fontSize: 16, color: Theme.of(context).hintColor),
      );
    }

    final seatName = seatTypeNames[seatType] ?? '未知座位';
    String displayText = seatName;
    if (seatType != 'wz_num' && seatInfo.isNotEmpty) {
      displayText += ' $seatInfo';
    }

    return Text(
      displayText,
      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
    );
  }
}

/// 信息区块容器
class InfoSection extends StatelessWidget {
  final String title;
  final IconData icon;
  final List<Widget> children;

  const InfoSection({
    super.key,
    required this.title,
    required this.icon,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 18, color: Theme.of(context).colorScheme.primary),
            const SizedBox(width: 8),
            Text(
              title,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ...children,
      ],
    );
  }
}

/// 统计卡片
class StatsCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const StatsCard({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: color.withValues(alpha: 0.8),
            ),
          ),
        ],
      ),
    );
  }
}
