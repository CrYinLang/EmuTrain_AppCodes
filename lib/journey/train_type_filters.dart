// train_type_filters.dart
// 车次类型筛选器组件

import 'package:flutter/material.dart';

/// 车次类型名称映射
const Map<String, String> trainTypeNames = {
  'C': '城际',
  'D': '动车',
  'G': '高速',
  'K': '快速',
  'T': '特快',
  'Z': '直达',
  'Y': '旅游',
  'L': '临客',
  'S': '市域',
  '数字': '普客',
};

/// 车次类型筛选芯片组
class TrainTypeFilterChips extends StatelessWidget {
  final Map<String, bool> filters;
  final Map<String, int> typeCounts;
  final ValueChanged<String> onToggle;

  const TrainTypeFilterChips({
    super.key,
    required this.filters,
    required this.typeCounts,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 4,
      children: filters.entries.map((entry) {
        final type = entry.key;
        final selected = entry.value;
        final count = typeCounts[type] ?? 0;
        final typeName = trainTypeNames[type] ?? type;
        final label = type == '数字' ? '$typeName($count)' : '$type「$typeName」($count)';

        return FilterChip(
          label: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              color: selected
                  ? Theme.of(context).colorScheme.onPrimary
                  : Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          selected: selected,
          onSelected: (v) => onToggle(type),
          selectedColor: Theme.of(context).colorScheme.primary,
          backgroundColor: Theme.of(context).colorScheme.surface,
          checkmarkColor: Theme.of(context).colorScheme.onPrimary,
          padding: const EdgeInsets.symmetric(horizontal: 4),
          visualDensity: VisualDensity.compact,
        );
      }).toList(),
    );
  }
}

/// 车站筛选芯片行
class StationFilterChipRow extends StatelessWidget {
  final String label;
  final Color color;
  final List<String> options;
  final String? selected;
  final ValueChanged<String?> onSelected;

  const StationFilterChipRow({
    super.key,
    required this.label,
    required this.color,
    required this.options,
    required this.selected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Wrap(
        spacing: 8,
        runSpacing: 4,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(label, style: const TextStyle(color: Colors.white, fontSize: 12)),
          ),
          FilterChip(
            label: const Text('全部'),
            selected: selected == null,
            onSelected: (_) => onSelected(null),
            selectedColor: Theme.of(context).colorScheme.primary,
            backgroundColor: Theme.of(context).colorScheme.surface,
            checkmarkColor: Theme.of(context).colorScheme.onPrimary,
            padding: const EdgeInsets.symmetric(horizontal: 4),
            visualDensity: VisualDensity.compact,
          ),
          ...options.where((opt) => opt != '全部').map((opt) {
            return FilterChip(
              label: Text(opt),
              selected: selected == opt,
              onSelected: (_) => onSelected(opt),
              selectedColor: Theme.of(context).colorScheme.primary,
              backgroundColor: Theme.of(context).colorScheme.surface,
              checkmarkColor: Theme.of(context).colorScheme.onPrimary,
              padding: const EdgeInsets.symmetric(horizontal: 4),
              visualDensity: VisualDensity.compact,
            );
          }),
        ],
      ),
    );
  }
}

/// 可折叠的筛选器容器
class CollapsibleFilterContainer extends StatelessWidget {
  final bool expanded;
  final VoidCallback onToggle;
  final Widget child;

  const CollapsibleFilterContainer({
    super.key,
    required this.expanded,
    required this.onToggle,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedSize(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeInOut,
      child: GestureDetector(
        onTap: onToggle,
        child: Container(
          width: double.infinity,
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
            borderRadius: BorderRadius.circular(12),
          ),
          child: expanded
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.tune, size: 16, color: Theme.of(context).colorScheme.primary),
                        const SizedBox(width: 6),
                        Text('筛选器', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Theme.of(context).colorScheme.primary)),
                        const Spacer(),
                        Icon(Icons.expand_less, size: 20, color: Theme.of(context).colorScheme.onSurfaceVariant),
                      ],
                    ),
                    const SizedBox(height: 10),
                    child,
                  ],
                )
              : Row(
                  children: [
                    Icon(Icons.tune, size: 16, color: Theme.of(context).colorScheme.primary),
                    const SizedBox(width: 6),
                    const Text('筛选器', style: TextStyle(fontSize: 13, color: Colors.blue)),
                    const Spacer(),
                    Icon(Icons.expand_more, size: 20, color: Colors.grey),
                  ],
                ),
        ),
      ),
    );
  }
}
