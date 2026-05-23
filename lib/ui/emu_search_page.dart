// emu_search_page.dart
import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';

import '../functions.dart';
import '../main.dart';
import 'function/error.dart';
import 'function/more_search.dart';
import 'journey.dart';

// ============================================================
// 数据模型
// ============================================================

/// 搜索结果数据类（统一所有查询类型的结果）
class SearchResult {
  final String model;
  final String number;
  final String bureau;
  final String bureauFullName;
  final String? depot;
  final String? manufacturer;
  final String? stationinfo;
  final String? remarks;
  final String? routeInfo;
  final double? score;
  final int? rank;
  final bool isAmbiguousMatch;
  final bool isCoupledTrain;
  final String queryTime;
  final String? trainCodeForJourney;

  const SearchResult({
    required this.model,
    required this.number,
    required this.bureau,
    required this.bureauFullName,
    this.depot,
    this.manufacturer,
    this.stationinfo,
    this.remarks,
    this.routeInfo,
    this.score,
    this.rank,
    this.isAmbiguousMatch = false,
    this.isCoupledTrain = false,
    required this.queryTime,
    this.trainCodeForJourney,
  });
}

// ============================================================
// 工具函数（纯函数，无状态依赖）
// ============================================================

/// 去除非字母数字字符并转大写
String cleanString(String input) =>
    input.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '').toUpperCase();

/// 提取末四位数字
String? extractLastFour(String? text) {
  if (text == null || text.isEmpty) return null;
  final digits = text.replaceAll(RegExp(r'[^0-9]'), '');
  return digits.length >= 4 ? digits.substring(digits.length - 4) : null;
}

/// 计算输入与车组的匹配分数（0.0 ~ 1.0）
double calculateMatchScore(String input, String trainNumber, String modelCode) {
  final cleanedInput = cleanString(input);
  final cleanedTrainNumber = cleanString(trainNumber);
  final cleanedModelCode = cleanString(modelCode);

  final fullTrainNumber = '$cleanedModelCode$cleanedTrainNumber';
  if (cleanedInput == fullTrainNumber) return 1.0;

  double numberScore = 0.0;
  if (cleanedTrainNumber.isNotEmpty) {
    if (cleanedInput.endsWith(cleanedTrainNumber)) {
      numberScore = 1.0;
    } else if (cleanedTrainNumber.length >= 4) {
      final trainLastFour = cleanedTrainNumber.substring(
        cleanedTrainNumber.length - 4,
      );
      if (cleanedInput.contains(trainLastFour)) numberScore = 0.8;
    }
  }

  double modelScore = 0.0;
  if (cleanedInput.startsWith(cleanedModelCode)) {
    modelScore = 1.0;
  } else if (cleanedModelCode.startsWith(cleanedInput)) {
    modelScore = cleanedInput.length / cleanedModelCode.length;
  } else {
    int commonPrefix = 0;
    final minLength = min(cleanedInput.length, cleanedModelCode.length);
    for (
      var i = 0;
      i < minLength && cleanedInput[i] == cleanedModelCode[i];
      i++
    ) {
      commonPrefix++;
    }
    if (commonPrefix >= 4) {
      modelScore = commonPrefix / cleanedModelCode.length;
    } else if (commonPrefix >= 2) {
      modelScore = commonPrefix / cleanedModelCode.length * 0.6;
    }
  }

  double finalScore = 0.0;
  if (numberScore > 0 && modelScore > 0) {
    finalScore = numberScore * 0.7 + modelScore * 0.3;
  } else if (numberScore > 0) {
    finalScore = numberScore * 0.5;
  } else if (modelScore > 0) {
    finalScore = modelScore * 0.4;
  }

  return finalScore.clamp(0.0, 1.0);
}

/// 格式化当前时间为 "yyyy-MM-dd HH:mm:ss"
String nowQueryTime() => DateTime.now().toLocal().toString().substring(0, 19);

/// 格式化当前日期为 "yyyyMMdd"（用于12306 API）
String formattedToday() {
  final now = DateTime.now();
  return '${now.year}'
      '${now.month.toString().padLeft(2, '0')}'
      '${now.day.toString().padLeft(2, '0')}';
}

// ============================================================
// 数据加载辅助
// ============================================================

/// 从 trainData 中提取去重排序的路局列表
List<String> extractBureauNames(List<Map<String, dynamic>> trainData) {
  return trainData
      .map((r) => (r['配属路局'] ?? '').toString().trim())
      .where((b) => b.isNotEmpty)
      .toSet()
      .toList()
    ..sort();
}

/// 从 trainData 中提取去重排序的动车所列表
List<String> extractDepotNames(List<Map<String, dynamic>> trainData) {
  return trainData
      .map((r) => (r['配属动车所'] ?? '').toString().trim())
      .where((d) => d.isNotEmpty)
      .toSet()
      .toList()
    ..sort();
}

/// 从 trainData 中提取去重排序的车型代号列表
List<String> extractCarTypes(List<Map<String, dynamic>> trainData) {
  return trainData
      .map((r) => (r['type_code'] ?? '').toString().trim())
      .where((t) => t.isNotEmpty)
      .toSet()
      .toList()
    ..sort();
}

// ============================================================
// 本地数据查询逻辑
// ============================================================

/// 根据路局名在 bureauNames 中查找完整名称
String getBureauFullName(String bureauCode, List<String> bureauNames) {
  for (final fullName in bureauNames) {
    if (fullName.contains(bureauCode) || bureauCode.contains(fullName)) {
      return fullName;
    }
  }
  return bureauCode;
}

