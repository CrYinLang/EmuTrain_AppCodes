// error_logger.dart

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

// ══════════════════════════════════════════════
//  数据模型
// ══════════════════════════════════════════════
class ErrorLog {
  final String from;
  final String message;
  final int level; // 0~5
  final DateTime time;

  ErrorLog({
    required this.from,
    required this.message,
    required this.level,
    DateTime? time,
  }) : time = time ?? DateTime.now();

  Map<String, dynamic> toJson() => {
        'from': from,
        'message': message,
        'level': level,
        'time': time.toIso8601String(),
      };

  factory ErrorLog.fromJson(Map<String, dynamic> json) => ErrorLog(
        from: json['from'] as String,
        message: json['message'] as String,
        level: json['level'] as int,
        time: DateTime.parse(json['time'] as String),
      );

  static Color colorForLevel(int level) {
    const colors = [
      Color(0xFF2196F3), // 0 蓝
      Color(0xFF00BCD4), // 1 青
      Color(0xFF4CAF50), // 2 绿
      Color(0xFFFFC107), // 3 黄
      Color(0xFFFF9800), // 4 橙
      Color(0xFFF44336), // 5 红
    ];
    return colors[level.clamp(0, 5)];
  }

  static String labelForLevel(int level) {
    const labels = ['TRACE', 'DEBUG', 'INFO', 'WARNING', 'ERROR', 'FATAL'];
    return labels[level.clamp(0, 5)];
  }

  String toCopyableText() {
    return '[${labelForLevel(level)}] '
        '${time.toString().substring(0, 19)}\n'
        '来源: $from\n'
        '详情: $message';
  }
}

// ══════════════════════════════════════════════
//  全局日志存储（单例 + 防抖写入 + 损坏恢复）
// ══════════════════════════════════════════════
class ErrorLogStore {
  ErrorLogStore._();
  static final instance = ErrorLogStore._();

  final List<ErrorLog> logs = [];
  bool _loaded = false;
  Timer? _saveTimer;

  Future<File> get _file async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/error_logs.json');
  }

  /// 首次读取，多次调用无副作用；JSON 损坏时备份旧文件
  Future<void> loadIfNeeded() async {
    if (_loaded) return;
    _loaded = true;

    try {
      final f = await _file;
      if (!await f.exists()) return;

      final raw = await f.readAsString();
      if (raw.trim().isEmpty) return;

      final List<dynamic> list = jsonDecode(raw);
      logs
        ..clear()
        ..addAll(
            list.map((e) => ErrorLog.fromJson(e as Map<String, dynamic>)));
    } catch (e) {
      debugPrint('日志文件损坏，已备份旧文件: $e');
      try {
        final f = await _file;
        if (await f.exists()) {
          await f.copy('${f.path}.bak');
        }
      } catch (_) {}
    }
  }

  /// 防抖写入：300ms 内多次 add 只落盘一次
  Future<void> add(ErrorLog log) async {
    logs.insert(0, log);
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(milliseconds: 300), _save);
  }

  Future<void> _save() async {
    try {
      final f = await _file;
      final jsonStr = jsonEncode(logs.map((e) => e.toJson()).toList());
      await f.writeAsString(jsonStr, flush: true);
    } catch (e) {
      debugPrint('ErrorLogStore._save 失败: $e');
    }
  }
}

// ══════════════════════════════════════════════
//  全局函数
// ══════════════════════════════════════════════
Future<void> logError({
  required String from,
  required String error,
  int level = 2,
}) async {
  await ErrorLogStore.instance.loadIfNeeded();

  final log = ErrorLog(from: from, message: error, level: level.clamp(0, 5));
  await ErrorLogStore.instance.add(log);

  debugPrint(
    '[${ErrorLog.labelForLevel(log.level)}] '
    '($from) $error',
  );
}

// ══════════════════════════════════════════════
//  UI
// ══════════════════════════════════════════════

const int _pageSize = 20;

class ErrorLogPage extends StatefulWidget {
  const ErrorLogPage({super.key});

  static Future<void> open(BuildContext context) async {
    await ErrorLogStore.instance.loadIfNeeded();
    if (context.mounted) {
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const ErrorLogPage()),
      );
    }
  }

  @override
  State<ErrorLogPage> createState() => _ErrorLogPageState();
}

