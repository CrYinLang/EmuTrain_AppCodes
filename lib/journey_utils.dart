// journey_utils.dart
// 纯逻辑工具函数 —— part of journey.dart

part of 'ui/journey.dart';

extension _JourneyUtils on _AddJourneyPageState {
  String _normalizeStationName(String name) {
    if (name.isEmpty) return '';
    // 移除"站"字和空格
    return name.replaceAll('站', '').replaceAll(' ', '').trim();
  }

  String _getStationName(String telecode) {
    final name = _stationNameMap[telecode.replaceAll(' ', '')] ?? telecode;
    return name.contains(RegExp(r'[a-zA-Z]')) ? '始发站  (环线)' : name;
  }

  String _cleanStationName(String name) {
    return name.replaceAll(' ', '');
  }

  void _formatInput(String value) {
    if (value.isEmpty) return;
    String uppercase = value.toUpperCase();
    const allowed = 'GDCSKZTWPQ';
    String result = '';
    for (int i = 0; i < uppercase.length; i++) {
      String char = uppercase[i];
      if (i == 0) {
        if (RegExp(r'[0-9]').hasMatch(char) || allowed.contains(char)) {
          result += char;
        }
      } else {
        if (RegExp(r'[0-9]').hasMatch(char)) result += char;
      }
    }
    if (result != _trainNumberCtrl.text) {
      _trainNumberCtrl.value = _trainNumberCtrl.value.copyWith(
        text: result,
        selection: TextSelection.collapsed(offset: result.length),
      );
    }
  }

  bool _hasAvailableTickets(Map<String, dynamic> seatInfo) {
    return seatInfo.entries.any((entry) => _isSeatAvailable(entry.value));
  }

  bool _isSeatAvailable(dynamic value) {
    return value != null &&
        value != '无票' &&
        value != '无' &&
        value != '' &&
        value != '--' &&
        value != 'NULL' &&
        value != '0';
  }

  String _calcRunTime(String start, String end, String day) {
    try {
      if (start == '--:--' || end == '--:--') return '--';

      List<String> startParts = start.split(':');
      List<String> endParts = end.split(':');
      if (startParts.length != 2 || endParts.length != 2) return '--';

      int startHour = int.tryParse(startParts[0]) ?? 0;
      int startMin = int.tryParse(startParts[1]) ?? 0;
      int endHour = int.tryParse(endParts[0]) ?? 0;
      int endMin = int.tryParse(endParts[1]) ?? 0;

      // 将day转换为整数，day=0表示不跨天
      int dayOffset = int.tryParse(day) ?? 0;

      int startTotal = startHour * 60 + startMin;
      int endTotal = endHour * 60 + endMin;

      // 如果day>0，需要加上跨天的分钟数
      endTotal += dayOffset * 24 * 60;

      // 如果end时间仍然小于start时间，再补上24小时
      if (endTotal < startTotal) endTotal += 24 * 60;

      int total = endTotal - startTotal;
      int hours = total ~/ 60;
      int minutes = total % 60;

      if (hours > 0) {
        return '$hours小时$minutes分';
      } else {
        return '$minutes分';
      }
    } catch (e) {
      return '--';
    }
  }

  bool _isStationPassedSection(Map<String, dynamic> stop, DateTime trainDate) {
    final first = (stop['isFirst'] as bool?) ?? false;
    final last = (stop['isLast'] as bool?) ?? false;

    // 修复：安全转换 DayDifference
    final dayDiffValue = stop['DayDifference'];
    int dayDiff = 0;

    if (dayDiffValue != null) {
      if (dayDiffValue is int) {
        dayDiff = dayDiffValue;
      } else if (dayDiffValue is String) {
        dayDiff = int.tryParse(dayDiffValue) ?? 0;
      } else if (dayDiffValue is num) {
        dayDiff = dayDiffValue.toInt();
      }
    }

    if (first) {
      // 始发站判断发车时间
      final dep = stop['departTime'] as String?;
      return _isTimePassed(trainDate, dep, dayDiff, last);
    } else if (last) {
      // 终点站判断到达时间
      final arr = stop['arriveTime'] as String?;
      return _isTimePassed(trainDate, arr, dayDiff, last);
    } else {
      // 中间站优先判断到达时间
      final arr = stop['arriveTime'] as String?;
      final dep = stop['departTime'] as String?;
      if (arr != null && arr != '--:--') {
        return _isTimePassed(trainDate, arr, dayDiff, last);
      } else if (dep != null && dep != '--:--') {
        return _isTimePassed(trainDate, dep, dayDiff, last);
      }
    }
    return false;
  }

