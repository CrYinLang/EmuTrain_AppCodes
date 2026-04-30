// lib/tool.dart
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'main.dart';

// ========== Config 全局函数 ==========

Future<bool> readConfig(String key) async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getBool(key) ?? false;
}

Future<void> writeConfig(String key, bool value) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setBool(key, value);
}

Future<void> toggleConfig(String key) async {
  final current = await readConfig(key);
  final newValue = !current;
  await writeConfig(key, newValue);
}

// ========== 工具全局函数 ==========

void showSnack(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(message), duration: const Duration(seconds: 2)),
  );
}

Future<void> launchSocialLink(BuildContext context, String url) async {
  final uri = Uri.parse(url);
  if (await canLaunchUrl(uri)) {
    await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('正在打开链接...'),
        duration: Duration(seconds: 2),
      ),
    );
  }
}

// ========== Tool 类（只保留 UI 构建函数） ==========

class Tool {
  static Widget buildSection({
    required BuildContext context,
    required IconData icon,
    required String title,
    required List<Widget> children,
  }) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Column(
        children: [
          ListTile(
            leading: Icon(icon, color: Theme.of(context).colorScheme.primary),
            title: Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
            ),
          ),
          ...children,
        ],
      ),
    );
  }

  static Widget buildSwitch({
    required BuildContext context,
    required String title,
    required String subtitle,
    required IconData icon,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return SwitchListTile(
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w500)),
      subtitle: Text(
        subtitle,
        style: TextStyle(
          fontSize: 12,
          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
        ),
      ),
      secondary: Icon(icon, color: Theme.of(context).colorScheme.primary),
      value: value,
      onChanged: onChanged,
    );
  }

  static Widget buildTrainDataSourceCard({
    required BuildContext context,
    required AppSettings settings,
    required TrainDataSource source,
    required String title,
    required String description,
    required IconData icon,
  }) {
    final isSelected = settings.dataSource == source;
    final primary = Theme.of(context).colorScheme.primary;
    final onSurface = Theme.of(context).colorScheme.onSurface;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isSelected ? primary : Colors.transparent,
          width: 2,
        ),
      ),
      child: InkWell(
        onTap: () {
          if (!isSelected) settings.setDataSource(source);
        },
        borderRadius: BorderRadius.circular(12),
        child: Container(
          constraints: const BoxConstraints(minHeight: 100),
          padding: const EdgeInsets.all(12),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 28,
                color: isSelected ? primary : onSurface.withValues(alpha: 0.7),
              ),
              const SizedBox(height: 8),
              Text(
                title,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                  color: isSelected ? primary : onSurface,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                description,
                maxLines: 2,
                textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 11,
                  color: isSelected
                      ? primary.withValues(alpha: 0.8)
                      : onSurface.withValues(alpha: 0.6),
                ),
              ),
              if (isSelected) ...[
                const SizedBox(height: 8),
                Icon(Icons.check_circle_rounded, size: 16, color: primary),
              ],
            ],
          ),
        ),
      ),
    );
  }
}