/// 工作日配置模型
/// 存储用户手动添加/移除的日期
class WorkdayConfig {
  /// 用户手动标记为工作日的日期（如调休上班的周末）
  Set<String> addedWorkdays;

  /// 用户手动标记为休息日的日期（如额外放假）
  Set<String> removedWorkdays;

  /// 用户自定义日期（含节假日名称）
  /// key: "yyyy-MM-dd", value: {'type': 'holiday'|'workday', 'name': '春节'|''}
  Map<String, Map<String, String>> customDates;

  WorkdayConfig({
    Set<String>? addedWorkdays,
    Set<String>? removedWorkdays,
    Map<String, Map<String, String>>? customDates,
  })  : addedWorkdays = addedWorkdays ?? {},
        removedWorkdays = removedWorkdays ?? {},
        customDates = customDates ?? {};

  Map<String, dynamic> toJson() => {
        'addedWorkdays': addedWorkdays.toList(),
        'removedWorkdays': removedWorkdays.toList(),
        'customDates': customDates,
      };

  factory WorkdayConfig.fromJson(Map<String, dynamic> json) {
    final customDatesRaw = json['customDates'] as Map<String, dynamic>? ?? {};
    final customDates = <String, Map<String, String>>{};
    for (final entry in customDatesRaw.entries) {
      if (entry.value is Map) {
        customDates[entry.key] = {
          'type': entry.value['type']?.toString() ?? 'holiday',
          'name': entry.value['name']?.toString() ?? '',
        };
      }
    }
    return WorkdayConfig(
      addedWorkdays: Set<String>.from(json['addedWorkdays'] ?? []),
      removedWorkdays: Set<String>.from(json['removedWorkdays'] ?? []),
      customDates: customDates,
    );
  }

  /// 添加工作日（调休上班）
  void addWorkday(DateTime date) {
    final key = _formatDate(date);
    addedWorkdays.add(key);
    removedWorkdays.remove(key);
    customDates[key] = {'type': 'workday', 'name': '班'};
  }

  /// 移除工作日（标记为休息日）
  void removeWorkday(DateTime date) {
    final key = _formatDate(date);
    removedWorkdays.add(key);
    addedWorkdays.remove(key);
    customDates[key] = {'type': 'holiday', 'name': ''};
  }

  /// 设置自定义日期（含名称）
  void setCustomDate(DateTime date, {required String type, required String name}) {
    final key = _formatDate(date);
    customDates[key] = {'type': type, 'name': name};
    if (type == 'workday') {
      addedWorkdays.add(key);
      removedWorkdays.remove(key);
    } else {
      removedWorkdays.add(key);
      addedWorkdays.remove(key);
    }
  }

  /// 删除自定义日期
  void removeCustomDate(DateTime date) {
    final key = _formatDate(date);
    customDates.remove(key);
    addedWorkdays.remove(key);
    removedWorkdays.remove(key);
  }

  /// 检查日期是否被用户覆盖
  bool isOverridden(DateTime date) {
    final key = _formatDate(date);
    return addedWorkdays.contains(key) ||
        removedWorkdays.contains(key) ||
        customDates.containsKey(key);
  }

  /// 获取用户覆盖的工作日状态：true=工作日, false=休息日, null=未覆盖
  bool? getOverride(DateTime date) {
    final key = _formatDate(date);
    if (customDates.containsKey(key)) {
      return customDates[key]!['type'] == 'workday';
    }
    if (addedWorkdays.contains(key)) return true;
    if (removedWorkdays.contains(key)) return false;
    return null;
  }

  /// 获取自定义日期的名称
  String getCustomName(DateTime date) {
    final key = _formatDate(date);
    return customDates[key]?['name'] ?? '';
  }

  static String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }
}
