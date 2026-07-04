// route_edit_widgets.dart
// 路线编辑页面的组件

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// 路路通导入对话框
class LutongImportDialog extends StatefulWidget {
  final Function(String parsedText) onImport;

  const LutongImportDialog({super.key, required this.onImport});

  @override
  State<LutongImportDialog> createState() => _LutongImportDialogState();
}

class _LutongImportDialogState extends State<LutongImportDialog> {
  final _ctrl = TextEditingController();
  int _matchedCount = 0;
  int _skippedCount = 0;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _parseText() {
    final text = _ctrl.text.trim();
    int matched = 0;
    int skipped = 0;

    for (final line in text.split('\n')) {
      if (line.trim().isEmpty) continue;
      if (RegExp(r'^(.+?)\s+\S+\s+([\d.]+)km').hasMatch(line)) {
        matched++;
      } else {
        skipped++;
      }
    }

    setState(() {
      _matchedCount = matched;
      _skippedCount = skipped;
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('导入路路通数据'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _ctrl,
            decoration: const InputDecoration(
              labelText: '粘贴路路通经由文本',
              hintText: '站名 任意内容 里程 km',
              border: OutlineInputBorder(),
            ),
            maxLines: 8,
            onChanged: (_) => _parseText(),
          ),
          const SizedBox(height: 12),
          if (_matchedCount > 0 || _skippedCount > 0)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '解析结果:',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.blue.shade700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '✓ 匹配 $_matchedCount 站',
                    style: TextStyle(fontSize: 12, color: Colors.green.shade700),
                  ),
                  if (_skippedCount > 0)
                    Text(
                      '⚠ 跳过 $_skippedCount 站（格式不符或含"所"）',
                      style: TextStyle(fontSize: 12, color: Colors.orange.shade700),
                    ),
                ],
              ),
            ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('取消'),
        ),
        ElevatedButton(
          onPressed: _matchedCount > 0 ? () => Navigator.pop(context, _ctrl.text) : null,
          child: const Text('导入'),
        ),
      ],
    );
  }
}

/// 站点编辑卡片
class EditableStationCard extends StatelessWidget {
  final String name;
  final String? telecode;
  final double? mileageToNext;
  final bool isHighlighted;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const EditableStationCard({
    super.key,
    required this.name,
    this.telecode,
    this.mileageToNext,
    this.isHighlighted = false,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Dismissible(
      key: Key(name),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: Colors.red,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      onDismissed: (_) => onDelete(),
      child: Card(
        margin: const EdgeInsets.only(bottom: 8),
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(
            color: isHighlighted ? theme.colorScheme.primary : theme.colorScheme.outline,
            width: isHighlighted ? 2 : 1,
          ),
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
                      Text(
                        name,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (telecode != null && telecode!.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          '电报码：$telecode',
                          style: TextStyle(
                            fontSize: 12,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                      if (mileageToNext != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          '里程：${mileageToNext!.toStringAsFixed(1)} km',
                          style: TextStyle(
                            fontSize: 12,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                Icon(
                  Icons.drag_handle,
                  color: theme.colorScheme.onSurfaceVariant,
                  size: 20,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 里程编辑器对话框
class MileageEditorDialog extends StatefulWidget {
  final String fromStation;
  final String toStation;
  final double? currentMileage;

  const MileageEditorDialog({
    super.key,
    required this.fromStation,
    required this.toStation,
    this.currentMileage,
  });

  @override
  State<MileageEditorDialog> createState() => _MileageEditorDialogState();
}

class _MileageEditorDialogState extends State<MileageEditorDialog> {
  late TextEditingController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(
      text: widget.currentMileage != null ? '${widget.currentMileage}' : '',
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('设置里程'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            '${widget.fromStation} → ${widget.toStation}',
            style: const TextStyle(fontSize: 13, color: Colors.grey),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _ctrl,
            autofocus: true,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[\d.]')),
              LengthLimitingTextInputFormatter(7),
            ],
            decoration: const InputDecoration(
              labelText: '里程（km）',
              hintText: '如 125.5',
              border: OutlineInputBorder(),
              suffixText: 'km',
            ),
            onSubmitted: (_) => _save(),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('取消'),
        ),
        ElevatedButton(
          onPressed: _save,
          child: const Text('确认'),
        ),
      ],
    );
  }

  void _save() {
    final text = _ctrl.text.trim();
    if (text.isEmpty) {
      Navigator.pop(context, null);
    } else {
      final mileage = double.tryParse(text);
      if (mileage == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('请输入有效的数字')),
        );
      } else {
        Navigator.pop(context, mileage);
      }
    }
  }
}