class _ErrorLogPageState extends State<ErrorLogPage>
    with SingleTickerProviderStateMixin {
  late AnimationController _headerAnim;
  int _currentPage = 0;
  int? _filterLevel; // null = 全部

  // ── 筛选后的完整列表 ──
  List<ErrorLog> get _filteredLogs {
    final all = ErrorLogStore.instance.logs;
    if (_filterLevel == null) return all;
    return all.where((l) => l.level == _filterLevel).toList();
  }

  int get _totalPages {
    final count = _filteredLogs.length;
    if (count == 0) return 1;
    return (count / _pageSize).ceil();
  }

  List<ErrorLog> get _pageLogs {
    final all = _filteredLogs;
    final start = _currentPage * _pageSize;
    final end = (start + _pageSize).clamp(0, all.length);
    if (start >= all.length) return [];
    return all.sublist(start, end);
  }

  @override
  void initState() {
    super.initState();
    _headerAnim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    )..forward();
  }

  @override
  void dispose() {
    _headerAnim.dispose();
    super.dispose();
  }

  void _goToPage(int page) {
    final target = page.clamp(0, _totalPages - 1);
    if (target == _currentPage) return;
    setState(() => _currentPage = target);
  }

  void _setFilter(int? level) {
    if (level == _filterLevel) return;
    setState(() {
      _filterLevel = level;
      _currentPage = 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0C0C0E),
      body: SafeArea(
        child: Column(
          children: [
            _buildTitleBar(),
            _buildPagination(),
            _buildFilterBar(),
            const SizedBox(height: 6),
            Expanded(child: _buildLogList()),
          ],
        ),
      ),
    );
  }

  // ── 标题栏 ──
  Widget _buildTitleBar() {
    return SlideTransition(
      position: Tween<Offset>(
        begin: const Offset(0, -0.4),
        end: Offset.zero,
      ).animate(CurvedAnimation(
        parent: _headerAnim,
        curve: Curves.easeOutCubic,
      )),
      child: FadeTransition(
        opacity: _headerAnim,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(4, 12, 16, 6),
          child: Row(
            children: [
              IconButton(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.arrow_back_ios_new_rounded),
                color: Colors.white70,
                iconSize: 20,
              ),
              const SizedBox(width: 4),
              const Text(
                'Error Logs',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.5,
                ),
              ),
              const Spacer(),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${_filteredLogs.length}',
                  style: const TextStyle(
                    color: Colors.white54,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── 分页器 ──
  Widget _buildPagination() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 8),
      child: Row(
        children: [
          _NavButton(
            icon: Icons.chevron_left_rounded,
            enabled: _currentPage > 0,
            onTap: () => _goToPage(_currentPage - 1),
          ),
          const SizedBox(width: 8),
          Expanded(child: _buildPageChips()),
          const SizedBox(width: 8),
          _NavButton(
            icon: Icons.chevron_right_rounded,
            enabled: _currentPage < _totalPages - 1,
            onTap: () => _goToPage(_currentPage + 1),
          ),
        ],
      ),
    );
  }

  Widget _buildPageChips() {
    return SizedBox(
      height: 36,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: _totalPages,
        itemBuilder: (context, index) {
          final selected = index == _currentPage;
          return GestureDetector(
            onTap: () => _goToPage(index),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.symmetric(horizontal: 3),
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                color: selected
                    ? Colors.white.withValues(alpha: 0.14)
                    : Colors.white.withValues(alpha: 0.04),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: selected
                      ? Colors.white.withValues(alpha: 0.25)
                      : Colors.white.withValues(alpha: 0.06),
                ),
              ),
              alignment: Alignment.center,
              child: Text(
                '${index + 1}',
                style: TextStyle(
                  color: selected ? Colors.white : Colors.white38,
                  fontSize: 13,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  // ── 等级筛选栏 ──
  Widget _buildFilterBar() {
    return SizedBox(
      height: 38,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [
          _filterChip(null, '全部', Colors.white38),
          for (int i = 0; i <= 5; i++)
            _filterChip(
              i,
              ErrorLog.labelForLevel(i),
              ErrorLog.colorForLevel(i),
            ),
        ],
      ),
    );
  }

  Widget _filterChip(int? level, String label, Color color) {
    final selected = _filterLevel == level;
    return GestureDetector(
      onTap: () => _setFilter(level),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: selected
              ? color.withValues(alpha: 0.18)
              : Colors.white.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: selected
                ? color.withValues(alpha: 0.4)
                : Colors.white.withValues(alpha: 0.06),
          ),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            color: selected ? color : Colors.white38,
            fontSize: 12,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      ),
    );
  }

  // ── 日志列表 ──
  Widget _buildLogList() {
    final pageLogs = _pageLogs;

    if (_filteredLogs.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.check_circle_outline_rounded,
                size: 56,
                color: Colors.white.withValues(alpha: 0.12)),
            const SizedBox(height: 12),
            Text(
              _filterLevel == null ? '暂无错误日志' : '该等级下暂无日志',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.25),
                fontSize: 15,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      key: ValueKey('$_currentPage-$_filterLevel'),
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      itemCount: pageLogs.length,
      itemBuilder: (context, index) {
        return _LogCard(log: pageLogs[index], index: index);
      },
    );
  }
}

