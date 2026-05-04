// lib/widgets/station_selector.dart
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/services.dart';
import 'dart:io';
import 'dart:convert';

// ============================================================
// 热门车站（20个，按知名度排序）
// ============================================================
const List<String> _kPopularTelecodes = [
  'BJP', // 北京
  'SHH', // 上海
  'GZQ', // 广州
  'SZQ', // 深圳
  'CDW', // 成都
  'WHN', // 武汉
  'NJH', // 南京
  'HGH', // 杭州
  'XAY', // 西安
  'TJP', // 天津
  'CQW', // 重庆
  'CSQ', // 长沙
  'ZZF', // 郑州
  'HBB', // 哈尔滨
  'SYT', // 沈阳
  'QDK', // 青岛
  'KMK', // 昆明
  'NNZ', // 南宁
  'FZS', // 福州
  'XMN', // 厦门
];

// ============================================================
// loadStations
// ============================================================
Future<List<dynamic>> loadStations() async {
  final directory = await getApplicationDocumentsDirectory();
  final file = File('${directory.path}/stations.json');
  if (await file.exists()) {
    final jsonString = await file.readAsString();
    final data = json.decode(jsonString);
    if (data is List) return data;
  }
  final jsonString = await rootBundle.loadString('assets/stations.json');
  return json.decode(jsonString) as List<dynamic>;
}

// ============================================================
// 持久化：最近使用 & 收藏
// ============================================================
Future<File> _prefsFile() async {
  final dir = await getApplicationDocumentsDirectory();
  return File('${dir.path}/station_prefs.json');
}

Future<Map<String, dynamic>> _loadPrefs() async {
  try {
    final f = await _prefsFile();
    if (await f.exists()) {
      return json.decode(await f.readAsString()) as Map<String, dynamic>;
    }
  } catch (_) {}
  return {};
}

Future<void> _savePrefs(Map<String, dynamic> prefs) async {
  final f = await _prefsFile();
  await f.writeAsString(json.encode(prefs));
}

Future<List<String>> loadRecentTelecodes() async {
  final p = await _loadPrefs();
  return List<String>.from(p['recent'] ?? []);
}

Future<void> addRecentTelecode(String telecode) async {
  final p = await _loadPrefs();
  final List<String> recent = List<String>.from(p['recent'] ?? []);
  recent.remove(telecode);
  recent.insert(0, telecode);
  if (recent.length > 10) recent.removeLast();
  p['recent'] = recent;
  await _savePrefs(p);
}

Future<List<String>> loadFavoriteTelecodes() async {
  final p = await _loadPrefs();
  return List<String>.from(p['favorites'] ?? []);
}

Future<void> toggleFavoriteTelecode(String telecode) async {
  final p = await _loadPrefs();
  final List<String> favs = List<String>.from(p['favorites'] ?? []);
  if (favs.contains(telecode)) {
    favs.remove(telecode);
  } else {
    favs.add(telecode);
  }
  p['favorites'] = favs;
  await _savePrefs(p);
}

// ============================================================
// StationSelector
// ============================================================
class StationSelector extends StatefulWidget {
  final String title;
  final String? selectedCode; // telecode
  final Function(Map<String, String?>) onSelected;

  const StationSelector({
    super.key,
    required this.title,
    this.selectedCode,
    required this.onSelected,
  });

  @override
  State<StationSelector> createState() => _StationSelectorState();
}

class _StationSelectorState extends State<StationSelector> {
  final TextEditingController _searchCtrl = TextEditingController();
  final FocusNode _searchFocus = FocusNode();

  List<dynamic> _allStations = [];
  Map<String, dynamic> _teleIndex = {}; // telecode → station

  List<dynamic> _filtered = [];
  bool _loadingStations = true;

  List<String> _recentTelecodes = [];
  List<String> _favoriteTelecodes = [];
  List<dynamic> _popularStations = [];