/// 路局过滤（返回排序后的记录列表）
List<Map<String, dynamic>> filterByBureau(
  List<Map<String, dynamic>> trainData,
  List<String> bureauNames,
  String bureauInput,
) {
  final pattern = bureauInput.trim().toLowerCase();
  final matched = trainData.where((record) {
    final bureau = (record['配属路局'] ?? '').toString().trim();
    if (bureau.isEmpty) return false;
    final fullName = getBureauFullName(bureau, bureauNames);
    return bureau.toLowerCase().contains(pattern) ||
        fullName.toLowerCase().contains(pattern);
  }).toList();

  matched.sort((a, b) {
    final modelA = a['type_code'] ?? '';
    final modelB = b['type_code'] ?? '';
    if (modelA != modelB) return modelA.compareTo(modelB);
    return (a['车组号'] ?? '').compareTo(b['车组号'] ?? '');
  });

  return matched;
}

/// 车型过滤（精确匹配，返回排序后的记录列表）
List<Map<String, dynamic>> filterByCarType(
  List<Map<String, dynamic>> trainData,
  String carTypeInput,
) {
  final pattern = carTypeInput.trim().toUpperCase();
  final matched = trainData
      .where(
        (record) =>
            (record['type_code'] ?? '').toString().trim().toUpperCase() ==
            pattern,
      )
      .toList();

  matched.sort((a, b) => (a['车组号'] ?? '').compareTo(b['车组号'] ?? ''));
  return matched;
}

/// 动车所过滤（返回排序后的记录列表）
List<Map<String, dynamic>> filterByDepot(
  List<Map<String, dynamic>> trainData,
  String depotInput,
) {
  final pattern = depotInput.trim().toLowerCase();
  final matched = trainData.where((record) {
    final depot = (record['配属动车所'] ?? '').toString().trim();
    return depot.isNotEmpty && depot.toLowerCase().contains(pattern);
  }).toList();

  matched.sort((a, b) {
    final modelA = a['type_code'] ?? '';
    final modelB = b['type_code'] ?? '';
    if (modelA != modelB) return modelA.compareTo(modelB);
    return (a['车组号'] ?? '').compareTo(b['车组号'] ?? '');
  });

  return matched;
}

/// 车号本地模糊匹配 + 评分，返回最优记录列表
/// 返回 null 表示无结果（调用方负责设置 errorMsg）
List<Map<String, dynamic>>? scoreAndSelectTrainId(
  List<Map<String, dynamic>> trainData,
  String input,
) {
  final cleanedInput = cleanString(input);
  final inputDigits = cleanedInput.replaceAll(RegExp(r'[^0-9]'), '');
  final hasFourDigits = inputDigits.length >= 4;

  // 粗筛
  List<Map<String, dynamic>> matches = trainData.where((record) {
    final trainNum = cleanString(record['车组号'] ?? '');
    return trainNum.contains(cleanedInput) || cleanedInput.contains(trainNum);
  }).toList();

  if (matches.isEmpty) return [];

  // 精确评分 + 末四位过滤
  final scored = <Map<String, dynamic>, double>{};
  for (final record in matches) {
    final model = record['type_code'] ?? '';
    final number = record['车组号'] ?? '';
    final score = calculateMatchScore(input, number, model);

    if (hasFourDigits) {
      final inputLastFour = inputDigits.substring(inputDigits.length - 4);
      final recordLastFour = extractLastFour(number);
      if (recordLastFour != inputLastFour) continue;
    }
    scored[record] = score;
  }

  if (scored.isEmpty) return null; // 区分"有粗筛无精筛"与"完全无匹配"

  final sortedEntries = scored.entries.toList()
    ..sort((a, b) => b.value.compareTo(a.value));
  final topScore = sortedEntries.first.value;

  if (topScore >= 0.9) {
    return sortedEntries
        .where((e) => e.value >= topScore - 0.05)
        .map((e) => e.key)
        .toList();
  } else {
    return sortedEntries.take(5).map((e) => e.key).toList();
  }
}

// ============================================================
// 网络请求层
// ============================================================

const _defaultHeaders = {'User-Agent': 'Mozilla/5.0'};

/// 查询始发终到站（12306 搜索接口）
Future<String?> fetchStationInfo(String trainCode) async {
  try {
    final date = formattedToday();
    final url =
        'https://search.12306.cn/search/v1/train/search?keyword=$trainCode&date=$date';
    final response = await http
        .get(Uri.parse(url), headers: _defaultHeaders)
        .timeout(const Duration(seconds: 10));

    if (response.statusCode != 200) return null;

    final data = json.decode(response.body) as Map<String, dynamic>;
    if (data['status'] != true || data['data'] == null) return null;

    for (final train in data['data'] as List) {
      final code = train['station_train_code']?.toString().trim() ?? '';
      final from = train['from_station']?.toString().trim() ?? '';
      final to = train['to_station']?.toString().trim() ?? '';
      if (code == trainCode && from.isNotEmpty && to.isNotEmpty) {
        return '$from ~ $to';
      }
    }
    return null;
  } catch (e) {
    logError(
      from: 'EmuSearchPage.fetchStationInfo',
      error: e.toString(),
      level: 2,
    );
    return null;
  }
}

/// 通过车次查询 emu_no（rail.re 数据源）
Future<http.Response?> fetchTrainByRailRe(String fullCode) => http.get(
  Uri.parse('https://api.rail.re/train/${fullCode.toUpperCase()}'),
  headers: _defaultHeaders,
);

/// 通过车次查询 emu_no（railGo 数据源）
Future<http.Response?> fetchTrainByRailGo(String fullCode) => http.get(
  Uri.parse(
    'https://emu.data.railgo.zenglingkun.cn/train/${fullCode.toUpperCase()}',
  ),
  headers: _defaultHeaders,
);

