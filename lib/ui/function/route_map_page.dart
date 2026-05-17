// ui/function/route_map_page.dart

import 'dart:math';

import 'package:flutter/material.dart';

import 'route_models.dart';
import '../../station_selector.dart'; // loadStations()

Color _colorForRouteId(String id) {
  // 用字符串哈希得到 0~1 之间均匀分布的 hue
  int hash = 0;
  for (final c in id.codeUnits) {
    hash = (hash * 31 + c) & 0xFFFFFFFF;
  }
  // 黄金比例散布避免相邻色相近
  const phi = 0.6180339887;
  final hue = ((hash & 0xFFFF) / 0xFFFF + phi * (hash >> 16)) % 1.0;
  return HSLColor.fromAHSL(1.0, hue * 360, 0.72, 0.48).toColor();
}


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
  // 命中的站点列表（支持多线路共站）
  List<({int ri, int si})> _selHits = [];
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

  // ── 数据加载 ─────────────────────────────────────────────────

  Future<void> _loadAndPlot() async {
    final allStations = await loadStations();
    // 用 telecode 建索引（精确匹配，不再依赖 name）
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

  // ── 点击处理 ─────────────────────────────────────────────────

  void _handleTap(TapUpDetails details, Size sz) {
    final local = MatrixUtils.transformPoint(
        Matrix4.inverted(_txCtrl.value), details.localPosition);
    final hr = 20.0 / _scale;

    // 收集所有在命中半径内的站点
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

    // 按距离排序，取最近的那个点，再把所有距离该点坐标够近的一起收集
    hits.sort((a, b) => a.d.compareTo(b.d));
    final nearest = _plotted[hits.first.ri].stations[hits.first.si];
    final grouped = hits.where((h) {
      final s = _plotted[h.ri].stations[h.si];
      return (Offset(s.x, s.y) - Offset(nearest.x, nearest.y)).distance <
          (hr * 1.5) / sz.shortestSide;
    }).map((h) => (ri: h.ri, si: h.si)).toList();

    setState(() {
      // 再次点击同一组则取消选中
      final same = _selHits.length == grouped.length &&
          _selHits.every((a) => grouped.any((b) => b.ri == a.ri && b.si == a.si));
      _selHits = same ? [] : grouped;
    });
  }

  // ── Build ────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor:
          isDark ? const Color(0xFF111111) : const Color(0xFFF5F5F5),
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
                if (_selHits.isNotEmpty)
                  _buildInfoCards(isDark, cs),
              ],
            ),
    );
  }

  // ── 图例 ─────────────────────────────────────────────────────

  Widget _buildLegend(bool isDark) => Container(
        color: isDark ? const Color(0xFF1A1A1A) : Colors.white,
        padding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
                          horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color:
                            r.color.withAlpha(r.visible ? 30 : 15),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                            color: r.color
                                .withAlpha(r.visible ? 150 : 60)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                              width: 10,
                              height: 10,
                              decoration: BoxDecoration(
                                  color: r.color,
                                  shape: BoxShape.circle)),
                          const SizedBox(width: 6),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(r.model.name,
                                  style: TextStyle(
                                      fontSize: 12,
                                      color: r.color,
                                      fontWeight: FontWeight.w600)),
                              if (r.stations.length >= 2)
                                Text(
                                  '${r.stations.first.name} → ${r.stations.last.name}',
                                  style: TextStyle(
                                      fontSize: 10,
                                      color: r.color.withAlpha(170)),
                                ),
                            ],
                          ),
                          const SizedBox(width: 4),
                          Icon(
                            r.visible
                                ? Icons.visibility
                                : Icons.visibility_off,
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

  // ── 地图 ─────────────────────────────────────────────────────

  Widget _buildMap() {
    final surfaceColor = Theme.of(context).colorScheme.surface;
    return Center(
      child: AspectRatio(
        aspectRatio: 1.0,
        child: Container(
          constraints:
              const BoxConstraints(maxWidth: 480, maxHeight: 480),
          margin: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: surfaceColor,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withAlpha(30),
                  blurRadius: 12,
                  offset: const Offset(0, 4))
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: LayoutBuilder(builder: (ctx, constraints) {
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
                      selHits: _selHits,
                      scale: _scale,
                      surfaceColor: surfaceColor,
                    ),
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }

  // ── 站点信息卡片 ─────────────────────────────────────────────

  // ── 多线路信息卡片（支持共站） ───────────────────────────────

  Widget _buildInfoCards(bool isDark, ColorScheme cs) {
    if (_selHits.isEmpty) return const SizedBox();
    // 站点名取第一个命中的（共站时名字相同）
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
        // 共站时显示站点名标题
        if (_selHits.length > 1 && firstName.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 6),
            child: Row(
              children: [
                const Icon(Icons.place, size: 14, color: Colors.grey),
                const SizedBox(width: 4),
                Text(firstName,
                    style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey)),
                const SizedBox(width: 6),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                  decoration: BoxDecoration(
                    color: Colors.orange.withAlpha(40),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.orange.withAlpha(120)),
                  ),
                  child: Text('${_selHits.length} 线路经过',
                      style: const TextStyle(
                          fontSize: 11,
                          color: Colors.orange,
                          fontWeight: FontWeight.w600)),
                ),
              ],
            ),
          ),
        ..._selHits.map((h) => _buildOneCard(h.ri, h.si, isDark, cs)),
      ],
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
              offset: const Offset(0, 2))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── 线路名 + 始发→终点 ──────────────────────────────
          Row(
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                    color: route.color, shape: BoxShape.circle),
              ),
              const SizedBox(width: 6),
              Text(route.model.name,
                  style: TextStyle(
                      fontSize: 12,
                      color: route.color,
                      fontWeight: FontWeight.w600)),
              if (originName.isNotEmpty && termName.isNotEmpty) ...[
                const SizedBox(width: 6),
                Container(
                  width: 6,
                  height: 6,
                  decoration: const BoxDecoration(
                      color: Colors.green, shape: BoxShape.circle),
                ),
                const SizedBox(width: 3),
                Text(originName,
                    style: TextStyle(
                        fontSize: 11, color: Colors.green.shade700)),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 3),
                  child: Icon(Icons.arrow_forward,
                      size: 10, color: route.color.withAlpha(140)),
                ),
                Container(
                  width: 6,
                  height: 6,
                  decoration: const BoxDecoration(
                      color: Colors.red, shape: BoxShape.circle),
                ),
                const SizedBox(width: 3),
                Expanded(
                  child: Text(termName,
                      style: TextStyle(
                          fontSize: 11, color: Colors.red.shade700),
                      overflow: TextOverflow.ellipsis),
                ),
              ],
            ],
          ),
          const SizedBox(height: 8),
          // ── 当前站信息 ────────────────────────────────────────
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                    color: route.color.withAlpha(30),
                    shape: BoxShape.circle),
                child: Center(
                  child: Text('${si + 1}',
                      style: TextStyle(
                          color: route.color,
                          fontWeight: FontWeight.bold,
                          fontSize: 13)),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(children: [
                      Flexible(
                        child: Text('${s.name}站',
                            style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold),
                            overflow: TextOverflow.ellipsis),
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
                    ]),
                    if (s.city.isNotEmpty)
                      Text(s.city,
                          style: TextStyle(
                              fontSize: 11,
                              color: cs.onSurface.withAlpha(140))),
                  ],
                ),
              ),
              if (!isLast && s.mileageToNext != null)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('${s.mileageToNext} km',
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: route.color)),
                    Text('至下一站',
                        style: TextStyle(
                            fontSize: 10,
                            color: cs.onSurface.withAlpha(120))),
                  ],
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _badge(String text, Color color) => Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
        decoration: BoxDecoration(
          color: color.withAlpha(40),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: color.withAlpha(120)),
        ),
        child: Text(text,
            style: TextStyle(
                fontSize: 10,
                color: color,
                fontWeight: FontWeight.bold)),
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
    for (final h in selHits) {
      _drawLabel(canvas, size, h.ri, h.si);
    }
  }

  void _drawLine(
      Canvas canvas, Size size, _PlottedRoute r, bool isSelected) {
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

  void _drawStops(
      Canvas canvas, Size size, _PlottedRoute r, int routeIdx) {
    final baseR = _px(6.0);
    for (int si = 0; si < r.stations.length; si++) {
      final s = r.stations[si];
      if (!s.hasLocation) continue;
      final isSel = selHits.any((h) => h.ri == routeIdx && h.si == si);
      final markerR = isSel ? _px(9.0) : baseR;
      final c = Offset(s.x * size.width, s.y * size.height);
      if (isSel) {
        canvas.drawCircle(
            c, markerR + _px(4), Paint()..color = r.color.withAlpha(50));
      }
      canvas.drawCircle(c, markerR, Paint()..color = r.color);
      canvas.drawCircle(
          c,
          markerR,
          Paint()
            ..color = Colors.white
            ..style = PaintingStyle.stroke
            ..strokeWidth = _px(2.0));
      final tp = TextPainter(
        text: TextSpan(
          text: '${si + 1}',
          style: TextStyle(
              color: Colors.white,
              fontSize: _px(6.5),
              fontWeight: FontWeight.bold,
              height: 1.0),
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
    final sub =
        r.model.name + (s.city.isNotEmpty ? ' · ${s.city}' : '');
    final mileStr =
        (si < r.stations.length - 1 && s.mileageToNext != null)
            ? '至下站 ${s.mileageToNext} km'
            : null;

    final fs = _px(11.0), fsS = _px(9.5);
    final nameTp = _tp('${s.name}站', fs, Colors.black87, bold: true);
    final subTp = _tp(sub, fsS, r.color);
    final mileTp =
        mileStr != null ? _tp(mileStr, fsS, Colors.black54) : null;

    final padH = _px(8.0), padV = _px(5.0), gap = _px(3.0);
    double cw = max(nameTp.width, subTp.width);
    if (mileTp != null) cw = max(cw, mileTp.width);
    double ch = nameTp.height + gap + subTp.height;
    if (mileTp != null) ch += gap + mileTp.height;

    final lw = cw + padH * 2,
        lh = ch + padV * 2,
        mg = _px(10.0);
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
    pos = Offset(pos.dx.clamp(0.0, size.width - lw),
        pos.dy.clamp(0.0, size.height - lh));

    final rr = RRect.fromLTRBR(pos.dx, pos.dy, pos.dx + lw, pos.dy + lh,
        Radius.circular(_px(6)));
    canvas.drawRRect(rr, Paint()..color = Colors.white.withAlpha(240));
    canvas.drawRRect(
        rr,
        Paint()
          ..color = r.color.withAlpha(180)
          ..style = PaintingStyle.stroke
          ..strokeWidth = _px(1.2));

    double tx = pos.dx + padH, ty = pos.dy + padV;
    nameTp.paint(canvas, Offset(tx, ty));
    ty += nameTp.height + gap;
    subTp.paint(canvas, Offset(tx, ty));
    if (mileTp != null) {
      ty += subTp.height + gap;
      mileTp.paint(canvas, Offset(tx, ty));
    }
  }

  TextPainter _tp(String text, double fontSize, Color color,
      {bool bold = false}) {
    return TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
            fontSize: fontSize,
            color: color,
            fontWeight: bold ? FontWeight.bold : FontWeight.normal,
            height: 1.2),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
  }

  @override
  bool shouldRepaint(_RouteMapPainter old) =>
      old.routes != routes ||
      old.selHits != selHits ||
      old.scale != scale;
}
