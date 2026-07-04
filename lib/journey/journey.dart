// journey.dart

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';

import '../models/journey_model.dart';
import '../providers/journey_provider.dart';
import '../config/station_selector.dart';
import 'custom_journey_page.dart';
import 'journey_toolbox_dialog.dart';
import '../config/app_settings.dart';
import '../config/functions.dart';
import '../config/data_enums.dart';
import '../widgets/error.dart';

part 'journey_search_ext.dart';
part 'journey_builders_ext.dart';
part 'journey_utils_ext.dart';

// 车次类型名称映射（顶层常量，part 文件可访问）
const Map<String, String> _trainTypeNames = {
  'C': '城际',
  'D': '动车',
  'G': '高速',
  'K': '快速',
  'T': '特快',
  'Z': '直达',
  'Y': '旅游',
  'L': '临客',
  'S': '市域',
  '数字': '普客',
};

class AddJourneyPage extends StatefulWidget {
  final String? initialTrainNumber;
  final bool autoSearchAndExpand;
  final String title;

  /// 自定义保存回调。如果提供，保存时调用此回调而不是默认的 JourneyProvider。
  /// 参数: trainInfo, date, stationList, isStation, fromStation, toStation, seatType, seatInfo
  final void Function({
    required Map<String, dynamic> trainInfo,
    required DateTime date,
    required List<dynamic> stationList,
    required bool isStation,
    required String fromStation,
    required String toStation,
    required String seatType,
    required String seatInfo,
  })? onSave;

  const AddJourneyPage({
    super.key,
    this.initialTrainNumber,
    this.autoSearchAndExpand = false,
    this.title = '添加旅途',
    this.onSave,
  });

  @override
  State<AddJourneyPage> createState() => _AddJourneyPageState();
}