/// 通过车次查询 emu_no（12306 数据源），返回已格式化为 rail.re 格式的 Response
Future<http.Response?> fetchTrainBy12306(String fullCode) async {
  final url =
      'https://mobile.12306.cn/wxxcx/openplatform-inner/miniprogram/wifiapps/appFrontEnd/v2/lounge/open-smooth-common/trainStyleBatch/getCarDetail'
      '?carCode=&trainCode=${fullCode.toUpperCase()}&runningDay=0&reqType=form';
  final resp = await http.get(Uri.parse(url), headers: _defaultHeaders);
  if (resp.statusCode != 200) return null;

  final data = json.decode(resp.body) as Map<String, dynamic>;
  if (data['content'] == null ||
      data['content'] is! Map ||
      data['content']['data'] == null) {
    return null;
  }

  final carCode = data['content']['data']['carCode'] as String?;
  if (carCode == null || carCode.isEmpty) return null;

  final synthetic =
      '[{"DateTime":"${DateTime.now()}","emu_no":"$carCode","train_no":"${fullCode.toUpperCase()}"}]';
  return http.Response(synthetic, 200);
}

/// 查询车组当前担当交路（moeFactory 数据源）
Future<String?> fetchRouteByMoeFactory(String emuNo) async {
  try {
    final resp = await http
        .post(
          Uri.parse('https://rail.moefactory.com/api/emuSerialNumber/query'),
          headers: {
            ..._defaultHeaders,
            'Content-Type': 'application/x-www-form-urlencoded',
          },
          body: {'keyword': emuNo},
        )
        .timeout(const Duration(seconds: 10));

    if (resp.statusCode != 200 || resp.body.isEmpty) return null;

    final body = json.decode(resp.body) as Map<String, dynamic>;
    if (body['code'] != 200) return null;

    final data = body['data'] as List? ?? [];
    if (data.isEmpty) return null;

    final item = data[0];
    final trainNo = item['trainNumber']?.toString().trim() ?? '';
    final date = item['date']?.toString().trim() ?? '';
    return trainNo.isNotEmpty ? '正在担当: $date\n本务车次: $trainNo' : null;
  } catch (_) {
    return null;
  }
}

/// 查询车组当前担当交路（railGo 数据源）
Future<String?> fetchRouteByRailGo(String emuNo) async {
  try {
    final resp = await http
        .get(
          Uri.parse('https://emu.data.railgo.zenglingkun.cn/emu/$emuNo'),
          headers: _defaultHeaders,
        )
        .timeout(const Duration(seconds: 10));

    if (resp.statusCode != 200 || resp.body.isEmpty || resp.body == '[]')
      return null;

    final emuData = json.decode(resp.body) as List;
    if (emuData.isEmpty) return null;

    final item = emuData[0];
    final trainNo = item['train_no']?.toString().trim() ?? '';
    final date = item['date']?.toString() ?? '';
    return trainNo.isNotEmpty ? '正在担当: $date\n本务车次: $trainNo' : null;
  } catch (_) {
    return null;
  }
}

/// 查询车组当前担当交路（rail.re 数据源）
Future<String?> fetchRouteByRailRe(String emuNo) async {
  try {
    final resp = await http
        .get(
          Uri.parse('https://api.rail.re/emu/$emuNo'),
          headers: _defaultHeaders,
        )
        .timeout(const Duration(seconds: 10));

    if (resp.statusCode != 200 || resp.body.isEmpty || resp.body == '[]')
      return null;

    final emuData = json.decode(resp.body) as List;
    if (emuData.isEmpty) return null;

    final item = emuData[0];
    final trainNo = item['train_no']?.toString().trim() ?? '';
    final date = item['date']?.toString() ?? '';
    return trainNo.isNotEmpty ? '正在担当: $date\n本务车次: $trainNo' : null;
  } catch (_) {
    return null;
  }
}

/// 按 AppSettings 选择对应数据源查询交路
Future<String?> fetchRouteInfo(String emuNo, AppSettings settings) {
  if (settings.dataEmuSource == TrainEmuDataSource.moeFactory) {
    return fetchRouteByMoeFactory(emuNo);
  } else if (settings.dataEmuSource == TrainEmuDataSource.railGo) {
    return fetchRouteByRailGo(emuNo);
  } else {
    return fetchRouteByRailRe(emuNo);
  }
}

// ============================================================
// 分页状态封装
// ============================================================

class PaginationState {
  List<Map<String, dynamic>> allRecords;
  int currentPage;
  final int pageSize;
  int totalResults;
  String? currentSearchLabel;
  bool loadingPage;

  PaginationState({this.pageSize = 7})
    : allRecords = [],
      currentPage = 1,
      totalResults = 0,
      loadingPage = false;

  int get totalPages => (totalResults / pageSize).ceil();

  void reset() {
    allRecords = [];
    currentPage = 1;
    totalResults = 0;
    currentSearchLabel = null;
    loadingPage = false;
  }

  /// 返回当前页的记录切片
  List<Map<String, dynamic>> pageRecords(int page) {
    final start = (page - 1) * pageSize;
    final end = min(page * pageSize, allRecords.length);
    if (start >= allRecords.length) return [];
    return allRecords.sublist(start, end);
  }
}

// ============================================================
// Widget
// ============================================================

class SearchPage extends StatefulWidget {
  const SearchPage({super.key});

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  // --- 基础状态 ---
  String prefix = 'G';
  final TextEditingController controller = TextEditingController();
  late final TextEditingController _pageController;
  String searchType = 'trainCode';
  bool showRoutes = false;
  bool isLoading = false;
  String errorMsg = '';
  DateTime? lastSearchTime;

  // --- 数据 ---
  List<Map<String, dynamic>> trainData = [];
  List<String> _bureauNames = [];
  List<String> _depotNames = [];
  final List<SearchResult> _searchResults = [];

