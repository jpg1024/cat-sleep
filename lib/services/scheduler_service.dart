import 'dart:async';
import 'package:flutter/material.dart';
import '../models/task_config.dart';
import 'log_service.dart';
import 'notification_service.dart';
import 'windows_service.dart';
import 'workday_service.dart';

/// 定时调度引擎
/// 单任务模式：全局只维护一个活跃 Timer
class SchedulerService {
  /// 推算下次执行时间时的最大步数，防止配置自相矛盾时死循环
  static const int _maxSearchSteps = 500;

  Timer? _timer;
  Timer? _reminderTimer;
  TaskConfig? _currentConfig;
  DateTime? _nextTriggerTime;
  DateTime _taskStartTime = DateTime.now();
  VoidCallback? _onStatusChanged;

  /// 设置状态变化回调
  void onStatusChanged(VoidCallback callback) {
    _onStatusChanged = callback;
  }

  /// 获取当前任务配置
  TaskConfig? get currentConfig => _currentConfig;

  /// 获取下次触发时间
  DateTime? get nextTriggerTime => _nextTriggerTime;

  /// 是否有活跃任务
  ///
  /// 以 `_currentConfig` 为准：周期任务执行后即使定时器尚未重新装载
  /// （如 _reschedule 暂未找到下次时间），任务仍应视为"活跃"，
  /// 保证主界面时间线不消失。
  bool get hasActiveTask => _currentConfig != null;

  /// 是否已装载"提前提醒"定时器
  @visibleForTesting
  bool get hasPendingPreReminder => _reminderTimer != null;

  /// 计算下次触发时间
  Future<DateTime?> _calculateNextTrigger(TaskConfig config) async {
    final now = DateTime.now();

    switch (config.scheduleMode) {
      case ScheduleMode.specificTime:
        if (config.targetTime == null) return null;
        var target = config.targetTime!;

        // 按频率逐步推进；带步数上限，避免"每周但未勾选该星期几"这类
        // 矛盾配置让循环永不退出（会永久卡住 startTask）
        for (int step = 0; step < _maxSearchSteps; step++) {
          if (!target.isBefore(now) && await _shouldExecute(target, config)) {
            return target;
          }
          target = _advance(target, config);
        }
        await LogService.write(
          '[SchedulerService] No valid execution time within $_maxSearchSteps steps '
          '(frequency=${config.frequency.name}, weekDays=${config.weekDays}, '
          'workdayOnly=${config.workdayOnly})',
        );
        return null;

      case ScheduleMode.countdown:
        return now.add(Duration(
          hours: config.countdownHours,
          minutes: config.countdownMinutes,
        ));

      case ScheduleMode.workday:
        // 找到下一个满足执行条件的日期
        var target = DateTime(
          now.year, now.month, now.day,
          config.targetTime?.hour ?? 23,
          config.targetTime?.minute ?? 55,
        );
        // 如果今天还没到执行时间且满足执行条件
        if (target.isAfter(now) && await _isWorkdayTriggerDay(target, config)) {
          return target;
        }
        // 否则逐天后移寻找满足条件的日期
        target = target.add(const Duration(days: 1));
        for (int step = 0; step < _maxSearchSteps; step++) {
          if (await _isWorkdayTriggerDay(target, config)) return target;
          target = target.add(const Duration(days: 1));
        }
        await LogService.write(
          '[SchedulerService] No workday trigger day within $_maxSearchSteps days',
        );
        return null;
    }
  }

  /// 按频率把候选时间推进到下一个周期
  DateTime _advance(DateTime target, TaskConfig config) {
    switch (config.frequency) {
      case Frequency.weekly:
        return target.add(const Duration(days: 7));
      case Frequency.monthly:
        return DateTime(
          target.year,
          target.month + 1,
          config.monthlyDay ?? target.day,
          target.hour,
          target.minute,
        );
      case Frequency.daily:
        return target.add(const Duration(days: 1));
    }
  }

  /// 工作日模式的执行日期是否有效
  /// workdayEveOnly=true：仅在次日为工作日的当天晚上执行（跳过周末/节假日前一天）
  Future<bool> _isWorkdayTriggerDay(DateTime day, TaskConfig config) async {
    if (!config.workdayEveOnly) {
      return await WorkdayService.isWorkday(day);
    }
    // workdayEveOnly: 检查次日是否为工作日
    return await WorkdayService.isWorkday(day.add(const Duration(days: 1)));
  }

