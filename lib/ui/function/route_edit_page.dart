// ui/function/route_edit_page.dart
// ─────────────────────────────────────────────────────────────
// 新建 / 编辑线路页面 — 站点数量无限制
// ─────────────────────────────────────────────────────────────
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../station_selector.dart';
import 'route_models.dart';

class RoutePage extends StatefulWidget {
  final RouteModel? existing;

  const RoutePage({super.key, this.existing});

  @override
  State<RoutePage> createState() => _RoutePageState();
}

class _RoutePageState extends State<RoutePage> {
  final _nameCtrl = TextEditingController();
  final List<EditableRouteStation> _stations = [];
  bool _saving = false;

  // 站点数量无限制（原来为 20）

  @override
  void initState() {
    super.initState();
    if (widget.existing != null) {
      _nameCtrl.text = widget.existing!.name;
      _stations.addAll(
        widget.existing!.stations.map(
          (s) => EditableRouteStation(
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
        EditableRouteStation(
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
          crossAxisAlignment: CrossAxisAlignment.stretch,
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
            crossAxisAlignment: CrossAxisAlignment.stretch,
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
                    RhMenuChip(
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
                  RhMenuChip(
                    icon: Icons.delete_outline,
                    label: '删除',
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
      crossAxisAlignment: CrossAxisAlignment.stretch,
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
                '${_stations.length} 站',
                style: TextStyle(
                  fontSize: 13,
                  color: cs.onSurface.withAlpha(140),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        if (_stations.isEmpty)
          _emptyHint(isDark)
        else
          _buildStationList(isDark, cs),
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

  Widget _buildStationList(bool isDark, ColorScheme cs) {
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
    final isFirst = idx == 0;
    final isLast = idx == _stations.length - 1;
    final isBoth = isFirst && isLast;
    final hasMileage = s.mileageToNext != null;

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
                        width: isFirst || isLast ? 16 : 12,
                        height: isFirst || isLast ? 16 : 12,
                        decoration: BoxDecoration(
                          color: isBoth
                              ? Colors.orange
                              : isFirst
                              ? Colors.green
                              : isLast
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
                                fontWeight: isFirst || isLast
                                    ? FontWeight.bold
                                    : FontWeight.w500,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 6),
                          if (isBoth) ...[
                            _badge('起点', Colors.green),
                            const SizedBox(width: 4),
                            _badge('终点', Colors.red),
                          ] else if (isFirst)
                            _badge('起点', Colors.green)
                          else if (isLast)
                            _badge('终点', Colors.red),
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
        crossAxisAlignment: CrossAxisAlignment.stretch,
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
