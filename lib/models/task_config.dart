/// 任务类型枚举
enum TaskType {
  shutdown('关机', 'shutdown'),
  restart('重启', 'restart'),
  logoff('注销', 'logoff'),
  hibernate('休眠', 'hibernate'),
  sleep('睡眠', 'sleep'),
  lock('锁定', 'lock'),
  remind('提醒', 'remind');

  final String label;
  final String method;
  const TaskType(this.label, this.method);
}

/// 调度方式枚举
enum ScheduleMode {
  countdown('从现在开始'),
  workday('工作日'),
  specificTime('指定时间');

  final String label;
  const ScheduleMode(this.label);
}

/// 频率枚举
enum Frequency {
  daily('每天'),
  weekly('每周'),
  monthly('每月');

  final String label;
  const Frequency(this.label);
}

/// 旧版 scheduleMode 按索引序列化：0=指定时间 1=倒计时 2=间隔 3=工作日
/// 间隔模式已移除，旧索引 2 兜底为倒计时；按名称序列化后不受枚举重排影响
ScheduleMode _parseScheduleMode(dynamic value) {
  if (value is String) {
    return ScheduleMode.values.firstWhere(
      (m) => m.name == value,
      orElse: () => ScheduleMode.countdown,
    );
  }
  const legacyByIndex = [
    ScheduleMode.specificTime,
    ScheduleMode.countdown,
    ScheduleMode.countdown,
    ScheduleMode.workday,
  ];
  final index = value is int ? value : 0;
  return legacyByIndex[index.clamp(0, 3)];
}

/// 任务配置模型
class TaskConfig {
  TaskType taskType;
  ScheduleMode scheduleMode;
  DateTime? targetTime;       // 指定时间/工作日模式的目标时间
  int countdownHours;          // 倒计时模式：小时
  int countdownMinutes;        // 倒计时模式：分钟
  Frequency frequency;
  List<int> weekDays;          // 每周模式：选中的星期几 (1=周一, 7=周日)
  int? monthlyDay;             // 每月模式：选中的日期 (1-31)
  bool reminderEnabled;        // 是否启用提前提醒
  int reminderMinutes;         // 提前提醒分钟数
  bool workdayOnly;            // 是否仅工作日执行
  bool workdayEveOnly;         // 工作日模式：仅在工作日前一晚执行（跳过周五/法定节假日前一天）
  String? reminderText;        // 提醒任务的提醒文本（仅 remind 类型使用）

  TaskConfig({
    this.taskType = TaskType.shutdown,
    this.scheduleMode = ScheduleMode.countdown,
    this.targetTime,
    this.countdownHours = 1,
    this.countdownMinutes = 30,
    this.frequency = Frequency.weekly,
    this.weekDays = const [1, 2, 3, 4, 5],
    this.monthlyDay,
    this.reminderEnabled = true,
    this.reminderMinutes = 10,
    this.workdayOnly = false,
    this.workdayEveOnly = false,
    this.reminderText,
  });

  /// 把提醒配置固定为绝对触发时间（秒数归零）
  ///
  /// 倒计时模式必须换算成具体时间点再持久化，否则每次应用重启都会
  /// 以"当前时间 + 倒计时"重新计算，提醒时间不断顺延。
  factory TaskConfig.fixedRemind(TaskConfig source, {DateTime? now}) {
    final base = now ?? DateTime.now();
    final DateTime raw;
    if (source.scheduleMode == ScheduleMode.countdown) {
      raw = base.add(Duration(
        hours: source.countdownHours,
        minutes: source.countdownMinutes,
      ));
    } else if (source.targetTime != null) {
      raw = source.targetTime!;
    } else {
      raw = base;
    }

    return TaskConfig(
      taskType: TaskType.remind,
      scheduleMode: ScheduleMode.specificTime,
      targetTime: DateTime(raw.year, raw.month, raw.day, raw.hour, raw.minute, 0),
      reminderText: source.reminderText,
    );
  }

  Map<String, dynamic> toJson() => {
        'taskType': taskType.index,
        'scheduleMode': scheduleMode.name,
        'targetTime': targetTime?.toIso8601String(),
        'countdownHours': countdownHours,
        'countdownMinutes': countdownMinutes,
        'frequency': frequency.index,
        'weekDays': weekDays,
        'monthlyDay': monthlyDay,
        'reminderEnabled': reminderEnabled,
        'reminderMinutes': reminderMinutes,
        'workdayOnly': workdayOnly,
        'workdayEveOnly': workdayEveOnly,
        'reminderText': reminderText,
      };

  /// 旧配置文件里可能仍带有 `idleEnabled` / `idleHours` / `idleMinutes` /
  /// `idleRepeat` / `passwordProtected`（功能从未实现，已于 2026-09-29 移除），
  /// 这些键会被直接忽略，不影响读取。
  factory TaskConfig.fromJson(Map<String, dynamic> json) => TaskConfig(
        taskType: TaskType.values[json['taskType'] ?? 0],
        scheduleMode: _parseScheduleMode(json['scheduleMode']),
        targetTime: json['targetTime'] != null
            ? DateTime.parse(json['targetTime'])
            : null,
        countdownHours: json['countdownHours'] ?? 1,
        countdownMinutes: json['countdownMinutes'] ?? 30,
        frequency: Frequency.values[json['frequency'] ?? 1],
        weekDays: List<int>.from(json['weekDays'] ?? [1, 2, 3, 4, 5]),
        monthlyDay: json['monthlyDay'],
        reminderEnabled: json['reminderEnabled'] ?? true,
        reminderMinutes: json['reminderMinutes'] ?? 10,
        workdayOnly: json['workdayOnly'] ?? false,
        workdayEveOnly: json['workdayEveOnly'] ?? false,
        reminderText: json['reminderText'],
      );
}
