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

  /// 加载所有提醒任务并启动定时器
  Future<void> loadAndStartTasks() async {
    // 先取消所有旧的定时器
    await cancelAll();
    
    final tasks = await StorageService.loadRemindTasks();
    await LogService.write('[RemindTaskService] Loaded ${tasks.length} remind tasks');
    
    for (final task in tasks) {
      if (task.targetTime != null && task.targetTime!.isAfter(DateTime.now())) {
        await LogService.write('[RemindTaskService] Starting timer for: "${task.reminderText}" at ${task.targetTime}');
        
        final duration = task.targetTime!.difference(DateTime.now());
        final timer = Timer(duration, () async {
          await LogService.write('[RemindTaskService] Task triggered: "${task.reminderText}"');
          await NotificationService.showNotification(
            title: '猫猫睡觉提醒',
            message: task.reminderText ?? '定时提醒时间到！',
          );
          
          // 触发后从列表中删除（一次性提醒）
          final allTasks = await StorageService.loadRemindTasks();
          allTasks.removeWhere((t) => t.targetTime == task.targetTime && t.reminderText == task.reminderText);
          await StorageService.saveRemindTasks(allTasks);
          await LogService.write('[RemindTaskService] Task completed and removed');
        });
        
        _timers.add(timer);
      } else if (task.targetTime != null) {
        await LogService.write('[RemindTaskService] Skipping expired task: "${task.reminderText}" at ${task.targetTime}');
      }
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
