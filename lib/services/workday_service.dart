import '../models/workday_config.dart';
import 'storage_service.dart';
import 'year_workday_cache_service.dart';

/// 工作日判断服务
/// 策略：用户自定义 → 本地缓存 → 内置数据
class WorkdayService {
  static WorkdayConfig? _config;
  static Map<String, dynamic>? _holidayCache;
  static bool _cacheLoaded = false;

  /// 2026 年官方放假安排（国务院通知）
  static const Map<String, Map<String, String>> holidays2026 = {
    '2026-01-01': {'name': '元旦', 'type': 'holiday'},
    '2026-01-02': {'name': '元旦', 'type': 'holiday'},
    '2026-01-03': {'name': '元旦', 'type': 'holiday'},
    '2026-01-04': {'name': '班', 'type': 'workday'},
    '2026-02-14': {'name': '班', 'type': 'workday'},
    '2026-02-15': {'name': '春节', 'type': 'holiday'},
    '2026-02-16': {'name': '春节', 'type': 'holiday'},
    '2026-02-17': {'name': '春节', 'type': 'holiday'},
    '2026-02-18': {'name': '春节', 'type': 'holiday'},
    '2026-02-19': {'name': '春节', 'type': 'holiday'},
    '2026-02-20': {'name': '春节', 'type': 'holiday'},
    '2026-02-21': {'name': '春节', 'type': 'holiday'},
    '2026-02-22': {'name': '春节', 'type': 'holiday'},
    '2026-02-23': {'name': '春节', 'type': 'holiday'},
    '2026-02-28': {'name': '班', 'type': 'workday'},
    '2026-04-04': {'name': '清明', 'type': 'holiday'},
    '2026-04-05': {'name': '清明', 'type': 'holiday'},
    '2026-04-06': {'name': '清明', 'type': 'holiday'},
    '2026-05-01': {'name': '劳动节', 'type': 'holiday'},
    '2026-05-02': {'name': '劳动节', 'type': 'holiday'},
    '2026-05-03': {'name': '劳动节', 'type': 'holiday'},
    '2026-05-04': {'name': '劳动节', 'type': 'holiday'},
    '2026-05-05': {'name': '劳动节', 'type': 'holiday'},
    '2026-05-09': {'name': '班', 'type': 'workday'},
    '2026-06-19': {'name': '端午', 'type': 'holiday'},
    '2026-06-20': {'name': '端午', 'type': 'holiday'},
    '2026-06-21': {'name': '端午', 'type': 'holiday'},
    '2026-09-25': {'name': '中秋', 'type': 'holiday'},
    '2026-09-26': {'name': '中秋', 'type': 'holiday'},
    '2026-09-27': {'name': '中秋', 'type': 'holiday'},
    '2026-09-20': {'name': '班', 'type': 'workday'},
    '2026-10-01': {'name': '国庆', 'type': 'holiday'},
    '2026-10-02': {'name': '国庆', 'type': 'holiday'},
    '2026-10-03': {'name': '国庆', 'type': 'holiday'},
    '2026-10-04': {'name': '国庆', 'type': 'holiday'},
    '2026-10-05': {'name': '国庆', 'type': 'holiday'},
    '2026-10-06': {'name': '国庆', 'type': 'holiday'},
    '2026-10-07': {'name': '国庆', 'type': 'holiday'},
    '2026-10-10': {'name': '班', 'type': 'workday'},
  };

  /// 常见节假日名称（供用户选择下拉）
  static const List<String> holidayNames = [
    '元旦', '春节', '清明', '劳动节', '端午', '中秋', '国庆', '调休', '其他',
  ];

  static Future<void> ensureCache() async => _ensureCache();
  static Map<String, dynamic>? get holidayCache => _holidayCache;

  static Future<void> _ensureCache() async {
    if (_cacheLoaded) return;
    _cacheLoaded = true;

    final cached = await StorageService.loadHolidayCache();
    if (cached != null) {
      _holidayCache = cached;
    } else {
      _holidayCache = {};
      for (final entry in holidays2026.entries) {
        _holidayCache![entry.key] = entry.value;
      }
      await StorageService.saveHolidayCache(_holidayCache!);
    }
  }

  static Future<void> _ensureConfig() async {
    _config ??= await StorageService.loadWorkdayConfig();
  }

  /// 判断指定日期是否为工作日
  static Future<bool> isWorkday(DateTime date) async {
    await _ensureConfig();
    await _ensureCache();

    final dateKey = _formatDate(date);

    // 1. 检查用户自定义日期（最高优先级）
    final custom = _config!.customDates[dateKey];
    if (custom != null) {
      return custom['type'] == 'workday';
    }

    // 2. 检查旧版用户覆盖
    final override = _config!.getOverride(date);
    if (override != null) return override;

    // 3. 检查本地节假日缓存
    if (_holidayCache != null && _holidayCache!.containsKey(dateKey)) {
      final info = _holidayCache![dateKey];
      if (info is Map) {
        return info['type'] == 'workday';
      }
    }

    // 4. 使用内置数据（周几判断）
    return _isWorkdayByDefault(date);
  }

