// ui/function/route_hub_page.dart
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../functions.dart';
import '../../station_selector.dart';
import 'route_edit_page.dart';
import 'route_map_page.dart';
import 'route_models.dart';

class RouteHubPage extends StatefulWidget {
  const RouteHubPage({super.key});

  @override
  State<RouteHubPage> createState() => _RouteHubPageState();
}

class _RouteHubPageState extends State<RouteHubPage> {
  // 每页 10 条
  final _pager = PaginatedController<RouteModel>(pageSize: 10);

  bool _loading = true;
  final Set<String> _selected = {};
  late TextEditingController _pageController;

  bool get _selecting => _selected.isNotEmpty;

  bool get _currentPageAllSelected =>
      _pager.currentPageItems.isNotEmpty &&
      _pager.currentPageItems.every((r) => _selected.contains(r.id));

  // ── 加载 ────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _pageController = TextEditingController(text: '1');
    _reload();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _reload() async {
    setState(() => _loading = true);

    // ① 加载所有线路
    final all = await RouteStorage.loadAll();

    // ② 加载站点字典（只做一次）
    final stationList = await loadStations();
    final telecodeNameMap = {
      for (final s in stationList)
        (s['telecode'] as String? ?? '').trim(): (s['name'] as String? ?? '')
            .replaceAll('站', '')
            .trim(),
    };

    // ③ 只补「起终点」
    for (final r in all) {
      if (r.stations.isEmpty) continue;

      final first = r.stations.first;
      final last = r.stations.last;

      if (first.name.isEmpty && first.telecode.isNotEmpty) {
        final newName = telecodeNameMap[first.telecode] ?? '';
        if (newName.isNotEmpty) {
          // ✅ 正确：用 copyWith 创建新对象
          r.stations[0] = first.copyWith(name: newName);
        }
      }

      if (last.name.isEmpty && last.telecode.isNotEmpty) {
        final newName = telecodeNameMap[last.telecode] ?? '';
        if (newName.isNotEmpty) {
          // ✅ 正确：用 copyWith 创建新对象
          r.stations[r.stations.length - 1] = last.copyWith(name: newName);
        }
      }
    }

    if (!mounted) return;

    setState(() {
      _pager.resetAndLoad(all);
      _selected.retainWhere((id) => all.any((r) => r.id == id));
      _pageController.text = '1';
      _loading = false;
    });
  }

  // ── 导出 / 导入 ─────────────────────────────────────────────

  Future<void> _exportSelected() async {
    final sel = _pager.allItems.where((r) => _selected.contains(r.id)).toList();
    if (sel.isEmpty) return;
    final jsonStr = const JsonEncoder.withIndent(
      '  ',
    ).convert(sel.map((r) => r.toJson()).toList());
    await Clipboard.setData(ClipboardData(text: jsonStr));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('已复制 ${sel.length} 条线路的 JSON 到剪贴板'),
        duration: const Duration(seconds: 3),
        action: SnackBarAction(
          label: '查看',
          onPressed: () => showDialog(
            context: context,
            builder: (ctx) => AlertDialog(
              title: const Text('导出 JSON'),
              content: SingleChildScrollView(
                child: SelectableText(
                  jsonStr,
                  style: const TextStyle(fontSize: 11, fontFamily: 'monospace'),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('关闭'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _importFromJson() async {
    final ctrl = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('导入线路 JSON'),
        content: TextField(
          controller: ctrl,
          maxLines: 8,
          decoration: const InputDecoration(
            hintText: '粘贴从「导出」获得的 JSON 文本…',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('导入'),
          ),
        ],
      ),
    );
    if (confirmed != true || ctrl.text.trim().isEmpty) return;

    List<RouteModel> imported;
    try {
      final raw = json.decode(ctrl.text.trim());
      if (raw is! List) throw const FormatException('顶层必须是 JSON 数组');
      imported = raw
          .map((e) => RouteModel.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('JSON 解析失败：$e')));
      return;
    }

    final existing = await RouteStorage.loadAll();
    final existingNames = {for (final r in existing) r.name: r};
    int added = 0, updated = 0, skipped = 0;

    for (final r in imported) {
      final conflict = existingNames[r.name];
      if (conflict != null) {
        if (!mounted) break;
        final overwrite = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('同名线路'),
            content: Text('已存在线路「${r.name}」，是否覆盖？'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('跳过'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('覆盖'),
              ),
            ],
          ),
        );
        if (overwrite == true) {
          final merged = RouteModel(
            id: conflict.id,
            name: r.name,
            author: r.author,
            icon: r.icon,
            createdAt: conflict.createdAt,
            updatedAt: DateTime.now(),
            stations: r.stations,
          );

          await RouteStorage.save(merged);
          updated++;
        } else {
          skipped++;
        }
      } else {
        await RouteStorage.save(r);
        added++;
      }
    }

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('导入完成：新增 $added，覆盖 $updated，跳过 $skipped')),
    );
    _reload();
  }

