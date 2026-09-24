// 测试 workday 模式的执行计划生成逻辑（使用完整节假日数据）
// 运行: dart test_workday_final.dart

void main() {
  // 模拟配置
  final now = DateTime(2026, 9, 23, 20, 0); // 假设当前时间
  final yearEnd = DateTime(2027, 1, 1);
  
  // 完整的节假日数据（从 holiday_cache.json 复制）
  final holidays2026 = <String, String>{
    '2026-01-01': 'holiday',
    '2026-01-02': 'holiday',
    '2026-01-03': 'holiday',
    '2026-01-04': 'workday', // 调休
    '2026-02-14': 'workday', // 调休
    '2026-02-15': 'holiday',
    '2026-02-16': 'holiday',
    '2026-02-17': 'holiday',
    '2026-02-18': 'holiday',
    '2026-02-19': 'holiday',
    '2026-02-20': 'holiday',
    '2026-02-21': 'holiday',
    '2026-02-22': 'holiday',
    '2026-02-23': 'holiday',
    '2026-02-28': 'workday', // 调休
    '2026-04-04': 'holiday',
    '2026-04-05': 'holiday',
    '2026-04-06': 'holiday',
    '2026-05-01': 'holiday',
    '2026-05-02': 'holiday',
    '2026-05-03': 'holiday',
    '2026-05-04': 'holiday',
    '2026-05-05': 'holiday',
    '2026-05-09': 'workday', // 调休
    '2026-06-19': 'holiday',
    '2026-06-20': 'holiday',
    '2026-06-21': 'holiday',
    '2026-09-20': 'workday', // 调休
    '2026-09-25': 'holiday', // 中秋
    '2026-09-26': 'holiday', // 中秋
    '2026-09-27': 'holiday', // 中秋
    '2026-10-01': 'holiday', // 国庆
    '2026-10-02': 'holiday', // 国庆
    '2026-10-03': 'holiday', // 国庆
    '2026-10-04': 'holiday', // 国庆
    '2026-10-05': 'holiday', // 国庆
    '2026-10-06': 'holiday', // 国庆
    '2026-10-07': 'holiday', // 国庆
    '2026-10-10': 'workday', // 调休
  };
  
  // 判断是否工作日
  bool isWorkday(DateTime date) {
    final key = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    
    // 检查节假日缓存
    if (holidays2026.containsKey(key)) {
      return holidays2026[key] == 'workday';
    }
    
    // 默认：周一到周五是工作日
    return date.weekday >= 1 && date.weekday <= 5;
  }
  
  // 检查"次日是否为工作日"（workdayEveOnly 语义）
  bool isWorkdayTriggerDay(DateTime day) {
    return isWorkday(day.add(const Duration(days: 1)));
  }
  
  // 找到首个执行日
  DateTime? findFirstTrigger() {
    var target = DateTime(now.year, now.month, now.day, 23, 55);
    if (target.isAfter(now) && isWorkdayTriggerDay(target)) {
      return target;
    }
    target = target.add(const Duration(days: 1));
    while (!isWorkdayTriggerDay(target)) {
      target = target.add(const Duration(days: 1));
    }
    return target;
  }
  
  // 生成执行计划
  final first = findFirstTrigger();
  if (first == null) {
    print('未找到首个执行日');
    return;
  }
  
  print('首个执行日: ${_formatDate(first)} (${_weekdayLabel(first.weekday)})');
  
  final result = <DateTime>[first];
  var candidate = first.add(const Duration(days: 1));
  
  while (result.length < 100 && candidate.isBefore(yearEnd)) {
    if (isWorkdayTriggerDay(candidate)) {
      result.add(candidate);
    }
    candidate = candidate.add(const Duration(days: 1));
  }
  
  print('\n执行计划（共 ${result.length} 次）:');
  for (int i = 0; i < result.length; i++) {
    final dt = result[i];
    final nextDay = dt.add(const Duration(days: 1));
    print('${i + 1}. ${_formatDate(dt)} (${_weekdayLabel(dt.weekday)}) → 次日 ${_formatDate(nextDay)} (${_weekdayLabel(nextDay.weekday)}, ${isWorkday(nextDay) ? "工作日" : "休息"})');
  }
  
  // 按月统计
  print('\n按月统计:');
  final monthCount = <String, int>{};
  for (final dt in result) {
    final key = '${dt.year}-${dt.month.toString().padLeft(2, '0')}';
    monthCount[key] = (monthCount[key] ?? 0) + 1;
  }
  for (final entry in monthCount.entries.toList()..sort((a, b) => a.key.compareTo(b.key))) {
    print('${entry.key}: ${entry.value} 次');
  }
}

String _formatDate(DateTime dt) {
  return '${dt.month}月${dt.day}日';
}

String _weekdayLabel(int weekday) {
  const labels = ['一', '二', '三', '四', '五', '六', '日'];
  return '周${labels[weekday - 1]}';
}
