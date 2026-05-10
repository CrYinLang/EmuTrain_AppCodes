// ui/function/custom_journey_page.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../journey_model.dart';
import '../journey_provider.dart';
import '../station_selector.dart';

// 内部数据模型：可编辑站点
class _EditableStation {
  String name;
  bool isCustom; // true = 自定义，false = 国铁
  String telecode; // 仅国铁有效
  String arrivalTime;
  String departureTime;
  int stayMinutes;
  int dayDiff;

  _EditableStation({
    required this.name,
    this.isCustom = false,
    this.telecode = '',
    this.arrivalTime = '--:--',
    this.departureTime = '--:--',
    this.stayMinutes = 0,
    this.dayDiff = 0,
  });

  StationDetail toStationDetail({required bool isStart, required bool isEnd}) {
    final stay = stayMinutes;
    return StationDetail(
      stationName: name,
      arrivalTime: arrivalTime,
      departureTime: departureTime,
      stayTime: stay,
      dayDifference: dayDiff,
      isStart: isStart,
      isEnd: isEnd,
    );
  }
}

// 入口 Widget
class CustomJourneyPage extends StatefulWidget {
  const CustomJourneyPage({super.key});

  @override
  State<CustomJourneyPage> createState() => _CustomJourneyPageState();
}

class _CustomJourneyPageState extends State<CustomJourneyPage> {
  //  基本信息 
  final _trainCodeCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();
  DateTime _travelDate = DateTime.now().add(const Duration(days: 1));

  //  座位 
  String _seatType = 'ze_num';
  String _customSeatTypeName = ''; // 自定义座位类型名称
  final _seatInfoCtrl = TextEditingController();

  //  站点 
  final List<_EditableStation> _stations = [];
  int? _fromIdx; // 上车站下标
  int? _toIdx; // 下车站下标

  //  表单相关 
  final _formKey = GlobalKey<FormState>();
  bool _saving = false;
  bool _onboardingShown = false; // 新手引导只弹一次

  //  常量 
  static const _seatTypes = {
    'ze_num': '二等座',
    'zy_num': '一等座',
    'swz_num': '商务座',
    'tz_num': '特等座',
    'gg_num': '优选一等座',
    'rw_num': '软卧',
    'srrb_num': '动卧',
    'yw_num': '硬卧',
    'rz_num': '软座',
    'yz_num': '硬座',
    'wz_num': '无座',
    'gr_num': '高级软卧',
    'custom_num': '自定义…',
  };

  @override
  void dispose() {
    _trainCodeCtrl.dispose();
    _noteCtrl.dispose();
    _seatInfoCtrl.dispose();
    super.dispose();
  }

    // 工具方法
  
  bool get _hasCustomStation => _stations.any((s) => s.isCustom);