  // --- 分页 ---
  final _pagination = PaginationState();

  // ---- 快捷访问分页字段（对外保持原有风格）----
  int get _currentPage => _pagination.currentPage;

  int get _totalPages => _pagination.totalPages;

  int get _totalResults => _pagination.totalResults;

  bool get _loadingPage => _pagination.loadingPage;

  String? get _currentBureauSearch => _pagination.currentSearchLabel;

  @override
  void initState() {
    super.initState();
    _pageController = TextEditingController(text: '1');
    _loadConfig();
  }

  @override
  void dispose() {
    controller.dispose();
    _pageController.dispose();
    super.dispose();
  }

  // ============================================================
  // 数据初始化
  // ============================================================

  Future<void> _loadConfig() async {
    try {
      final loaded = await DataFileHelper.loadTrains();
      if (!mounted) return;
      setState(() {
        trainData = loaded;
        _bureauNames = extractBureauNames(loaded);
        _depotNames = extractDepotNames(loaded);
      });
    } catch (e) {
      logError(
        from: 'EmuSearchPage._loadConfig',
        error: e.toString(),
        level: 4,
      );
      if (mounted) setState(() => errorMsg = '加载数据失败: $e');
    }
  }

  // ============================================================
  // 辅助方法（依赖 state）
  // ============================================================

  String _getBureauFullName(String bureauCode) =>
      getBureauFullName(bureauCode, _bureauNames);

  List<String> _getAllCarTypes() => extractCarTypes(trainData);

  List<String> _getCommonBureauCodes() => List<String>.from(_bureauNames);

  void _resetPagination() {
    _pagination.reset();
    _pageController.text = '1';
  }

  // ============================================================
  // 分页加载
  // ============================================================

  void _loadBureauPage(int page) {
    if (_pagination.allRecords.isEmpty || page < 1 || page > _totalPages)
      return;

    setState(() => _pagination.loadingPage = true);

    final pageRecords = _pagination.pageRecords(page);
    final queryTime = nowQueryTime();

    final newResults = pageRecords.map((record) {
      final bureau = (record['配属路局'] ?? '').toString().trim();
      return SearchResult(
        model: record['type_code'] ?? '',
        number: record['车组号'] ?? '',
        bureau: bureau,
        bureauFullName: _getBureauFullName(bureau),
        depot: record['配属动车所']?.toString(),
        manufacturer: record['生产厂家']?.toString(),
        remarks: record['备注']?.toString(),
        queryTime: queryTime,
      );
    }).toList();

    setState(() {
      _searchResults
        ..clear()
        ..addAll(newResults);
      _pagination.currentPage = page;
      _pagination.loadingPage = false;
      _pageController.text = page.toString();
      isLoading = false;
    });
  }

  void _goToPage(int page) {
    if (page == _currentPage ||
        _loadingPage ||
        page < 1 ||
        page > _totalPages) {
      _pageController.text = _currentPage.toString();
      return;
    }
    _loadBureauPage(page);
  }

  // ============================================================
  // 搜索分支
  // ============================================================

  Future<void> _searchByBureau(String input) async {
    if (input.isEmpty) return;
    _beginSearch();

    final matched = filterByBureau(trainData, _bureauNames, input);
    if (matched.isEmpty) {
      setState(() {
        isLoading = false;
        errorMsg = '未找到匹配的路局';
      });
      return;
    }

    _pagination
      ..allRecords = matched
      ..totalResults = matched.length
      ..currentSearchLabel = input;

    _loadBureauPage(1);
  }

  Future<void> _searchByCarType(String input) async {
    if (input.isEmpty) return;
    _beginSearch();

    final matched = filterByCarType(trainData, input);
    if (matched.isEmpty) {
      setState(() {
        isLoading = false;
        errorMsg = '未找到车型 "$input"，请检查输入是否正确';
      });
      return;
    }

    _pagination
      ..allRecords = matched
      ..totalResults = matched.length
      ..currentSearchLabel = input.trim().toUpperCase();

    _loadBureauPage(1);
  }

  Future<void> _searchByDepot(String input) async {
    if (input.isEmpty) return;
    _beginSearch();

    final matched = filterByDepot(trainData, input);
    if (matched.isEmpty) {
      setState(() {
        isLoading = false;
        errorMsg = '未找到配属于"$input"的车辆';
      });
      return;
    }

    _pagination
      ..allRecords = matched
      ..totalResults = matched.length
      ..currentSearchLabel = input.trim();

    _loadBureauPage(1);
  }

