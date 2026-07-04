// journey_form_fields.dart
// 旅途表单字段组件

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'journey_utils.dart';

/// 日期选择器字段
class JourneyDatePicker extends StatelessWidget {
  final DateTime? selectedDate;
  final VoidCallback onTap;

  const JourneyDatePicker({
    super.key,
    required this.selectedDate,
    required this.onTap,
  });

  String get dateText => selectedDate == null
      ? "选择日期"
      : formatDate(selectedDate!);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
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
            Icon(Icons.calendar_today, size: 20, color: Theme.of(context).colorScheme.primary),
            const SizedBox(width: 8),
            Text(
              dateText,
              style: TextStyle(
                fontSize: 16,
                color: selectedDate == null
                    ? Theme.of(context).colorScheme.onSurfaceVariant
                    : Theme.of(context).colorScheme.onSurface,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 车次输入框
class TrainNumberInput extends StatelessWidget {
  final TextEditingController controller;
  final VoidCallback? onClear;

  const TrainNumberInput({
    super.key,
    required this.controller,
    this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      onChanged: (value) {
        if (value.isNotEmpty && value != value.toUpperCase()) {
          controller.text = value.toUpperCase();
          controller.selection = TextSelection.collapsed(offset: controller.text.length);
        }
      },
      inputFormatters: [
        FilteringTextInputFormatter.allow(RegExp(r'[0-9GDCSKZTWPQgdcskztwpq1]')),
        TextInputFormatter.withFunction(
          (oldValue, newValue) => newValue.copyWith(text: newValue.text.toUpperCase()),
        ),
      ],
      decoration: InputDecoration(
        hintText: "请输入车次",
        hintStyle: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Theme.of(context).colorScheme.outline),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Theme.of(context).colorScheme.outline),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Theme.of(context).colorScheme.primary, width: 2),
        ),
        filled: true,
        fillColor: Theme.of(context).colorScheme.surface,
        suffixIcon: controller.text.isNotEmpty
            ? IconButton(
                icon: const Icon(Icons.clear, size: 20),
                onPressed: onClear,
              )
            : null,
      ),
      style: TextStyle(
        fontSize: 16,
        color: Theme.of(context).colorScheme.onSurface,
      ),
      maxLines: 1,
    );
  }
}

/// 车站选择按钮
class StationSelectorButton extends StatelessWidget {
  final String? stationName;
  final bool isFrom;
  final VoidCallback onTap;

  const StationSelectorButton({
    super.key,
    required this.stationName,
    required this.isFrom,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final hasValue = stationName != null && stationName!.isNotEmpty;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 56,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          border: Border.all(
            color: hasValue ? Colors.blue : Theme.of(context).colorScheme.outline,
          ),
          borderRadius: BorderRadius.circular(12),
          color: Theme.of(context).colorScheme.surface,
        ),
        alignment: Alignment.centerLeft,
        child: Row(
          children: [
            Icon(
              Icons.location_on,
              size: 20,
              color: hasValue ? Colors.blue : Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                stationName ?? '请选择',
                style: TextStyle(
                  fontSize: 16,
                  color: hasValue
                      ? Theme.of(context).colorScheme.onSurface
                      : Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 搜索按钮
class JourneySearchButton extends StatelessWidget {
  final bool loading;
  final VoidCallback onPressed;

  const JourneySearchButton({
    super.key,
    required this.loading,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: loading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: Theme.of(context).colorScheme.primary,
          foregroundColor: Theme.of(context).colorScheme.onPrimary,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        child: loading
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation(Colors.white),
                ),
              )
            : const Text(
                '搜索',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
      ),
    );
  }
}