  void _maybeShowOnboardingHint() {
    if (_onboardingShown) return;
    if (_stations.length < 2) return; // 至少2站才提示
    _onboardingShown = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          icon: const Icon(
            Icons.lightbulb_outline,
            color: Colors.orange,
            size: 32,
          ),
          title: const Text('设置上下车站'),
          content: const Text(
            '添加完所有站点后，点击站点卡片可以：'
            '• 设为上车站（绿色边框）'
            '• 设为下车站（橙色边框）'
            '• 编辑到达和出发时间'
            '• 设置跨天（如次日到达）'
            '上车站和下车站都设置好后，才能点击右上角「保存」。',
            style: TextStyle(height: 1.6),
          ),
          actions: [
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('知道了'),
            ),
          ],
        ),
      );
    });
  }

  void _showSnack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), duration: const Duration(seconds: 2)),
    );
  }

  String _dateText(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

    // 日期选择
  
  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _travelDate,
      firstDate: now.subtract(const Duration(days: 365)),
      lastDate: now.add(const Duration(days: 730)),
    );
    if (picked != null) setState(() => _travelDate = picked);
  }

    // 添加站点
  
  void _showAddStationDialog() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _AddStationSheet(
        onAddRail: () {
          Navigator.pop(ctx);
          _pickRailStation();
        },
        onAddCustom: () {
          Navigator.pop(ctx);
          _showCustomStationDialog();
        },
      ),
    );
  }

  Future<void> _pickRailStation() async {
    // 注意：StationSelector 内部在 onSelected 前已经自己调用了 Navigator.pop()
    // 所以这里的 onSelected 回调里不能再 pop，否则会多弹一层关掉整个页面
    Map<String, String?>? result;
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => StationSelector(
        title: '选择国铁车站',
        onSelected: (r) {
          // StationSelector 已自行 pop，这里只记录结果即可
          result = r;
        },
      ),
    );
    if (result == null) return;
    final name = (result!['name'] ?? '').replaceAll('站', '').trim();
    if (name.isEmpty) return;
    setState(() {
      _stations.add(
        _EditableStation(
          name: name,
          isCustom: false,
          telecode: result!['telecode'] ?? '',
        ),
      );
      _maybeShowOnboardingHint();
    });
  }

  void _showCustomStationDialog({_EditableStation? existing, int? idx}) {
    final ctrl = TextEditingController(text: existing?.name ?? '');
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(existing == null ? '添加自定义车站' : '编辑车站名称'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: '输入车站名称（如：研究院站）',
            border: OutlineInputBorder(),
          ),
          inputFormatters: [LengthLimitingTextInputFormatter(20)],
          onSubmitted: (_) {
            _saveCustomStation(ctx, ctrl.text.trim(), existing, idx);
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () =>
                _saveCustomStation(ctx, ctrl.text.trim(), existing, idx),
            child: const Text('确认'),
          ),
        ],
      ),
    );
  }

  void _saveCustomStation(
    BuildContext ctx,
    String name,
    _EditableStation? existing,
    int? idx,
  ) {
    if (name.isEmpty) {
      _showSnack('站名不能为空');
      return;
    }
    Navigator.pop(ctx);
    setState(() {
      if (existing != null && idx != null) {
        _stations[idx] = _EditableStation(
          name: name,
          isCustom: true,
          arrivalTime: existing.arrivalTime,
          departureTime: existing.departureTime,
          stayMinutes: existing.stayMinutes,
          dayDiff: existing.dayDiff,
        );
      } else {
        _stations.add(_EditableStation(name: name, isCustom: true));
        _maybeShowOnboardingHint();
      }
    });
  }

    // 站点操作菜单
  
  void _showStationMenu(int idx) {
    final s = _stations[idx];
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _StationMenuSheet(
        stationName: s.name,
        isCustom: s.isCustom,
        isFrom: _fromIdx == idx,
        isTo: _toIdx == idx,
        onSetFrom: () {
          Navigator.pop(ctx);
          setState(() {
            _fromIdx = idx;
            if (_toIdx != null && _toIdx! <= idx) _toIdx = null;
          });
        },
        onSetTo: () {
          Navigator.pop(ctx);
          setState(() {
            _toIdx = idx;
            if (_fromIdx != null && _fromIdx! >= idx) _fromIdx = null;
          });
        },
        onEditTime: () {
          Navigator.pop(ctx);
          _showTimeEditor(idx);
        },
        onEditName: s.isCustom
            ? () {
                Navigator.pop(ctx);
                _showCustomStationDialog(existing: s, idx: idx);
              }
            : null,
        onDelete: () {
          Navigator.pop(ctx);
          _deleteStation(idx);
        },
        onEditDay: () {
          Navigator.pop(ctx);
          _showDayEditor(idx);
        },
      ),
    );
  }

  void _deleteStation(int idx) {
    setState(() {
      _stations.removeAt(idx);
      if (_fromIdx == idx) _fromIdx = null;
      if (_toIdx == idx) _toIdx = null;
      // 修正下标
      if (_fromIdx != null && _fromIdx! > idx) _fromIdx = _fromIdx! - 1;
      if (_toIdx != null && _toIdx! > idx) _toIdx = _toIdx! - 1;
    });
  }

    // 时间编辑
  
  void _showTimeEditor(int idx) {
    final s = _stations[idx];
    final arrCtrl = TextEditingController(
      text: s.arrivalTime == '--:--' ? '' : s.arrivalTime,
    );
    final depCtrl = TextEditingController(
      text: s.departureTime == '--:--' ? '' : s.departureTime,
    );
    final stayCtrl = TextEditingController(
      text: s.stayMinutes > 0 ? '${s.stayMinutes}' : '',
    );

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('编辑 ${s.name} 时间'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _TimeField(label: '到达时间', controller: arrCtrl, hint: '如 08:30'),
            const SizedBox(height: 12),
            _TimeField(label: '出发时间', controller: depCtrl, hint: '如 08:32'),
            const SizedBox(height: 12),
            TextField(
              controller: stayCtrl,
              keyboardType: TextInputType.number,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(3),
              ],
              decoration: const InputDecoration(
                labelText: '停站时长（分钟，可留空）',
                border: OutlineInputBorder(),
                suffixText: '分',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () {
              final arr = _normalizeTime(arrCtrl.text.trim());
              final dep = _normalizeTime(depCtrl.text.trim());
              final stay = int.tryParse(stayCtrl.text.trim()) ?? 0;

              // 自动推算停站时长
              int calcStay = stay;
              if (calcStay == 0 && arr != '--:--' && dep != '--:--') {
                calcStay = _minutesBetween(arr, dep);
              }

              setState(() {
                _stations[idx] = _EditableStation(
                  name: s.name,
                  isCustom: s.isCustom,
                  telecode: s.telecode,
                  arrivalTime: arr,
                  departureTime: dep,
                  stayMinutes: calcStay,
                  dayDiff: s.dayDiff,
                );
              });
              Navigator.pop(ctx);
            },
            child: const Text('保存'),
          ),
        ],
      ),
    );
  }

  void _showDayEditor(int idx) {
    final s = _stations[idx];
    int day = s.dayDiff;
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) => AlertDialog(
          title: Text('${s.name} 跨天设置'),
          content: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                icon: const Icon(Icons.remove_circle_outline),
                onPressed: day > 0 ? () => setD(() => day--) : null,
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  day == 0 ? '当天' : '+$day 天',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.add_circle_outline),
                onPressed: day < 7 ? () => setD(() => day++) : null,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('取消'),
            ),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  _stations[idx] = _EditableStation(
                    name: s.name,
                    isCustom: s.isCustom,
                    telecode: s.telecode,
                    arrivalTime: s.arrivalTime,
                    departureTime: s.departureTime,
                    stayMinutes: s.stayMinutes,
                    dayDiff: day,
                  );
                });
                Navigator.pop(ctx);
              },
              child: const Text('保存'),
            ),
          ],
        ),
      ),
    );
  }

  String _normalizeTime(String t) {
    if (t.isEmpty) return '--:--';
    // 接受 "830" → "08:30"，"8:30" → "08:30"
    final cleaned = t.replaceAll('：', ':').replaceAll(' ', '');
    if (RegExp(r'^\d{1,2}:\d{2}$').hasMatch(cleaned)) {
      final parts = cleaned.split(':');
      final h = int.tryParse(parts[0]) ?? 0;
      final m = int.tryParse(parts[1]) ?? 0;
      if (h > 23 || m > 59) return '--:--';
      return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}';
    }
    if (RegExp(r'^\d{3,4}$').hasMatch(cleaned)) {
      final full = cleaned.padLeft(4, '0');
      final h = int.tryParse(full.substring(0, 2)) ?? 0;
      final m = int.tryParse(full.substring(2)) ?? 0;
      if (h > 23 || m > 59) return '--:--';
      return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}';
    }
    return '--:--';
  }

  int _minutesBetween(String t1, String t2) {
    try {
      final p1 = t1.split(':');
      final p2 = t2.split(':');
      int m1 = int.parse(p1[0]) * 60 + int.parse(p1[1]);
      int m2 = int.parse(p2[0]) * 60 + int.parse(p2[1]);
      if (m2 < m1) m2 += 1440;
      return m2 - m1;
    } catch (_) {
      return 0;
    }
  }

    // 保存
  
  void _save() {
    final trainCode = _trainCodeCtrl.text.trim().toUpperCase();

    // 收集所有问题
    final issues = <String>[];
    if (trainCode.isEmpty) issues.add('• 请在「列车信息」里填写车次号');
    if (_stations.length < 2) issues.add('• 至少需要添加 2 个站点');
    if (_stations.length >= 2) {
      if (_fromIdx == null) issues.add('• 还没有设置上车站（点击站点卡片 → 设为上车站）');
      if (_toIdx == null) issues.add('• 还没有设置下车站（点击站点卡片 → 设为下车站）');
      if (_fromIdx != null && _toIdx != null && _fromIdx! >= _toIdx!) {
        issues.add('• 上车站必须排在下车站前面（可拖动站点调整顺序）');
      }
    }

    if (issues.isNotEmpty) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          icon: const Icon(Icons.error_outline, color: Colors.red, size: 32),
          title: const Text('还不能保存'),
          content: Text(issues.join(''), style: const TextStyle(height: 1.8)),
          actions: [
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('知道了，去修改'),
            ),
          ],
        ),
      );
      return;
    }

    setState(() => _saving = true);

    try {
      final fromS = _stations[_fromIdx!];
      final toS = _stations[_toIdx!];

      final stationDetails = _stations.asMap().entries.map((e) {
        final i = e.key;
        final s = e.value;
        return s.toStationDetail(
          isStart: i == 0,
          isEnd: i == _stations.length - 1,
        );
      }).toList();

      final id = 'custom_${trainCode}_${_travelDate.millisecondsSinceEpoch}';

      final journey = Journey(
        id: id,
        trainCode: trainCode,
        fromStation: fromS.name,
        toStation: toS.name,
        fromStationCode: fromS.telecode,
        toStationCode: toS.telecode,
        departureTime: fromS.departureTime != '--:--'
            ? fromS.departureTime
            : '--:--',
        arrivalTime: toS.arrivalTime != '--:--' ? toS.arrivalTime : '--:--',
        travelDate: _travelDate,
        stations: stationDetails,
        // isStation=true 表示包含自定义车站或本页面来源，用于限制工具箱
        isStation: true,
        seatType: _seatType,
        seatInfo: _buildSeatInfo(),
      );

      Provider.of<JourneyProvider>(context, listen: false).addJourney(journey);
      _showSnack('已添加 $trainCode 次自定义行程');
      if (mounted) Navigator.of(context).pop();

      Future.delayed(const Duration(milliseconds: 600), () {
        if (mounted) Navigator.of(context).pop();
      });
    } catch (e) {
      _showSnack('保存失败：$e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  String _buildSeatInfo() {
    final info = _seatInfoCtrl.text.trim();
    final note = _noteCtrl.text.trim();
    final parts = <String>[];
    if (info.isNotEmpty) parts.add(info);
    if (note.isNotEmpty) parts.add('备注:$note');
    return parts.join(' | ');
  }

    // Build
  
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark
          ? const Color(0xFF111111)
          : const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: const Text('自定义旅途'),
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
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(12),
          children: [
            _sectionCard(
              icon: Icons.train,
              title: '列车信息',
              child: _buildTrainInfoSection(isDark),
            ),
            const SizedBox(height: 12),
            _sectionCard(
              icon: Icons.event_seat,
              title: '座位信息',
              child: _buildSeatSection(),
            ),
            const SizedBox(height: 12),
            _buildStationsSection(isDark, cs),
            const SizedBox(height: 12),
            _sectionCard(
              icon: Icons.notes,
              title: '备注',
              child: TextField(
                controller: _noteCtrl,
                maxLines: 2,
                maxLength: 100,
                decoration: const InputDecoration(
                  hintText: '本务、组号、其他备注…',
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
            // 提示卡片
            if (_hasCustomStation)
              _buildHintCard(
                icon: Icons.info_outline,
                color: Colors.orange,
                text: '包含自定义车站，保存后不可使用工具箱（交路表 / 在线线路图）',
              )
            else if (_stations.isNotEmpty)
              _buildHintCard(
                icon: Icons.check_circle_outline,
                color: Colors.green,
                text: '全部为国铁车站，保存后可查看本地线路走向图',
              ),
            const SizedBox(height: 80),
          ],
        ),
      ),
    );
  }

  //  列车信息 

  Widget _buildTrainInfoSection(bool isDark) {
    return Column(
      children: [
        // 车次号
        TextFormField(
          controller: _trainCodeCtrl,
          textCapitalization: TextCapitalization.characters,
          inputFormatters: [
            UpperCaseTextFormatter(),
            LengthLimitingTextInputFormatter(8),
          ],
          decoration: const InputDecoration(
            labelText: '车次号 *',
            hintText: '如 G1、D101、Z1',
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.confirmation_number_outlined),
          ),
          validator: (v) => (v == null || v.trim().isEmpty) ? '请输入车次号' : null,
        ),
        const SizedBox(height: 12),
        // 日期
        InkWell(
          onTap: _pickDate,
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade400),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                const Icon(Icons.calendar_today, size: 20, color: Colors.grey),
                const SizedBox(width: 12),
                Text(
                  '乘车日期：${_dateText(_travelDate)}',
                  style: const TextStyle(fontSize: 16),
                ),
                const Spacer(),
                const Icon(
                  Icons.arrow_forward_ios,
                  size: 14,
                  color: Colors.grey,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  //  座位 

  void _showCustomSeatNameDialog() {
    final ctrl = TextEditingController(text: _customSeatTypeName);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('自定义座位类型'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          maxLength: 10,
          decoration: const InputDecoration(
            hintText: '如：软卧上铺、包厢、餐车…',
            border: OutlineInputBorder(),
          ),
          onSubmitted: (_) {
            final name = ctrl.text.trim();
            Navigator.pop(ctx);
            setState(
              () => _customSeatTypeName = name.isNotEmpty ? name : '自定义',
            );
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () {
              final name = ctrl.text.trim();
              Navigator.pop(ctx);
              setState(
                () => _customSeatTypeName = name.isNotEmpty ? name : '自定义',
              );
            },
            child: const Text('确认'),
          ),
        ],
      ),
    );
  }

  Widget _buildSeatSection() {
    final isCustom = _seatType == 'custom_num';
    final isNoSeat = _seatType == 'wz_num';
    return Column(
      children: [
        DropdownButtonFormField<String>(
          initialValue: _seatType,
          decoration: const InputDecoration(
            labelText: '座位类型',
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.airline_seat_recline_normal_outlined),
          ),
          items: _seatTypes.entries
              .map((e) => DropdownMenuItem(value: e.key, child: Text(e.value)))
              .toList(),
          onChanged: (v) {
            setState(() => _seatType = v ?? 'wz_num');
            if (v == 'custom_num') {
              // 选完立即弹出名称输入
              WidgetsBinding.instance.addPostFrameCallback(
                (_) => _showCustomSeatNameDialog(),
              );
            }
          },
        ),
        // 自定义座位类型名显示
        if (isCustom && _customSeatTypeName.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: GestureDetector(
              onTap: _showCustomSeatNameDialog,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: Colors.purple.withAlpha(20),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.purple.withAlpha(100)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.edit, size: 16, color: Colors.purple),
                    const SizedBox(width: 8),
                    Text(
                      '类型名称：$_customSeatTypeName',
                      style: const TextStyle(
                        color: Colors.purple,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const Spacer(),
                    const Text(
                      '点击修改',
                      style: TextStyle(fontSize: 11, color: Colors.grey),
                    ),
                  ],
                ),
              ),
            ),
          ),
        const SizedBox(height: 12),
        TextField(
          controller: _seatInfoCtrl,
          enabled: !isNoSeat,
          decoration: InputDecoration(
            labelText: '座位号',
            hintText: isNoSeat ? '无座无需填写' : '如 05车12F',
            border: const OutlineInputBorder(),
            prefixIcon: const Icon(Icons.chair_outlined),
          ),
        ),
      ],
    );
  }

  //  站点区域 

  Widget _buildStationsSection(bool isDark, ColorScheme cs) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 标题行
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
          child: Row(
            children: [
              Icon(Icons.route, color: cs.primary, size: 20),
              const SizedBox(width: 8),
              const Text(
                '站点列表',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const Spacer(),
              Text(
                '${_stations.length} 个站',
                style: TextStyle(
                  fontSize: 13,
                  color: cs.onSurface.withAlpha(140),
                ),
              ),
            ],
          ),
        ),
        // 区间提示
        if (_fromIdx != null || _toIdx != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: cs.primaryContainer,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.compare_arrows,
                    size: 16,
                    color: cs.onPrimaryContainer,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '${_fromIdx != null ? _stations[_fromIdx!].name : '?'} → ${_toIdx != null ? _stations[_toIdx!].name : '?'}',
                    style: TextStyle(
                      fontSize: 13,
                      color: cs.onPrimaryContainer,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        const SizedBox(height: 6),
        // 站点列表（可拖拽排序）
        if (_stations.isEmpty)
          _emptyStationsHint(isDark)
        else
          _buildReorderableList(isDark, cs),
        const SizedBox(height: 8),
        // 添加按钮
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: _showAddStationDialog,
            icon: const Icon(Icons.add_location_alt_outlined),
            label: const Text('添加站点'),
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

  Widget _emptyStationsHint(bool isDark) {
    return Container(
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
            '还没有站点，点击下方「添加站点」',
            style: TextStyle(color: Colors.grey.shade500),
          ),
          const SizedBox(height: 6),
          Text(
            '添加后点击卡片可设置上下车站和到发时间',
            style: TextStyle(fontSize: 11, color: Colors.grey.shade400),
          ),
        ],
      ),
    );
  }

  Widget _buildReorderableList(bool isDark, ColorScheme cs) {
    return ReorderableListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _stations.length,
      onReorder: (oldIdx, newIdx) {
        setState(() {
          if (newIdx > oldIdx) newIdx--;
          final item = _stations.removeAt(oldIdx);
          _stations.insert(newIdx, item);
          // 更新上下车站下标
          _fromIdx = _remapIdx(_fromIdx, oldIdx, newIdx);
          _toIdx = _remapIdx(_toIdx, oldIdx, newIdx);
        });
      },
      proxyDecorator: (child, idx, anim) => Material(
        elevation: 4,
        borderRadius: BorderRadius.circular(12),
        child: child,
      ),
      itemBuilder: (ctx, idx) => _buildStationTile(idx, isDark, cs),
    );
  }

  int? _remapIdx(int? cur, int oldIdx, int newIdx) {
    if (cur == null) return null;
    if (cur == oldIdx) return newIdx;
    if (oldIdx < newIdx) {
      if (cur > oldIdx && cur <= newIdx) return cur - 1;
    } else {
      if (cur >= newIdx && cur < oldIdx) return cur + 1;
    }
    return cur;
  }

  Widget _buildStationTile(int idx, bool isDark, ColorScheme cs) {
    final s = _stations[idx];
    final isFrom = _fromIdx == idx;
    final isTo = _toIdx == idx;
    final inRange =
        _fromIdx != null && _toIdx != null && idx > _fromIdx! && idx < _toIdx!;

    Color borderColor = isDark
        ? Colors.white.withAlpha(30)
        : Colors.grey.shade300;
    if (isFrom) borderColor = Colors.green;
    if (isTo) borderColor = Colors.orange;

    return Padding(
      key: ValueKey('station_$idx'),
      padding: const EdgeInsets.only(bottom: 6),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _showStationMenu(idx),
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: borderColor,
                width: isFrom || isTo ? 2 : 1,
              ),
            ),
            child: Row(
              children: [
                // 左侧：序号 + 竖线
                Column(
                  children: [
                    Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: isFrom
                            ? Colors.green
                            : isTo
                            ? Colors.orange
                            : inRange
                            ? cs.primary.withAlpha(180)
                            : Colors.grey.shade400,
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text(
                          '${idx + 1}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 10),
                // 中间：站名 + 时间
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            '${s.name}站',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: isFrom || isTo
                                  ? FontWeight.bold
                                  : FontWeight.w500,
                            ),
                          ),
                          const SizedBox(width: 6),
                          if (s.isCustom) _badge('自定义', Colors.purple),
                          if (isFrom) _badge('上车', Colors.green),
                          if (isTo) _badge('下车', Colors.orange),
                          if (s.dayDiff > 0)
                            _badge('+${s.dayDiff}天', Colors.blue),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          _timeChip('到', s.arrivalTime),
                          const SizedBox(width: 8),
                          _timeChip('发', s.departureTime),
                          if (s.stayMinutes > 0) ...[
                            const SizedBox(width: 8),
                            Text(
                              '停${s.stayMinutes}分',
                              style: TextStyle(
                                fontSize: 11,
                                color: cs.onSurface.withAlpha(140),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                // 右侧：拖拽把手
                Padding(
                  padding: const EdgeInsets.only(left: 6),
                  child: Icon(
                    Icons.drag_handle,
                    color: Colors.grey.shade400,
                    size: 20,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _badge(String text, Color color) => Container(
    margin: const EdgeInsets.only(right: 4),
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

  Widget _timeChip(String label, String time) => RichText(
    text: TextSpan(
      children: [
        TextSpan(
          text: '$label ',
          style: TextStyle(
            fontSize: 11,
            color: Colors.grey.shade500,
            fontFamily: DefaultTextStyle.of(context).style.fontFamily,
          ),
        ),
        TextSpan(
          text: time,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: Theme.of(context).colorScheme.onSurface,
            fontFamily: DefaultTextStyle.of(context).style.fontFamily,
          ),
        ),
      ],
    ),
  );

  //  通用卡片 

  Widget _sectionCard({
    required IconData icon,
    required String title,
    required Widget child,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
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
        crossAxisAlignment: CrossAxisAlignment.start,
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

  Widget _buildHintCard({
    required IconData icon,
    required Color color,
    required String text,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: color.withAlpha(20),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withAlpha(80)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Text(text, style: TextStyle(fontSize: 12, color: color)),
          ),
        ],
      ),
    );
  }
}

// 添加站点选择 bottom sheet
class _AddStationSheet extends StatelessWidget {
  final VoidCallback onAddRail;
  final VoidCallback onAddCustom;

  const _AddStationSheet({required this.onAddRail, required this.onAddCustom});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
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
          const SizedBox(height: 16),
          const Text(
            '添加站点',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          // 国铁车站
          _OptionTile(
            icon: Icons.train,
            color: Colors.blue,
            title: '国铁车站',
            subtitle: '从本地数据库搜索国铁车站（支持离线线路图）',
            onTap: onAddRail,
          ),
          const SizedBox(height: 10),
          // 自定义
          _OptionTile(
            icon: Icons.edit_location_alt,
            color: Colors.purple,
            title: '自定义车站',
            subtitle: '手动输入站名（不支持线路图及工具箱）',
            onTap: onAddCustom,
          ),
        ],
      ),
    );
  }
}

class _OptionTile extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _OptionTile({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: color.withAlpha(isDark ? 20 : 15),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withAlpha(80)),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: color.withAlpha(30),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: Colors.grey.shade400),
          ],
        ),
      ),
    );
  }
}