  @override
  void initState() {
    super.initState();
    _searchCtrl.addListener(_onSearchChanged);
    _init();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  Future<void> _init() async {
    final stationsList = await loadStations();
    final recent = await loadRecentTelecodes();
    final favs = await loadFavoriteTelecodes();

    // 建立 telecode 索引
    final Map<String, dynamic> idx = {};
    for (final s in stationsList) {
      final tc = (s['telecode'] ?? '').toString().trim();
      if (tc.isNotEmpty) idx[tc] = s;
    }

    // 热门站（按 _kPopularTelecodes 顺序）
    final popular = _kPopularTelecodes
        .where((tc) => idx.containsKey(tc))
        .map((tc) => idx[tc]!)
        .toList();

    if (!mounted) return;
    setState(() {
      _allStations = stationsList;
      _teleIndex = idx;
      _filtered = stationsList;
      _recentTelecodes = recent;
      _favoriteTelecodes = favs;
      _popularStations = popular;
      _loadingStations = false;
    });
  }

  void _onSearchChanged() {
    final query = _searchCtrl.text.toLowerCase().trim();
    setState(() {
      if (query.isEmpty) {
        _filtered = _allStations;
      } else {
        _filtered = _allStations.where((s) {
          final name = (s['name'] ?? '').toLowerCase();
          final tc = (s['telecode'] ?? '').toLowerCase();
          final city = (s['city'] ?? '').toLowerCase();
          return name.contains(query) ||
              tc.contains(query) ||
              city.contains(query);
        }).toList();
      }
    });
  }

  Future<void> _onStationTap(dynamic station) async {
    final telecode = (station['telecode'] ?? '').toString();
    final name = (station['name'] ?? '').toString();
    final city = (station['city'] ?? '').toString();
    await addRecentTelecode(telecode);
    if (mounted) Navigator.of(context).pop();
    widget.onSelected({
      'code': telecode,
      'telecode': telecode,
      'name': name,
      'city': city,
    });
  }

  Future<void> _onToggleFavorite(String telecode) async {
    await toggleFavoriteTelecode(telecode);
    final favs = await loadFavoriteTelecodes();
    if (mounted) setState(() => _favoriteTelecodes = favs);
  }

  bool _isSelected(dynamic station) {
    final tc = (station['telecode'] ?? '').toString();
    return tc == widget.selectedCode;
  }

  bool _isFavorite(dynamic station) {
    final tc = (station['telecode'] ?? '').toString();
    return _favoriteTelecodes.contains(tc);
  }

  // ---- 构建单个车站 Tile ----
  Widget _stationTile(dynamic station, {bool compact = false}) {
    final selected = _isSelected(station);
    final fav = _isFavorite(station);
    final tc = (station['telecode'] ?? '').toString();
    final name = (station['name'] ?? '').toString();
    final city = (station['city'] ?? '').toString();
    final primary = Theme.of(context).colorScheme.primary;

    return ListTile(
      dense: compact,
      contentPadding: compact
          ? const EdgeInsets.symmetric(horizontal: 12, vertical: 0)
          : const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      leading: Icon(
        Icons.train,
        size: compact ? 18 : 22,
        color: selected ? primary : Theme.of(context).hintColor,
      ),
      title: Text(
        '$name站',
        style: TextStyle(
          fontSize: compact ? 13 : 15,
          fontWeight: FontWeight.w500,
          color: selected ? primary : Theme.of(context).colorScheme.onSurface,
        ),
      ),
      subtitle: Text(
        '$city市  $tc',
        style: TextStyle(fontSize: 11, color: Theme.of(context).hintColor),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 收藏星星
          GestureDetector(
            onTap: () => _onToggleFavorite(tc),
            child: Padding(
              padding: const EdgeInsets.all(6),
              child: Icon(
                fav ? Icons.star_rounded : Icons.star_border_rounded,
                size: 20,
                color: fav ? Colors.amber : Theme.of(context).hintColor,
              ),
            ),
          ),
          // 已选中勾
          if (selected)
            const Icon(Icons.check_circle, size: 18, color: Colors.blue),
        ],
      ),
      onTap: () => _onStationTap(station),
    );
  }

  // ---- 分组标题 ----
  Widget _sectionHeader(String label, IconData icon) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Row(
        children: [
          Icon(icon, size: 14, color: Theme.of(context).hintColor),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Theme.of(context).hintColor,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }

  // ---- 无搜索时的首屏（收藏 + 常用 + 热门） ----
  Widget _buildHomeSections() {
    final List<Widget> sections = [];

    // 收藏
    final favStations = _favoriteTelecodes
        .where(_teleIndex.containsKey)
        .map((tc) => _teleIndex[tc]!)
        .toList();
    if (favStations.isNotEmpty) {
      sections.add(_sectionHeader('收藏车站', Icons.star_rounded));
      for (final s in favStations) {
        sections.add(_stationTile(s, compact: true));
      }
      sections.add(const Divider(height: 1, indent: 16, endIndent: 16));
    }

    // 最近使用
    final recentStations = _recentTelecodes
        .where(_teleIndex.containsKey)
        .map((tc) => _teleIndex[tc]!)
        .toList();
    if (recentStations.isNotEmpty) {
      sections.add(_sectionHeader('最近使用', Icons.history_rounded));
      for (final s in recentStations) {
        sections.add(_stationTile(s, compact: true));
      }
      sections.add(const Divider(height: 1, indent: 16, endIndent: 16));
    }

    // 热门车站
    if (_popularStations.isNotEmpty) {
      sections.add(_sectionHeader('热门车站', Icons.local_fire_department_rounded));
      for (final s in _popularStations) {
        sections.add(_stationTile(s, compact: true));
      }
    }

    return ListView(children: sections);
  }

  // ---- 搜索结果列表 ----
  Widget _buildSearchResults() {
    if (_filtered.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.search_off,
              size: 56,
              color: Theme.of(context).hintColor,
            ),
            const SizedBox(height: 12),
            Text(
              '未找到相关车站',
              style: TextStyle(
                fontSize: 15,
                color: Theme.of(context).hintColor,
              ),
            ),
          ],
        ),
      );
    }
    return ListView.builder(
      itemCount: _filtered.length,
      itemBuilder: (_, i) => _stationTile(_filtered[i]),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isSearching = _searchCtrl.text.isNotEmpty;

    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Column(
        children: [
          // 顶部拖动条
          Container(
            margin: const EdgeInsets.only(top: 8, bottom: 4),
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: Theme.of(context).hintColor.withAlpha(80),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          // 标题行
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                Text(
                  widget.title,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
          ),
          // 搜索框
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              controller: _searchCtrl,
              focusNode: _searchFocus,
              decoration: InputDecoration(
                hintText: '搜索车站名称、城市、电报码',
                prefixIcon: const Icon(Icons.search, size: 20),
                suffixIcon: isSearching
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 18),
                        onPressed: () {
                          _searchCtrl.clear();
                          _searchFocus.unfocus();
                        },
                      )
                    : null,
                filled: true,
                fillColor: Theme.of(
                  context,
                ).colorScheme.surfaceContainerHighest,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
              ),
            ),
          ),
          // 计数提示（搜索中时显示）
          if (isSearching)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  '找到 ${_filtered.length} 个车站',
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).hintColor,
                  ),
                ),
              ),
            )
          else
            const SizedBox(height: 6),
          // 内容区
          Expanded(
            child: _loadingStations
                ? const Center(child: CircularProgressIndicator())
                : isSearching
                ? _buildSearchResults()
                : _buildHomeSections(),
          ),
        ],
      ),
    );
  }
}
