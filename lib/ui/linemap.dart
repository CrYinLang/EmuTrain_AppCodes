// linemap.dart
import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../journey_model.dart';
import '../station_selector.dart';

// ─────────────────────────────────────────────────────────────
// 入口 Dialog
// ─────────────────────────────────────────────────────────────
class LineMapDialog extends StatelessWidget {
  final Journey journey;

  const LineMapDialog({super.key, required this.journey});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Center(
        child: Material(
          borderRadius: BorderRadius.circular(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      _buildRouteSummary(context, journey),
                      const SizedBox(height: 16),
                      Expanded(child: LineMapContent(journey: journey)),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRouteSummary(BuildContext context, Journey journey) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Icon(Icons.train, color: Theme.of(context).colorScheme.onSurface),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${journey.trainCode}次 • ${journey.fromStation} → ${journey.toStation}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Text(
                    '全程${journey.getTotalDuration()} • ${journey.stations.length}个站点',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// 主体 Widget
// ─────────────────────────────────────────────────────────────
class LineMapContent extends StatefulWidget {
  final Journey journey;

  const LineMapContent({super.key, required this.journey});

  @override
  State<LineMapContent> createState() => _LineMapContentState();
}

class _LineMapContentState extends State<LineMapContent>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  // 停车站（带时间，isViaStation==false）
  List<_Station> _stops = [];

  // 全路线所有站（含小站）
  List<_Station> _full = [];

  bool _isLoading = true;
  String _errorMessage = '';

  // 当前选中站的序号（stops 列表下标），null 表示无
  int? _selectedStop;

  final TransformationController _txCtrl = TransformationController();
  double _scale = 1.0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _txCtrl.dispose();
    super.dispose();
  }

  // ── 时间工具 ────────────────────────────────────────────────

  static DateTime? _parseRelative(DateTime ref, String? t) {
    if (t == null || t.isEmpty) return null;
    final p = t.split(':');
    if (p.length < 2) return null;
    final h = int.tryParse(p[0]);
    final m = int.tryParse(p[1]);
    if (h == null || m == null) return null;
    var dt = DateTime(ref.year, ref.month, ref.day, h, m);
    if (dt.isBefore(ref.subtract(const Duration(hours: 2)))) {
      dt = dt.add(const Duration(days: 1));
    }
    return dt;
  }

  // 返回每个停车站的状态：'past' | 'current' | 'future'
  List<String> _computeStatuses() {
    final now = DateTime.now();
    final n = _stops.length;
    if (n == 0) return [];

    // 找第一站时间定基准
    DateTime ref = now;
    for (final s in _stops) {
      final raw = s.departureTime ?? s.arrivalTime;
      if (raw != null && raw.isNotEmpty) {
        final p = raw.split(':');
        if (p.length >= 2) {
          final h = int.tryParse(p[0]);
          final m = int.tryParse(p[1]);
          if (h != null && m != null) {
            ref = DateTime(now.year, now.month, now.day, h, m);
            break;
          }
        }
      }
    }

    final deps = List<DateTime?>.filled(n, null);
    final arrs = List<DateTime?>.filled(n, null);
    DateTime prev = ref;
    for (int i = 0; i < n; i++) {
      final arr = _parseRelative(prev, _stops[i].arrivalTime);
      final dep = _parseRelative(arr ?? prev, _stops[i].departureTime);
      arrs[i] = arr;
      deps[i] = dep;
      prev = dep ?? arr ?? prev;
    }

    final statuses = List<String>.filled(n, 'future');
    int lastPast = -1;
    for (int i = 0; i < n; i++) {
      final t = deps[i] ?? arrs[i];
      if (t != null && t.isBefore(now)) {
        statuses[i] = 'past';
        lastPast = i;
      }
    }
    if (lastPast >= 0 && lastPast + 1 < n) {
      statuses[lastPast + 1] = 'current';
    }
    return statuses;
  }

  // ── 数据加载 ────────────────────────────────────────────────

  Future<void> _load() async {
    try {
      final raw = await _fetchFromApi(
        widget.journey.trainCode,
      ).timeout(const Duration(seconds: 10));
      final withLoc = await _matchLocal(raw);
      final fullStations = _toStations(withLoc, isFiltered: false);
      final stopStations = _filterStops(withLoc, widget.journey.stations);

      // 归一化坐标：以全路线包围盒为准
      _normalizePositions(fullStations);
      // 停车站坐标直接从全路线复用，保证与线段端点完全重合
      _reuseFromFull(stopStations, fullStations);

      setState(() {
        _full = fullStations;
        _stops = stopStations;
        _isLoading = false;
      });

      WidgetsBinding.instance.addPostFrameCallback((_) {
        _checkAnomalies();
      });
    } catch (e) {
      // fallback：均匀排列
      final fb = _buildFallback();
      setState(() {
        _full = fb;
        _stops = fb;
        _isLoading = false;
      });
    }
  }

  List<_Station> _buildFallback() {
    final js = widget.journey.stations;
    final n = js.length;
    return List.generate(
      n,
      (i) => _Station(
        name: js[i].stationName.replaceAll('站', '').trim(),
        isVia: false,
        arrivalTime: js[i].arrivalTime,
        departureTime: js[i].departureTime,
        hasLocation: true,
        city: '',
        x: n > 1 ? 0.1 + 0.8 * (i / (n - 1)) : 0.5,
        y: 0.5,
      ),
    );
  }

  // ── 数据转换 ────────────────────────────────────────────────

  List<_Station> _toStations(
    List<Map<String, dynamic>> raw, {
    required bool isFiltered,
  }) {
    return raw
        .map(
          (m) => _Station(
            name: ((m['stationName'] ?? m['name']) as String? ?? '')
                .replaceAll('站', '')
                .trim(),
            isVia: (m['isViaStation'] as bool?) ?? false,
            arrivalTime: m['arrivalTime'] as String?,
            departureTime: m['departureTime'] as String?,
            hasLocation: (m['hasLocation'] as bool?) ?? false,
            city: (m['city'] as String?) ?? '',
            lng: (m['longitude'] as num?)?.toDouble() ?? 0,
            lat: (m['latitude'] as num?)?.toDouble() ?? 0,
          ),
        )
        .toList();
  }

  List<_Station> _filterStops(
    List<Map<String, dynamic>> fullRaw,
    List<StationDetail> journeyStations,
  ) {
    final names = journeyStations
        .map((s) => s.stationName.replaceAll('站', '').trim())
        .toList();

    final matched = fullRaw.where((m) {
      final n = ((m['stationName'] ?? m['name']) as String? ?? '')
          .replaceAll('站', '')
          .trim();
      return names.contains(n);
    }).toList();

    matched.sort((a, b) {
      final na = ((a['stationName'] ?? a['name']) as String? ?? '')
          .replaceAll('站', '')
          .trim();
      final nb = ((b['stationName'] ?? b['name']) as String? ?? '')
          .replaceAll('站', '')
          .trim();
      return names.indexOf(na).compareTo(names.indexOf(nb));
    });

    return matched.map((m) {
      final name = ((m['stationName'] ?? m['name']) as String? ?? '')
          .replaceAll('站', '')
          .trim();
      final idx = names.indexOf(name);
      final js = idx >= 0 ? journeyStations[idx] : null;
      return _Station(
        name: name,
        isVia: false,
        arrivalTime: js?.arrivalTime ?? m['arrivalTime'] as String?,
        departureTime: js?.departureTime ?? m['departureTime'] as String?,
        hasLocation: (m['hasLocation'] as bool?) ?? false,
        city: (m['city'] as String?) ?? '',
        lng: (m['longitude'] as num?)?.toDouble() ?? 0,
        lat: (m['latitude'] as num?)?.toDouble() ?? 0,
      );
    }).toList();
  }

  // ── 坐标归一化 ──────────────────────────────────────────────

  void _normalizePositions(List<_Station> stations) {
    final valid = stations
        .where((s) => s.hasLocation && (s.lng != 0 || s.lat != 0))
        .toList();
    if (valid.length < 2) {
      // 退化：均匀排列
      final n = stations.length;
      for (int i = 0; i < n; i++) {
        stations[i].x = n > 1 ? 0.1 + 0.8 * (i / (n - 1)) : 0.5;
        stations[i].y = 0.5;
      }
      return;
    }

    double minLng = double.infinity, maxLng = -double.infinity;
    double minLat = double.infinity, maxLat = -double.infinity;
    for (final s in valid) {
      minLng = min(minLng, s.lng);
      maxLng = max(maxLng, s.lng);
      minLat = min(minLat, s.lat);
      maxLat = max(maxLat, s.lat);
    }

    // 保持宽高比接近 1.8:1，留 20% 边距
    const ar = 1.8;
    double adjLng = maxLng - minLng;
    double adjLat = maxLat - minLat;
    if (adjLng / adjLat > ar) {
      adjLat = adjLng / ar;
    } else {
      adjLng = adjLat * ar;
    }
    final cx = (minLng + maxLng) / 2;
    final cy = (minLat + maxLat) / 2;
    final fMinLng = cx - adjLng * 0.6;
    final fMaxLng = cx + adjLng * 0.6;
    final fMinLat = cy - adjLat * 0.6;
    final fMaxLat = cy + adjLat * 0.6;
    final lngR = fMaxLng - fMinLng;
    final latR = fMaxLat - fMinLat;

    for (final s in stations) {
      if (s.hasLocation && (s.lng != 0 || s.lat != 0)) {
        s.x = ((s.lng - fMinLng) / lngR).clamp(0.0, 1.0);
        s.y = (1.0 - (s.lat - fMinLat) / latR).clamp(0.0, 1.0);
      } else {
        s.x = 0.5;
        s.y = 0.5;
      }
    }
  }

  // 停车站坐标直接从全路线按站名复用，保证与线段端点重合
  void _reuseFromFull(List<_Station> stops, List<_Station> full) {
    final Map<String, _Station> map = {for (final s in full) s.name: s};
    for (final s in stops) {
      final f = map[s.name];
      if (f != null) {
        s.x = f.x;
        s.y = f.y;
        if (!s.hasLocation && f.hasLocation) {
          s.hasLocation = f.hasLocation;
          s.city = f.city;
        }
      } else {
        s.x = 0.5;
        s.y = 0.5;
        s.hasLocation = false;
      }
    }
  }

  // ── 异常检测 ────────────────────────────────────────────────

  void _checkAnomalies() async {
    final real = await _getSetting('show_real_train_map');
    if (!real || !mounted) return;
    final bad = <String>[];
    for (int i = 1; i < _full.length; i++) {
      final a = _full[i - 1], b = _full[i];
      if (!a.hasLocation || !b.hasLocation) continue;
      final dx = (b.x - a.x) * 100;
      final dy = (b.y - a.y) * 100;
      final d = sqrt(dx * dx + dy * dy);
      if (d > 30) bad.add('${a.name} → ${b.name}: ${d.toStringAsFixed(1)}单位');
    }
    if (bad.isEmpty || !mounted) return;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning_amber, color: Colors.orange),
            SizedBox(width: 8),
            Text('走向图数据异常'),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('检测到以下异常线段：'),
              const SizedBox(height: 8),
              ...bad.map((s) => Text('• $s')),
              const SizedBox(height: 12),
              const Text(
                '请联系技术支持。',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('确定'),
          ),
        ],
      ),
    );
  }

  // ── API ─────────────────────────────────────────────────────

  Future<bool> _getSetting(String key) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(key) ?? true;
  }

  Future<List<Map<String, dynamic>>> _fetchFromApi(String trainNumber) async {
    final real = await _getSetting('show_real_train_map');
    if (!real) return _fallbackRaw();
    try {
      final url = Uri.parse(
        'https://rail.moefactory.com/api/trainDetails/queryTrainRoutes',
      );
      final resp = await http.post(url, body: {'trainNumber': trainNumber});
      if (resp.statusCode == 200) {
        final data = json.decode(resp.body);
        if (data['code'] == 200 && data['data'] != null) {
          return List<Map<String, dynamic>>.from(data['data']);
        }
      }
    } catch (_) {}
    return _fallbackRaw();
  }

  List<Map<String, dynamic>> _fallbackRaw() {
    return List.generate(widget.journey.stations.length, (i) {
      final s = widget.journey.stations[i];
      return {
        'stationName': s.stationName,
        'isViaStation': false,
        'arrivalTime': s.arrivalTime,
        'departureTime': s.departureTime,
        'stationSequence': i + 1,
      };
    });
  }

  Future<List<Map<String, dynamic>>> _matchLocal(
    List<Map<String, dynamic>> raw,
  ) async {
    try {
      final all = (await loadStations()).cast<Map<String, dynamic>>();
      return raw.map((api) {
        final clean = (api['stationName'] as String? ?? '')
            .replaceAll('站', '')
            .trim();
        final match = all.firstWhere(
          (s) =>
              (s['name'] as String? ?? '').replaceAll('站', '').trim() == clean,
          orElse: () => <String, dynamic>{},
        );
        if (match.isNotEmpty) {
          final loc = match['location']?.toString() ?? '';
          final coords = loc.split(',');
          final lng = coords.length == 2
              ? (double.tryParse(coords[0]) ?? 0.0)
              : 0.0;
          final lat = coords.length == 2
              ? (double.tryParse(coords[1]) ?? 0.0)
              : 0.0;
          return {
            ...api,
            'name': api['stationName'],
            'city': match['city'] ?? '',
            'longitude': lng,
            'latitude': lat,
            'hasLocation':
                loc.isNotEmpty && coords.length == 2 && (lng != 0 || lat != 0),
          };
        }
        return {
          ...api,
          'name': api['stationName'],
          'city': '',
          'longitude': 0.0,
          'latitude': 0.0,
          'hasLocation': false,
        };
      }).toList();
    } catch (_) {
      return raw
          .map(
            (s) => {
              ...s,
              'hasLocation': false,
              'longitude': 0.0,
              'latitude': 0.0,
            },
          )
          .toList();
    }
  }

  // ── 点击检测 ────────────────────────────────────────────────

  // 将屏幕坐标转换为画布坐标，再找最近的停车站
  void _handleTap(TapUpDetails details, Size canvasSize) {
    // InteractiveViewer 的变换矩阵：屏幕坐标 → 画布坐标
    final matrix = _txCtrl.value;
    final inv = Matrix4.inverted(matrix);
    final local = MatrixUtils.transformPoint(inv, details.localPosition);

    // 找点击半径内最近的停车站（屏幕像素 24 / scale）
    final hitRadius = 24.0 / _scale;
    double minDist = double.infinity;
    int? hitIdx;

    for (int i = 0; i < _stops.length; i++) {
      final s = _stops[i];
      final px = s.x * canvasSize.width;
      final py = s.y * canvasSize.height;
      final dx = local.dx - px;
      final dy = local.dy - py;
      final d = sqrt(dx * dx + dy * dy);
      if (d < hitRadius && d < minDist) {
        minDist = d;
        hitIdx = i;
      }
    }

    setState(() {
      _selectedStop = (_selectedStop == hitIdx) ? null : hitIdx;
    });
  }

  // ── Build ────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    super.build(context);

    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('正在加载走向图...'),
          ],
        ),
      );
    }

    if (_errorMessage.isNotEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.red),
            const SizedBox(height: 16),
            Text('加载失败: $_errorMessage'),
            const SizedBox(height: 16),
            ElevatedButton(onPressed: _load, child: const Text('重试')),
          ],
        ),
      );
    }

    final statuses = _computeStatuses();
    final surfaceColor = Theme.of(context).colorScheme.surface;

    return Column(
      children: [
        Expanded(
          child: Center(
            child: AspectRatio(
              aspectRatio: 1.0,
              child: Container(
                constraints: const BoxConstraints(
                  maxWidth: 440,
                  maxHeight: 440,
                ),
                decoration: BoxDecoration(
                  color: surfaceColor,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withAlpha(26),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: LayoutBuilder(
                    builder: (ctx, constraints) {
                      final side = constraints.biggest.shortestSide;
                      final sz = Size(side, side);

                      return GestureDetector(
                        // 点击：先经过 InteractiveViewer 内部的坐标变换
                        onTapUp: (d) => _handleTap(d, sz),
                        child: InteractiveViewer(
                          transformationController: _txCtrl,
                          minScale: 0.8,
                          maxScale: 6.0,
                          boundaryMargin: const EdgeInsets.all(80),
                          onInteractionUpdate: (_) {
                            final s = _txCtrl.value.getMaxScaleOnAxis();
                            if (s != _scale) setState(() => _scale = s);
                          },
                          child: CustomPaint(
                            size: sz,
                            painter: _MapPainter(
                              full: _full,
                              stops: _stops,
                              statuses: statuses,
                              selectedStop: _selectedStop,
                              scale: _scale,
                              surfaceColor: surfaceColor,
                              showVia: _scale > 1.8,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────
// 数据模型
// ─────────────────────────────────────────────────────────────
class _Station {
  final String name;
  final bool isVia;
  final String? arrivalTime;
  final String? departureTime;
  bool hasLocation;
  String city;
  final double lng;
  final double lat;

  // 归一化后的相对坐标（可写，由 _normalizePositions / _reuseFromFull 填入）
  double x;
  double y;

  _Station({
    required this.name,
    required this.isVia,
    this.arrivalTime,
    this.departureTime,
    required this.hasLocation,
    required this.city,
    this.lng = 0,
    this.lat = 0,
    this.x = 0.5,
    this.y = 0.5,
  });
}

// ─────────────────────────────────────────────────────────────
// 唯一的 CustomPainter：线段 + 途径站点 + 停车站圆点 + 标签
// 所有元素都在同一坐标系内绘制，彻底消除偏移
// ─────────────────────────────────────────────────────────────
class _MapPainter extends CustomPainter {
  final List<_Station> full;
  final List<_Station> stops;
  final List<String> statuses;
  final int? selectedStop;
  final double scale;
  final Color surfaceColor;
  final bool showVia;

  const _MapPainter({
    required this.full,
    required this.stops,
    required this.statuses,
    required this.selectedStop,
    required this.scale,
    required this.surfaceColor,
    required this.showVia,
  });

  // 逻辑像素 → 画布像素（抵消缩放，保持视觉大小固定）
  double _px(double logicalPixels) => logicalPixels / scale;

  @override
  void paint(Canvas canvas, Size size) {
    _drawFullLine(canvas, size);
    _drawSegmentedLine(canvas, size);
    if (showVia) _drawViaMarkers(canvas, size);
    _drawStopMarkers(canvas, size);
    if (selectedStop != null) _drawLabel(canvas, size, selectedStop!);
  }

  // ── 全路线底线（灰蓝色）──────────────────────────────────────
  void _drawFullLine(Canvas canvas, Size size) {
    final valid = full.where((s) => s.hasLocation).toList();
    if (valid.length < 2) return;

    final paint = Paint()
      ..color = Colors.blue.shade300
      ..strokeWidth = _px(2.5)
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

  // ── 按时间状态分段着色（沿全路线子路径）──────────────────────
  void _drawSegmentedLine(Canvas canvas, Size size) {
    if (stops.length < 2) return;
    final valid = full.where((s) => s.hasLocation).toList();
    if (valid.length < 2) return;

    // 站名 → valid 下标
    final Map<String, int> idx = {};
    for (int i = 0; i < valid.length; i++) {
      if (valid[i].name.isNotEmpty) idx[valid[i].name] = i;
    }

    for (int fi = 1; fi < stops.length; fi++) {
      final ts = fi < statuses.length ? statuses[fi] : 'future';
      if (ts == 'future') continue; // future 段不着色，底线已是蓝色

      final color = ts == 'past' ? Colors.orange : Colors.green;
      final paint = Paint()
        ..color = color
        ..strokeWidth = _px(3.5)
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round;

      final from = stops[fi - 1];
      final to = stops[fi];
      final i0 = idx[from.name];
      final i1 = idx[to.name];

      if (i0 != null && i1 != null && i0 < i1) {
        // 沿全路线子路径
        final path = Path()
          ..moveTo(valid[i0].x * size.width, valid[i0].y * size.height);
        for (int k = i0 + 1; k <= i1; k++) {
          path.lineTo(valid[k].x * size.width, valid[k].y * size.height);
        }
        canvas.drawPath(path, paint);
      } else if (from.hasLocation && to.hasLocation) {
        // fallback：直线
        canvas.drawLine(
          Offset(from.x * size.width, from.y * size.height),
          Offset(to.x * size.width, to.y * size.height),
          paint,
        );
      }
    }
  }

  // ── 途径小站（橙色小圆，仅高缩放时显示）─────────────────────
  void _drawViaMarkers(Canvas canvas, Size size) {
    final r = _px(3.5);
    final fill = Paint()..color = Colors.orange;
    final border = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = _px(0.8);

    for (final s in full) {
      if (!s.isVia || !s.hasLocation) continue;
      final c = Offset(s.x * size.width, s.y * size.height);
      canvas.drawCircle(c, r, fill);
      canvas.drawCircle(c, r, border);
    }
  }

  // ── 停车站圆点（彩色，带序号）────────────────────────────────
  void _drawStopMarkers(Canvas canvas, Size size) {
    final r = _px(7.0);
    final borderPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = _px(2.0);

    for (int i = 0; i < stops.length; i++) {
      final s = stops[i];
      if (!s.hasLocation) continue;

      final status = i < statuses.length ? statuses[i] : 'future';
      final color = switch (status) {
        'past' => Colors.orange,
        'current' => Colors.green,
        _ => Colors.blue.shade600,
      };

      final c = Offset(s.x * size.width, s.y * size.height);
      canvas.drawCircle(c, r, Paint()..color = color);
      canvas.drawCircle(c, r, borderPaint);

      // 序号文字
      final tp = TextPainter(
        text: TextSpan(
          text: '${i + 1}',
          style: TextStyle(
            color: Colors.white,
            fontSize: _px(7.0),
            fontWeight: FontWeight.bold,
            height: 1.0,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, c - Offset(tp.width / 2, tp.height / 2));
    }
  }

  // ── 信息标签 ────────────────────────────────────────────────
  void _drawLabel(Canvas canvas, Size size, int idx) {
    if (idx >= stops.length) return;
    final s = stops[idx];

    final cx = s.x * size.width;
    final cy = s.y * size.height;

    // 文字内容
    final name = '${s.name}站';
    final city = s.city.isNotEmpty ? '${s.city}市' : null;
    final time = (s.arrivalTime != null || s.departureTime != null)
        ? '${s.arrivalTime ?? ""} - ${s.departureTime ?? ""}'
        : null;

    final fs = _px(11.0);
    final fsSmall = _px(9.0);

    final nameTp = _makeTp(name, fs, Colors.black87, bold: true);
    final cityTp = city != null ? _makeTp(city, fsSmall, Colors.black54) : null;
    final timeTp = time != null ? _makeTp(time, fsSmall, Colors.black54) : null;

    final padH = _px(8.0);
    final padV = _px(5.0);
    final lineGap = _px(2.0);
    // 站名 → 城市之间额外留白，视觉上明显分开
    final nameCityGap = _px(7.0);

    double contentW = nameTp.width;
    if (cityTp != null) contentW = max(contentW, cityTp.width);
    if (timeTp != null) contentW = max(contentW, timeTp.width);

    double contentH = nameTp.height;
    if (cityTp != null) contentH += nameCityGap + cityTp.height;
    if (timeTp != null) contentH += lineGap + timeTp.height;

    final lw = contentW + padH * 2;
    final lh = contentH + padV * 2;
    final mg = _px(8.0);

    // 选择标签位置（右→左→上→下）
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
    // 夹紧边界
    pos = Offset(
      pos.dx.clamp(0.0, size.width - lw),
      pos.dy.clamp(0.0, size.height - lh),
    );

    final rect = RRect.fromLTRBR(
      pos.dx,
      pos.dy,
      pos.dx + lw,
      pos.dy + lh,
      Radius.circular(_px(6.0)),
    );

    // 背景
    canvas.drawRRect(rect, Paint()..color = Colors.white.withAlpha(242));
    // 边框
    canvas.drawRRect(
      rect,
      Paint()
        ..color = Colors.grey.shade400
        ..style = PaintingStyle.stroke
        ..strokeWidth = _px(1.0),
    );

    // 文字
    double tx = pos.dx + padH;
    double ty = pos.dy + padV;

    // 站名（若无坐标加警告图标区域，此处简化为纯文字）
    nameTp.paint(canvas, Offset(tx, ty));
    ty += nameTp.height + nameCityGap;

    if (cityTp != null) {
      cityTp.paint(canvas, Offset(tx, ty));
      ty += cityTp.height + lineGap;
    }
    if (timeTp != null) {
      timeTp.paint(canvas, Offset(tx, ty));
    }
  }

  TextPainter _makeTp(
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
  bool shouldRepaint(_MapPainter old) =>
      old.stops != stops ||
      old.full != full ||
      old.statuses != statuses ||
      old.selectedStop != selectedStop ||
      old.scale != scale ||
      old.showVia != showVia;
}