  // ── 选择 ────────────────────────────────────────────────────

  void _toggleSelectCurrentPage() {
    setState(() {
      if (_currentPageAllSelected) {
        for (final r in _pager.currentPageItems) _selected.remove(r.id);
      } else {
        for (final r in _pager.currentPageItems) _selected.add(r.id);
      }
    });
  }

  void _toggleSelect(String id) => setState(() {
    _selected.contains(id) ? _selected.remove(id) : _selected.add(id);
  });

  void _clearSelect() => setState(() => _selected.clear());

  // ── 分页 ────────────────────────────────────────────────────

  void _goToPage(int page) {
    if (page == _pager.currentPage || page < 1 || page > _pager.totalPages) {
      _pageController.text = _pager.currentPage.toString();
      return;
    }
    setState(() {
      _pager.loadPage(page);
      _pageController.text = page.toString();
    });
  }

  // ── 删除 ────────────────────────────────────────────────────

  Future<void> _deleteRoute(RouteModel r) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('确认删除'),
        content: Text('删除线路「${r.name}」？此操作不可撤销。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await RouteStorage.delete(r.id);
      _selected.remove(r.id);
      _reload();
    }
  }

  Future<void> _deleteBatch() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('批量删除'),
        content: Text('确定删除已选中的 ${_selected.length} 条线路吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (confirm == true) {
      for (final id in _selected) {
        await RouteStorage.delete(id);
      }
      _selected.clear();
      if (mounted) _reload();
    }
  }

  // ── 导航 ────────────────────────────────────────────────────

  Future<void> _openNew() async {
    final result = await Navigator.of(
      context,
    ).push<RouteModel>(MaterialPageRoute(builder: (_) => const RoutePage()));
    if (result != null) _reload();
  }

  Future<void> _openEdit(RouteModel r) async {
    final result = await Navigator.of(context).push<RouteModel>(
      MaterialPageRoute(builder: (_) => RoutePage(existing: r)),
    );
    if (result != null) _reload();
  }

  void _openMap() {
    final sel = _pager.allItems.where((r) => _selected.contains(r.id)).toList();
    if (sel.isEmpty) return;
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => RouteMapPage(routes: sel)));
  }

  // ── 卡片菜单 ────────────────────────────────────────────────

  void _showCardMenu(RouteModel r) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final cs = Theme.of(ctx).colorScheme;
        return Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
          ),
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
            top: 16,
            left: 20,
            right: 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade400,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: cs.primary.withAlpha(30),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(Icons.route, color: cs.primary, size: 20),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          r.name,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          '${r.fromStation} → ${r.toStation}',
                          style: TextStyle(
                            fontSize: 12,
                            color: cs.onSurface.withAlpha(150),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  RhMenuChip(
                    icon: Icons.edit_outlined,
                    label: '编辑线路',
                    color: cs.primary,
                    onTap: () {
                      Navigator.pop(ctx);
                      _openEdit(r);
                    },
                  ),
                  RhMenuChip(
                    icon: _selected.contains(r.id)
                        ? Icons.check_box
                        : Icons.check_box_outline_blank,
                    label: _selected.contains(r.id) ? '取消选中' : '选中此线路',
                    color: Colors.teal,
                    onTap: () {
                      Navigator.pop(ctx);
                      _toggleSelect(r.id);
                    },
                  ),
                  RhMenuChip(
                    icon: Icons.map_outlined,
                    label: '单独查看走向图',
                    color: Colors.indigo,
                    onTap: () {
                      Navigator.pop(ctx);
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => RouteMapPage(routes: [r]),
                        ),
                      );
                    },
                  ),
                  RhMenuChip(
                    icon: Icons.delete_outline,
                    label: '删除',
                    color: Colors.red,
                    onTap: () {
                      Navigator.pop(ctx);
                      _deleteRoute(r);
                    },
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  // ── 商店占位（后期功能）────────────────────────────────────

  void _openShop() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('商店功能即将上线，敬请期待 🚀'),
        duration: Duration(seconds: 2),
      ),
    );
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
        title: Text(_selecting ? '已选 ${_selected.length} 条线路' : '线路处'),
        backgroundColor: isDark ? Colors.black : Colors.white,
        foregroundColor: cs.onSurface,
        elevation: 0,
        leading: _selecting
            ? IconButton(icon: const Icon(Icons.close), onPressed: _clearSelect)
            : null,
        actions: [
          if (_selecting) ...[
            IconButton(
              icon: Icon(
                _currentPageAllSelected ? Icons.deselect : Icons.select_all,
              ),
              tooltip: _currentPageAllSelected ? '取消全选本页' : '全选本页',
              onPressed: _toggleSelectCurrentPage,
            ),
            IconButton(
              icon: const Icon(Icons.ios_share_outlined),
              tooltip: '导出选中',
              onPressed: _exportSelected,
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline),
              tooltip: '批量删除',
              onPressed: _deleteBatch,
              style: IconButton.styleFrom(foregroundColor: Colors.red),
            ),
          ] else ...[
            // 导入
            IconButton(
              icon: const Icon(Icons.file_download_outlined),
              tooltip: '导入线路',
              onPressed: _importFromJson,
            ),
            // 商店（占位，后期加功能）
            IconButton(
              icon: const Icon(Icons.storefront_outlined),
              tooltip: '商店',
              onPressed: _openShop,
            ),
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _reload,
              tooltip: '刷新',
            ),
          ],
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _pager.totalCount == 0
          ? _buildEmpty(isDark)
          : Column(
              children: [
                if (_pager.hasMultiplePages)
                  buildPaginationControls(
                    context: context,
                    currentPage: _pager.currentPage,
                    totalPages: _pager.totalPages,
                    totalResults: _pager.totalCount,
                    loadingPage: false,
                    pageController: _pageController,
                    onGoToPage: _goToPage,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                Expanded(child: _buildList(isDark, cs)),
              ],
            ),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (_selecting && _selected.isNotEmpty) ...[
            FloatingActionButton.extended(
              heroTag: 'fab_map',
              onPressed: _openMap,
              icon: const Icon(Icons.map_outlined),
              label: const Text('查看走向图'),
              backgroundColor: cs.primary,
              foregroundColor: cs.onPrimary,
            ),
            const SizedBox(height: 12),
          ],
          FloatingActionButton(
            heroTag: 'fab_new',
            onPressed: _openNew,
            tooltip: '新建线路',
            child: const Icon(Icons.add),
          ),
        ],
      ),
    );
  }

  // ── 空态 ────────────────────────────────────────────────────

  Widget _buildEmpty(bool isDark) => Center(
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.route, size: 64, color: Colors.grey.shade400),
        const SizedBox(height: 16),
        Text(
          '还没有线路',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: Colors.grey.shade500,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          '点击右下角「+」新建第一条线路',
          style: TextStyle(fontSize: 14, color: Colors.grey.shade400),
        ),
      ],
    ),
  );

  // ── 列表 ────────────────────────────────────────────────────

  Widget _buildList(bool isDark, ColorScheme cs) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
      children: [
        if (!_selecting)
          Container(
            margin: const EdgeInsets.only(bottom: 12),
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
                    '点击卡片可编辑或选中，长按进入多选模式',
                    style: TextStyle(
                      fontSize: 12,
                      color: cs.primary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ..._pager.items.map((r) => _buildCard(r, isDark, cs)),
      ],
    );
  }

  // ── 卡片 ─────────────────────────────────────────────────────

  Widget _buildCard(RouteModel r, bool isDark, ColorScheme cs) {
    final isSel = _selected.contains(r.id);
    final mileage = r.totalMileage;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Dismissible(
        key: ValueKey(r.id),
        direction: DismissDirection.endToStart,
        background: Container(
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.only(right: 20),
          decoration: BoxDecoration(
            color: Colors.red,
            borderRadius: BorderRadius.circular(14),
          ),
          child: const Icon(
            Icons.delete_outline,
            color: Colors.white,
            size: 28,
          ),
        ),
        confirmDismiss: (_) async {
          await _deleteRoute(r);
          return false;
        },
        child: GestureDetector(
          onTap: () => _selecting ? _toggleSelect(r.id) : _showCardMenu(r),
          onLongPress: () => _toggleSelect(r.id),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isSel
                    ? cs.primary
                    : isDark
                    ? Colors.white.withAlpha(20)
                    : Colors.transparent,
                width: isSel ? 2 : 1,
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
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 200),
                    child: _selecting
                        ? Container(
                            key: const ValueKey('chk'),
                            width: 24,
                            height: 24,
                            margin: const EdgeInsets.only(right: 12),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: isSel ? cs.primary : Colors.transparent,
                              border: Border.all(
                                color: isSel
                                    ? cs.primary
                                    : Colors.grey.shade400,
                                width: 2,
                              ),
                            ),
                            child: isSel
                                ? const Icon(
                                    Icons.check,
                                    size: 14,
                                    color: Colors.white,
                                  )
                                : null,
                          )
                        : const SizedBox(key: ValueKey('none')),
                  ),
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: cs.primary.withAlpha(30),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: r.icon.isEmpty
                        ? Icon(Icons.route, color: cs.primary, size: 24)
                        : Padding(
                            padding: const EdgeInsets.all(5.5), // ~75% of 44px
                            child: Image.asset(
                              'assets/icon/${r.icon}',
                              fit: BoxFit.contain,
                              errorBuilder: (_, __, ___) =>
                                  Icon(Icons.route, color: cs.primary, size: 24),
                            ),
                          ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          r.name,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          '${r.fromStation} → ${r.toStation}',
                          style: TextStyle(
                            fontSize: 13,
                            color: cs.onSurface.withAlpha(160),
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 3),
                        Row(
                          children: [
                            _infoChip(
                              Icons.location_on_outlined,
                              '${r.stations.length} 站',
                              cs,
                            ),
                            if (mileage > 0) ...[
                              const SizedBox(width: 6),
                              _infoChip(
                                Icons.straighten,
                                '${mileage.toStringAsFixed(0)} km',
                                cs,
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                  if (!_selecting)
                    IconButton(
                      icon: const Icon(Icons.edit_outlined, size: 20),
                      onPressed: () => _openEdit(r),
                      color: Colors.grey.shade400,
                      tooltip: '编辑线路',
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _infoChip(IconData icon, String label, ColorScheme cs) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(icon, size: 12, color: cs.onSurface.withAlpha(120)),
      const SizedBox(width: 3),
      Text(
        label,
        style: TextStyle(fontSize: 11, color: cs.onSurface.withAlpha(120)),
      ),
    ],
  );
}
