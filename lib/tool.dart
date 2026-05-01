// lib/tool.dart
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/services.dart';

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


// ==================== 资产检查 ====================
Future<bool> checkAssetExists(String path) async {
  try {
    await rootBundle.load(path);
    return true;
  } catch (_) {
    return false;
  }
}

// ==================== 信息行 ====================
/// 通用键值信息行，labelWidth 默认 80，可按需调整
Widget buildInfoRow(
    String label,
    String value, {
      double labelWidth = 80,
    }) {
  return Padding(
    padding: const EdgeInsets.only(bottom: 4),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: labelWidth,
          child: Text(
            '$label:',
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(child: Text(value, style: const TextStyle(fontSize: 14))),
      ],
    ),
  );
}

// ==================== 匹配分数条 ====================
/// 匹配分数条 + 百分比文字 + 可选排名徽章
Widget buildScoreBar(
    BuildContext context,
    double score, {
      int? rank,
    }) {
  final color = score >= 0.8
      ? Colors.green
      : score >= 0.5
      ? Colors.orange
      : Colors.red;

  return Row(
    children: [
      Container(
        width: 60,
        height: 6,
        decoration: BoxDecoration(
          color: Colors.grey[200],
          borderRadius: BorderRadius.circular(3),
        ),
        child: FractionallySizedBox(
          alignment: Alignment.centerLeft,
          widthFactor: score.clamp(0.0, 1.0),
          child: Container(
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(3),
            ),
          ),
        ),
      ),
      const SizedBox(width: 8),
      Text(
        '${(score * 100).toInt()}%',
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: color,
        ),
      ),
      if (rank != null) ...[
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primary.withAlpha(20),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            '#$rank',
            style: TextStyle(
              fontSize: 10,
              color: Theme.of(context).colorScheme.primary,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    ],
  );
}

// ==================== 错误提示卡片 ====================
Widget buildErrorCard(
    BuildContext context,
    String errorMsg,
    VoidCallback onClose,
    ) {
  return Card(
    color: Theme.of(context).colorScheme.errorContainer,
    child: Padding(
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          const Icon(Icons.error_outline),
          const SizedBox(width: 12),
          Expanded(child: Text(errorMsg)),
          IconButton(onPressed: onClose, icon: const Icon(Icons.close)),
        ],
      ),
    ),
  );
}

// ==================== 结果统计栏 ====================
Widget buildResultCountBar(
    BuildContext context, {
      required String label,
      required VoidCallback onClear,
    }) {
  return Row(
    children: [
      Expanded(
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.info_outline, size: 16),
              const SizedBox(width: 8),
              Text(
                label,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
      const SizedBox(width: 8),
      IconButton(
        icon: const Icon(Icons.close),
        tooltip: '清除结果',
        onPressed: onClear,
      ),
    ],
  );
}

// ==================== 分页控件 ====================
/// 通用分页控件：上一页 / 页码输入框 / 下一页
Widget buildPaginationControls({
  required BuildContext context,
  required int currentPage,
  required int totalPages,
  required int totalResults,
  required bool loadingPage,
  required TextEditingController pageController,
  required void Function(int) onGoToPage,
  EdgeInsetsGeometry padding = const EdgeInsets.symmetric(vertical: 16),
}) {
  if (totalPages <= 1) return const SizedBox.shrink();

  return Padding(
    padding: padding,
    child: Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        IconButton(
          icon: const Icon(Icons.chevron_left),
          onPressed: currentPage > 1 && !loadingPage
              ? () => onGoToPage(currentPage - 1)
              : null,
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 60,
          child: TextField(
            controller: pageController,
            keyboardType: TextInputType.number,
            textAlign: TextAlign.center,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: InputDecoration(
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              contentPadding: const EdgeInsets.symmetric(vertical: 8),
            ),
            onSubmitted: (v) {
              final p = int.tryParse(v);
              if (p != null && p >= 1 && p <= totalPages) {
                onGoToPage(p);
              } else {
                pageController.text = currentPage.toString();
              }
            },
          ),
        ),
        const SizedBox(width: 8),
        Text(
          '/ $totalPages 页（共 $totalResults 条）',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(width: 8),
        IconButton(
          icon: const Icon(Icons.chevron_right),
          onPressed: currentPage < totalPages && !loadingPage
              ? () => onGoToPage(currentPage + 1)
              : null,
        ),
      ],
    ),
  );
}

