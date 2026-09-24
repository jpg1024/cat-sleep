import 'dart:async';
import 'package:flutter/material.dart';
import '../models/task_config.dart';
import 'windows_service.dart';
import 'workday_service.dart';

/// 定时调度引擎
/// 单任务模式：全局只维护一个活跃 Timer
class SchedulerService {
  Timer? _timer;
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
  bool get hasActiveTask => _timer != null && _currentConfig != null;

  /// 计算下次触发时间
  Future<DateTime?> _calculateNextTrigger(TaskConfig config) async {
    final now = DateTime.now();

    switch (config.scheduleMode) {
      case ScheduleMode.specificTime:
        if (config.targetTime == null) return null;
        var target = config.targetTime!;

        // 根据频率调整
        if (config.frequency == Frequency.weekly) {
          // 找到下一个匹配的星期几
          while (target.isBefore(now) || !await _shouldExecute(target, config)) {
            target = target.add(const Duration(days: 7));
          }
        } else if (config.frequency == Frequency.monthly) {
          // 找到下一个匹配的日期
          while (target.isBefore(now) || !await _shouldExecute(target, config)) {
            target = DateTime(target.year, target.month + 1, config.monthlyDay ?? target.day, target.hour, target.minute);
          }
        } else {
          // 每天
          while (target.isBefore(now) || !await _shouldExecute(target, config)) {
            target = target.add(const Duration(days: 1));
          }
        }
        return target;

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
        while (!await _isWorkdayTriggerDay(target, config)) {
          target = target.add(const Duration(days: 1));
        }
        return target;
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
    _timer?.cancel();
    _timer = null;

    _currentConfig = config;
    _taskStartTime = DateTime.now();
    final nextTime = await _calculateNextTrigger(config);

    if (nextTime == null) {
      _onStatusChanged?.call();
      return;
    }

    _nextTriggerTime = nextTime;
    final duration = nextTime.difference(DateTime.now());

    if (duration.isNegative) {
      _onStatusChanged?.call();
      return;
    }

    _timer = Timer(duration, () async {
      await _executeTask();
    });

    _onStatusChanged?.call();
  }

  /// 执行任务
  Future<void> _executeTask() async {
    if (_currentConfig == null) return;

    final config = _currentConfig!;

    // 特殊处理提醒类型
    if (config.taskType == TaskType.remind) {
      // 发送系统通知
      final text = config.reminderText != null && config.reminderText!.isNotEmpty
          ? config.reminderText!
          : '定时提醒时间到！';
      await WindowsService.showNotification('猫猫睡觉提醒', text);
      
      // 提醒类型不执行关机操作，直接重置
      _timer = null;
      _currentConfig = null;
      _nextTriggerTime = null;
      _onStatusChanged?.call();
      return;
    }

    // 发送提醒（其他类型的提前提醒）
    if (config.reminderEnabled && config.reminderMinutes > 0) {
      // TODO: 显示提醒通知
    }

    // 执行系统操作（关机/重启等）
    await WindowsService.executeTask(config.taskType.method);

    // 任务完成后重置状态
    _timer = null;
    _currentConfig = null;
    _nextTriggerTime = null;
    _onStatusChanged?.call();
  }

  /// 取消任务
  Future<void> cancelTask() async {
    _timer?.cancel();
    _timer = null;
    _currentConfig = null;
    _nextTriggerTime = null;
    await WindowsService.cancelShutdown();
    _onStatusChanged?.call();
  }

  /// 从配置恢复任务
  Future<void> restoreFromConfig(TaskConfig config) async {
    await startTask(config);
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

  /// specificTime 模式下，从给定时间推算下一次执行时间
  DateTime? _nextSpecificTime(DateTime from, TaskConfig config) {
    final timeOfDay = config.targetTime != null
        ? TimeOfDay(hour: config.targetTime!.hour, minute: config.targetTime!.minute)
        : const TimeOfDay(hour: 23, minute: 55);

    switch (config.frequency) {
      case Frequency.daily:
        return DateTime(from.year, from.month, from.day + 1, timeOfDay.hour, timeOfDay.minute);
      case Frequency.weekly:
        if (config.weekDays.isEmpty) return null;
        var candidate = DateTime(from.year, from.month, from.day + 1, timeOfDay.hour, timeOfDay.minute);
        while (!config.weekDays.contains(candidate.weekday)) {
          candidate = candidate.add(const Duration(days: 1));
        }
        return candidate;
      case Frequency.monthly:
        final day = config.monthlyDay ?? 1;
        var month = from.month + 1;
        var year = from.year;
        if (month > 12) { month = 1; year++; }
        return DateTime(year, month, day, timeOfDay.hour, timeOfDay.minute);
    }
  }

  /// 释放资源
  void dispose() {
    _timer?.cancel();
    _timer = null;
  }
}