  /// 检查是否应该在该日期执行（工作日过滤）
  Future<bool> _shouldExecute(DateTime date, TaskConfig config) async {
    if (!config.workdayOnly) return true;

    if (config.frequency == Frequency.weekly) {
      // 检查星期几是否匹配
      if (!config.weekDays.contains(date.weekday)) return false;
    }

    return await WorkdayService.isWorkday(date);
  }

  /// 启动任务
  Future<void> startTask(TaskConfig config) async {
    // 先取消旧任务（不触发状态回调）
    _cancelTimers();

    _currentConfig = config;
    _taskStartTime = DateTime.now();
    final nextTime = await _calculateNextTrigger(config);

    if (nextTime == null) {
      await LogService.write(
        '[SchedulerService] startTask aborted: no next trigger time '
        '(type=${config.taskType.name}, mode=${config.scheduleMode.name})',
      );
      _currentConfig = null;
      _nextTriggerTime = null;
      _onStatusChanged?.call();
      return;
    }

    _nextTriggerTime = nextTime;
    final duration = nextTime.difference(DateTime.now());

    if (duration.isNegative) {
      await LogService.write('[SchedulerService] startTask aborted: next trigger $nextTime is in the past');
      _currentConfig = null;
      _nextTriggerTime = null;
      _onStatusChanged?.call();
      return;
    }

    _armTimers(config, nextTime);

    await LogService.write(
      '[SchedulerService] Task armed: type=${config.taskType.name}, '
      'mode=${config.scheduleMode.name}, next=$nextTime '
      '(in ${duration.inMinutes} min'
      '${_reminderTimer != null ? ", pre-reminder ${config.reminderMinutes}min before" : ""})',
    );

    _onStatusChanged?.call();
  }

  /// 是否需要提前提醒（提醒类型本身就是提醒，不再叠加）
  bool _shouldPreRemind(TaskConfig config) =>
      config.taskType != TaskType.remind &&
      config.reminderEnabled &&
      config.reminderMinutes > 0;

  /// 装载执行定时器，并按需装载提前提醒定时器
  void _armTimers(TaskConfig config, DateTime nextTime) {
    final now = DateTime.now();
    var duration = nextTime.difference(now);
    if (duration.isNegative) duration = Duration.zero;

    _timer = Timer(duration, () async => _executeTask());

    _reminderTimer?.cancel();
    _reminderTimer = null;

    if (!_shouldPreRemind(config)) return;

    final lead = Duration(minutes: config.reminderMinutes);
    if (duration <= lead) {
      return;
    }

    _reminderTimer = Timer(duration - lead, () => _firePreReminder(config, nextTime));
  }

  /// 触发提前提醒
  Future<void> _firePreReminder(TaskConfig config, DateTime triggerTime) async {
    _reminderTimer = null;
    final hh = triggerTime.hour.toString().padLeft(2, '0');
    final mm = triggerTime.minute.toString().padLeft(2, '0');
    final message = '将在 ${config.reminderMinutes} 分钟后（$hh:$mm）'
        '执行「${config.taskType.label}」';

    await LogService.write('[SchedulerService] Pre-reminder fired: $message');

    try {
      await NotificationService.showNotification(title: '猫猫睡觉提醒', message: message);
    } catch (e, stackTrace) {
      // 提前提醒失败不能影响真正的任务执行
      await LogService.write('[SchedulerService] Pre-reminder failed: $e\n$stackTrace');
    }
  }

  /// 只取消定时器，不动任务状态
  void _cancelTimers() {
    _timer?.cancel();
    _timer = null;
    _reminderTimer?.cancel();
    _reminderTimer = null;
  }

  /// 该配置是否为周期任务（执行后需要重新排期）
  bool _isRecurring(TaskConfig config) {
    if (config.taskType == TaskType.remind) return false;
    return config.scheduleMode == ScheduleMode.workday ||
        config.scheduleMode == ScheduleMode.specificTime;
  }

