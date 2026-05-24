// ui/function/route_store_page.dart
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../../functions.dart';
import '../../main.dart';
import 'route_models.dart';

// ─────────────────────────────────────────────────────────────
// 数据模型
// ─────────────────────────────────────────────────────────────

class _StoreItem {
  final String name;
  final String id;
  final String author;
  final String icon;
  final String page;

  const _StoreItem({
    required this.name,
    required this.id,
    required this.author,
    required this.icon,
    required this.page,
  });

  factory _StoreItem.fromJson(Map<String, dynamic> j) => _StoreItem(
    name: j['name'] as String? ?? '',
    id: j['id'] as String? ?? '',
    author: j['author'] as String? ?? '',
    icon: j['icon'] as String? ?? '',
    page: j['page']?.toString() ?? '1',
  );
}

enum _StoreAction { refresh }

// ─────────────────────────────────────────────────────────────
// RouteStorePage
// ─────────────────────────────────────────────────────────────

class RouteStorePage extends StatefulWidget {
  const RouteStorePage({super.key});

  @override
  State<RouteStorePage> createState() => _RouteStorePageState();
}

class _RouteStorePageState extends State<RouteStorePage> {
  // 目录列表
  List<_StoreItem> _items = [];
  bool _loadingIndex = true;
  String? _indexError;

  // 已安装的线路 id 集合（用于显示"已安装"标记）
  Set<String> _installedIds = {};

  bool _loadingPage = false;

  final _pager = PaginatedController<_StoreItem>(pageSize: 25);
  late TextEditingController _pageController;

  // 正在安装的 id 集合
  final Set<String> _installing = {};

  // 批量勾选
  final Set<String> _checked = {};

  bool get _currentPageAllChecked =>
      _pager.currentPageItems.isNotEmpty &&
      _pager.currentPageItems.every((i) => _checked.contains(i.id));

  void _toggleSelectCurrentPage() {
    setState(() {
      if (_currentPageAllChecked) {
        for (final i in _pager.currentPageItems) _checked.remove(i.id);
      } else {
        for (final i in _pager.currentPageItems) _checked.add(i.id);
      }
    });
  }

  // ── 搜索 ──────────────────────────────────────────────────────
  bool _searchOpen = false;
  String _searchQuery = '';

  bool get _isFiltered => _searchQuery.isNotEmpty;

