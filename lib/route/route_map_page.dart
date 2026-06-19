// ui/function/route_map_page.dart

import 'dart:math';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config/station_selector.dart'; // loadStations()
import 'route_models.dart';

const String _routeMapMileageFallbackKey = 'route_map_mileage_fallback';

Color _colorForRouteId(String id) {
  int hash = 0;
  for (final c in id.codeUnits) {
    hash = (hash * 31 + c) & 0xFFFFFFFF;
  }
  const phi = 0.6180339887;
  final hue = ((hash & 0xFFFF) / 0xFFFF + phi * (hash >> 16)) % 1.0;
  return HSLColor.fromAHSL(1.0, hue * 360, 0.72, 0.48).toColor();
}

class _PlottedStation {
  final String name;
  final String city;
  final double? mileageToNext;
  bool hasLocation;
  bool isInferredLocation = false;
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

// ═════════════════════════════════════════════════════════════
// RouteMapPage
// ═════════════════════════════════════════════════════════════

class RouteMapPage extends StatefulWidget {
  final List<RouteModel> routes;

  const RouteMapPage({super.key, required this.routes});

  @override
  State<RouteMapPage> createState() => _RouteMapPageState();
}

class _RouteMapPageState extends State<RouteMapPage> {
  List<_PlottedRoute> _plotted = [];
  bool _loading = true;
  bool _showStationNumbers = true;

  // 命中的站点列表（支持多线路共站）
  List<({int ri, int si})> _selHits = [];
  final TransformationController _txCtrl = TransformationController();
  double _scale = 1.0;
  double _maxScale = 12.0;

  // 底部面板控制器
  final DraggableScrollableController _draggableCtrl =
      DraggableScrollableController();

  @override
  void initState() {
    super.initState();
    // 监听变换矩阵的每一帧变化（包含惯性动画），确保叠加层始终跟随
    _txCtrl.addListener(_onTransformChanged);
    _loadAndPlot();
  }

  void _onTransformChanged() {
    final s = _txCtrl.value.getMaxScaleOnAxis();
    if ((s - _scale).abs() > 0.001) {
      // scale 有变化，同时更新 _scale
      setState(() => _scale = s);
    } else {
      // 纯平移：scale 不变，但 transform 变了，叠加层需要跟随
      setState(() {});
    }
  }

  @override
  void dispose() {
    _txCtrl.removeListener(_onTransformChanged);
    _txCtrl.dispose();
    _draggableCtrl.dispose();
    super.dispose();
  }

  // ── 数据加载 ─────────────────────────────────────────────────

  Future<void> _loadAndPlot() async {
    final prefs = await SharedPreferences.getInstance();
    final useMileageFallback =
        prefs.getBool(_routeMapMileageFallbackKey) ?? true;
    final allStations = await loadStations();
    final Map<String, Map<String, dynamic>> tcIdx = {};
    for (final s in allStations) {
      final tc = (s['telecode'] as String? ?? '').trim();
      if (tc.isEmpty) continue;
      final loc = (s['location'] as String? ?? '');
      final parts = loc.split(',');
      if (parts.length == 2) {
        final lng = double.tryParse(parts[0]);
        final lat = double.tryParse(parts[1]);
        if (lng != null && lat != null) {
          tcIdx[tc] = {
            'name': (s['name'] as String? ?? '').replaceAll('站', '').trim(),
            'lng': lng,
            'lat': lat,
            'city': s['city'] as String? ?? '',
          };
        }
      }
    }

    final List<_PlottedRoute> raw = [];
    for (final r in widget.routes) {
      final color = _colorForRouteId(r.id);
      final stations = r.stations.map((s) {
        final info = tcIdx[s.telecode];
        return _PlottedStation(
          name: info?['name'] as String? ?? s.name.replaceAll('站', '').trim(),
          city: info?['city'] as String? ?? s.city,
          mileageToNext: s.mileageToNext,
          hasLocation: info != null,
          lng: (info?['lng'] as double?) ?? 0,
          lat: (info?['lat'] as double?) ?? 0,
        );
      }).toList();
      raw.add(_PlottedRoute(model: r, stations: stations, color: color));
    }

    _normalizeAll(raw, inferMissingLocations: useMileageFallback);
    final maxScale = _computeMaxScale(raw);
    setState(() {
      _plotted = raw;
      _loading = false;
      _maxScale = maxScale;
    });
  }