  /// 立即执行当前任务（与定时器触发走完全相同的路径）
  ///
  /// 仅供测试驱动，避免测试依赖真实 Timer 等待。
  @visibleForTesting
  Future<void> debugExecuteTask() => _executeTask();

  /// 执行任务
  Future<void> _executeTask() async {
    if (_currentConfig == null) return;

    final config = _currentConfig!;
    // 执行时间已到，提前提醒不再有意义的情况（提前量为 0 或被跳过）
    _reminderTimer?.cancel();
    _reminderTimer = null;

    await LogService.write(
      '[SchedulerService] Task fired: type=${config.taskType.name}, '
      'scheduled=$_nextTriggerTime',
    );

    // 特殊处理提醒类型
    if (config.taskType == TaskType.remind) {
      final text = config.reminderText != null && config.reminderText!.isNotEmpty
          ? config.reminderText!
          : '定时提醒时间到！';
      // 走 NotificationService，保证托盘/最小化状态下也能强制弹出
      await NotificationService.showNotification(title: '猫猫睡觉提醒', message: text);
      _clearTask();
      return;
    }

    // 执行系统操作（关机/重启等）
    try {
      await WindowsService.executeTask(config.taskType.method);
      await LogService.write('[SchedulerService] Executed: ${config.taskType.method}');
    } catch (e, stackTrace) {
      await LogService.write(
        '[SchedulerService] Failed to execute ${config.taskType.method}: $e\n$stackTrace',
      );
    }

    // 周期任务重新排期，一次性任务清空状态
    if (_isRecurring(config)) {
      await _reschedule(config);
    } else {
      _clearTask();
    }
  }

  /// 为周期任务排下一次执行
  ///
  /// 周期任务（workday / specificTime）执行后必须保留任务状态，
  /// 即使暂时找不到下次执行时间也不能 `_clearTask()`——任务配置
  /// 仍需保留，因为后续还有执行机会。
  Future<void> _reschedule(TaskConfig config) async {
    _cancelTimers();
    final nextTime = await _calculateNextTrigger(config);

    if (nextTime == null) {
      await LogService.write(
        '[SchedulerService] Reschedule: no next trigger time found, '
        'keeping task alive for retry (type=${config.taskType.name}, '
        'mode=${config.scheduleMode.name})',
      );
      // 不删除任务：周期任务还有后续执行机会，保留配置等待下次重试
      _nextTriggerTime = null;
      _onStatusChanged?.call();
      return;
    }

    _taskStartTime = DateTime.now();
    _nextTriggerTime = nextTime;
    _armTimers(config, nextTime);

    await LogService.write('[SchedulerService] Rescheduled next run at $nextTime');
    _onStatusChanged?.call();
  }

  /// 清空当前任务状态
  void _clearTask() {
    _cancelTimers();
    _currentConfig = null;
    _nextTriggerTime = null;
    _onStatusChanged?.call();
  }

  /// 取消任务
  Future<void> cancelTask() async {
    await LogService.write(
      '[SchedulerService] Cancelling task (type=${_currentConfig?.taskType.name}, '
      'next=$_nextTriggerTime)',
    );
    _cancelTimers();
    _currentConfig = null;
    _nextTriggerTime = null;
    // 先刷新 UI，再做原生的兜底取消，避免原生调用抛异常时界面不更新
    _onStatusChanged?.call();

    try {
      await WindowsService.cancelShutdown();
    } catch (e) {
      // 没有待取消的系统关机时属正常情况，不应影响任务取消
      await LogService.write('[SchedulerService] cancelShutdown ignored: $e');
    }
  }

  /// 从配置恢复任务
  ///
  /// 恢复失败时不抛异常——主界面必须能正常显示，即使任务无法恢复。
  Future<void> restoreFromConfig(TaskConfig config) async {
    try {
      await startTask(config);
    } catch (e, stackTrace) {
      await LogService.write(
        '[SchedulerService] restoreFromConfig failed: $e\n$stackTrace',
      );
      _currentConfig = null;
      _nextTriggerTime = null;
    }
  }

