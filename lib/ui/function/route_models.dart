// ui/function/route_models.dart
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

class PaginatedController<T> {
  final int pageSize;

  PaginatedController({this.pageSize = 10});

  List<T> _allItems = [];
  List<T> _pagedItems = [];
  int _currentPage = 1;
  bool isLoading = false;

  List<T> get allItems => _allItems;

  List<T> get items => _pagedItems;

  int get currentPage => _currentPage;

  int get totalPages =>
      _allItems.isEmpty ? 1 : (_allItems.length / pageSize).ceil();

  int get totalCount => _allItems.length;

  bool get hasMultiplePages => totalPages > 1;

  List<T> get currentPageItems => _pagedItems;

  void resetAndLoad(List<T> allItems) {
    _allItems = allItems;
    _currentPage = 1;
    loadPage(1);
  }

  void loadPage(int page) {
    if (page < 1 || page > totalPages) return;
    isLoading = true;
    final start = (page - 1) * pageSize;
    final end = (start + pageSize).clamp(0, _allItems.length);
    _pagedItems = _allItems.sublist(start, end);
    _currentPage = page;
    isLoading = false;
  }

  void goToPage(int page, VoidCallback onUpdate) {
    if (page == _currentPage || isLoading) return;
    loadPage(page);
    onUpdate();
  }

  void clear() {
    _allItems.clear();
    _pagedItems.clear();
    _currentPage = 1;
  }
}

// ═════════════════════════════════════════════════════════════
// 数据模型
// ═════════════════════════════════════════════════════════════

class RouteStation {
  final String name;
  final String telecode;
  final String city;
  final double? mileageToNext;

  const RouteStation({
    required this.name,
    required this.telecode,
    required this.city,
    this.mileageToNext,
  });

  RouteStation copyWith({String? name, String? city}) => RouteStation(
    name: name ?? this.name,
    telecode: telecode,
    city: city ?? this.city,
    mileageToNext: mileageToNext,
  );

  Map<String, dynamic> toJson() => {
    'tel': telecode,
    if (mileageToNext != null) 'mile': mileageToNext,
  };

  factory RouteStation.fromJson(Map<String, dynamic> j) => RouteStation(
    name: j['name'] as String? ?? '',
    telecode: (j['tel'] ?? j['telecode']) as String? ?? '',
    city: j['city'] as String? ?? '',
    mileageToNext: ((j['mile'] ?? j['mileageToNext']) as num?)?.toDouble(),
  );
}

class RouteModel {
  final String id;
  final String name;
  final String author; // 新增：作者
  final String icon; // 新增：图标路径
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<RouteStation> stations;

  const RouteModel({
    required this.id,
    required this.name,
    required this.author, // 新增
    required this.icon, // 新增
    required this.createdAt,
    required this.updatedAt,
    required this.stations,
  });

  RouteModel copyWith({
    String? name,
    String? author, // 新增
    String? icon, // 新增
    List<RouteStation>? stations,
  }) => RouteModel(
    id: id,
    name: name ?? this.name,
    author: author ?? this.author,
    // 新增
    icon: icon ?? this.icon,
    // 新增
    createdAt: createdAt,
    updatedAt: updatedAt,
    stations: stations ?? this.stations,
  );