  double _computeMaxScale(List<_PlottedRoute> routes) {
    double minSpan = double.infinity;
    for (final r in routes) {
      final valid = r.stations.where((s) => s.hasLocation).toList();
      if (valid.length < 2) continue;
      double minX = double.infinity, maxX = -double.infinity;
      double minY = double.infinity, maxY = -double.infinity;
      for (final s in valid) {
        minX = min(minX, s.x);
        maxX = max(maxX, s.x);
        minY = min(minY, s.y);
        maxY = max(maxY, s.y);
      }
      final span = max(maxX - minX, maxY - minY);
      if (span > 0.01) minSpan = min(minSpan, span);
    }
    if (minSpan == double.infinity || minSpan <= 0) return 12.0;
    final scale = (1.0 / minSpan) * 1.5;
    return scale.clamp(8.0, 40.0);
  }

  void _normalizeAll(
    List<_PlottedRoute> routes, {
    required bool inferMissingLocations,
  }) {
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

    if (inferMissingLocations) {
      for (final r in routes) {
        _inferMissingStationLocations(r);
      }
    }
  }

  void _inferMissingStationLocations(_PlottedRoute route) {
    final stations = route.stations;
    for (int i = 0; i < stations.length; i++) {
      final station = stations[i];
      if (station.hasLocation) continue;

      final prevIdx = _nearestExactLocationBefore(stations, i);
      final nextIdx = _nearestExactLocationAfter(stations, i);
      if (prevIdx == null || nextIdx == null) continue;

      final totalMileage = _sumMileage(stations, prevIdx, nextIdx);
      final offsetMileage = _sumMileage(stations, prevIdx, i);
      if (totalMileage == null ||
          offsetMileage == null ||
          totalMileage <= 0 ||
          offsetMileage < 0) {
        continue;
      }

      final ratio = (offsetMileage / totalMileage).clamp(0.0, 1.0);
      final prev = stations[prevIdx];
      final next = stations[nextIdx];
      station.x = prev.x + (next.x - prev.x) * ratio;
      station.y = prev.y + (next.y - prev.y) * ratio;
      station.hasLocation = true;
      station.isInferredLocation = true;
    }
  }

  int? _nearestExactLocationBefore(List<_PlottedStation> stations, int index) {
    for (int i = index - 1; i >= 0; i--) {
      if (stations[i].hasLocation && !stations[i].isInferredLocation) {
        return i;
      }
    }
    return null;
  }

  int? _nearestExactLocationAfter(List<_PlottedStation> stations, int index) {
    for (int i = index + 1; i < stations.length; i++) {
      if (stations[i].hasLocation && !stations[i].isInferredLocation) {
        return i;
      }
    }
    return null;
  }

  double? _sumMileage(
    List<_PlottedStation> stations,
    int startIndex,
    int endIndex,
  ) {
    if (startIndex >= endIndex) return 0;
    double total = 0;
    for (int i = startIndex; i < endIndex; i++) {
      final mileage = stations[i].mileageToNext;
      if (mileage == null || mileage < 0) return null;
      total += mileage;
    }
    return total;
  }

  // ── 点击处理 ─────────────────────────────────────────────────