  /// 获取某月的日历数据
  static Future<List<Map<String, dynamic>>> getMonthCalendar(int year, int month) async {
    await _ensureConfig();
    await _ensureCache();

    final result = <Map<String, dynamic>>[];
    final daysInMonth = DateTime(year, month + 1, 0).day;

    for (int day = 1; day <= daysInMonth; day++) {
      final date = DateTime(year, month, day);
      final dateKey = _formatDate(date);
      final weekday = date.weekday;

      // 获取缓存中的节假日信息
      Map<String, String>? dateInfo;
      if (_holidayCache != null && _holidayCache!.containsKey(dateKey)) {
        final info = _holidayCache![dateKey];
        if (info is Map) {
          dateInfo = {
            'name': info['name']?.toString() ?? '',
            'type': info['type']?.toString() ?? '',
          };
        }
      }

      // 判断日期类型（优先级：用户自定义名称 > 内置/缓存样式）
      String dayType;
      String label = '';

      final customEntry = _config!.customDates[dateKey];
      final customName = customEntry?['name'] ?? '';
      final customType = customEntry?['type'] ?? '';

      if (dateInfo != null) {
        // 内置/缓存中有此日期 → 保留内置样式，仅用自定义名称覆盖标签
        if (dateInfo['type'] == 'workday') {
          dayType = 'makeup_workday';
        } else {
          dayType = 'holiday';
        }
        label = customName.isNotEmpty ? customName : (dateInfo['name'] ?? '');
      } else if (customEntry != null) {
        // 自定义日期但不在内置范围内 → 用自定义样式
        if (customType == 'workday') {
          dayType = 'workday_override';
          label = customName.isNotEmpty ? customName : '班';
        } else {
          dayType = 'holiday_override';
          label = customName;
        }
      } else if (weekday == 6 || weekday == 7) {
        dayType = 'weekend';
      } else {
        dayType = 'workday';
      }

      result.add({
        'date': date,
        'dateKey': dateKey,
        'day': day,
        'weekday': weekday,
        'type': dayType,
        'label': label,
        'isPast': date.isBefore(DateTime.now().subtract(const Duration(days: 1))),
        'isToday': _isToday(date),
      });
    }

    return result;
  }

  /// 设置自定义日期（含名称）
  static Future<void> setCustomDate(DateTime date, {required String type, required String name}) async {
    await _ensureConfig();
    _config!.setCustomDate(date, type: type, name: name);
    await StorageService.saveWorkdayConfig(_config!);
    YearWorkdayCacheService.invalidate();
    
    // 如果涉及未来年份，自动初始化该年份缓存
    final year = date.year;
    final currentYear = DateTime.now().year;
    if (year > currentYear) {
      await YearWorkdayCacheService.ensureYearInitialized(year);
    }
  }

  /// 删除自定义日期
  static Future<void> removeCustomDate(DateTime date) async {
    await _ensureConfig();
    _config!.removeCustomDate(date);
    await StorageService.saveWorkdayConfig(_config!);
    YearWorkdayCacheService.invalidate();
    
    // 如果涉及未来年份，自动重新初始化该年份缓存
    final year = date.year;
    final currentYear = DateTime.now().year;
    if (year > currentYear) {
      await YearWorkdayCacheService.initialize(year);
    }
  }

  /// 添加工作日（用户手动点击日历）
  static Future<void> addWorkday(DateTime date) async {
    await _ensureConfig();
    _config!.addWorkday(date);
    await StorageService.saveWorkdayConfig(_config!);
    YearWorkdayCacheService.invalidate();
    
    // 如果涉及未来年份，自动初始化该年份缓存
    final year = date.year;
    final currentYear = DateTime.now().year;
    if (year > currentYear) {
      await YearWorkdayCacheService.ensureYearInitialized(year);
    }
  }

  /// 移除工作日（用户手动点击日历）
  static Future<void> removeWorkday(DateTime date) async {
    await _ensureConfig();
    _config!.removeWorkday(date);
    await StorageService.saveWorkdayConfig(_config!);
    YearWorkdayCacheService.invalidate();
    
    // 如果涉及未来年份，自动重新初始化该年份缓存
    final year = date.year;
    final currentYear = DateTime.now().year;
    if (year > currentYear) {
      await YearWorkdayCacheService.initialize(year);
    }
  }

  /// 获取当前配置
  static Future<WorkdayConfig> getConfig() async {
    await _ensureConfig();
    return _config!;
  }

  static bool _isWorkdayByDefault(DateTime date) {
    final weekday = date.weekday;
    return weekday >= 1 && weekday <= 5;
  }

  static bool _isToday(DateTime date) {
    final now = DateTime.now();
    return date.year == now.year && date.month == now.month && date.day == now.day;
  }

  static String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }
}
