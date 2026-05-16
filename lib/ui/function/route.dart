// ui/function/route.dart
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

import '../../station_selector.dart';

// ═════════════════════════════════════════════════════════════
// 数据模型
// ═════════════════════════════════════════════════════════════

/// 线路中的一个站点
class RouteStation {
  final String name;
  final String telecode;
  final String city;

  /// 到下一站的里程（km），终点站为 null
  final double? mileageToNext;

  const RouteStation({
    required this.name,
    required this.telecode,
    required this.city,
    this.mileageToNext,
  });

  Map<String, dynamic> toJson() => {
    'name': name,
    'telecode': telecode,
    'city': city,
    if (mileageToNext != null) 'mileageToNext': mileageToNext,
  };

  factory RouteStation.fromJson(Map<String, dynamic> j) => RouteStation(
    name: j['name'] as String? ?? '',
    telecode: j['telecode'] as String? ?? '',
    city: j['city'] as String? ?? '',
    mileageToNext: (j['mileageToNext'] as num?)?.toDouble(),
  );
}

/// 一条线路
class RouteModel {
  final String id;
  final String name;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<RouteStation> stations;

  const RouteModel({
    required this.id,
    required this.name,
    required this.createdAt,
    required this.updatedAt,
    required this.stations,
  });

  double get totalMileage {
    double t = 0;
    for (final s in stations) {
      if (s.mileageToNext != null) t += s.mileageToNext!;
    }
    return t;
  }

  String get fromStation => stations.isNotEmpty ? stations.first.name : '';

  String get toStation => stations.isNotEmpty ? stations.last.name : '';

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
    'stations': stations.map((s) => s.toJson()).toList(),
  };

  factory RouteModel.fromJson(Map<String, dynamic> j) => RouteModel(
    id: j['id'] as String? ?? '',
    name: j['name'] as String? ?? '',
    createdAt: j['createdAt'] != null
        ? DateTime.tryParse(j['createdAt'] as String) ?? DateTime.now()
        : DateTime.now(),
    updatedAt: j['updatedAt'] != null
        ? DateTime.tryParse(j['updatedAt'] as String) ?? DateTime.now()
        : DateTime.now(),
    stations: (j['stations'] as List<dynamic>? ?? [])
        .map((e) => RouteStation.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList(),
  );
}

// ═════════════════════════════════════════════════════════════
// 持久化
// ═════════════════════════════════════════════════════════════

class RouteStorage {
  static Future<File> _file() async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/routes.json');
  }

  static Future<List<RouteModel>> loadAll() async {
    try {
      final f = await _file();
      if (!await f.exists()) return [];
      final raw = json.decode(await f.readAsString());
      if (raw is! List) return [];
      final list = raw
          .map((e) => RouteModel.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
      list.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
      return list;
    } catch (_) {
      return [];
    }
  }

  static Future<void> save(RouteModel model) async {
    final all = await loadAll();
    final idx = all.indexWhere((r) => r.id == model.id);
    if (idx >= 0) {
      all[idx] = model;
    } else {
      all.insert(0, model);
    }
    final f = await _file();
    await f.writeAsString(
      json.encode(all.map((r) => r.toJson()).toList()),
      flush: true,
    );
  }

  static Future<void> delete(String id) async {
    final all = await loadAll();
    all.removeWhere((r) => r.id == id);
    final f = await _file();
    await f.writeAsString(
      json.encode(all.map((r) => r.toJson()).toList()),
      flush: true,
    );
  }
}

// ═════════════════════════════════════════════════════════════
// RouteHubPage — 主页面
// ═════════════════════════════════════════════════════════════

class RouteHubPage extends StatefulWidget {
  const RouteHubPage({super.key});

  @override
  State<RouteHubPage> createState() => _RouteHubPageState();
}

class _RouteHubPageState extends State<RouteHubPage> {
  List<RouteModel> _routes = [];
  bool _loading = true;
  final Set<String> _selected = {};

