// ui/function/route_map_page.dart
// ─────────────────────────────────────────────────────────────
// 多线路叠加走向图
// ─────────────────────────────────────────────────────────────
import 'dart:math';

import 'package:flutter/material.dart';

import 'route_models.dart';
import '../../station_selector.dart'; // loadStations()

// ─────────────────────────────────────────────────────────────
// 线路色盘
// ─────────────────────────────────────────────────────────────

// ─────────────────────────────────────────────────────────────
// 根据路线 id hash 生成固定色（HSL 均匀散布，饱和度/亮度固定）
// ─────────────────────────────────────────────────────────────

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

// ─────────────────────────────────────────────────────────────
// 内部绘制模型
// ─────────────────────────────────────────────────────────────

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
    int? br, bs;
    double md = double.infinity;
    for (int ri = 0; ri < _plotted.length; ri++) {
      if (!_plotted[ri].visible) continue;
      for (int si = 0; si < _plotted[ri].stations.length; si++) {
        final s = _plotted[ri].stations[si];
        if (!s.hasLocation) continue;
        final d =
            (local - Offset(s.x * sz.width, s.y * sz.height)).distance;
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
                if (_selRouteIdx != null && _selStopIdx != null)
                  _buildInfoCard(isDark, cs),
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
                          Text(r.model.name,
                              style: TextStyle(
                                  fontSize: 12,
                                  color: r.color,
                                  fontWeight: FontWeight.w600)),
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
                      selRouteIdx: _selRouteIdx,
                      selStopIdx: _selStopIdx,
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

  Widget _buildInfoCard(bool isDark, ColorScheme cs) {
    final ri = _selRouteIdx!, si = _selStopIdx!;
    if (ri >= _plotted.length) return const SizedBox();
    final route = _plotted[ri];
    if (si >= route.stations.length) return const SizedBox();
    final s = route.stations[si];
    final isFirst = si == 0;
    final isLast = si == route.stations.length - 1;
    final isBoth = isFirst && isLast;

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border:
            Border.all(color: route.color.withAlpha(120), width: 1.5),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withAlpha(20),
              blurRadius: 8,
              offset: const Offset(0, 2))
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
                color: route.color.withAlpha(30),
                shape: BoxShape.circle),
            child: Center(
              child: Text('${si + 1}',
                  style: TextStyle(
                      color: route.color,
                      fontWeight: FontWeight.bold,
                      fontSize: 14)),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(children: [
                  Text('${s.name}站',
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.bold)),
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
                const SizedBox(height: 3),
                Row(children: [
                  Text(route.model.name,
                      style: TextStyle(
                          fontSize: 12,
                          color: route.color,
                          fontWeight: FontWeight.w500)),
                  if (s.city.isNotEmpty) ...[
                    Text(' · ',
                        style: TextStyle(
                            fontSize: 12,
                            color: cs.onSurface.withAlpha(100))),
                    Text(s.city,
                        style: TextStyle(
                            fontSize: 12,
                            color: cs.onSurface.withAlpha(140))),
                  ],
                ]),
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
                        fontSize: 14,
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
      final isSel = routeIdx == selRouteIdx && si == selStopIdx;
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
      old.selRouteIdx != selRouteIdx ||
      old.selStopIdx != selStopIdx ||
      old.scale != scale;
}
