// error_logger.dart

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

/// ====================== 数据模型 ======================
class ErrorLog {
  final String from;
  final String message;
  final int level; // 0\~5
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

  static Color colorForLevel(int level, BuildContext context) {
    final baseColors = [
      Colors.blue,
      Colors.cyan,
      Colors.green,
      Colors.orange,
      Colors.deepOrange,
      Colors.red,
    ];
    return baseColors[level.clamp(0, 5)];
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

/// ====================== 日志存储 ======================
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

  Future<void> loadIfNeeded() async {
    if (_loaded) return;
    _loaded = true;

    // Web 平台跳过文件加载，仅使用内存
    if (kIsWeb) return;

    try {
      final f = await _file;
      if (!await f.exists()) return;

      final raw = await f.readAsString();
      if (raw.trim().isEmpty) return;

      final List<dynamic> list = jsonDecode(raw);
      logs
        ..clear()
        ..addAll(list.map((e) => ErrorLog.fromJson(e as Map<String, dynamic>)));
    } catch (e) {
      logError(from: 'error/loadIfNeeded', error: e.toString());
      debugPrint('日志文件损坏: $e');
      try {
        final f = await _file;
        if (await f.exists()) await f.copy('${f.path}.bak');
      } catch (e) {}
    }
  }

  Future<void> add(ErrorLog log) async {
    logs.insert(0, log);
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(milliseconds: 300), _save);
  }

  Future<void> _save() async {
    // Web 平台跳过文件保存
    if (kIsWeb) return;

    try {
      final f = await _file;
      final jsonStr = jsonEncode(logs.map((e) => e.toJson()).toList());
      await f.writeAsString(jsonStr, flush: true);
    } catch (e) {
      logError(from: 'error/_save', error: e.toString());
      debugPrint('ErrorLogStore._save 失败: $e');
    }
  }
}

/// ====================== 全局日志函数 ======================
Future<void> logError({
  required String from,
  required String error,
  int level = 2,
}) async {
  await ErrorLogStore.instance.loadIfNeeded();
  final log = ErrorLog(from: from, message: error, level: level.clamp(0, 5));
  await ErrorLogStore.instance.add(log);

  debugPrint('[${ErrorLog.labelForLevel(log.level)}] ($from) $error');
}

/// ====================== Material 3 UI ======================
const int _pageSize = 20;

class ErrorLogPage extends StatefulWidget {
  const ErrorLogPage({super.key});

  static Future<void> open(BuildContext context) async {
    await ErrorLogStore.instance.loadIfNeeded();
    if (context.mounted) {
      Navigator.of(
        context,
      ).push(MaterialPageRoute(builder: (_) => const ErrorLogPage()));
    }
  }

  @override
  State<ErrorLogPage> createState() => _ErrorLogPageState();
}

class _ErrorLogPageState extends State<ErrorLogPage> {
  int _currentPage = 0;
  int? _filterLevel; // null = 全部

  List<ErrorLog> get _filteredLogs {
    final all = ErrorLogStore.instance.logs;
    return _filterLevel == null
        ? all
        : all.where((l) => l.level == _filterLevel).toList();
  }

  int get _totalPages {
    final count = _filteredLogs.length;
    return count == 0 ? 1 : (count / _pageSize).ceil();
  }

  List<ErrorLog> get _pageLogs {
    final all = _filteredLogs;
    final start = _currentPage * _pageSize;
    final end = (start + _pageSize).clamp(0, all.length);
    return start >= all.length ? [] : all.sublist(start, end);
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
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Error Logs'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Chip(
              label: Text('${_filteredLogs.length}'),
              backgroundColor: theme.colorScheme.surfaceContainerHighest,
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          _buildFilterBar(),
          _buildPagination(),
          Expanded(child: _buildLogList()),
        ],
      ),
    );
  }

  // 等级筛选栏（使用 FilterChip）
  Widget _buildFilterBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            FilterChip(
              label: const Text('全部'),
              selected: _filterLevel == null,
              onSelected: (_) => _setFilter(null),
            ),
            const SizedBox(width: 8),
            for (int i = 0; i <= 5; i++)
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: FilterChip(
                  label: Text(ErrorLog.labelForLevel(i)),
                  selected: _filterLevel == i,
                  backgroundColor: ErrorLog.colorForLevel(
                    i,
                    context,
                  ).withValues(alpha: 0.1),
                  selectedColor: ErrorLog.colorForLevel(
                    i,
                    context,
                  ).withValues(alpha: 0.3),
                  labelStyle: TextStyle(
                    color: _filterLevel == i
                        ? ErrorLog.colorForLevel(i, context)
                        : null,
                  ),
                  onSelected: (_) => _setFilter(i),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // 分页控件
  Widget _buildPagination() {
    if (_totalPages <= 1) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        children: [
          IconButton.outlined(
            onPressed: _currentPage > 0
                ? () => _goToPage(_currentPage - 1)
                : null,
            icon: const Icon(Icons.chevron_left),
          ),
          Expanded(
            child: Center(
              child: Text(
                '${_currentPage + 1} / $_totalPages',
                style: Theme.of(context).textTheme.titleSmall,
              ),
            ),
          ),
          IconButton.outlined(
            onPressed: _currentPage < _totalPages - 1
                ? () => _goToPage(_currentPage + 1)
                : null,
            icon: const Icon(Icons.chevron_right),
          ),
        ],
      ),
    );
  }

  // 日志列表
  Widget _buildLogList() {
    if (_filteredLogs.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.check_circle_outline, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              _filterLevel == null ? '暂无错误日志' : '该等级下暂无日志',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(color: Colors.grey),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _pageLogs.length,
      itemBuilder: (context, index) {
        final log = _pageLogs[index];
        return _LogCard(log: log);
      },
    );
  }
}

// 单条日志卡片（Material 3 Card + ExpansionTile）
class _LogCard extends StatefulWidget {
  final ErrorLog log;

  const _LogCard({required this.log});

  @override
  State<_LogCard> createState() => _LogCardState();
}

class _LogCardState extends State<_LogCard> {
  bool _copied = false;

  Future<void> _copy() async {
    await Clipboard.setData(ClipboardData(text: widget.log.toCopyableText()));
    setState(() => _copied = true);
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) setState(() => _copied = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final levelColor = ErrorLog.colorForLevel(widget.log.level, context);
    final levelLabel = ErrorLog.labelForLevel(widget.log.level);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 1,
      child: ExpansionTile(
        leading: CircleAvatar(
          backgroundColor: levelColor.withValues(alpha: 0.15),
          child: Text(
            widget.log.level.toString(),
            style: TextStyle(color: levelColor, fontWeight: FontWeight.bold),
          ),
        ),
        title: Text(widget.log.from, style: theme.textTheme.titleSmall),
        subtitle: Text(
          levelLabel,
          style: TextStyle(color: levelColor, fontWeight: FontWeight.w600),
        ),
        trailing: Text(
          '${widget.log.time.hour.toString().padLeft(2, '0')}:'
          '${widget.log.time.minute.toString().padLeft(2, '0')}',
          style: theme.textTheme.bodySmall,
        ),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: SelectableText(
              widget.log.message,
              style: theme.textTheme.bodyMedium,
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 16, bottom: 12),
            child: Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: _copy,
                icon: Icon(_copied ? Icons.check : Icons.copy, size: 18),
                label: Text(_copied ? '已复制' : '复制'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