  bool get _selecting => _selected.isNotEmpty;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    final all = await RouteStorage.loadAll();
    if (!mounted) return;
    setState(() {
      _routes = all;
      _loading = false;
    });
  }

  void _toggleSelect(String id) => setState(() {
    _selected.contains(id) ? _selected.remove(id) : _selected.add(id);
  });

  void _clearSelect() => setState(() => _selected.clear());

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
            child: const Text(''),
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
    final sel = _routes.where((r) => _selected.contains(r.id)).toList();
    if (sel.isEmpty) return;
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => RouteMapPage(routes: sel)));
  }

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
          if (_selecting)
            TextButton.icon(
              onPressed: _selected.length == _routes.length
                  ? _clearSelect
                  : () => setState(() {
                      _selected
                        ..clear()
                        ..addAll(_routes.map((r) => r.id));
                    }),
              icon: Icon(
                _selected.length == _routes.length
                    ? Icons.deselect
                    : Icons.select_all,
              ),
              label: Text(_selected.length == _routes.length ? '取消全选' : '全选'),
              style: TextButton.styleFrom(foregroundColor: cs.primary),
            )
          else
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _reload,
              tooltip: '刷新',
            ),
          if (_selecting)
            TextButton.icon(
              onPressed: () async {
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
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.red,
                        ),
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

                  if (mounted) {
                    _reload();
                  }
                }
              },
              icon: const Icon(Icons.delete_outline),
              label: const Text('删除'),
              style: TextButton.styleFrom(foregroundColor: Colors.red),
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _routes.isEmpty
          ? _buildEmpty(isDark)
          : _buildList(isDark, cs),
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

  Widget _buildList(bool isDark, ColorScheme cs) => ListView(
    padding: const EdgeInsets.fromLTRB(12, 12, 12, 120),
    children: [
      Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: cs.primary.withAlpha(18),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: cs.primary.withAlpha(50)),
        ),
        child: Row(
          children: [
            Icon(Icons.touch_app_outlined, size: 18, color: cs.primary),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                '长按线路可进入多选模式，支持查看线路图与批量删除',
                style: TextStyle(
                  fontSize: 13,
                  color: cs.primary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),

      ..._routes.map((r) => _buildCard(r, isDark, cs)),
    ],
  );

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
          onTap: () => _selecting ? _toggleSelect(r.id) : _openEdit(r),
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
                    child: Icon(Icons.route, color: cs.primary, size: 24),
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

// ═════════════════════════════════════════════════════════════
// RoutePage — 新建 / 编辑线路
// ═════════════════════════════════════════════════════════════

class RoutePage extends StatefulWidget {
  final RouteModel? existing;

  const RoutePage({super.key, this.existing});

  @override
  State<RoutePage> createState() => _RoutePageState();
}