// 站点操作菜单 bottom sheet
class _StationMenuSheet extends StatelessWidget {
  final String stationName;
  final bool isCustom;
  final bool isFrom;
  final bool isTo;
  final VoidCallback onSetFrom;
  final VoidCallback onSetTo;
  final VoidCallback onEditTime;
  final VoidCallback? onEditName;
  final VoidCallback onDelete;
  final VoidCallback onEditDay;

  const _StationMenuSheet({
    required this.stationName,
    required this.isCustom,
    required this.isFrom,
    required this.isTo,
    required this.onSetFrom,
    required this.onSetTo,
    required this.onEditTime,
    this.onEditName,
    required this.onDelete,
    required this.onEditDay,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
        top: 16,
        left: 20,
        right: 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
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
            '$stationName站',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          if (isCustom)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                '自定义车站',
                style: TextStyle(fontSize: 12, color: Colors.purple.shade400),
              ),
            ),
          const SizedBox(height: 6),
          // 操作引导提示
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            decoration: BoxDecoration(
              color: Colors.blue.withAlpha(20),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(Icons.touch_app, size: 14, color: Colors.blue.shade400),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    '点击下方按钮设置上下车站、编辑时间',
                    style: TextStyle(fontSize: 11, color: Colors.blue.shade400),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _MenuChip(
                icon: Icons.login,
                label: isFrom ? '取消上车站' : '设为上车站',
                color: Colors.green,
                onTap: onSetFrom,
              ),
              _MenuChip(
                icon: Icons.logout,
                label: isTo ? '取消下车站' : '设为下车站',
                color: Colors.orange,
                onTap: onSetTo,
              ),
              _MenuChip(
                icon: Icons.access_time,
                label: '编辑时间',
                color: Colors.blue,
                onTap: onEditTime,
              ),
              _MenuChip(
                icon: Icons.calendar_today,
                label: '设置跨天',
                color: Colors.indigo,
                onTap: onEditDay,
              ),
              if (onEditName != null)
                _MenuChip(
                  icon: Icons.edit,
                  label: '修改名称',
                  color: Colors.purple,
                  onTap: onEditName!,
                ),
              _MenuChip(
                icon: Icons.delete_outline,
                label: '删除',
                color: Colors.red,
                onTap: onDelete,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MenuChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _MenuChip({
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

// 时间输入 Field
class _TimeField extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final String hint;

  const _TimeField({
    required this.label,
    required this.controller,
    required this.hint,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: TextInputType.number,
      inputFormatters: [
        FilteringTextInputFormatter.allow(RegExp(r'[\d:]')),
        LengthLimitingTextInputFormatter(5),
      ],
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        border: const OutlineInputBorder(),
        suffixIcon: IconButton(
          icon: const Icon(Icons.access_time, size: 18),
          onPressed: () async {
            final parts = controller.text.split(':');
            final initH = int.tryParse(parts.isNotEmpty ? parts[0] : '') ?? 0;
            final initM = int.tryParse(parts.length > 1 ? parts[1] : '') ?? 0;
            final picked = await showTimePicker(
              context: context,
              initialTime: TimeOfDay(hour: initH, minute: initM),
              builder: (ctx, child) => MediaQuery(
                data: MediaQuery.of(ctx).copyWith(alwaysUse24HourFormat: true),
                child: child!,
              ),
            );
            if (picked != null) {
              controller.text =
                  '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
            }
          },
        ),
      ),
    );
  }
}

// 强制大写 InputFormatter
class UpperCaseTextFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    return newValue.copyWith(text: newValue.text.toUpperCase());
  }
}
