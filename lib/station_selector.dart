// lib/widgets/station_selector.dart
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/services.dart';
import 'dart:io';
import 'dart:convert';
import 'functions.dart';

//读取车站信息
Future<List<dynamic>> loadStations() async {
  final directory = await getApplicationDocumentsDirectory();
  final file = File('${directory.path}/stations.json');

  if (await file.exists()) {
    final jsonString = await file.readAsString();
    final data = json.decode(jsonString);
    if (data is List) {
      return data;
    }
  }

  final jsonString = await rootBundle.loadString('assets/stations.json');
  return json.decode(jsonString) as List<dynamic>;
}

// 车站选择器组件
class StationSelector extends StatefulWidget {
  final String title;
  final String? selectedCode;
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
  List<dynamic> _filtered = [];
  bool _loadingStations = false;

  @override
  void initState() {
    super.initState();
    _loadStations();
    _searchCtrl.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  Future<void> _loadStations() async {
    setState(() => _loadingStations = true);
    try {
      final stationsList = await loadStations();
      setState(() {
        _allStations = stationsList;
        _filtered = stationsList;
      });
    } catch (e) {
      if (mounted) showSnack(context, '加载站点数据失败: $e');
    } finally {
      setState(() => _loadingStations = false);
    }
  }

  void _onSearchChanged() {
    final query = _searchCtrl.text.toLowerCase();
    setState(() {
      if (query.isEmpty) {
        _filtered = _allStations;
      } else {
        _filtered = _allStations.where((station) {
          final name = (station['name'] ?? '').toLowerCase();
          final telecode = (station['telecode'] ?? '').toLowerCase();
          final city = (station['city'] ?? '').toLowerCase();
          return name.contains(query) ||
              telecode.contains(query) ||
              city.contains(query);
        }).toList();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      height: MediaQuery.of(context).size.height * 0.8,
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                widget.title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _searchCtrl,
            focusNode: _searchFocus,
            decoration: InputDecoration(
              hintText: '搜索车站名称、拼音、电报码',
              prefixIcon: const Icon(Icons.search),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 12,
              ),
            ),
            autofocus: false,
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '共 ${_filtered.length} 个车站',
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).hintColor,
                  ),
                ),
                if (_searchCtrl.text.isNotEmpty)
                  TextButton(
                    onPressed: () {
                      _searchCtrl.clear();
                      _searchFocus.unfocus();
                    },
                    child: const Text('清空搜索'),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: _loadingStations
                ? const Center(child: CircularProgressIndicator())
                : _filtered.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.train, size: 64, color: Colors.grey),
                        const SizedBox(height: 16),
                        Text(
                          '未找到相关车站',
                          style: TextStyle(
                            fontSize: 16,
                            color: Theme.of(context).hintColor,
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    itemCount: _filtered.length,
                    itemBuilder: (context, index) {
                      final station = _filtered[index];
                      final code = station['code'] ?? station['telecode'] ?? '';
                      final name = station['name'] ?? '';
                      final telecode = station['telecode'] ?? '';
                      final city = station['city'] ?? '';
                      final selected = code == widget.selectedCode;
                      return ListTile(
                        leading: Icon(
                          Icons.fireplace_outlined,
                          color: selected
                              ? Theme.of(context).colorScheme.primary
                              : Theme.of(context).hintColor,
                        ),
                        title: Text(
                          '$name站',
                          style: TextStyle(
                            fontWeight: FontWeight.w500,
                            color: selected
                                ? Theme.of(context).colorScheme.primary
                                : Theme.of(context).colorScheme.onSurface,
                          ),
                        ),
                        subtitle: Text(
                          '$city市 电报码($telecode)',
                          style: TextStyle(
                            fontSize: 12,
                            color: Theme.of(context).hintColor,
                          ),
                        ),
                        trailing: selected
                            ? const Icon(Icons.check_circle, color: Colors.blue)
                            : null,
                        onTap: () {
                          Navigator.of(context).pop();
                          widget.onSelected({
                            'code': code,
                            'name': name,
                            'telecode': telecode,
                            'city': city,
                          });
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
