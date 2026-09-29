import 'dart:async';
import '../models/task_config.dart';
import '../services/storage_service.dart';
import '../services/notification_service.dart';
import '../services/log_service.dart';

/// 提醒任务服务：管理所有提醒任务的定时器
class RemindTaskService {
  static final RemindTaskService _instance = RemindTaskService._internal();
  factory RemindTaskService() => _instance;
  RemindTaskService._internal();

  final List<Timer> _timers = [];

  /// 当前已启动的定时器数量
  int get activeTimerCount => _timers.length;

  /// 加载所有提醒任务并启动定时器
  Future<void> loadAndStartTasks() async {
    // 先取消所有旧的定时器
    await cancelAll();

    final tasks = await StorageService.loadRemindTasks();
    final now = DateTime.now();
    await LogService.write('[RemindTaskService] Loaded ${tasks.length} remind tasks');

    for (final task in tasks) {
      final targetTime = task.targetTime;
      if (targetTime == null) {
        // 没有绝对触发时间的提醒永远无法调度，必须显式记录而不是静默丢弃
        await LogService.write(
          '[RemindTaskService] Skipping task without targetTime: "${task.reminderText}" '
          '(scheduleMode=${task.scheduleMode.name}, countdown='
          '${task.countdownHours}h${task.countdownMinutes}m)',
        );
        continue;
      }

      if (!targetTime.isAfter(now)) {
        await LogService.write('[RemindTaskService] Skipping expired task: "${task.reminderText}" at $targetTime');
        continue;
      }

      final duration = targetTime.difference(DateTime.now());
      await LogService.write(
        '[RemindTaskService] Starting timer for: "${task.reminderText}" at $targetTime '
        '(in ${duration.inMinutes} min)',
      );

      _timers.add(Timer(duration, () => _fire(task)));
    }

    await LogService.write('[RemindTaskService] ${_timers.length} timer(s) armed');
  }

  /// 触发单个提醒任务：弹出通知后将其从列表中移除（一次性提醒）
  Future<void> _fire(TaskConfig task) async {
    await LogService.write('[RemindTaskService] Task triggered: "${task.reminderText}"');

    try {
      await NotificationService.showNotification(
        title: '猫猫睡觉提醒',
        message: (task.reminderText == null || task.reminderText!.isEmpty)
            ? '定时提醒时间到！'
            : task.reminderText!,
      );
    } catch (e, stackTrace) {
      // 通知失败也必须继续清理，否则任务会残留在列表里反复触发
      await LogService.write('[RemindTaskService] Notification failed: $e\n$stackTrace');
    }

    try {
      final allTasks = await StorageService.loadRemindTasks();
      allTasks.removeWhere(
        (t) => t.targetTime == task.targetTime && t.reminderText == task.reminderText,
      );
      await StorageService.saveRemindTasks(allTasks);
      await LogService.write('[RemindTaskService] Task completed and removed');
    } catch (e, stackTrace) {
      await LogService.write('[RemindTaskService] Failed to remove fired task: $e\n$stackTrace');
    }
  }

  /// 取消所有定时器
  Future<void> cancelAll() async {
    await LogService.write('[RemindTaskService] Cancelling ${_timers.length} timers');
    for (final timer in _timers) {
      timer.cancel();
    }
    _timers.clear();
  }

  /// 释放资源
  void dispose() {
    for (final timer in _timers) {
      timer.cancel();
    }
    _timers.clear();
  }
}
