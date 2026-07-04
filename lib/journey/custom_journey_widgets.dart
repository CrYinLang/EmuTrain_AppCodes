// custom_journey_widgets.dart
// 自定义旅途页面的组件

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// 添加车站选择面板
class AddStationSheet extends StatelessWidget {
  final VoidCallback onAddRail;
  final VoidCallback onAddCustom;

  const AddStationSheet({
    super.key,
    required this.onAddRail,
    required this.onAddCustom,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            '添加车站',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: onAddRail,
            icon: const Icon(Icons.location_on),
            label: const Text('选择国铁车站'),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: onAddCustom,
            icon: const Icon(Icons.edit_location),
            label: const Text('自定义车站'),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }
}

/// 站点操作菜单
class StationMenuSheet extends StatelessWidget {
  final String stationName;
  final bool isCustom;
  final bool isFrom;
  final bool isTo;
  final VoidCallback onSetFrom;
  final VoidCallback onSetTo;
  final VoidCallback onEditTime;
  final VoidCallback onEditName;
  final VoidCallback onDelete;

  const StationMenuSheet({
    super.key,
    required this.stationName,
    required this.isCustom,
    required this.isFrom,
    required this.isTo,
    required this.onSetFrom,
    required this.onSetTo,
    required this.onEditTime,
    required this.onEditName,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            stationName,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 16),
          if (!isFrom)
            ListTile(
              leading: const Icon(Icons.circle, color: Colors.green, size: 20),
              title: const Text('设为上车站'),
              onTap: onSetFrom,
            ),
          if (!isTo)
            ListTile(
              leading: const Icon(Icons.location_on, color: Colors.orange, size: 20),
              title: const Text('设为下车站'),
              onTap: onSetTo,
            ),
          ListTile(
            leading: const Icon(Icons.access_time),
            title: const Text('编辑时间'),
            onTap: onEditTime,
          ),
          if (isCustom)
            ListTile(
              leading: const Icon(Icons.edit),
              title: const Text('编辑站名'),
              onTap: onEditName,
            ),
          const Divider(height: 24),
          ListTile(
            leading: const Icon(Icons.delete, color: Colors.red),
            title: const Text('删除此站', style: TextStyle(color: Colors.red)),
            onTap: onDelete,
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }
}

/// 时间编辑器对话框
class TimeEditorDialog extends StatefulWidget {
  final String arrivalTime;
  final String departureTime;
  final int stayMinutes;
  final int dayDiff;

  const TimeEditorDialog({
    super.key,
    required this.arrivalTime,
    required this.departureTime,
    required this.stayMinutes,
    required this.dayDiff,
  });

  @override
  State<TimeEditorDialog> createState() => _TimeEditorDialogState();
}

class _TimeEditorDialogState extends State<TimeEditorDialog> {
  late TextEditingController _arrCtrl;
  late TextEditingController _depCtrl;
  late int _dayDiff;

  @override
  void initState() {
    super.initState();
    _arrCtrl = TextEditingController(text: widget.arrivalTime);
    _depCtrl = TextEditingController(text: widget.departureTime);
    _dayDiff = widget.dayDiff;
  }

  @override
  void dispose() {
    _arrCtrl.dispose();
    _depCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('编辑时间'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _arrCtrl,
            decoration: const InputDecoration(
              labelText: '到达时间',
              hintText: 'HH:MM',
              border: OutlineInputBorder(),
            ),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[0-9:]')),
              LengthLimitingTextInputFormatter(5),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _depCtrl,
            decoration: const InputDecoration(
              labelText: '出发时间',
              hintText: 'HH:MM',
              border: OutlineInputBorder(),
            ),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[0-9:]')),
              LengthLimitingTextInputFormatter(5),
            ],
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<int>(
            value: _dayDiff,
            decoration: const InputDecoration(
              labelText: '跨天设置',
              border: OutlineInputBorder(),
            ),
            items: const [
              DropdownMenuItem(value: 0, child: Text('当天')),
              DropdownMenuItem(value: 1, child: Text('次日')),
              DropdownMenuItem(value: 2, child: Text('第三日')),
            ],
            onChanged: (v) => setState(() => _dayDiff = v!),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('取消'),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(context, {
            'arrival': _arrCtrl.text.trim(),
            'departure': _depCtrl.text.trim(),
            'dayDiff': _dayDiff,
          }),
          child: const Text('确认'),
        ),
      ],
    );
  }
}

/// 站点卡片组件
class StationCard extends StatelessWidget {
  final String name;
  final bool isCustom;
  final bool isFrom;
  final bool isTo;
  final String arrivalTime;
  final String departureTime;
  final int stayMinutes;
  final int dayDiff;
  final VoidCallback onTap;

  const StationCard({
    super.key,
    required this.name,
    required this.isCustom,
    required this.isFrom,
    required this.isTo,
    required this.arrivalTime,
    required this.departureTime,
    required this.stayMinutes,
    required this.dayDiff,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    Color borderColor;
    if (isFrom) {
      borderColor = Colors.green;
    } else if (isTo) {
      borderColor = Colors.orange;
    } else {
      borderColor = theme.colorScheme.outline;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: borderColor, width: isFrom || isTo ? 2 : 1),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          name,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        if (isCustom) ...[
                          const SizedBox(width: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade200,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text(
                              '自定义',
                              style: TextStyle(fontSize: 10, color: Colors.grey),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '到 $arrivalTime  发 $departureTime',
                      style: TextStyle(
                        fontSize: 12,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    if (stayMinutes > 0) ...[
                      const SizedBox(height: 2),
                      Text(
                        '停$stayMinutes 分',
                        style: TextStyle(
                          fontSize: 11,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                    ],
                    if (dayDiff > 0) ...[
                      const SizedBox(height: 2),
                      Text(
                        dayDiff == 1 ? '次日' : '第${dayDiff + 1}日',
                        style: TextStyle(
                          fontSize: 11,
                          color: theme.colorScheme.tertiary,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Icon(
                isFrom ? Icons.circle : isTo ? Icons.location_on : Icons.info_outline,
                color: isFrom ? Colors.green : isTo ? Colors.orange : theme.colorScheme.onSurfaceVariant,
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