class _RoutePageState extends State<RoutePage> {
  final _nameCtrl = TextEditingController();
  final List<_EditableRouteStation> _stations = [];
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    if (widget.existing != null) {
      _nameCtrl.text = widget.existing!.name;
      _stations.addAll(
        widget.existing!.stations.map(
          (s) => _EditableRouteStation(
            name: s.name,
            telecode: s.telecode,
            city: s.city,
            mileageToNext: s.mileageToNext,
          ),
        ),
      );
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  // ── 添加车站 ────────────────────────────────────────────────

  Future<void> _pickStation() async {
    Map<String, String?>? result;
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) =>
          StationSelector(title: '选择国铁车站', onSelected: (r) => result = r),
    );
    if (result == null) return;
    final name = (result!['name'] ?? '').replaceAll('站', '').trim();
    if (name.isEmpty) return;
    if (_stations.any((s) => s.name == name)) {
      _showSnack('「$name」已在线路中');
      return;
    }
    setState(
      () => _stations.add(
        _EditableRouteStation(
          name: name,
          telecode: result!['telecode'] ?? '',
          city: result!['city'] ?? '',
        ),
      ),
    );
  }

  // ── 编辑里程 ────────────────────────────────────────────────

  void _editMileage(int idx) {
    if (idx >= _stations.length - 1) {
      _showSnack('终点站无需设置里程');
      return;
    }
    final s = _stations[idx];
    final ctrl = TextEditingController(
      text: s.mileageToNext != null ? '${s.mileageToNext}' : '',
    );
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('设置里程'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${s.name} → ${_stations[idx + 1].name}',
              style: const TextStyle(fontSize: 13, color: Colors.grey),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: ctrl,
              autofocus: true,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
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
              onSubmitted: (_) => _saveMileage(ctx, idx, ctrl.text.trim()),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              setState(() => _stations[idx].mileageToNext = null);
              Navigator.pop(ctx);
            },
            child: const Text('清除', style: TextStyle(color: Colors.orange)),
          ),
          ElevatedButton(
            onPressed: () => _saveMileage(ctx, idx, ctrl.text.trim()),
            child: const Text('保存'),
          ),
        ],
      ),
    );
  }

  void _saveMileage(BuildContext ctx, int idx, String raw) {
    final v = double.tryParse(raw);
    if (raw.isNotEmpty && v == null) {
      _showSnack('请输入有效的数字');
      return;
    }
    setState(() => _stations[idx].mileageToNext = v);
    Navigator.pop(ctx);
  }

  // ── 站点菜单 ────────────────────────────────────────────────

  void _showStationMenu(int idx) {
    final s = _stations[idx];
    final hasNext = idx < _stations.length - 1;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        return Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
          ),
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
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
              const SizedBox(height: 12),
              Text(
                '${s.name}站',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (s.city.isNotEmpty)
                Text(
                  s.city,
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (hasNext)
                    _RhMenuChip(
                      icon: Icons.straighten,
                      label: s.mileageToNext != null
                          ? '修改里程 (${s.mileageToNext}km)'
                          : '设置里程',
                      color: Colors.blue,
                      onTap: () {
                        Navigator.pop(ctx);
                        _editMileage(idx);
                      },
                    ),
                  _RhMenuChip(
                    icon: Icons.delete_outline,
                    label: '',
                    color: Colors.red,
                    onTap: () {
                      Navigator.pop(ctx);
                      setState(() => _stations.removeAt(idx));
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

  // ── 保存 ────────────────────────────────────────────────────

  Future<void> _save() async {
    final name = _nameCtrl.text.trim();
    final issues = <String>[];
    if (name.isEmpty) issues.add('• 请填写线路名称');
    if (_stations.length < 2) issues.add('• 至少需要 2 个站点');
    if (issues.isNotEmpty) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          icon: const Icon(Icons.error_outline, color: Colors.red, size: 32),
          title: const Text('还不能保存'),
          content: Text(issues.join('\n'), style: const TextStyle(height: 1.8)),
          actions: [
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('知道了'),
            ),
          ],
        ),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      final model = RouteModel(
        id:
            widget.existing?.id ??
            'route_${DateTime.now().millisecondsSinceEpoch}',
        name: name,
        createdAt: widget.existing?.createdAt ?? DateTime.now(),
        updatedAt: DateTime.now(),
        stations: _stations
            .map(
              (s) => RouteStation(
                name: s.name,
                telecode: s.telecode,
                city: s.city,
                mileageToNext: s.mileageToNext,
              ),
            )
            .toList(),
      );
      await RouteStorage.save(model);
      if (mounted) {
        _showSnack(widget.existing == null ? '线路「$name」已保存' : '线路「$name」已更新');
        Navigator.of(context).pop(model);
      }
    } catch (e) {
      _showSnack('保存失败：$e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _showSnack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), duration: const Duration(seconds: 2)),
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
        title: Text(widget.existing == null ? '新建线路' : '编辑线路'),
        backgroundColor: isDark ? Colors.black : Colors.white,
        foregroundColor: cs.onSurface,
        elevation: 0,
        actions: [
          if (_saving)
            const Padding(
              padding: EdgeInsets.only(right: 16),
              child: Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            )
          else
            TextButton.icon(
              onPressed: _save,
              icon: const Icon(Icons.check),
              label: const Text('保存'),
              style: TextButton.styleFrom(foregroundColor: cs.primary),
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          _sectionCard(
            icon: Icons.route,
            title: '线路信息',
            isDark: isDark,
            child: TextField(
              controller: _nameCtrl,
              inputFormatters: [LengthLimitingTextInputFormatter(30)],
              decoration: const InputDecoration(
                labelText: '线路名称 *',
                hintText: '如 京沪高铁、成渝城际',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.label_outline),
              ),
            ),
          ),
          const SizedBox(height: 12),
          _buildStationsSection(isDark, cs),
          const SizedBox(height: 80),
        ],
      ),
    );
  }

  Widget _buildStationsSection(bool isDark, ColorScheme cs) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
          child: Row(
            children: [
              Icon(Icons.linear_scale, color: cs.primary, size: 20),
              const SizedBox(width: 8),
              const Text(
                '站点列表',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const Spacer(),
              Text(
                '${_stations.length} 个站',
                style: TextStyle(
                  fontSize: 13,
                  color: cs.onSurface.withAlpha(140),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        if (_stations.isEmpty) _emptyHint(isDark) else _buildList(isDark, cs),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: _pickStation,
            icon: const Icon(Icons.add_location_alt_outlined),
            label: const Text('添加国铁车站'),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _emptyHint(bool isDark) => Container(
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: isDark ? Colors.white.withAlpha(10) : Colors.grey.shade100,
      borderRadius: BorderRadius.circular(10),
      border: Border.all(
        color: isDark ? Colors.white.withAlpha(30) : Colors.grey.shade300,
      ),
    ),
    child: Column(
      children: [
        Icon(Icons.add_road, size: 36, color: Colors.grey.shade400),
        const SizedBox(height: 8),
        Text(
          '还没有站点，点击下方「添加国铁车站」',
          style: TextStyle(color: Colors.grey.shade500),
        ),
        const SizedBox(height: 4),
        Text(
          '点击已添加的车站可设置与下一站里程',
          style: TextStyle(fontSize: 11, color: Colors.grey.shade400),
        ),
      ],
    ),
  );

  Widget _buildList(bool isDark, ColorScheme cs) {
    return ReorderableListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _stations.length,
      onReorder: (oldIdx, newIdx) {
        setState(() {
          if (newIdx > oldIdx) newIdx--;
          _stations.insert(newIdx, _stations.removeAt(oldIdx));
        });
      },
      proxyDecorator: (child, idx, anim) => Material(
        elevation: 4,
        borderRadius: BorderRadius.circular(12),
        child: child,
      ),
      itemBuilder: (ctx, idx) => _buildTile(idx, isDark, cs),
    );
  }

  Widget _buildTile(int idx, bool isDark, ColorScheme cs) {
    final s = _stations[idx];

    final firstName = _stations.isNotEmpty ? _stations.first.name : '';

    final lastName = _stations.isNotEmpty ? _stations.last.name : '';

    final isStartStation = s.name == firstName;
    final isEndStation = s.name == lastName;

    final isFirst = idx == 0;
    final isLast = idx == _stations.length - 1;

    final hasMileage = s.mileageToNext != null;

    final isBoth = isStartStation && isEndStation;

    return Column(
      key: ValueKey('rs_$idx'),
      children: [
        InkWell(
          onTap: () => _showStationMenu(idx),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
            child: Row(
              children: [
                // 竖线 + 圆点
                SizedBox(
                  width: 32,
                  child: Column(
                    children: [
                      if (!isFirst)
                        Container(
                          width: 2,
                          height: 8,
                          color: cs.primary.withAlpha(100),
                        ),
                      Container(
                        width: isStartStation || isEndStation ? 16 : 12,
                        height: isStartStation || isEndStation ? 16 : 12,
                        decoration: BoxDecoration(
                          color: isBoth
                              ? Colors.orange
                              : isStartStation
                              ? Colors.green
                              : isEndStation
                              ? Colors.red
                              : cs.primary,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                      ),

                      if (!isLast)
                        Container(
                          width: 2,
                          height: 8,
                          color: cs.primary.withAlpha(100),
                        ),
                    ],
                  ),
                ),

                const SizedBox(width: 10),

                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              '${s.name}站',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: isStartStation || isEndStation
                                    ? FontWeight.bold
                                    : FontWeight.w500,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),

                          const SizedBox(width: 6),

                          if (isStartStation)
                            _badge('起点', isBoth ? Colors.orange : Colors.green),

                          if (isEndStation)
                            Padding(
                              padding: const EdgeInsets.only(left: 4),
                              child: _badge(
                                '终点',
                                isBoth ? Colors.orange : Colors.red,
                              ),
                            ),
                        ],
                      ),

                      if (s.city.isNotEmpty)
                        Text(
                          s.city,
                          style: TextStyle(
                            fontSize: 11,
                            color: cs.onSurface.withAlpha(130),
                          ),
                        ),
                    ],
                  ),
                ),

                if (!isLast)
                  GestureDetector(
                    onTap: () => _editMileage(idx),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: hasMileage
                            ? Colors.blue.withAlpha(30)
                            : Colors.grey.withAlpha(30),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: hasMileage
                              ? Colors.blue.withAlpha(100)
                              : Colors.grey.withAlpha(80),
                        ),
                      ),
                      child: Text(
                        hasMileage ? '${s.mileageToNext} km' : '设置里程',
                        style: TextStyle(
                          fontSize: 11,
                          color: hasMileage ? Colors.blue : Colors.grey,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),

                const SizedBox(width: 6),

                Icon(Icons.drag_handle, color: Colors.grey.shade400, size: 20),
              ],
            ),
          ),
        ),

        Divider(
          height: 1,
          indent: 54,
          color: isDark ? Colors.white.withAlpha(20) : Colors.grey.shade200,
        ),
      ],
    );
  }

  Widget _badge(String text, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
    decoration: BoxDecoration(
      color: color.withAlpha(40),
      borderRadius: BorderRadius.circular(4),
      border: Border.all(color: color.withAlpha(120)),
    ),
    child: Text(
      text,
      style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.bold),
    ),
  );

  Widget _sectionCard({
    required IconData icon,
    required String title,
    required Widget child,
    required bool isDark,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(14),
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
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                icon,
                size: 18,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// 内部编辑模型（仅 RoutePage 使用）
// ─────────────────────────────────────────────────────────────
class _EditableRouteStation {
  String name;
  String telecode;
  String city;
  double? mileageToNext;

  _EditableRouteStation({
    required this.name,
    required this.telecode,
    required this.city,
    this.mileageToNext,
  });
}

// ─────────────────────────────────────────────────────────────
// 菜单 Chip（内部共用）
// ─────────────────────────────────────────────────────────────
class _RhMenuChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _RhMenuChip({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color: color.withAlpha(20),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: color.withAlpha(100)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                color: color,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════
// RouteMapPage — 多线路叠加走向图
// ═════════════════════════════════════════════════════════════

const _kRouteColors = [
  Color(0xFF2196F3),
  Color(0xFFE91E63),
  Color(0xFF4CAF50),
  Color(0xFFFF9800),
  Color(0xFF9C27B0),
  Color(0xFF00BCD4),
  Color(0xFFFF5722),
  Color(0xFF607D8B),
];

class _PlottedStation {
  final String name;
  final String city;
  final double? mileageToNext;
  final bool hasLocation;
  double x;
  double y;
  final double lng;
  final double lat;

  _PlottedStation({
    required this.name,
    required this.city,
    this.mileageToNext,
    required this.hasLocation,
    this.x = 0.5,
    this.y = 0.5,
    this.lng = 0,
    this.lat = 0,
  });
}

class _PlottedRoute {
  final RouteModel model;
  final List<_PlottedStation> stations;
  final Color color;
  bool visible;

  _PlottedRoute({
    required this.model,
    required this.stations,
    required this.color,
    this.visible = true,
  });
}

class RouteMapPage extends StatefulWidget {
  final List<RouteModel> routes;

  const RouteMapPage({super.key, required this.routes});

  @override
  State<RouteMapPage> createState() => _RouteMapPageState();
}

class _RouteMapPageState extends State<RouteMapPage> {
  List<_PlottedRoute> _plotted = [];
  bool _loading = true;
  int? _selRouteIdx;
  int? _selStopIdx;
  final TransformationController _txCtrl = TransformationController();
  double _scale = 1.0;

  @override
  void initState() {
    super.initState();
    _loadAndPlot();
  }

  @override
  void dispose() {
    _txCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadAndPlot() async {
    final allStations = await loadStations();
    final Map<String, Map<String, dynamic>> nameIdx = {};
    for (final s in allStations) {
      final name = (s['name'] as String? ?? '').replaceAll('站', '').trim();
      final loc = (s['location'] as String? ?? '');
      final parts = loc.split(',');
      if (parts.length == 2) {
        final lng = double.tryParse(parts[0]);
        final lat = double.tryParse(parts[1]);
        if (lng != null && lat != null) {
          nameIdx[name] = {
            'lng': lng,
            'lat': lat,
            'city': s['city'] as String? ?? '',
          };
        }
      }
    }

    final List<_PlottedRoute> raw = [];
    for (int ri = 0; ri < widget.routes.length; ri++) {
      final r = widget.routes[ri];
      final color = _kRouteColors[ri % _kRouteColors.length];
      final stations = r.stations.map((s) {
        final clean = s.name.replaceAll('站', '').trim();
        final info = nameIdx[clean];
        return _PlottedStation(
          name: clean,
          city: info?['city'] as String? ?? s.city,
          mileageToNext: s.mileageToNext,
          hasLocation: info != null,
          lng: (info?['lng'] as double?) ?? 0,
          lat: (info?['lat'] as double?) ?? 0,
        );
      }).toList();
      raw.add(_PlottedRoute(model: r, stations: stations, color: color));
    }

    _normalizeAll(raw);
    setState(() {
      _plotted = raw;
      _loading = false;
    });
  }

  void _normalizeAll(List<_PlottedRoute> routes) {
    final valid = <_PlottedStation>[
      for (final r in routes) ...r.stations.where((s) => s.hasLocation),
    ];
    if (valid.length < 2) {
      for (final r in routes) {
        final n = r.stations.length;
        for (int i = 0; i < n; i++) {
          r.stations[i].x = n > 1 ? 0.1 + 0.8 * (i / (n - 1)) : 0.5;
          r.stations[i].y = 0.5;
        }
      }
      return;
    }

    double minLng = double.infinity,
        maxLng = -double.infinity,
        minLat = double.infinity,
        maxLat = -double.infinity;
    for (final s in valid) {
      minLng = min(minLng, s.lng);
      maxLng = max(maxLng, s.lng);
      minLat = min(minLat, s.lat);
      maxLat = max(maxLat, s.lat);
    }

    const ar = 1.8;
    double adjLng = max(maxLng - minLng, 0.001);
    double adjLat = max(maxLat - minLat, adjLng / ar / 2);
    if (adjLng / adjLat > ar) {
      adjLat = adjLng / ar;
    } else {
      adjLng = adjLat * ar;
    }

    final cx = (minLng + maxLng) / 2, cy = (minLat + maxLat) / 2;
    final fMinLng = cx - adjLng * 0.6, fMaxLng = cx + adjLng * 0.6;
    final fMinLat = cy - adjLat * 0.6, fMaxLat = cy + adjLat * 0.6;
    final lngR = fMaxLng - fMinLng, latR = fMaxLat - fMinLat;

    for (final r in routes) {
      for (final s in r.stations) {
        if (s.hasLocation) {
          s.x = ((s.lng - fMinLng) / lngR).clamp(0.0, 1.0);
          s.y = (1.0 - (s.lat - fMinLat) / latR).clamp(0.0, 1.0);
        } else {
          s.x = 0.5;
          s.y = 0.5;
        }
      }
    }
  }

  void _handleTap(TapUpDetails details, Size sz) {
    final local = MatrixUtils.transformPoint(
      Matrix4.inverted(_txCtrl.value),
      details.localPosition,
    );
    final hr = 20.0 / _scale;
    int? br, bs;
    double md = double.infinity;
    for (int ri = 0; ri < _plotted.length; ri++) {
      if (!_plotted[ri].visible) continue;
      for (int si = 0; si < _plotted[ri].stations.length; si++) {
        final s = _plotted[ri].stations[si];
        if (!s.hasLocation) continue;
        final d = (local - Offset(s.x * sz.width, s.y * sz.height)).distance;
        if (d < hr && d < md) {
          md = d;
          br = ri;
          bs = si;
        }
      }
    }
    setState(() {
      if (br == _selRouteIdx && bs == _selStopIdx) {
        _selRouteIdx = _selStopIdx = null;
      } else {
        _selRouteIdx = br;
        _selStopIdx = bs;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark
          ? const Color(0xFF111111)
          : const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: const Text('线路走向图'),
        backgroundColor: isDark ? Colors.black : Colors.white,
        foregroundColor: cs.onSurface,
        elevation: 0,
      ),
      body: _loading
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('正在加载坐标数据…'),
                ],
              ),
            )
          : Column(
              children: [
                _buildLegend(isDark),
                Expanded(child: _buildMap()),
                if (_selRouteIdx != null && _selStopIdx != null)
                  _buildInfoCard(isDark, cs),
              ],
            ),
    );
  }

  Widget _buildLegend(bool isDark) => Container(
    color: isDark ? const Color(0xFF1A1A1A) : Colors.white,
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    child: SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: _plotted.map((r) {
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: GestureDetector(
              onTap: () => setState(() => r.visible = !r.visible),
              child: AnimatedOpacity(
                opacity: r.visible ? 1.0 : 0.4,
                duration: const Duration(milliseconds: 200),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: r.color.withAlpha(r.visible ? 30 : 15),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: r.color.withAlpha(r.visible ? 150 : 60),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: r.color,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        r.model.name,
                        style: TextStyle(
                          fontSize: 12,
                          color: r.color,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(
                        r.visible ? Icons.visibility : Icons.visibility_off,
                        size: 12,
                        color: r.color.withAlpha(180),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    ),
  );

  Widget _buildMap() {
    final surfaceColor = Theme.of(context).colorScheme.surface;
    return Center(
      child: AspectRatio(
        aspectRatio: 1.0,
        child: Container(
          constraints: const BoxConstraints(maxWidth: 480, maxHeight: 480),
          margin: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: surfaceColor,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withAlpha(30),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: LayoutBuilder(
              builder: (ctx, constraints) {
                final side = constraints.biggest.shortestSide;
                final sz = Size(side, side);
                return GestureDetector(
                  onTapUp: (d) => _handleTap(d, sz),
                  child: InteractiveViewer(
                    transformationController: _txCtrl,
                    minScale: 0.8,
                    maxScale: 8.0,
                    boundaryMargin: const EdgeInsets.all(80),
                    onInteractionUpdate: (_) {
                      final s = _txCtrl.value.getMaxScaleOnAxis();
                      if (s != _scale) setState(() => _scale = s);
                    },
                    child: CustomPaint(
                      size: sz,
                      painter: _RouteMapPainter(
                        routes: _plotted,
                        selRouteIdx: _selRouteIdx,
                        selStopIdx: _selStopIdx,
                        scale: _scale,
                        surfaceColor: surfaceColor,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInfoCard(bool isDark, ColorScheme cs) {
    final ri = _selRouteIdx!, si = _selStopIdx!;
    if (ri >= _plotted.length) return const SizedBox();
    final route = _plotted[ri];
    if (si >= route.stations.length) return const SizedBox();
    final s = route.stations[si];
    final isFirst = si == 0, isLast = si == route.stations.length - 1;

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: route.color.withAlpha(120), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(20),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: route.color.withAlpha(30),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                '${si + 1}',
                style: TextStyle(
                  color: route.color,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Text(
                      '${s.name}站',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(width: 6),
                    if (isFirst)
                      _rmBadge('起点', Colors.green)
                    else if (isLast)
                      _rmBadge('终点', Colors.red),
                  ],
                ),
                const SizedBox(height: 3),
                Row(
                  children: [
                    Text(
                      route.model.name,
                      style: TextStyle(
                        fontSize: 12,
                        color: route.color,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    if (s.city.isNotEmpty) ...[
                      Text(
                        ' · ',
                        style: TextStyle(
                          fontSize: 12,
                          color: cs.onSurface.withAlpha(100),
                        ),
                      ),
                      Text(
                        s.city,
                        style: TextStyle(
                          fontSize: 12,
                          color: cs.onSurface.withAlpha(140),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          if (!isLast && s.mileageToNext != null)
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '${s.mileageToNext} km',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: route.color,
                  ),
                ),
                Text(
                  '至下一站',
                  style: TextStyle(
                    fontSize: 10,
                    color: cs.onSurface.withAlpha(120),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _rmBadge(String text, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
    decoration: BoxDecoration(
      color: color.withAlpha(40),
      borderRadius: BorderRadius.circular(4),
      border: Border.all(color: color.withAlpha(120)),
    ),
    child: Text(
      text,
      style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.bold),
    ),
  );
}

// ─────────────────────────────────────────────────────────────
// CustomPainter
// ─────────────────────────────────────────────────────────────
class _RouteMapPainter extends CustomPainter {
  final List<_PlottedRoute> routes;
  final int? selRouteIdx;
  final int? selStopIdx;
  final double scale;
  final Color surfaceColor;

  const _RouteMapPainter({
    required this.routes,
    required this.selRouteIdx,
    required this.selStopIdx,
    required this.scale,
    required this.surfaceColor,
  });

  double _px(double v) => v / scale;

  @override
  void paint(Canvas canvas, Size size) {
    for (int ri = 0; ri < routes.length; ri++) {
      final r = routes[ri];
      if (!r.visible) continue;
      _drawLine(canvas, size, r, ri == selRouteIdx);
    }
    for (int ri = 0; ri < routes.length; ri++) {
      final r = routes[ri];
      if (!r.visible) continue;
      _drawStops(canvas, size, r, ri);
    }
    if (selRouteIdx != null && selStopIdx != null) {
      _drawLabel(canvas, size, selRouteIdx!, selStopIdx!);
    }
  }

  void _drawLine(Canvas canvas, Size size, _PlottedRoute r, bool isSelected) {
    final valid = r.stations.where((s) => s.hasLocation).toList();
    if (valid.length < 2) return;
    final paint = Paint()
      ..color = isSelected ? r.color : r.color.withAlpha(180)
      ..strokeWidth = _px(isSelected ? 3.5 : 2.5)
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final path = Path()
      ..moveTo(valid.first.x * size.width, valid.first.y * size.height);
    for (int i = 1; i < valid.length; i++) {
      path.lineTo(valid[i].x * size.width, valid[i].y * size.height);
    }
    canvas.drawPath(path, paint);
  }

  void _drawStops(Canvas canvas, Size size, _PlottedRoute r, int routeIdx) {
    final baseR = _px(6.0);
    for (int si = 0; si < r.stations.length; si++) {
      final s = r.stations[si];
      if (!s.hasLocation) continue;
      final isSel = routeIdx == selRouteIdx && si == selStopIdx;
      final markerR = isSel ? _px(9.0) : baseR;
      final c = Offset(s.x * size.width, s.y * size.height);
      if (isSel) {
        canvas.drawCircle(
          c,
          markerR + _px(4),
          Paint()..color = r.color.withAlpha(50),
        );
      }
      canvas.drawCircle(c, markerR, Paint()..color = r.color);
      canvas.drawCircle(
        c,
        markerR,
        Paint()
          ..color = Colors.white
          ..style = PaintingStyle.stroke
          ..strokeWidth = _px(2.0),
      );
      final tp = TextPainter(
        text: TextSpan(
          text: '${si + 1}',
          style: TextStyle(
            color: Colors.white,
            fontSize: _px(6.5),
            fontWeight: FontWeight.bold,
            height: 1.0,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, c - Offset(tp.width / 2, tp.height / 2));
    }
  }

  void _drawLabel(Canvas canvas, Size size, int ri, int si) {
    if (ri >= routes.length) return;
    final r = routes[ri];
    if (si >= r.stations.length) return;
    final s = r.stations[si];
    if (!s.hasLocation) return;

    final cx = s.x * size.width, cy = s.y * size.height;
    final sub = r.model.name + (s.city.isNotEmpty ? ' · ${s.city}' : '');
    final mileStr = (si < r.stations.length - 1 && s.mileageToNext != null)
        ? '至下站 ${s.mileageToNext} km'
        : null;

    final fs = _px(11.0), fsS = _px(9.5);
    final nameTp = _tp('${s.name}站', fs, Colors.black87, bold: true);
    final subTp = _tp(sub, fsS, r.color);
    final mileTp = mileStr != null ? _tp(mileStr, fsS, Colors.black54) : null;

    final padH = _px(8.0), padV = _px(5.0), gap = _px(3.0);
    double cw = max(nameTp.width, subTp.width);
    if (mileTp != null) cw = max(cw, mileTp.width);
    double ch = nameTp.height + gap + subTp.height;
    if (mileTp != null) ch += gap + mileTp.height;

    final lw = cw + padH * 2, lh = ch + padV * 2, mg = _px(10.0);
    final candidates = [
      Offset(cx + mg, cy - lh / 2),
      Offset(cx - lw - mg, cy - lh / 2),
      Offset(cx - lw / 2, cy - lh - mg),
      Offset(cx - lw / 2, cy + mg),
    ];
    Offset pos = candidates.first;
    for (final p in candidates) {
      if (p.dx >= 0 &&
          p.dx + lw <= size.width &&
          p.dy >= 0 &&
          p.dy + lh <= size.height) {
        pos = p;
        break;
      }
    }
    pos = Offset(
      pos.dx.clamp(0.0, size.width - lw),
      pos.dy.clamp(0.0, size.height - lh),
    );

    final rr = RRect.fromLTRBR(
      pos.dx,
      pos.dy,
      pos.dx + lw,
      pos.dy + lh,
      Radius.circular(_px(6)),
    );
    canvas.drawRRect(rr, Paint()..color = Colors.white.withAlpha(240));
    canvas.drawRRect(
      rr,
      Paint()
        ..color = r.color.withAlpha(180)
        ..style = PaintingStyle.stroke
        ..strokeWidth = _px(1.2),
    );

    double tx = pos.dx + padH, ty = pos.dy + padV;
    nameTp.paint(canvas, Offset(tx, ty));
    ty += nameTp.height + gap;
    subTp.paint(canvas, Offset(tx, ty));
    if (mileTp != null) {
      ty += subTp.height + gap;
      mileTp.paint(canvas, Offset(tx, ty));
    }
  }

  TextPainter _tp(
    String text,
    double fontSize,
    Color color, {
    bool bold = false,
  }) {
    return TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          fontSize: fontSize,
          color: color,
          fontWeight: bold ? FontWeight.bold : FontWeight.normal,
          height: 1.2,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
  }

  @override
  bool shouldRepaint(_RouteMapPainter old) =>
      old.routes != routes ||
      old.selRouteIdx != selRouteIdx ||
      old.selStopIdx != selStopIdx ||
      old.scale != scale;
}