  void _handleTap(TapUpDetails details, Size sz) {
    // details.localPosition 已经是 canvas 坐标系（InteractiveViewer 内的
    // Transform 在 hit-test 时会将全局坐标逆变换后再传给子 widget），
    // 不需要也不能再对其应用 Matrix4.inverted(_txCtrl.value)，否则会双重逆变换。
    final local = details.localPosition;
    final hr = 20.0 / _scale;

    final hits = <({int ri, int si, double d})>[];
    for (int ri = 0; ri < _plotted.length; ri++) {
      if (!_plotted[ri].visible) continue;
      for (int si = 0; si < _plotted[ri].stations.length; si++) {
        final s = _plotted[ri].stations[si];
        if (!s.hasLocation) continue;
        final d = (local - Offset(s.x * sz.width, s.y * sz.height)).distance;
        if (d < hr) hits.add((ri: ri, si: si, d: d));
      }
    }

    if (hits.isEmpty) {
      setState(() => _selHits = []);
      return;
    }

    hits.sort((a, b) => a.d.compareTo(b.d));
    final nearest = _plotted[hits.first.ri].stations[hits.first.si];
    final grouped = hits
        .where((h) {
          final s = _plotted[h.ri].stations[h.si];
          return (Offset(s.x, s.y) - Offset(nearest.x, nearest.y)).distance <
              (hr * 1.5) / sz.shortestSide;
        })
        .map((h) => (ri: h.ri, si: h.si))
        .toList();

    setState(() {
      final same =
          _selHits.length == grouped.length &&
          _selHits.every(
            (a) => grouped.any((b) => b.ri == a.ri && b.si == a.si),
          );
      _selHits = same ? [] : grouped;
    });
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
        title: Row(
          children: [
            const Text('线路走向图'),
            const Spacer(),
            IconButton(
              icon: Icon(
                _showStationNumbers
                    ? Icons.confirmation_number
                    : Icons.confirmation_number_outlined,
                size: 20,
              ),
              tooltip: _showStationNumbers ? '隐藏车站序号' : '显示车站序号',
              onPressed: () {
                setState(() {
                  _showStationNumbers = !_showStationNumbers;
                });
              },
            ),
          ],
        ),
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
          : Stack(
              children: [
                Column(
                  children: [
                    _buildLegend(isDark),
                    Expanded(child: _buildMap()),
                    const SizedBox(height: 0),
                  ],
                ),
                if (_selHits.isNotEmpty)
                  DraggableScrollableSheet(
                    controller: _draggableCtrl,
                    initialChildSize: 0.32,
                    minChildSize: 0.10,
                    maxChildSize: 0.70,
                    snap: true,
                    snapSizes: const [0.10, 0.32, 0.70],
                    builder: (ctx, scrollCtrl) =>
                        _buildDraggablePanel(isDark, cs, scrollCtrl),
                  ),
              ],
            ),
    );
  }

  // ── 图例 ─────────────────────────────────────────────────────

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
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            r.model.name,
                            style: TextStyle(
                              fontSize: 12,
                              color: r.color,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          if (r.stations.length >= 2)
                            Text(
                              '${r.stations.first.name} → ${r.stations.last.name}',
                              style: TextStyle(
                                fontSize: 10,
                                color: r.color.withAlpha(170),
                              ),
                            ),
                        ],
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

  // ── 地图（全页铺满） ─────────────────────────────────────────