  // 静态方法：创建空对象
  static RouteModel createEmpty() => RouteModel(
    id: 'route_${DateTime.now().millisecondsSinceEpoch}',
    name: '未命名线路',
    author: '',
    icon: 'train/cr400bf.png',
    // 默认图标
    createdAt: DateTime.now(),
    updatedAt: DateTime.now(),
    stations: [],
  );

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
    'author': author, // 新增
    'icon': icon, // 新增
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
    'stations': stations.map((s) => s.toJson()).toList(),
  };

  factory RouteModel.fromJson(Map<String, dynamic> j) => RouteModel(
    id: j['id'] as String? ?? '',
    name: j['name'] as String? ?? '未命名线路',
    author: j['author'] as String? ?? '',
    // 新增，兼容旧格式
    icon: j['icon'] as String? ?? 'train/cr400bf.png',
    // 新增，兼容旧格式
    createdAt: j['createdAt'] != null
        ? DateTime.tryParse(j['createdAt'] as String) ?? DateTime.now()
        : DateTime.now(),
    updatedAt: j['updatedAt'] != null
        ? DateTime.tryParse(j['updatedAt'] as String) ?? DateTime.now()
        : DateTime.now(),
    stations: (j['stations'] as List<dynamic>? ?? [])
        .map((e) => RouteStation.fromJson(Map<String, dynamic>.from(e)))
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
      list.sort((a, b) {
        // id 格式: route_<timestamp>，直接比较字符串即可（数字越大越新）
        final ta = int.tryParse(a.id.replaceFirst('route_', '')) ?? 0;
        final tb = int.tryParse(b.id.replaceFirst('route_', '')) ?? 0;
        return tb.compareTo(ta);
      });
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
// 内部编辑模型（供 RoutePage 使用）
// ═════════════════════════════════════════════════════════════

class EditableRouteStation {
  String name;
  String telecode;
  String city;
  double? mileageToNext;

  EditableRouteStation({
    required this.name,
    required this.telecode,
    required this.city,
    this.mileageToNext,
  });
}

// ═════════════════════════════════════════════════════════════
// 共享小组件
// ═════════════════════════════════════════════════════════════

/// 通用操作菜单 Chip
class RhMenuChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const RhMenuChip({
    super.key,
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

/// 分页控制栏（RouteHubPage 和其他页面复用）
class PagerBar extends StatelessWidget {
  final int currentPage;
  final int totalPages;
  final int totalCount;
  final bool isDark;
  final ColorScheme cs;
  final void Function(int page) onPage;

  const PagerBar({
    super.key,
    required this.currentPage,
    required this.totalPages,
    required this.totalCount,
    required this.isDark,
    required this.cs,
    required this.onPage,
  });

  List<int> _pages() {
    if (totalPages <= 5) return List.generate(totalPages, (i) => i + 1);
    final cur = currentPage;
    final pages = <int>[1];
    if (cur > 3) pages.add(-1);
    for (int p = max(2, cur - 1); p <= min(totalPages - 1, cur + 1); p++) {
      pages.add(p);
    }
    if (cur < totalPages - 2) pages.add(-1);
    pages.add(totalPages);
    return pages;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: isDark ? const Color(0xFF1A1A1A) : Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left),
            onPressed: currentPage > 1 ? () => onPage(currentPage - 1) : null,
            visualDensity: VisualDensity.compact,
          ),
          ..._pages().map((p) {
            if (p == -1) {
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: Text(
                  '…',
                  style: TextStyle(color: cs.onSurface.withAlpha(120)),
                ),
              );
            }
            final isActive = p == currentPage;
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: InkWell(
                onTap: () => onPage(p),
                borderRadius: BorderRadius.circular(6),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: isActive ? cs.primary : Colors.transparent,
                    borderRadius: BorderRadius.circular(6),
                    border: isActive
                        ? null
                        : Border.all(color: cs.onSurface.withAlpha(40)),
                  ),
                  child: Center(
                    child: Text(
                      '$p',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: isActive
                            ? FontWeight.bold
                            : FontWeight.normal,
                        color: isActive
                            ? cs.onPrimary
                            : cs.onSurface.withAlpha(180),
                      ),
                    ),
                  ),
                ),
              ),
            );
          }),
          IconButton(
            icon: const Icon(Icons.chevron_right),
            onPressed: currentPage < totalPages
                ? () => onPage(currentPage + 1)
                : null,
            visualDensity: VisualDensity.compact,
          ),
          const SizedBox(width: 8),
          Text(
            '共 $totalCount 条',
            style: TextStyle(fontSize: 12, color: cs.onSurface.withAlpha(140)),
          ),
        ],
      ),
    );
  }
}