  @override
  void initState() {
    super.initState();
    _pageController = TextEditingController(text: '1');
    _loadIndex();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  // ── 加载目录 ─────────────────────────────────────────────────

  void _goToPage(int page) {
    if (page == _pager.currentPage) return;
    setState(() => _loadingPage = true);
    setState(() {
      _pager.loadPage(page);
      _pageController.text = page.toString();
      _loadingPage = false;
    });
  }

  Future<void> _loadIndex() async {
    setState(() {
      _loadingIndex = true;
      _indexError = null;
    });

    // 同时加载「已安装」列表，用于标记
    final installed = await RouteStorage.loadAll();
    _installedIds = {for (final r in installed) r.id};

    final baseUrl = Vars.mirrorBaseUrl;
    final url = '${baseUrl}lines/lines.json';

    try {
      final resp = await http
          .get(Uri.parse(url))
          .timeout(const Duration(seconds: 12));
      if (resp.statusCode != 200) throw Exception('HTTP ${resp.statusCode}');
      final raw = json.decode(resp.body);
      if (raw is! List) throw const FormatException('顶层必须是 JSON 数组');
      final items = raw
          .map((e) => _StoreItem.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();

      if (mounted) {
        setState(() {
          _items = items;
          // 重载后保持当前搜索过滤状态
          final toLoad = _isFiltered ? _filterItems(items, _searchQuery) : items;
          _pager.resetAndLoad(toLoad);
          _pageController.text = '1';
          _loadingIndex = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _indexError = e.toString();
          _loadingIndex = false;
        });
      }
    }
  }

  // ── 搜索过滤 ─────────────────────────────────────────────────

  List<_StoreItem> _filterItems(List<_StoreItem> src, String q) =>
      src.where((i) => i.name.contains(q) || i.author.contains(q)).toList();

  void _onSearch(String q) {
    setState(() {
      _searchQuery = q;
      final toLoad = q.isEmpty ? _items : _filterItems(_items, q);
      _pager.resetAndLoad(toLoad);
      _pageController.text = '1';
      _loadingPage = false;
    });
  }

  void _toggleSearch() {
    setState(() {
      _searchOpen = !_searchOpen;
      if (!_searchOpen && _isFiltered) {
        _searchQuery = '';
        _pager.resetAndLoad(_items);
        _pageController.text = '1';
      }
    });
  }

  // ── 安装单条线路 ─────────────────────────────────────────────

  Future<void> _installItem(_StoreItem item) async {
    if (_installing.contains(item.id)) return;
    setState(() => _installing.add(item.id));

    try {
      final baseUrl = Vars.mirrorBaseUrl;
      final url = '${baseUrl}lines/line${item.page}.json';
      final resp = await http
          .get(Uri.parse(url))
          .timeout(const Duration(seconds: 15));
      if (resp.statusCode != 200) throw Exception('HTTP ${resp.statusCode}');

      final raw = json.decode(resp.body);
      if (raw is! List) throw const FormatException('数据格式错误');

      // 在该页数据中找到对应 id 的线路
      final found = (raw as List).cast<Map<String, dynamic>>().firstWhere(
        (e) => e['id'] == item.id,
        orElse: () => throw Exception('页面数据中未找到该线路'),
      );

      final model = RouteModel.fromJson(found);

      // 冲突检测
      final existing = await RouteStorage.loadAll();
      final conflict = existing
          .where((r) => r.name == model.name && r.id != model.id)
          .firstOrNull;

      if (conflict != null && mounted) {
        final overwrite = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('同名线路'),
            content: Text('本地已存在线路「${model.name}」，是否覆盖？'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('取消'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('覆盖'),
              ),
            ],
          ),
        );
        if (overwrite != true) {
          setState(() => _installing.remove(item.id));
          return;
        }
      }

      await RouteStorage.save(model);
      if (mounted) {
        setState(() {
          _installedIds.add(item.id);
          _installing.remove(item.id);
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('「${model.name}」已安装'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _installing.remove(item.id));
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('安装失败：$e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  // ── 批量安装 ─────────────────────────────────────────────────

  Future<void> _installChecked() async {
    final toInstall = _items.where((i) => _checked.contains(i.id)).toList();
    if (toInstall.isEmpty) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('批量安装'),
        content: Text('确认安装选中的 ${toInstall.length} 条线路？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('安装'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    // 标记所有选中项为"安装中"
    setState(() => _installing.addAll(toInstall.map((i) => i.id)));

    // 按 page 分组，每个 page 只请求一次
    final Map<String, List<_StoreItem>> byPage = {};
    for (final item in toInstall) {
      byPage.putIfAbsent(item.page, () => []).add(item);
    }

    final baseUrl = Vars.mirrorBaseUrl;
    final existing = await RouteStorage.loadAll();
    final List<String> errors = [];

    for (final entry in byPage.entries) {
      final page = entry.key;
      final pageItems = entry.value;

      // 每个 page 只发一次请求
      List<Map<String, dynamic>> pageData;
      try {
        final url = '${baseUrl}lines/line$page.json';
        final resp = await http
            .get(Uri.parse(url))
            .timeout(const Duration(seconds: 15));
        if (resp.statusCode != 200) throw Exception('HTTP ${resp.statusCode}');
        final raw = json.decode(resp.body);
        if (raw is! List) throw const FormatException('数据格式错误');
        pageData = (raw as List).cast<Map<String, dynamic>>();
      } catch (e) {
        // 整页请求失败，把该页所有 id 标记失败
        errors.add('第 $page 页加载失败：$e');
        if (mounted) {
          setState(() {
            for (final item in pageItems) {
              _installing.remove(item.id);
            }
          });
        }
        continue;
      }

      // 从页数据中逐条匹配并保存
      for (final item in pageItems) {
        try {
          final found = pageData.firstWhere(
            (e) => e['id'] == item.id,
            orElse: () => throw Exception('页面数据中未找到「${item.name}」'),
          );
          final model = RouteModel.fromJson(found);

          // 冲突检测
          final conflict = existing
              .where((r) => r.name == model.name && r.id != model.id)
              .firstOrNull;

          if (conflict != null && mounted) {
            final overwrite = await showDialog<bool>(
              context: context,
              builder: (ctx) => AlertDialog(
                title: const Text('同名线路'),
                content: Text('本地已存在线路「${model.name}」，是否覆盖？'),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx, false),
                    child: const Text('取消'),
                  ),
                  ElevatedButton(
                    onPressed: () => Navigator.pop(ctx, true),
                    child: const Text('覆盖'),
                  ),
                ],
              ),
            );
            if (overwrite != true) {
              if (mounted) setState(() => _installing.remove(item.id));
              continue;
            }
          }

          await RouteStorage.save(model);
          if (mounted) {
            setState(() {
              _installedIds.add(item.id);
              _installing.remove(item.id);
            });
          }
        } catch (e) {
          errors.add('「${item.name}」安装失败：$e');
          if (mounted) setState(() => _installing.remove(item.id));
        }
      }
    }

    if (!mounted) return;
    setState(() => _checked.clear());

    if (errors.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('已安装 ${toInstall.length} 条线路'),
          duration: const Duration(seconds: 2),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('部分安装失败：\n${errors.join('\n')}'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }

  // ── Build ────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark
          ? const Color(0xFF111111)
          : const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: Text(_checked.isNotEmpty ? '已选 ${_checked.length} 条' : '线路商城'),
        backgroundColor: isDark ? Colors.black : Colors.white,
        foregroundColor: cs.onSurface,
        elevation: 0,
        leading: _checked.isNotEmpty
            ? IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => setState(() => _checked.clear()),
              )
            : null,
        actions: [
          if (_checked.isNotEmpty) ...[
            IconButton(
              icon: Icon(
                _currentPageAllChecked ? Icons.deselect : Icons.select_all,
              ),
              tooltip: _currentPageAllChecked ? '取消全选本页' : '全选本页',
              onPressed: _toggleSelectCurrentPage,
            ),
            IconButton(
              icon: const Icon(Icons.download),
              tooltip: '安装选中',
              onPressed: _installChecked,
            ),
          ],
          if (_checked.isEmpty) ...[
            IconButton(
              icon: Icon(_searchOpen ? Icons.search_off : Icons.search),
              tooltip: _searchOpen ? '关闭搜索' : '搜索线路',
              onPressed: _toggleSearch,
            ),
            PopupMenuButton<_StoreAction>(
              icon: const Icon(Icons.more_vert),
              tooltip: '更多操作',
              onSelected: (action) {
                switch (action) {
                  case _StoreAction.refresh:
                    _loadIndex();
                }
              },
              itemBuilder: (_) => const [
                PopupMenuItem(
                  value: _StoreAction.refresh,
                  child: Row(
                    children: [
                      Icon(Icons.refresh),
                      SizedBox(width: 12),
                      Text('刷新'),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
      body: _loadingIndex
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('正在加载线路目录…'),
                ],
              ),
            )
          : _indexError != null
          ? _buildError(isDark, cs)
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ── 内联搜索栏 ──
                if (_searchOpen) ...[
                  InlineSearchBar(
                    initialQuery: _searchQuery,
                    hintText: '输入线路名 / 作者名…',
                    onSearch: _onSearch,
                  ),
                  const Divider(height: 1),
                ],
                // ── 搜索结果提示条 ──
                if (_isFiltered)
                  Container(
                    color: cs.primary.withAlpha(15),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 6,
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.filter_list, size: 14, color: cs.primary),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            '「$_searchQuery」的搜索结果：共 ${_pager.totalCount} 条',
                            style: TextStyle(
                              fontSize: 12,
                              color: cs.primary,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        GestureDetector(
                          onTap: () => _onSearch(''),
                          child: Icon(
                            Icons.close,
                            size: 16,
                            color: cs.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                // ── 提示 + 列表 ──
                if (_pager.totalCount == 0)
                  Expanded(child: _buildEmpty())
                else ...[
                  if (!_isFiltered) _buildHint(),
                  if (_pager.hasMultiplePages)
                    buildPaginationControls(
                      context: context,
                      currentPage: _pager.currentPage,
                      totalPages: _pager.totalPages,
                      totalResults: _pager.totalCount,
                      pageController: _pageController,
                      loadingPage: _loadingPage,
                      onGoToPage: _goToPage,
                    ),
                  Expanded(child: _buildList(isDark, cs)),
                ],
              ],
            ),
    );
  }

  // ── 错误态 ───────────────────────────────────────────────────

  Widget _buildError(bool isDark, ColorScheme cs) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.cloud_off_outlined, size: 64, color: Colors.grey.shade400),
          const SizedBox(height: 16),
          Text(
            '加载失败',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _indexError ?? '',
            style: TextStyle(fontSize: 12, color: Colors.grey.shade400),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: _loadIndex,
            icon: const Icon(Icons.refresh),
            label: const Text('重试'),
          ),
        ],
      ),
    ),
  );

  // ── 空态 ─────────────────────────────────────────────────────

  Widget _buildEmpty() => Center(
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.store_outlined, size: 64, color: Colors.grey.shade400),
        const SizedBox(height: 16),
        Text(
          '暂无线路',
          style: TextStyle(fontSize: 18, color: Colors.grey.shade500),
        ),
      ],
    ),
  );