  /// 设置变更（如提前提醒分钟数）后按当前执行时间重新装载定时器
  ///
  /// 与 `startTask` 的区别：不重新推算 `_nextTriggerTime`，也不重置
  /// `_taskStartTime`，因此倒计时任务不会被"从现在开始"重新计时。
  Future<void> refreshSettings() async {
    final config = _currentConfig;
    final nextTime = _nextTriggerTime;
    if (config == null || nextTime == null) return;

    _cancelTimers();
    _armTimers(config, nextTime);
    await LogService.write(
      '[SchedulerService] Timers re-armed after settings change, next=$nextTime',
    );
    _onStatusChanged?.call();
  }

  /// 获取剩余时间字符串
  String? getRemainingTime() {
    if (_nextTriggerTime == null) return null;
    final remaining = _nextTriggerTime!.difference(DateTime.now());
    if (remaining.isNegative) return '已过期';

    final hours = remaining.inHours;
    final minutes = remaining.inMinutes % 60;
    final seconds = remaining.inSeconds % 60;

    if (hours > 0) {
      return '${hours}小时${minutes}分${seconds}秒';
    } else if (minutes > 0) {
      return '${minutes}分${seconds}秒';
    } else {
      return '${seconds}秒';
    }
  }

  /// 获取进度（0.0 ~ 1.0）
  double getProgress() {
    if (_nextTriggerTime == null || _currentConfig == null) return 0.0;

    final now = DateTime.now();
    final total = _nextTriggerTime!.difference(_taskStartTime).inSeconds;
    if (total <= 0) return 1.0;

    final elapsed = now.difference(_taskStartTime).inSeconds;
    return (elapsed / total).clamp(0.0, 1.0);
  }

  /// 获取最近 N 次执行时间（仅当前年度）
  Future<List<DateTime>> getNextExecutions(TaskConfig config, {int count = 10}) async {
    final result = <DateTime>[];
    final currentYear = DateTime.now().year;
    final yearEnd = DateTime(currentYear + 1, 1, 1);

    var nextTimeNullable = await _calculateNextTrigger(config);
    if (nextTimeNullable == null) return result;

    var nextTime = nextTimeNullable;
    if (nextTime.isBefore(yearEnd)) {
      result.add(nextTime);
    } else {
      return result;
    }

    // 从 nextTime+1 开始逐天遍历，收集所有满足条件的日期
    var candidate = nextTime.add(const Duration(days: 1));
    int totalChecked = 0;
    while (result.length < count && candidate.isBefore(yearEnd)) {
      totalChecked++;
      bool shouldExecute = false;
      switch (config.scheduleMode) {
        case ScheduleMode.specificTime:
          // specificTime 模式：检查日期是否匹配频率规则
          shouldExecute = await _matchesFrequency(candidate, config);
          if (config.workdayOnly && shouldExecute) {
            shouldExecute = await WorkdayService.isWorkday(candidate);
          }
          break;

        case ScheduleMode.countdown:
          // countdown 模式：一次性任务，不再有更多执行
          return result;

        case ScheduleMode.workday:
          // workday 模式：检查"次日是否为工作日"（workdayEveOnly 语义）
          shouldExecute = await _isWorkdayTriggerDay(candidate, config);
      }

      if (shouldExecute) {
        result.add(candidate);
      }
      candidate = candidate.add(const Duration(days: 1));
    }

    // 验证：确保检查了足够的天数
    // 从 9/24 到 12/31 共 99 天，应该能找到 66 次（加上首个执行日共 67 次）
    // 如果只找到很少的次数，说明有问题
    if (totalChecked > 50 && result.length < 40) {
      print('[WARNING] 检查了 $totalChecked 天，但只找到 ${result.length} 次执行，可能存在逻辑问题');
    }

    return result;
  }

  /// 检查日期是否匹配频率规则（specificTime 模式）
  Future<bool> _matchesFrequency(DateTime date, TaskConfig config) async {
    if (config.targetTime == null) return false;
    
    // 检查时间是否匹配
    if (date.hour != config.targetTime!.hour || date.minute != config.targetTime!.minute) {
      return false;
    }

    switch (config.frequency) {
      case Frequency.daily:
        return true;
      case Frequency.weekly:
        return config.weekDays.contains(date.weekday);
      case Frequency.monthly:
        return date.day == (config.monthlyDay ?? date.day);
    }
  }

  /// 释放资源
  void dispose() {
    _cancelTimers();
  }
}