  Future<void> _searchByTrainCode(
    String input,
    AppSettings settings,
    String queryTime,
  ) async {
    if (!RegExp(r'^[1-9]\d{0,3}$').hasMatch(input)) {
      setState(() => errorMsg = '车次数字格式错误（1-4位数字，不能以0开头）');
      return;
    }

    if (input == '9178' || input == '9169') {
      setState(() => errorMsg = '?你什么意思阿');
      return;
    }

    final fullCode = '$prefix$input';

    if (settings.dataSource == TrainDataSource.railGo) {
      logError(from: 'EmuSearchPage', error: 'RAILGO数据源已停用', level: 3);
      setState(() => errorMsg = 'RAILGO数据源已停用!请切换数据源!');
      return;
    }

    // 拉取 emu_no
    http.Response? resp;
    try {
      if (settings.dataSource == TrainDataSource.railRe) {
        resp = await fetchTrainByRailRe(fullCode);
      } else if (settings.dataSource == TrainDataSource.railGo) {
        resp = await fetchTrainByRailGo(fullCode);
      } else {
        resp = await fetchTrainBy12306(fullCode);
        if (resp == null) {
          setState(
            () => errorMsg = '车次不存在!\n当前数据源: ${_dataSourceLabel(settings)}',
          );
          return;
        }
      }
    } catch (e) {
      logError(
        from: 'EmuSearchPage._searchByTrainCode[fetch]',
        error: e.toString(),
        level: 4,
      );
    }

    if (resp == null) {
      setState(
        () => errorMsg =
            '请求失败，请检查网络连接或数据源设置\n当前数据源: ${_dataSourceLabel(settings)}',
      );
      return;
    }

    // 解析响应
    final List rawData = json.decode(resp.body);
    if (resp.body.isEmpty || resp.body == '[]' || rawData.isEmpty) {
      setState(
        () => errorMsg =
            '未查询到车次,请尝试:\n1.前往12306查询今日是否运行\n2.切换数据源查询\n当前数据源: ${_dataSourceLabel(settings)}',
      );
      return;
    }

    // 日期有效性检查（仅 railRe）
    if (settings.dataSource == TrainDataSource.railRe) {
      final error = _checkDateFreshness(rawData, settings);
      if (error != null) {
        setState(() => errorMsg = error);
        return;
      }
    }

    // 重联判断
    final first = rawData[0];
    final second = rawData.length > 1 ? rawData[1] : null;
    final sameRun =
        second != null &&
        first['date']?.toString() == second['date']?.toString();

    final emuNos = <String>[];
    final firstEmu = first['emu_no']?.toString().trim() ?? '';
    if (firstEmu.isNotEmpty) emuNos.add(firstEmu);
    if (sameRun) {
      final secondEmu = second['emu_no']?.toString().trim() ?? '';
      if (secondEmu.isNotEmpty) emuNos.add(secondEmu);
    }
    final uniqueEmuNos = emuNos.toSet().toList();

    if (uniqueEmuNos.isEmpty) {
      setState(
        () => errorMsg = 'API未返回车组号\n当前数据源: ${_dataSourceLabel(settings)}',
      );
      return;
    }

    // 查询交路（重联共用第一个）
    final routeInfo = await fetchRouteInfo(uniqueEmuNos.first, settings) ?? '';

    // 本地匹配 + 构建结果
    for (final emuNo in uniqueEmuNos) {
      final cleanedEmuNo = cleanString(emuNo);
      List<Map<String, dynamic>> exactMatches = trainData
          .where(
            (r) => cleanString('${r['type_code']}${r['车组号']}') == cleanedEmuNo,
          )
          .toList();

      if (exactMatches.isEmpty) {
        final lastFour = extractLastFour(emuNo);
        if (lastFour != null) {
          exactMatches = trainData
              .where((r) => extractLastFour(r['车组号']) == lastFour)
              .toList();
        }
      }

      for (final record in exactMatches) {
        final bureau = (record['配属路局'] ?? '').toString().trim();
        final stationinfo = await fetchStationInfo(fullCode);

        _searchResults.add(
          SearchResult(
            model: record['type_code'] ?? '',
            number: record['车组号'] ?? '',
            bureau: bureau,
            bureauFullName: _getBureauFullName(bureau),
            depot: record['配属动车所']?.toString(),
            manufacturer: record['生产厂家']?.toString(),
            stationinfo: stationinfo,
            remarks: record['备注']?.toString(),
            routeInfo: routeInfo.isNotEmpty ? routeInfo : null,
            score: 1.0,
            isAmbiguousMatch: exactMatches.length > 1,
            isCoupledTrain: uniqueEmuNos.length > 1,
            queryTime: queryTime,
            trainCodeForJourney: fullCode,
          ),
        );
      }
    }
  }

  Future<void> _searchByTrainId(
    String input,
    AppSettings settings,
    String queryTime,
  ) async {
    final cleanedInput = cleanString(input);
    if (cleanedInput.length < 4) {
      setState(() => errorMsg = '请输入至少4位有效字符');
      return;
    }

    final inputDigits = cleanedInput.replaceAll(RegExp(r'[^0-9]'), '');
    final hasFourDigits = inputDigits.length >= 4;

    final bestRecords = scoreAndSelectTrainId(trainData, input);
    if (bestRecords == null || bestRecords.isEmpty) {
      setState(
        () => errorMsg = bestRecords == null
            ? (hasFourDigits ? '未找到末四位匹配的车组' : '未找到匹配车组')
            : '本地未找到匹配车组',
      );
      return;
    }

    // 并行查交路
    final Map<String, String?> routeMap = {};
    if (showRoutes) {
      await Future.wait(
        bestRecords.map((record) async {
          final emuNo = cleanString('${record['type_code']}${record['车组号']}');
          try {
            routeMap[emuNo] = await fetchRouteInfo(emuNo, settings);
          } catch (_) {
            routeMap[emuNo] = null;
          }
        }),
      );
    }

    // 重新计算分数映射（用于 rank / score 字段）
    final scoredMap = <Map<String, dynamic>, double>{};
    for (final record in bestRecords) {
      scoredMap[record] = calculateMatchScore(
        input,
        record['车组号'] ?? '',
        record['type_code'] ?? '',
      );
    }

    // 构建结果
    for (int i = 0; i < bestRecords.length; i++) {
      final record = bestRecords[i];
      final bureau = (record['配属路局'] ?? '').toString().trim();
      final emuNo = cleanString('${record['type_code']}${record['车组号']}');

      String? trainCodeForJourney;
      if (showRoutes && routeMap[emuNo] != null) {
        final match = RegExp(
          r'本务车次:\s*([^\s\n]+)',
        ).firstMatch(routeMap[emuNo]!);
        trainCodeForJourney = match?.group(1)?.trim();
      }

      _searchResults.add(
        SearchResult(
          model: record['type_code'] ?? '',
          number: record['车组号'] ?? '',
          bureau: bureau,
          bureauFullName: _getBureauFullName(bureau),
          depot: record['配属动车所']?.toString(),
          manufacturer: record['生产厂家']?.toString(),
          remarks: record['备注']?.toString(),
          score: scoredMap[record],
          rank: i + 1,
          routeInfo: showRoutes ? routeMap[emuNo] : null,
          queryTime: queryTime,
          trainCodeForJourney: trainCodeForJourney,
        ),
      );
    }
  }