  // ── 列表 ─────────────────────────────────────────────────────

  Widget _buildHint() {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: cs.primary.withAlpha(18),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cs.primary.withAlpha(50)),
      ),
      child: Row(
        children: [
          Icon(Icons.touch_app_outlined, size: 16, color: cs.primary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '你知道吗，长按线路卡片可以批量选择',
              style: TextStyle(
                fontSize: 12,
                color: cs.primary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildList(bool isDark, ColorScheme cs) {
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 32),
      itemCount: _pager.currentPageItems.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (ctx, idx) =>
          _buildCard(_pager.currentPageItems[idx], isDark, cs),
    );
  }

  Widget _buildCard(_StoreItem item, bool isDark, ColorScheme cs) {
    final isInstalled = _installedIds.contains(item.id);
    final isInstalling = _installing.contains(item.id);
    final isChecked = _checked.contains(item.id);

    return GestureDetector(
      onTap: () {
        if (_checked.isNotEmpty) {
          // 批量模式：切换勾选
          setState(() {
            isChecked ? _checked.remove(item.id) : _checked.add(item.id);
          });
        }
      },
      onLongPress: () => setState(() {
        isChecked ? _checked.remove(item.id) : _checked.add(item.id);
      }),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isChecked
                ? cs.primary
                : isDark
                ? Colors.white.withAlpha(20)
                : Colors.transparent,
            width: isChecked ? 2 : 1,
          ),
          boxShadow: isDark
              ? []
              : [
                  BoxShadow(
                    color: Colors.black.withAlpha(15),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              // 勾选圆圈（批量模式时显示）
              if (_checked.isNotEmpty)
                Container(
                  width: 24,
                  height: 24,
                  margin: const EdgeInsets.only(right: 12),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isChecked ? cs.primary : Colors.transparent,
                    border: Border.all(
                      color: isChecked ? cs.primary : Colors.grey.shade400,
                      width: 2,
                    ),
                  ),
                  child: isChecked
                      ? const Icon(Icons.check, size: 14, color: Colors.white)
                      : null,
                ),
              // 图标
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: cs.primary.withAlpha(30),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: item.icon.isEmpty
                    ? Icon(Icons.route, color: cs.primary, size: 24)
                    : Padding(
                        padding: const EdgeInsets.all(5.5),
                        child: Image.asset(
                          'assets/icon/${item.icon}',
                          fit: BoxFit.contain,
                          errorBuilder: (_, __, ___) =>
                              Icon(Icons.route, color: cs.primary, size: 24),
                        ),
                      ),
              ),
              const SizedBox(width: 12),
              // 文字信息
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.name,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        Icon(
                          Icons.person_outline,
                          size: 12,
                          color: cs.onSurface.withAlpha(120),
                        ),
                        const SizedBox(width: 3),
                        Text(
                          item.author,
                          style: TextStyle(
                            fontSize: 12,
                            color: item.author == "CrYinLang"
                                ? Colors.red
                                : cs.onSurface.withAlpha(140),
                          ),
                        ),
                        if (item.author == "CrYinLang") ...[
                          const SizedBox(width: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 1,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.yellow.withOpacity(0.8),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text(
                              '氪金玩家',
                              style: TextStyle(
                                fontSize: 9,
                                color: Colors.black,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                        if (isInstalled) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 1,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.green.withAlpha(40),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: Colors.green.withAlpha(100),
                              ),
                            ),
                            child: const Text(
                              '已安装',
                              style: TextStyle(
                                fontSize: 10,
                                color: Colors.green,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              // 安装按钮
              if (_checked.isEmpty)
                isInstalling
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : IconButton(
                        icon: Icon(
                          isInstalled
                              ? Icons.download_done_outlined
                              : Icons.download_outlined,
                          color: isInstalled ? Colors.green : cs.primary,
                        ),
                        tooltip: isInstalled ? '重新安装' : '安装',
                        onPressed: () => _installItem(item),
                      ),
            ],
          ),
        ),
      ),
    );
  }
}