class _AddJourneyPageState extends State<AddJourneyPage>
    with SingleTickerProviderStateMixin {
  DateTime? _selectedDate;
  final _trainNumberCtrl = TextEditingController();
  bool _loading = false;
  List<dynamic> _trainResults = [];
  int? _expandedIndex;
  late AnimationController _animCtrl;
  late Animation<double> _anim;
  String? _fromCode, _toCode;
  String? _fromName = '请选择', _toName = '请选择';
  List<dynamic> _stationResults = [];
  int? _stationExpandedIndex;
  final Map<int, List<dynamic>> _stationDetails = {};
  final Map<int, bool> _stationLoading = {};
  int _searchMode = 0;
  final Map<int, List<dynamic>> _trainDetails = {};
  final Map<int, bool> _trainLoading = {};

  // 缓存 sharyou 返回的完整数据（交路 + 车型），key 为 trainCode
  final Map<String, Map<String, dynamic>> _sharyouCache = {};

  // ── 分页 ──────────────────────────────────────────────────
  final int _journeyPageSize = 50;
  int _trainCurrentPage = 1;
  int _stationCurrentPage = 1;
  final TextEditingController _trainPageCtrl = TextEditingController(text: '1');
  final TextEditingController _stationPageCtrl = TextEditingController(text: '1');

  // 车次类型筛选（车站查询模式）
  // key: 类型前缀（如 G/D/C/K 等），value: 是否选中
  final Map<String, bool> _trainTypeFilters = {};
  // 出发站/到达站筛选（车站查询模式）
  String? _filterFromStation;
  String? _filterToStation;
  // 筛选器折叠状态
  bool _filterExpanded = false;


  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _anim = CurvedAnimation(parent: _animCtrl, curve: Curves.easeInOut);
    _loadStationNameMap();
    _trainNumberCtrl.addListener(() {
      final text = _trainNumberCtrl.text;
      if (text.isNotEmpty && text != text.toUpperCase()) _formatInput(text);
    });
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    // 记录模式默认今天，行程模式默认明天
    _selectedDate = widget.onSave != null ? today : today.add(const Duration(days: 1));

    if (widget.initialTrainNumber != null &&
        widget.initialTrainNumber!.isNotEmpty) {
      _trainNumberCtrl.text = widget.initialTrainNumber!;
      _searchMode = 0; // 强制车次查询模式
      _selectedDate = today;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _searchTrain(); // 自动触发搜索
      });
    }
  }

  Map<String, String> _stationNameMap = {};

  String _normalizeStationName(String name) {
    if (name.isEmpty) return '';
    // 移除"站"字和空格
    return name.replaceAll('站', '').replaceAll(' ', '').trim();
  }

  Future<void> _loadStationNameMap() async {
    try {
      final stationsList = await loadStations();
      final Map<String, String> nameMap = {};
      for (var station in stationsList) {
        final telecode = station['telecode'];
        final name = station['name'];
        if (telecode != null && name != null) {
          nameMap[telecode] = name;
        }
      }
      if (mounted) setState(() => _stationNameMap = nameMap);
    } catch (e) { logError(from: 'journey/_loadStationNameMap', error: e.toString()); }
  }

  String _getStationName(String telecode) {
    final name = _stationNameMap[telecode.replaceAll(' ', '')] ?? telecode;
    return name.contains(RegExp(r'[a-zA-Z]')) ? '始发站  (环线)' : name;
  }

  String _cleanStationName(String name) {
    return name.replaceAll(' ', '');
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    _trainNumberCtrl.dispose();
    _trainPageCtrl.dispose();
    _stationPageCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final daytwo = today.add(const Duration(days: -2));
    final tomorrow = today.add(const Duration(days: 1));
    final maxDate = today.add(const Duration(days: 14));
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? tomorrow,
      firstDate: daytwo,
      lastDate: maxDate,
    );
    if (picked != null) {
      setState(() {
        _selectedDate = picked;
        _expandedIndex = null;
        _stationExpandedIndex = null;
        _trainDetails.clear();
        _trainLoading.clear();
        _stationDetails.clear();
        _stationLoading.clear();
        _sharyouCache.clear();
        _trainCurrentPage = 1;
        _trainPageCtrl.text = '1';
        _stationCurrentPage = 1;
        _stationPageCtrl.text = '1';
        if (_animCtrl.isAnimating) _animCtrl.reset();
      });
    }
  }

  String get dateText => _selectedDate == null
      ? "选择日期"
      : "${_selectedDate!.year}-${_selectedDate!.month.toString().padLeft(2, '0')}-${_selectedDate!.day.toString().padLeft(2, '0')}";

  String get _formattedDate => _selectedDate == null
      ? ""
      : "${_selectedDate!.year}${_selectedDate!.month.toString().padLeft(2, '0')}${_selectedDate!.day.toString().padLeft(2, '0')}";

  void _switchMode(int mode) {
    if (_searchMode == mode) return;
    setState(() {
      _searchMode = mode;
      _expandedIndex = null;
      _stationExpandedIndex = null;
      _trainDetails.clear();
      _trainLoading.clear();
      _stationDetails.clear();
      _stationLoading.clear();
      _sharyouCache.clear();
      _trainTypeFilters.clear();
      _filterFromStation = null;
      _filterToStation = null;
      _fromStationOptions.clear();
      _toStationOptions.clear();
      _filterExpanded = false;
      _trainCurrentPage = 1;
      _trainPageCtrl.text = '1';
      _stationCurrentPage = 1;
      _stationPageCtrl.text = '1';
      if (_animCtrl.isAnimating) _animCtrl.reset();
    });
  }

  List<String> _fromStationOptions = [];
  List<String> _toStationOptions = [];

  Future<void> _showStationSelector(bool isFrom) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => StationSelector(
        title: isFrom ? '选择出发站' : '选择到达站',
        crOnly: true,
        selectedCode: isFrom ? _fromCode : _toCode,
        onSelected: (result) {
          if (mounted) {
            setState(() {
              if (isFrom) {
                _fromCode = result['telecode'];
                _fromName = result['name'];
              } else {
                _toCode = result['telecode'];
                _toName = result['name'];
              }
            });
          }
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          if ((_searchMode == 0 && _trainResults.isNotEmpty) ||
              (_searchMode == 1 && _stationResults.isNotEmpty))
            IconButton(
              icon: const Icon(Icons.close),
              onPressed: _clearResults,
              tooltip: '清除搜索结果',
            ),
          if (widget.onSave == null)
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert),
              onSelected: (v) {
                if (v == 'custom') {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const CustomJourneyPage()),
                  );
                }
              },
              itemBuilder: (_) => const [
                PopupMenuItem(
                  value: 'custom',
                  child: Row(
                    children: [
                      Icon(
                        Icons.edit_location_alt,
                        size: 18,
                        color: Colors.purple,
                      ),
                      SizedBox(width: 10),
                      Text('自定义旅途'),
                    ],
                  ),
                ),
              ],
            ),
        ],
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              // 日期选择器 - 使用主题色边框
              Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: _pickDate,
                      child: Container(
                        height: 56,
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: Theme.of(
                              context,
                            ).colorScheme.outline.withValues(alpha: 0.5),
                          ),
                          borderRadius: BorderRadius.circular(12),
                          color: Theme.of(context).colorScheme.surface,
                        ),
                        alignment: Alignment.centerLeft,
                        child: Row(
                          children: [
                            Icon(
                              Icons.calendar_today,
                              size: 20,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              dateText,
                              style: TextStyle(
                                fontSize: 16,
                                color: _selectedDate == null
                                    ? Theme.of(
                                        context,
                                      ).colorScheme.onSurfaceVariant
                                    : Theme.of(context).colorScheme.onSurface,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // SegmentedButton - 保持原样
              Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                ),
                child: SegmentedButton<int>(
                  segments: const [
                    ButtonSegment(
                      value: 0,
                      label: Text('车次查询', style: TextStyle(fontSize: 16)),
                      icon: Icon(Icons.train, size: 20),
                    ),
                    ButtonSegment(
                      value: 1,
                      label: Text('车站查询', style: TextStyle(fontSize: 16)),
                      icon: Icon(Icons.location_on, size: 20),
                    ),
                  ],
                  selected: {_searchMode},
                  onSelectionChanged: (Set<int> s) => _switchMode(s.first),
                  style: SegmentedButton.styleFrom(
                    backgroundColor: Theme.of(
                      context,
                    ).colorScheme.surfaceContainerHighest,
                    selectedBackgroundColor: Theme.of(
                      context,
                    ).colorScheme.primary,
                    selectedForegroundColor: Theme.of(
                      context,
                    ).colorScheme.onPrimary,
                    visualDensity: VisualDensity.compact,
                    minimumSize: const Size(0, 56),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              if (_searchMode == 0) ...[
                // 车次输入框 - 使用主题色
                SizedBox(
                  height: 56,
                  child: TextField(
                    controller: _trainNumberCtrl,
                    onChanged: (value) {
                      if (value.isNotEmpty) _formatInput(value);
                    },
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(
                        RegExp(r'[0-9GDCSKZTWPQgdcskztwpq1]'),
                      ),
                      TextInputFormatter.withFunction(
                        (oldValue, newValue) => newValue.copyWith(
                          text: newValue.text.toUpperCase(),
                        ),
                      ),
                    ],
                    decoration: InputDecoration(
                      hintText: "请输入车次",
                      hintStyle: TextStyle(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 0,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: Theme.of(context).colorScheme.outline,
                        ),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: Theme.of(context).colorScheme.outline,
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: Theme.of(context).colorScheme.primary,
                          width: 2,
                        ),
                      ),
                      filled: true,
                      fillColor: Theme.of(context).colorScheme.surface,
                    ),
                    style: TextStyle(
                      fontSize: 16,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                    maxLines: 1,
                  ),
                ),
                const SizedBox(height: 20),

                // 搜索按钮
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: _loading ? null : _searchTrain,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      foregroundColor: Theme.of(context).colorScheme.onPrimary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: _loading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation(Colors.white),
                            ),
                          )
                        : Text(
                            '搜索车次',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),
                ),
                const SizedBox(height: 20),

                // 车次列表结果
                _buildTrainList(),
              ],

              if (_searchMode == 1) ...[
                // 车站选择器 - 使用主题色
                Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () => _showStationSelector(true),
                        child: Container(
                          height: 56,
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: _fromCode != null
                                  ? Colors.blue
                                  : Theme.of(context).colorScheme.outline,
                            ),
                            borderRadius: BorderRadius.circular(12),
                            color: Theme.of(context).colorScheme.surface,
                          ),
                          alignment: Alignment.centerLeft,
                          child: Row(
                            children: [
                              Icon(
                                Icons.location_on,
                                size: 20,
                                color: _fromCode != null
                                    ? Colors.blue
                                    : Theme.of(
                                        context,
                                      ).colorScheme.onSurfaceVariant,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _fromName!,
                                  style: TextStyle(
                                    fontSize: 16,
                                    color: _fromCode != null
                                        ? Theme.of(
                                            context,
                                          ).colorScheme.onSurface
                                        : Theme.of(
                                            context,
                                          ).colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    GestureDetector(
                      onTap: () {
                        if (_fromCode != null || _toCode != null) {
                          setState(() {
                            final tmpCode = _fromCode;
                            final tmpName = _fromName;
                            _fromCode = _toCode;
                            _fromName = _toName;
                            _toCode = tmpCode;
                            _toName = tmpName;
                          });
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          Icons.swap_horiz,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                    Expanded(
                      child: GestureDetector(
                        onTap: () => _showStationSelector(false),
                        child: Container(
                          height: 56,
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: _toCode != null
                                  ? Colors.orange
                                  : Theme.of(context).colorScheme.outline,
                            ),
                            borderRadius: BorderRadius.circular(12),
                            color: Theme.of(context).colorScheme.surface,
                          ),
                          alignment: Alignment.centerLeft,
                          child: Row(
                            children: [
                              Icon(
                                Icons.location_on,
                                size: 20,
                                color: _toCode != null
                                    ? Colors.orange
                                    : Theme.of(
                                        context,
                                      ).colorScheme.onSurfaceVariant,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _toName!,
                                  style: TextStyle(
                                    fontSize: 16,
                                    color: _toCode != null
                                        ? Theme.of(
                                            context,
                                          ).colorScheme.onSurface
                                        : Theme.of(
                                            context,
                                          ).colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // 搜索按钮
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: _loading ? null : _searchStation,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      foregroundColor: Theme.of(context).colorScheme.onPrimary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: _loading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation(Colors.white),
                            ),
                          )
                        : Text(
                            '搜索车次',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),
                ),
                const SizedBox(height: 20),

                // 车站列表结果
                _buildStationList(),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