// ── 左右翻页按钮 ──
class _NavButton extends StatelessWidget {
  final IconData icon;
  final bool enabled;
  final VoidCallback onTap;

  const _NavButton({
    required this.icon,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: enabled
              ? Colors.white.withValues(alpha: 0.1)
              : Colors.white.withValues(alpha: 0.03),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: enabled
                ? Colors.white.withValues(alpha: 0.15)
                : Colors.white.withValues(alpha: 0.04),
          ),
        ),
        child: Icon(
          icon,
          size: 20,
          color: enabled
              ? Colors.white70
              : Colors.white.withValues(alpha: 0.12),
        ),
      ),
    );
  }
}

// ── 单条日志卡片（单击展开/收起，长按复制）──
class _LogCard extends StatefulWidget {
  final ErrorLog log;
  final int index;

  const _LogCard({required this.log, required this.index});

  @override
  State<_LogCard> createState() => _LogCardState();
}

class _LogCardState extends State<_LogCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _anim;
  bool _copied = false;
  bool _expanded = false;

  @override
  void initState() {
    super.initState();
    _anim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    Future.delayed(Duration(milliseconds: 35 * widget.index), () {
      if (mounted) _anim.forward();
    });
  }

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final log = widget.log;
    final levelColor = ErrorLog.colorForLevel(log.level);
    final levelLabel = ErrorLog.labelForLevel(log.level);

    return FadeTransition(
      opacity: CurvedAnimation(parent: _anim, curve: Curves.easeOut),
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0.12, 0),
          end: Offset.zero,
        ).animate(
            CurvedAnimation(parent: _anim, curve: Curves.easeOutCubic)),
        child: GestureDetector(
          onTap: () => setState(() => _expanded = !_expanded),
          onLongPress: _handleLongPress,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOutCubic,
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFF161618),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: _expanded
                    ? levelColor.withValues(alpha: 0.45)
                    : levelColor.withValues(alpha: 0.25),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: levelColor.withValues(alpha: _expanded ? 0.12 : 0.06),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── 顶部：等级 + 来源 + 时间 ──
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: levelColor.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        'Lv.${log.level}  $levelLabel',
                        style: TextStyle(
                          color: levelColor,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        log.from,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    // 展开指示
                    AnimatedRotation(
                      turns: _expanded ? 0.5 : 0,
                      duration: const Duration(milliseconds: 200),
                      child: Icon(
                        Icons.expand_more_rounded,
                        size: 18,
                        color: Colors.white.withValues(alpha: 0.2),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      _formatTime(log.time),
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.25),
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                // ── 错误详情 ──
                AnimatedCrossFade(
                  firstChild: Text(
                    log.message,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.75),
                      fontSize: 13,
                      height: 1.5,
                    ),
                    maxLines: 4,
                    overflow: TextOverflow.ellipsis,
                  ),
                  secondChild: SelectableText(
                    log.message,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.85),
                      fontSize: 13,
                      height: 1.6,
                    ),
                  ),
                  crossFadeState: _expanded
                      ? CrossFadeState.showSecond
                      : CrossFadeState.showFirst,
                  duration: const Duration(milliseconds: 200),
                ),

                const SizedBox(height: 8),

                // ── 底部：复制反馈 ──
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 250),
                      child: _copied
                          ? Text(
                              '已复制 ✓',
                              key: const ValueKey('copied'),
                              style: TextStyle(
                                color: levelColor,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            )
                          : Text(
                              _expanded ? '长按复制' : '点击展开 · 长按复制',
                              key: const ValueKey('hint'),
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.2),
                                fontSize: 11,
                              ),
                            ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _handleLongPress() async {
    await Clipboard.setData(
      ClipboardData(text: widget.log.toCopyableText()),
    );
    setState(() => _copied = true);
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) setState(() => _copied = false);
    });
  }

  String _formatTime(DateTime t) {
    return '${t.hour.toString().padLeft(2, '0')}:'
        '${t.minute.toString().padLeft(2, '0')}:'
        '${t.second.toString().padLeft(2, '0')}';
  }
}