  Widget _buildMap() {
    final surfaceColor = Theme.of(context).colorScheme.surface;
    return LayoutBuilder(
      builder: (ctx, constraints) {
        final sz = constraints.biggest;
        return Stack(
          children: [
            Positioned.fill(child: ColoredBox(color: surfaceColor)),
            // 交互式地图层
            InteractiveViewer(
              transformationController: _txCtrl,
              minScale: 0.5,
              maxScale: _maxScale,
              boundaryMargin: const EdgeInsets.all(100),
              child: GestureDetector(
                onTapUp: (d) => _handleTap(d, sz),
                child: CustomPaint(
                  size: sz,
                  painter: _RouteMapPainter(
                    routes: _plotted,
                    selHits: _selHits,
                    scale: _scale,
                    surfaceColor: surfaceColor,
                  ),
                ),
              ),
            ),
            // ── 站点序号叠加层（Widget 渲染）────────
            if (_showStationNumbers)
              ClipRect(
                child: IgnorePointer(
                child: SizedBox.expand(
                  child: CustomMultiChildLayout(
                    delegate: _NumberOverlayDelegate(
                      routes: _plotted,
                      transform: _txCtrl.value,
                      canvasSize: sz,
                      scale: _scale,
                    ),
                    children: [
                      for (int ri = 0; ri < _plotted.length; ri++)
                        if (_plotted[ri].visible)
                          for (
                            int si = 0;
                            si < _plotted[ri].stations.length;
                            si++
                          )
                            if (_plotted[ri].stations[si].hasLocation)
                              LayoutId(
                                id: '$ri-$si',
                                child: Text(
                                  '${si + 1}',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 9,
                                    fontWeight: FontWeight.bold,
                                    height: 1.0,
                                  ),
                                ),
                              ),
                    ],
                  ),
                ),
                ),
              ),
            // Flutter Widget label 叠加层（不模糊，永远清晰）
            if (_selHits.isNotEmpty)
              IgnorePointer(
                child: SizedBox.expand(
                  child: CustomMultiChildLayout(
                    delegate: _LabelLayoutDelegate(
                      hits: _selHits,
                      routes: _plotted,
                      transform: _txCtrl.value,
                      canvasSize: sz,
                    ),
                    children: _selHits.asMap().entries.map((e) {
                      final idx = e.key;
                      final h = e.value;
                      if (h.ri >= _plotted.length) {
                        return LayoutId(id: idx, child: const SizedBox());
                      }
                      final route = _plotted[h.ri];
                      if (h.si >= route.stations.length) {
                        return LayoutId(id: idx, child: const SizedBox());
                      }
                      final s = route.stations[h.si];
                      final mileStr =
                          (h.si < route.stations.length - 1 &&
                              s.mileageToNext != null)
                          ? '至下站 ${s.mileageToNext} km'
                          : null;
                      return LayoutId(
                        id: idx,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 7,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withAlpha(245),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: route.color.withAlpha(200),
                              width: 1.5,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withAlpha(40),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                '${s.name}站',
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black87,
                                  height: 1.2,
                                ),
                              ),
                              Text(
                                route.model.name +
                                    (s.city.isNotEmpty ? ' · ${s.city}' : ''),
                                style: TextStyle(
                                  fontSize: 11,
                                  color: route.color,
                                  height: 1.2,
                                ),
                              ),
                              if (s.isInferredLocation)
                                const Text(
                                  '里程估算位置',
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: Colors.orange,
                                    height: 1.2,
                                  ),
                                ),
                              if (mileStr != null)
                                Text(
                                  mileStr,
                                  style: const TextStyle(
                                    fontSize: 10,
                                    color: Colors.black54,
                                    height: 1.2,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  // ── 多线路信息卡片（支持共站） ───────────────────────────────

  Widget _buildInfoCards(bool isDark, ColorScheme cs) {
    if (_selHits.isEmpty) return const SizedBox();
    final firstName = () {
      final h = _selHits.first;
      if (h.ri < _plotted.length && h.si < _plotted[h.ri].stations.length) {
        return '${_plotted[h.ri].stations[h.si].name}站';
      }
      return '';
    }();

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (_selHits.length > 1 && firstName.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 6),
            child: Row(
              children: [
                const Icon(Icons.place, size: 14, color: Colors.grey),
                const SizedBox(width: 4),
                Text(
                  firstName,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey,
                  ),
                ),
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 1,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.orange.withAlpha(40),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.orange.withAlpha(120)),
                  ),
                  child: Text(
                    '${_selHits.length} 线路经过',
                    style: const TextStyle(
                      fontSize: 11,
                      color: Colors.orange,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ..._selHits.map((h) => _buildOneCard(h.ri, h.si, isDark, cs)),
      ],
    );
  }

  // ── 可拖动底部面板 ───────────────────────────────────────────

  Widget _buildDraggablePanel(
    bool isDark,
    ColorScheme cs,
    ScrollController scrollCtrl,
  ) {
    final bgColor = isDark ? const Color(0xFF1A1A1A) : Colors.white;

    final firstName = () {
      final h = _selHits.first;
      if (h.ri < _plotted.length && h.si < _plotted[h.ri].stations.length) {
        return '${_plotted[h.ri].stations[h.si].name}站';
      }
      return '';
    }();

    final totalHits = _selHits.length;

    return Container(
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(50),
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: ListView(
        controller: scrollCtrl,
        padding: EdgeInsets.zero,
        children: [
          GestureDetector(
            onTap: () {
              final cur = _draggableCtrl.size;
              _draggableCtrl.animateTo(
                cur < 0.20 ? 0.32 : 0.10,
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeOut,
              );
            },
            child: Container(
              color: Colors.transparent,
              padding: const EdgeInsets.only(top: 10, bottom: 6),
              child: Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: cs.onSurface.withAlpha(80),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 8),
            child: Row(
              children: [
                const Icon(Icons.place, size: 16, color: Colors.grey),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    firstName,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (totalHits > 1)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.orange.withAlpha(40),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.orange.withAlpha(120)),
                    ),
                    child: Text(
                      '$totalHits 线路经过',
                      style: const TextStyle(
                        fontSize: 11,
                        color: Colors.orange,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: () => setState(() => _selHits = []),
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: cs.onSurface.withAlpha(20),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.close,
                      size: 16,
                      color: cs.onSurface.withAlpha(160),
                    ),
                  ),
                ),
              ],
            ),
          ),
          ..._selHits.map((h) => _buildOneCard(h.ri, h.si, isDark, cs)),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildOneCard(int ri, int si, bool isDark, ColorScheme cs) {
    if (ri >= _plotted.length) return const SizedBox();
    final route = _plotted[ri];
    if (si >= route.stations.length) return const SizedBox();
    final s = route.stations[si];
    final isFirst = si == 0;
    final isLast = si == route.stations.length - 1;
    final isBoth = isFirst && isLast;
    final originName = route.stations.isNotEmpty
        ? '${route.stations.first.name}站'
        : '';
    final termName = route.stations.length > 1
        ? '${route.stations.last.name}站'
        : '';

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: route.color.withAlpha(150), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(18),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: route.color,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                route.model.name,
                style: TextStyle(
                  fontSize: 12,
                  color: route.color,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (originName.isNotEmpty && termName.isNotEmpty) ...[
                const SizedBox(width: 6),
                Container(
                  width: 6,
                  height: 6,
                  decoration: const BoxDecoration(
                    color: Colors.green,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 3),
                Text(
                  originName,
                  style: TextStyle(fontSize: 11, color: Colors.green.shade700),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 3),
                  child: Icon(
                    Icons.arrow_forward,
                    size: 10,
                    color: route.color.withAlpha(140),
                  ),
                ),
                Container(
                  width: 6,
                  height: 6,
                  decoration: const BoxDecoration(
                    color: Colors.red,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 3),
                Expanded(
                  child: Text(
                    termName,
                    style: TextStyle(fontSize: 11, color: Colors.red.shade700),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
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
                      fontSize: 13,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            '${s.name}站',
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
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
                        if (s.isInferredLocation) ...[
                          const SizedBox(width: 4),
                          _badge('里程估算', Colors.orange),
                        ],
                      ],
                    ),
                    if (s.city.isNotEmpty)
                      Text(
                        s.city,
                        style: TextStyle(
                          fontSize: 11,
                          color: cs.onSurface.withAlpha(140),
                        ),
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
                        fontSize: 13,
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
        ],
      ),
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
}

// ═════════════════════════════════════════════════════════════
// CustomPainter
// ═════════════════════════════════════════════════════════════

class _RouteMapPainter extends CustomPainter {
  final List<_PlottedRoute> routes;
  final List<({int ri, int si})> selHits;
  final double scale;
  final Color surfaceColor;

  const _RouteMapPainter({
    required this.routes,
    required this.selHits,
    required this.scale,
    required this.surfaceColor,
  });

  double _px(double v) => v / scale;

  @override
  void paint(Canvas canvas, Size size) {
    final selRouteIdxs = selHits.map((h) => h.ri).toSet();
    for (int ri = 0; ri < routes.length; ri++) {
      final r = routes[ri];
      if (!r.visible) continue;
      _drawLine(canvas, size, r, selRouteIdxs.contains(ri));
    }
    for (int ri = 0; ri < routes.length; ri++) {
      final r = routes[ri];
      if (!r.visible) continue;
      _drawStops(canvas, size, r, ri);
    }
    // 序号由 _NumberOverlayDelegate Widget 层渲染，不在此绘制
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
      final isSel = selHits.any((h) => h.ri == routeIdx && h.si == si);
      final markerR = isSel
          ? _px(9.0)
          : s.isInferredLocation
          ? _px(5.0)
          : baseR;
      final c = Offset(s.x * size.width, s.y * size.height);
      if (isSel) {
        canvas.drawCircle(
          c,
          markerR + _px(4),
          Paint()..color = r.color.withAlpha(50),
        );
      }
      canvas.drawCircle(
        c,
        markerR,
        Paint()
          ..color = s.isInferredLocation ? r.color.withAlpha(150) : r.color,
      );
      canvas.drawCircle(
        c,
        markerR,
        Paint()
          ..color = Colors.white
          ..style = PaintingStyle.stroke
          ..strokeWidth = _px(2.0),
      );
      // 序号不在此绘制，由 Widget 叠加层负责
    }
  }

  @override
  bool shouldRepaint(_RouteMapPainter old) =>
      old.routes != routes || old.selHits != selHits || old.scale != scale;
}

// ═════════════════════════════════════════════════════════════
// 站点序号叠加层 delegate（Widget 渲染，永远清晰不模糊）
// ═════════════════════════════════════════════════════════════

class _NumberOverlayDelegate extends MultiChildLayoutDelegate {
  final List<_PlottedRoute> routes;
  final Matrix4 transform;
  final Size canvasSize;
  final double scale;

  _NumberOverlayDelegate({
    required this.routes,
    required this.transform,
    required this.canvasSize,
    required this.scale,
  });

  @override
  void performLayout(Size size) {
    for (int ri = 0; ri < routes.length; ri++) {
      final r = routes[ri];
      if (!r.visible) continue;
      for (int si = 0; si < r.stations.length; si++) {
        final s = r.stations[si];
        if (!s.hasLocation) continue;
        final id = '$ri-$si';
        if (!hasChild(id)) continue;

        final canvasPt = Offset(
          s.x * canvasSize.width,
          s.y * canvasSize.height,
        );
        final screenPt = MatrixUtils.transformPoint(transform, canvasPt);

        final childSize = layoutChild(
          id,
          BoxConstraints.loose(const Size(32, 32)),
        );
        positionChild(
          id,
          Offset(
            screenPt.dx - childSize.width / 2,
            screenPt.dy - childSize.height / 2,
          ),
        );
      }
    }
  }

  @override
  bool shouldRelayout(_NumberOverlayDelegate old) =>
      old.transform.storage.toString() != transform.storage.toString() ||
      old.routes != routes ||
      old.scale != scale;
}

// ═════════════════════════════════════════════════════════════
// Label overlay layout delegate
// ═════════════════════════════════════════════════════════════

class _LabelLayoutDelegate extends MultiChildLayoutDelegate {
  final List<({int ri, int si})> hits;
  final List<_PlottedRoute> routes;
  final Matrix4 transform;
  final Size canvasSize;

  _LabelLayoutDelegate({
    required this.hits,
    required this.routes,
    required this.transform,
    required this.canvasSize,
  });

  @override
  void performLayout(Size size) {
    for (int idx = 0; idx < hits.length; idx++) {
      if (!hasChild(idx)) continue;
      final h = hits[idx];
      if (h.ri >= routes.length) {
        layoutChild(idx, const BoxConstraints.tightFor(width: 0, height: 0));
        positionChild(idx, Offset.zero);
        continue;
      }
      final route = routes[h.ri];
      if (h.si >= route.stations.length) {
        layoutChild(idx, const BoxConstraints.tightFor(width: 0, height: 0));
        positionChild(idx, Offset.zero);
        continue;
      }
      final s = route.stations[h.si];

      final canvasPt = Offset(s.x * canvasSize.width, s.y * canvasSize.height);
      final screenPt = MatrixUtils.transformPoint(transform, canvasPt);

      final childSize = layoutChild(
        idx,
        BoxConstraints.loose(const Size(220, 120)),
      );

      const mg = 12.0;
      double dx = screenPt.dx + mg;
      double dy = screenPt.dy - childSize.height - mg;
      if (dx + childSize.width > size.width)
        dx = screenPt.dx - childSize.width - mg;
      if (dy < 0) dy = screenPt.dy + mg;
      dx = dx.clamp(4.0, size.width - childSize.width - 4);
      dy = dy.clamp(4.0, size.height - childSize.height - 4);

      positionChild(idx, Offset(dx, dy));
    }
  }

  @override
  bool shouldRelayout(_LabelLayoutDelegate old) =>
      old.hits != hits ||
      old.transform.storage.toString() != transform.storage.toString() ||
      old.routes != routes;
}
