// lib/functions.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import 'main.dart';
import 'ui/function/error.dart';

// ========== Config 全局函数 ==========

Future<bool> readConfig(String key) async {
  try {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(key) ?? false;
  } catch (e, stack) {
    await logError(from: 'readConfig', error: '读取配置失败 key=$key: $e', level: 3);
    debugPrint('readConfig error: $e\n$stack');
    return false;
  }
}

Future<void> writeConfig(String key, bool value) async {
  try {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(key, value);
  } catch (e, stack) {
    await logError(
      from: 'writeConfig',
      error: '写入配置失败 key=$key, value=$value: $e',
      level: 4,
    );
    debugPrint('writeConfig error: $e\n$stack');
  }
}

Future<void> toggleConfig(String key) async {
  try {
    final current = await readConfig(key);
    final newValue = !current;
    await writeConfig(key, newValue);
  } catch (e) {
    await logError(
      from: 'toggleConfig',
      error: '切换配置失败 key=$key: $e',
      level: 4,
    );
  }
}

// ========== 工具全局函数 ==========

Future<void> showSnack(BuildContext context, String message) async {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(message), duration: const Duration(seconds: 2)),
  );
}

Future<void> launchSocialLink(BuildContext context, String url) async {
  try {
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
    } else {
      await logError(from: 'launchSocialLink', error: '无法打开链接: $url', level: 3);
      if (context.mounted) {
        showSnack(context, '无法打开该链接');
      }
    }
  } catch (e) {
    await logError(
      from: 'launchSocialLink',
      error: '打开链接失败: $url\n$e',
      level: 4,
    );
    if (context.mounted) {
      showSnack(context, '打开链接失败');
    }
  }
}

// ==================== 资产检查 ====================
Future<bool> checkAssetExists(String path) async {
  try {
    await rootBundle.load(path);
    return true;
  } catch (e) {
    await logError(
      from: 'checkAssetExists',
      error: '资产文件不存在或加载失败: $path',
      level: 3,
    );
    return false;
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

// ==================== 信息行 ====================
Widget buildInfoRow(String label, String value, {double labelWidth = 80}) {
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
Widget buildScoreBar(BuildContext context, double score, {int? rank}) {
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
                style: Theme.of(
                  context,
                ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
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

// ==================== 搜索弹窗 ====================
/// 通用搜索弹窗。
/// [items]       全量数据列表
/// [filter]      返回 true 表示该条目匹配搜索词
/// [itemBuilder] 构建每条结果的 Widget（context, item, index）
/// [pageSize]    每页条数，默认 10
/// [hintText]    输入框占位文字
Future<void> showSearchDialog<T>({
  required BuildContext context,
  required List<T> items,
  required bool Function(T item, String query) filter,
  required Widget Function(BuildContext context, T item, int index) itemBuilder,
  int pageSize = 10,
  String hintText = '输入关键词搜索…',
  String title = '搜索',
}) {
  return showDialog(
    context: context,
    builder: (ctx) => _SearchDialog<T>(
      items: items,
      filter: filter,
      itemBuilder: itemBuilder,
      pageSize: pageSize,
      hintText: hintText,
      title: title,
    ),
  );
}

class _SearchDialog<T> extends StatefulWidget {
  final List<T> items;
  final bool Function(T item, String query) filter;
  final Widget Function(BuildContext context, T item, int index) itemBuilder;
  final int pageSize;
  final String hintText;
  final String title;

  const _SearchDialog({
    required this.items,
    required this.filter,
    required this.itemBuilder,
    required this.pageSize,
    required this.hintText,
    required this.title,
  });

  @override
  State<_SearchDialog<T>> createState() => _SearchDialogState<T>();
}

class _SearchDialogState<T> extends State<_SearchDialog<T>> {
  final _ctrl = TextEditingController();
  List<T> _results = [];
  bool _searched = false;
  int _page = 1;

  int get _totalPages =>
      _results.isEmpty ? 1 : (_results.length / widget.pageSize).ceil();

  List<T> get _pageItems {
    final start = (_page - 1) * widget.pageSize;
    final end = (start + widget.pageSize).clamp(0, _results.length);
    return _results.sublist(start, end);
  }

  void _doSearch() {
    final q = _ctrl.text.trim();
    if (q.isEmpty) return;
    setState(() {
      _results = widget.items.where((i) => widget.filter(i, q)).toList();
      _searched = true;
      _page = 1;
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── 标题栏 ──
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 8, 0),
            child: Row(
              children: [
                Icon(Icons.search, color: cs.primary, size: 20),
                const SizedBox(width: 8),
                Text(
                  widget.title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
          ),
          // ── 搜索框 ──
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _ctrl,
                    autofocus: true,
                    textInputAction: TextInputAction.search,
                    onSubmitted: (_) => _doSearch(),
                    decoration: InputDecoration(
                      hintText: widget.hintText,
                      prefixIcon: const Icon(Icons.search, size: 20),
                      filled: true,
                      fillColor: isDark
                          ? Colors.white.withAlpha(12)
                          : Colors.grey.shade100,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        vertical: 10,
                        horizontal: 12,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _doSearch,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: const Text('搜索'),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          // ── 结果区域 ──
          if (!_searched)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 32),
              child: Column(
                children: [
                  Icon(
                    Icons.manage_search,
                    size: 48,
                    color: cs.onSurface.withAlpha(80),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    '输入关键词后点击「搜索」',
                    style: TextStyle(
                      color: cs.onSurface.withAlpha(120),
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            )
          else if (_results.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 32),
              child: Column(
                children: [
                  Icon(
                    Icons.search_off,
                    size: 48,
                    color: cs.onSurface.withAlpha(80),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    '没有符合「${_ctrl.text.trim()}」的结果',
                    style: TextStyle(
                      color: cs.onSurface.withAlpha(120),
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            )
          else ...[
            // 结果统计
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  Icon(Icons.info_outline, size: 14, color: cs.primary),
                  const SizedBox(width: 6),
                  Text(
                    '共 ${_results.length} 条结果',
                    style: TextStyle(
                      fontSize: 12,
                      color: cs.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            // 列表（限高）
            ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.4,
              ),
              child: ListView.separated(
                shrinkWrap: true,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                itemCount: _pageItems.length,
                separatorBuilder: (_, __) => const SizedBox(height: 4),
                itemBuilder: (c, i) =>
                    widget.itemBuilder(c, _pageItems[i], i),
              ),
            ),
            // 分页栏
            if (_totalPages > 1)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.chevron_left),
                      onPressed: _page > 1
                          ? () => setState(() => _page--)
                          : null,
                      visualDensity: VisualDensity.compact,
                    ),
                    Text(
                      '$_page / $_totalPages',
                      style: const TextStyle(fontSize: 13),
                    ),
                    IconButton(
                      icon: const Icon(Icons.chevron_right),
                      onPressed: _page < _totalPages
                          ? () => setState(() => _page++)
                          : null,
                      visualDensity: VisualDensity.compact,
                    ),
                  ],
                ),
              ),
          ],
          const SizedBox(height: 8),
        ],
      ),
    );
  }
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