  // ============================================================
  // 主搜索入口
  // ============================================================

  void _beginSearch() {
    setState(() {
      isLoading = true;
      errorMsg = '';
      _searchResults.clear();
      _resetPagination();
    });
  }

  Future<void> _performSearch() async {
    if (isLoading) return;

    final input = controller.text.trim();
    if (input.isEmpty) {
      setState(() => errorMsg = '请输入查询内容');
      return;
    }

    _beginSearch();

    final settings = Provider.of<AppSettings>(context, listen: false);
    final queryTime = nowQueryTime();

    try {
      switch (searchType) {
        case 'bureau':
          await _searchByBureau(input);
          return; // 分页搜索自行管理 isLoading
        case 'carType':
          await _searchByCarType(input);
          return;
        case 'depot':
          await _searchByDepot(input);
          return;
        case 'trainCode':
          await _searchByTrainCode(input, settings, queryTime);
          lastSearchTime = DateTime.now();
        case 'trainId':
          await _searchByTrainId(input, settings, queryTime);
          if (showRoutes) lastSearchTime = DateTime.now();
      }
    } catch (e) {
      logError(
        from: 'EmuSearchPage._performSearch',
        error: e.toString(),
        level: 4,
      );
      setState(() => errorMsg = '查询失败: $e');
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  // ============================================================
  // 私有辅助
  // ============================================================

  String _dataSourceLabel(AppSettings settings) =>
      settings.dataSource.toString().split('.').last;

  /// 检查 rail.re 数据日期新鲜度，返回 errorMsg 或 null
  String? _checkDateFreshness(List<dynamic> data, AppSettings settings) {
    DateTime? latestDate;
    for (final item in data) {
      final emuDate = item['date']?.toString().trim() ?? '';
      if (emuDate.isEmpty) continue;
      try {
        final datePart = emuDate.contains(' ')
            ? emuDate.split(' ')[0]
            : emuDate;
        final parsed = DateTime.parse(datePart);
        if (latestDate == null || parsed.isAfter(latestDate)) {
          latestDate = parsed;
        }
      } catch (_) {}
    }

    if (latestDate == null) {
      return '无法解析车次日期\n当前数据源: ${_dataSourceLabel(settings)}';
    }

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final latestDay = DateTime(
      latestDate.year,
      latestDate.month,
      latestDate.day,
    );
    if (latestDay.difference(today).inDays.abs() > 2) {
      return '车次过期! 时间过久可尝试切换数据源';
    }
    return null;
  }

  void _handleBureauChipTap(String bureauName) {
    controller.text = bureauName;
    _performSearch();
  }

  void _changeSearchType(String newType) {
    if (searchType == newType) return;
    setState(() {
      searchType = newType;
      controller.clear();
      _searchResults.clear();
      errorMsg = '';
      _resetPagination();
      if (newType == 'trainId') showRoutes = false;
    });
  }

  // ============================================================
  // UI 组件
  // ============================================================

  Widget _buildSearchBar() {
    return Row(
      children: [
        if (searchType == 'trainCode')
          DropdownButton<String>(
            value: prefix,
            items: ['G', 'D', 'C']
                .map(
                  (v) => DropdownMenuItem(
                    value: v,
                    child: Text(v, style: const TextStyle(fontSize: 18)),
                  ),
                )
                .toList(),
            onChanged: (v) => setState(() => prefix = v!),
          ),
        const SizedBox(width: 12),
        Expanded(child: _buildTextField()),
        const SizedBox(width: 12),
        ElevatedButton(
          onPressed: isLoading ? null : _performSearch,
          style: ElevatedButton.styleFrom(
            minimumSize: const Size(80, 56),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: Text(isLoading ? '查询中...' : '查询'),
        ),
      ],
    );
  }

  Widget _buildTextField() {
    final labels = {
      'trainCode': ('输入车次数字（1-4位）', '如: 31'),
      'trainId': ('输入车号', '如: CR400AF-AZ-2311'),
      'carType': ('输入车型代号', '如: CRH6F-A'),
      'bureau': ('输入路局名称', '如: 上局 或 上海铁路局'),
      'depot': ('输入动车所名称', '如: 上海动车段'),
    };
    final (label, hint) = labels[searchType] ?? ('输入查询内容', '');

    return TextField(
      controller: controller,
      keyboardType: TextInputType.text,
      inputFormatters: searchType == 'trainCode'
          ? [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(4),
              TextInputFormatter.withFunction(
                (old, newV) => newV.text.startsWith('0') && newV.text.length > 1
                    ? old
                    : newV,
              ),
            ]
          : [],
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        border: const OutlineInputBorder(),
        filled: true,
      ),
      onSubmitted: (_) => _performSearch(),
    );
  }

  Widget _buildSearchTypeRow() {
    return Row(
      children: [
        Expanded(
          child: _buildSearchTypeChip(
            label: '车次查询',
            icon: Icons.numbers,
            isSelected: searchType == 'trainCode',
            onTap: () => _changeSearchType('trainCode'),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _buildSearchTypeChip(
            label: '车号查询',
            icon: Icons.confirmation_number,
            isSelected: searchType == 'trainId',
            onTap: () => _changeSearchType('trainId'),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(child: _buildMoreMenu()),
      ],
    );
  }

  Widget _buildSearchTypeChip({
    required String label,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: isSelected
              ? theme.colorScheme.primary
              : theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? theme.colorScheme.primary
                : theme.colorScheme.outlineVariant,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: isSelected
                  ? theme.colorScheme.onPrimary
                  : theme.colorScheme.onSurface,
              size: 22,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                color: isSelected
                    ? theme.colorScheme.onPrimary
                    : theme.colorScheme.onSurface,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMoreMenu() {
    final theme = Theme.of(context);
    final isMoreSelected = const {
      'carType',
      'bureau',
      'depot',
    }.contains(searchType);

    return PopupMenuButton<String>(
      onSelected: _changeSearchType,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      position: PopupMenuPosition.under,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: isMoreSelected
              ? theme.colorScheme.primary
              : theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isMoreSelected
                ? theme.colorScheme.primary
                : theme.colorScheme.outlineVariant,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.more_horiz,
              color: isMoreSelected
                  ? theme.colorScheme.onPrimary
                  : theme.colorScheme.onSurface,
              size: 22,
            ),
            const SizedBox(height: 4),
            const Text(
              '更多',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
            ),
          ],
        ),
      ),
      itemBuilder: (context) => const [
        PopupMenuItem(
          value: 'carType',
          child: ListTile(
            leading: Icon(Icons.card_travel_rounded),
            title: Text('车型查询'),
            dense: true,
          ),
        ),
        PopupMenuItem(
          value: 'bureau',
          child: ListTile(
            leading: Icon(Icons.business),
            title: Text('路局查询'),
            dense: true,
          ),
        ),
        PopupMenuItem(
          value: 'depot',
          child: ListTile(
            leading: Icon(Icons.warehouse_outlined),
            title: Text('动车所查询'),
            dense: true,
          ),
        ),
      ],
    );
  }

  Widget _buildRouteToggleCard() {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: Column(
        children: [
          CheckboxListTile(
            title: const Text('显示交路信息'),
            subtitle: const Text('启用后将应用3秒冷却时间'),
            value: showRoutes,
            onChanged: (v) => setState(() => showRoutes = v!),
            dense: true,
            controlAffinity: ListTileControlAffinity.leading,
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Text('不显示交路信息时无冷却时间限制', style: TextStyle(fontSize: 12)),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    final isPaginated = const {
      'bureau',
      'carType',
      'depot',
    }.contains(searchType);

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 40),
      child: Column(
        children: [
          Icon(switch (searchType) {
            'trainCode' => Icons.numbers,
            'trainId' => Icons.confirmation_number,
            'carType' => Icons.card_travel_rounded,
            'bureau' => Icons.business,
            'depot' => Icons.warehouse_outlined,
            _ => Icons.train_outlined,
          }, size: 64),
          const SizedBox(height: 16),
          Text(
            switch (searchType) {
              'trainCode' => '请输入车次数字进行查询\n（例如：25）',
              'trainId' => '请输入车号进行查询',
              'carType' => '请输入车型进行查询',
              'bureau' => '请输入路局名称或点击下方简称查询',
              _ => '请输入动车所名称或点击下方快捷查询',
            },
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 16),
          ),
          if (searchType == 'trainCode') _buildTrainCodePrefixChips(),
          if (searchType == 'carType')
            _buildQuickChips(
              title: '所有可查车型:',
              items: _getAllCarTypes(),
              onTap: (item) {
                controller.text = item;
                _performSearch();
              },
            ),
          if (searchType == 'bureau')
            _buildQuickChips(
              title: '支持的路局简称:',
              items: _getCommonBureauCodes(),
              onTap: _handleBureauChipTap,
            ),
          if (searchType == 'depot')
            _buildQuickChips(
              title: '所有动车所:',
              items: _depotNames,
              onTap: (item) {
                controller.text = item;
                _performSearch();
              },
            ),
        ],
      ),
    );
  }

  Widget _buildTrainCodePrefixChips() {
    return Column(
      children: [
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: ['G', 'D', 'C']
              .map(
                (p) => Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: FilterChip(
                    label: Text(p),
                    selected: prefix == p,
                    onSelected: (s) => s ? setState(() => prefix = p) : null,
                  ),
                ),
              )
              .toList(),
        ),
      ],
    );
  }

  Widget _buildQuickChips({
    required String title,
    required List<String> items,
    required void Function(String) onTap,
  }) {
    return Column(
      children: [
        const SizedBox(height: 20),
        Text(title),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 4,
          alignment: WrapAlignment.center,
          children: items
              .map(
                (item) => GestureDetector(
                  onTap: () => onTap(item),
                  child: Chip(label: Text(item)),
                ),
              )
              .toList(),
        ),
      ],
    );
  }

