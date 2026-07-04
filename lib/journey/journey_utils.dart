// journey_utils.dart
// 旅途相关工具函数

import '../../widgets/error.dart';

/// 计算运行时间
String calcRunTime(String start, String end, String day) {
  try {
    if (start == '--:--' || end == '--:--') return '--';

    final startParts = start.split(':');
    final endParts = end.split(':');
    if (startParts.length != 2 || endParts.length != 2) return '--';

    final startHour = int.tryParse(startParts[0]) ?? 0;
    final startMin = int.tryParse(startParts[1]) ?? 0;
    final endHour = int.tryParse(endParts[0]) ?? 0;
    final endMin = int.tryParse(endParts[1]) ?? 0;

    int dayOffset = int.tryParse(day) ?? 0;
    int startTotal = startHour * 60 + startMin;
    int endTotal = endHour * 60 + endMin;
    endTotal += dayOffset * 24 * 60;
    if (endTotal < startTotal) endTotal += 24 * 60;

    int total = endTotal - startTotal;
    int hours = total ~/ 60;
    int minutes = total % 60;

    if (hours > 0) {
      return '$hours 小时$minutes 分';
    } else {
      return '$minutes 分';
    }
  } catch (e) {
    logError(from: 'journey_utils/calcRunTime', error: e.toString());
    return '--';
  }
}

/// 判断时间是否已过
bool isTimePassed(DateTime trainDate, String? timeString, int dayDiff) {
  if (timeString == null || timeString.isEmpty || timeString == '--:--') return false;

  try {
    final timeParts = timeString.split(':');
    if (timeParts.length < 2) return false;

    final hour = int.tryParse(timeParts[0]) ?? 0;
    final minute = int.tryParse(timeParts[1]) ?? 0;

    final stationDateTime = DateTime(
      trainDate.year,
      trainDate.month,
      trainDate.day + dayDiff,
      hour,
      minute,
    );

    return stationDateTime.isBefore(DateTime.now());
  } catch (e) {
    logError(from: 'journey_utils/isTimePassed', error: e.toString());
    return false;
  }
}

/// 解析 DayDifference
int parseDayDifference(dynamic value) {
  if (value == null) return 0;
  if (value is int) return value;
  if (value is String) return int.tryParse(value) ?? 0;
  if (value is double) return value.toInt();
  if (value is num) return value.toInt();
  return 0;
}

/// 判断座位是否可用
bool isSeatAvailable(dynamic value) {
  return value != null &&
      value != '无票' &&
      value != '无' &&
      value != '' &&
      value != '--' &&
      value != 'NULL' &&
      value != '0';
}

/// 检查是否有任何可用座位
bool hasAvailableTickets(Map<String, dynamic> seatInfo) {
  return seatInfo.entries.any((entry) => isSeatAvailable(entry.value));
}

/// 格式化日期为 yyyy-MM-dd
String formatDate(DateTime date) {
  return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
}

/// 格式化日期为 yyyyMMdd（用于 API）
String formatApiDate(DateTime date) {
  return '${date.year}${date.month.toString().padLeft(2, '0')}${date.day.toString().padLeft(2, '0')}';
}

/// 标准化站名
String normalizeStationName(String name) {
  if (name.isEmpty) return '';
  return name.replaceAll('站', '').replaceAll(' ', '').trim();
}

/// 清理站名（移除空格）
String cleanStationName(String name) {
  return name.replaceAll(' ', '');
}