  bool _isStationPassed(Map<String, dynamic> stop, DateTime trainDate) {
    final first = (stop['isFirst'] as bool?) ?? false;
    final last = (stop['isLast'] as bool?) ?? false;
    final dayDiff = (stop['DayDifference'] as int?) ?? 0;

    if (first) {
      // 始发站判断发车时间
      final dep = stop['departTime'] as String?;
      return _isTimePassed(trainDate, dep, dayDiff, last);
    } else if (last) {
      // 终点站判断到达时间
      final arr = stop['arriveTime'] as String?;
      return _isTimePassed(trainDate, arr, dayDiff, last);
    } else {
      // 中间站优先判断到达时间
      final arr = stop['arriveTime'] as String?;
      final dep = stop['departTime'] as String?;
      if (arr != null && arr != '--:--') {
        return _isTimePassed(trainDate, arr, dayDiff, last);
      } else if (dep != null && dep != '--:--') {
        return _isTimePassed(trainDate, dep, dayDiff, last);
      }
    }
    return false;
  }

  bool _isExpired(int index, Map<String, dynamic> item, bool isStation) {
    // 获取车次日期
    final date = _selectedDate ?? DateTime.now();

    if (isStation) {
      return _isStationExpired(index, date);
    } else {
      return _isTrainExpired(index, date);
    }
  }

  bool _isStationExpired(int index, DateTime trainDate) {
    final stopData = _stationDetails[index] ?? [];
    if (stopData.isEmpty) return false;

    // 找到用户查询的车站
    final queryStop = stopData.cast<Map<String, dynamic>?>().firstWhere(
      (stop) => stop?['isCurrent'] == true,
      orElse: () => null,
    );

    if (queryStop != null) {
      return _isStationPassed(queryStop, trainDate);
    }

    return false;
  }

  bool _isTrainExpired(int index, DateTime trainDate) {
    final stopData = _trainDetails[index] ?? [];
    if (stopData.isEmpty) return false;

    // 找到终点站
    final lastStop = stopData.cast<Map<String, dynamic>?>().firstWhere(
      (stop) => stop?['isLast'] == true,
      orElse: () => null,
    );

    if (lastStop != null) {
      final arriveTime = lastStop['arriveTime'] as String?;
      final dayDiff = _parseDayDifference(lastStop['DayDifference']);
      return _isTimePassed(trainDate, arriveTime, dayDiff, true);
    }

    return false;
  }

  int _parseDayDifference(dynamic value) {
    if (value == null) return 0;

    if (value is int) return value;
    if (value is String) return int.tryParse(value) ?? 0;
    if (value is double) return value.toInt();
    if (value is num) return value.toInt();

    return 0;
  }

  bool _isTimePassed(
    DateTime trainDate,
    String? timeString,
    int dayDiff,
    bool isLast,
  ) {
    if (timeString == null || timeString.isEmpty || timeString == '--:--') {
      return false;
    }

    try {
      // 解析时间字符串
      final timeParts = timeString.split(':');
      if (timeParts.length < 2) return false;

      final hour = int.tryParse(timeParts[0]) ?? 0;
      final minute = int.tryParse(timeParts[1]) ?? 0;

      // 计算列车实际时间
      // trainDate 是用户选择的日期
      // dayDiff 是相对于发车日的天数差
      final stationDateTime = DateTime(
        trainDate.year,
        trainDate.month,
        trainDate.day + dayDiff, // 加上天数差
        hour,
        minute,
      );

      // 获取当前时间
      final now = DateTime.now();

      // 直接比较：列车时间是否已经过去了
      return stationDateTime.isBefore(now);
    } catch (e) {
      return false;
    }
  }

}