  Widget _buildResultCard(SearchResult result) {
    final settings = Provider.of<AppSettings>(context, listen: false);
    final isPaginated = const {
      'bureau',
      'carType',
      'depot',
    }.contains(searchType);

    final canNavigateToJourney =
        result.trainCodeForJourney != null &&
        result.trainCodeForJourney!.isNotEmpty &&
        (searchType == 'trainCode' || (searchType == 'trainId' && showRoutes));

    return InkWell(
      onTap: canNavigateToJourney
          ? () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => AddJourneyPage(
                  initialTrainNumber: result.trainCodeForJourney!,
                  autoSearchAndExpand: true,
                ),
              ),
            )
          : null,
      borderRadius: BorderRadius.circular(12),
      child: Card(
        elevation: 4,
        margin: const EdgeInsets.only(bottom: 12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildCardHeader(result, settings, isPaginated),
              const SizedBox(height: 12),
              _buildCardDetails(result),
              if (result.routeInfo != null && result.routeInfo!.isNotEmpty)
                _buildRouteInfoBox(result.routeInfo!),
              const SizedBox(height: 8),
              Text(
                '查询时间: ${result.queryTime}',
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).colorScheme.onSurface.withAlpha(150),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCardHeader(
    SearchResult result,
    AppSettings settings,
    bool isPaginated,
  ) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        TrainIconWidget(model: result.model, number: result.number, size: 32),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${result.model}-${result.number}',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (isPaginated)
                Text(
                  result.bureauFullName,
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurface.withAlpha(150),
                  ),
                ),
              if (result.isCoupledTrain)
                Text(
                  '可能为重联列车',
                  style: TextStyle(
                    fontSize: 11,
                    color: Theme.of(context).colorScheme.primary,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              if (result.isAmbiguousMatch)
                Text(
                  '存在多个匹配结果，请核对车号',
                  style: TextStyle(
                    fontSize: 11,
                    color: Theme.of(context).colorScheme.error,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              if (result.score != null) ...[
                const SizedBox(height: 4),
                buildScoreBar(context, result.score!, rank: result.rank),
              ],
            ],
          ),
        ),
        if (settings.showBureauIcons)
          BureauIconWidget(bureau: result.bureau, size: 32)
        else
          const SizedBox(width: 32, height: 32),
      ],
    );
  }

  Widget _buildCardDetails(SearchResult result) {
    final isPaginated = const {
      'bureau',
      'carType',
      'depot',
    }.contains(searchType);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (result.bureau.isNotEmpty && !isPaginated)
          buildInfoRow('配属路局', result.bureauFullName),
        if (result.depot != null && result.depot!.isNotEmpty)
          buildInfoRow('配属动车所', result.depot!),
        if (result.manufacturer != null && result.manufacturer!.isNotEmpty)
          buildInfoRow('生产厂家', result.manufacturer!),
        if (result.stationinfo != null)
          buildInfoRow('运行交路', result.stationinfo!),
        if (result.remarks != null && result.remarks!.isNotEmpty)
          buildInfoRow('备注', result.remarks!),
      ],
    );
  }

  Widget _buildRouteInfoBox(String routeInfo) {
    return Column(
      children: [
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primary.withAlpha(20),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: routeInfo
                .split('\n')
                .map(
                  (line) => Text(
                    line,
                    style: TextStyle(
                      fontSize: 14,
                      color: Theme.of(
                        context,
                      ).colorScheme.onSurface.withAlpha(200),
                    ),
                  ),
                )
                .toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildErrorSection(AppSettings settings) {
    return Column(
      children: [
        buildErrorCard(context, errorMsg, () => setState(() => errorMsg = '')),
        const SizedBox(height: 12),
        if (searchType == 'trainCode')
          IntrinsicHeight(
            child: Row(
              children: [
                Expanded(
                  child: Tool.buildTrainDataSourceCard(
                    context: context,
                    settings: settings,
                    source: TrainDataSource.railRe,
                    title: 'Rail.re',
                    description: '第三方数据源',
                    icon: Icons.cloud_upload,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Tool.buildTrainDataSourceCard(
                    context: context,
                    settings: settings,
                    source: TrainDataSource.official12306,
                    title: '12306',
                    description: '官方数据源',
                    icon: Icons.train,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildPaginationControls() => buildPaginationControls(
    context: context,
    currentPage: _currentPage,
    totalPages: _totalPages,
    totalResults: _totalResults,
    loadingPage: _loadingPage,
    pageController: _pageController,
    onGoToPage: _goToPage,
  );

  // ============================================================
  // build
  // ============================================================

  @override
  Widget build(BuildContext context) {
    final settings = Provider.of<AppSettings>(context);
    final isPaginated = const {
      'bureau',
      'carType',
      'depot',
    }.contains(searchType);
    final displayedCount = _searchResults.length;
    final totalCount = isPaginated ? _totalResults : displayedCount;

    return Scaffold(
      appBar: AppBar(
        title: const Text('动车组查询'),
        centerTitle: true,
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            onSelected: (value) {
              if (value == 'coach') {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const CoachSearchPage()),
                );
              } else if (value == 'loco') {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const LocoSearchPage()),
                );
              }
            },
            itemBuilder: (_) => const [
              PopupMenuItem(
                value: 'coach',
                child: ListTile(
                  leading: Icon(Icons.directions_railway),
                  title: Text('客车查询'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              PopupMenuItem(
                value: 'loco',
                child: ListTile(
                  leading: Icon(Icons.train),
                  title: Text('机车查询'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ],
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildSearchBar(),
            const SizedBox(height: 20),
            _buildSearchTypeRow(),
            const SizedBox(height: 20),
            if (searchType == 'trainId') _buildRouteToggleCard(),
            if (searchType == 'trainId') const SizedBox(height: 20),

            if (isLoading && _searchResults.isEmpty)
              const Center(child: CircularProgressIndicator()),

            if (errorMsg.isNotEmpty) _buildErrorSection(settings),

            if (_searchResults.isNotEmpty) ...[
              buildResultCountBar(
                context,
                label: isPaginated
                    ? '$_currentBureauSearch 共 $totalCount 条（当前 $displayedCount 条）'
                    : '共找到 $totalCount 条结果',
                onClear: () => setState(() {
                  _searchResults.clear();
                  controller.clear();
                  errorMsg = '';
                  _resetPagination();
                }),
              ),
              const SizedBox(height: 12),
              if (isPaginated) _buildPaginationControls(),
              for (final result in _searchResults) _buildResultCard(result),
              if (_loadingPage)
                const Center(child: CircularProgressIndicator()),
            ],

            const SizedBox(height: 40),

            if (!isLoading && errorMsg.isEmpty && _searchResults.isEmpty)
              _buildEmptyState(),
          ],
        ),
      ),
    );
  }
}
