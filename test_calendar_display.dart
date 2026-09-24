// 测试日历显示逻辑（模拟 HolidayCalendar 组件）
// 运行: dart test_calendar_display.dart

void main() {
  // 模拟用户当前的配置（从 workday_config.json 读取后已清除 addedWorkdays/removedWorkdays）
  final customDates = <String, Map<String, String>>{
    '2026-09-25': {'type': 'holiday', 'name': '中秋'},
    '2026-09-26': {'type': 'holiday', 'name': '中秋'},
    '2026-09-27': {'type': 'holiday', 'name': '中秋'},
    '2026-10-01': {'type': 'holiday', 'name': '国庆'},
    '2026-10-02': {'type': 'holiday', 'name': '国庆'},
    '2026-10-03': {'type': 'holiday', 'name': '国庆'},
    '2026-10-04': {'type': 'holiday', 'name': '国庆'},
    '2026-10-05': {'type': 'holiday', 'name': '国庆'},
    '2026-10-06': {'type': 'holiday', 'name': '国庆'},
    '2026-10-07': {'type': 'holiday', 'name': '国庆'},
    '2026-10-10': {'type': 'workday', 'name': '班'},
  };

  // 内置节假日数据
  final holidays2026 = <String, Map<String, String>>{
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
    '2026-09-20': {'name': '班', 'type': 'workday'},
    '2026-09-25': {'name': '中秋', 'type': 'holiday'},
    '2026-09-26': {'name': '中秋', 'type': 'holiday'},
    '2026-09-27': {'name': '中秋', 'type': 'holiday'},
    '2026-10-01': {'name': '国庆', 'type': 'holiday'},
    '2026-10-02': {'name': '国庆', 'type': 'holiday'},
    '2026-10-03': {'name': '国庆', 'type': 'holiday'},
    '2026-10-04': {'name': '国庆', 'type': 'holiday'},
    '2026-10-05': {'name': '国庆', 'type': 'holiday'},
    '2026-10-06': {'name': '国庆', 'type': 'holiday'},
    '2026-10-07': {'name': '国庆', 'type': 'holiday'},
    '2026-10-10': {'name': '班', 'type': 'workday'},
  };

  // 判断日期类型（模拟 getMonthCalendar 逻辑）
  String getDayType(DateTime date, String label) {
    final dateKey = _formatDate(date);
    
    // 检查自定义日期
    final customEntry = customDates[dateKey];
    final customName = customEntry?['name'] ?? '';
    final customType = customEntry?['type'] ?? '';
    
    // 检查内置/缓存数据
    final dateInfo = holidays2026[dateKey];
    
    String dayType;
    String finalLabel = label;
    
    if (dateInfo != null) {
      // 内置/缓存中有此日期 → 保留内置样式，仅用自定义名称覆盖标签
      if (dateInfo['type'] == 'workday') {
        dayType = 'makeup_workday';
      } else {
        dayType = 'holiday';
      }
      finalLabel = customName.isNotEmpty ? customName : (dateInfo['name'] ?? '');
    } else if (customEntry != null) {
      // 自定义日期但不在内置范围内 → 用自定义样式
      if (customType == 'workday') {
        dayType = 'workday_override';
        finalLabel = customName.isNotEmpty ? customName : '班';
      } else {
        dayType = 'holiday_override';
        finalLabel = customName;
      }
    } else if (date.weekday == 6 || date.weekday == 7) {
      dayType = 'weekend';
    } else {
      dayType = 'workday';
    }
    
    return '$dayType|$finalLabel';
  }

  // 打印 9-12 月的日历
  for (int month = 9; month <= 12; month++) {
    print('\n========== ${month}月 ==========');
    final daysInMonth = DateTime(2026, month + 1, 0).day;
    
    for (int day = 1; day <= daysInMonth; day++) {
      final date = DateTime(2026, month, day);
      final result = getDayType(date, '').split('|');
      final dayType = result[0];
      final label = result.length > 1 ? result[1] : '';
      
      final weekdayLabels = ['', '一', '二', '三', '四', '五', '六', '日'];
      final weekday = weekdayLabels[date.weekday];
      
      print('${day}日 (周$weekday): $dayType ${label.isNotEmpty ? "- $label" : ""}');
    }
  }
  
  // 打印执行日期（workdayEveOnly=true）
  print('\n========== 执行日期（workdayEveOnly=true） ==========');
  
  bool isWorkday(DateTime date) {
    final dateKey = _formatDate(date);
    final customEntry = customDates[dateKey];
    if (customEntry != null) {
      return customEntry['type'] == 'workday';
    }
    final dateInfo = holidays2026[dateKey];
    if (dateInfo != null) {
      return dateInfo['type'] == 'workday';
    }
    return date.weekday >= 1 && date.weekday <= 5;
  }
  
  int execCount = 0;
  for (int month = 9; month <= 12; month++) {
    final daysInMonth = DateTime(2026, month + 1, 0).day;
    for (int day = 1; day <= daysInMonth; day++) {
      final date = DateTime(2026, month, day);
      final tomorrow = date.add(const Duration(days: 1));
      
      if (isWorkday(tomorrow)) {
        execCount++;
        final weekdayLabels = ['', '一', '二', '三', '四', '五', '六', '日'];
        final weekday = weekdayLabels[date.weekday];
        final nextWeekday = weekdayLabels[tomorrow.weekday];
        print('$execCount. ${month}月${day}日 (周$weekday) → 次日 ${tomorrow.month}月${tomorrow.day}日 (周$nextWeekday, ${isWorkday(tomorrow) ? "工作日" : "休息"})');
      }
    }
  }
  
  print('\n总计: $execCount 次执行');
}

String _formatDate(DateTime date) {
  return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
}
