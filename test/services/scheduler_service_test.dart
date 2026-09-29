import 'dart:convert';
import 'dart:io';

import 'package:cat_sleep/models/task_config.dart';
import 'package:cat_sleep/services/scheduler_service.dart';
import 'package:cat_sleep/services/workday_service.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

const _pathProviderChannel = MethodChannel('plugins.flutter.io/path_provider');
const _windowsChannel = MethodChannel('cat_sleep/windows');

/// 预置 2026 全年节假日缓存（含周末），使 isWorkday 完全离线且结果确定
Map<String, dynamic> _build2026Cache() {
  final cache = <String, dynamic>{};
  for (final entry in WorkdayService.holidays2026.entries) {
    cache[entry.key] = {
      'name': entry.value['name'],
      'type': entry.value['type'],
    };
  }
  for (int m = 1; m <= 12; m++) {
    final daysInMonth = DateTime(2026, m + 1, 0).day;
    for (int d = 1; d <= daysInMonth; d++) {
      final date = DateTime(2026, m, d);
      final key =
          '2026-${m.toString().padLeft(2, '0')}-${d.toString().padLeft(2, '0')}';
      if (cache.containsKey(key)) continue;
      final isWeekend = date.weekday == 6 || date.weekday == 7;
      cache[key] = {'name': '', 'type': isWeekend ? 'holiday' : 'workday'};
    }
  }
  return cache;
}

void main() {
  late Directory tempDir;

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    tempDir = await Directory.systemTemp.createTemp('catsleep_sched_test');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_pathProviderChannel, (call) async {
      if (call.method == 'getApplicationDocumentsDirectory') {
        return tempDir.path;
      }
      return null;
    });
    final dir = Directory('${tempDir.path}/CatSleep');
    await dir.create(recursive: true);
    await File('${dir.path}/holiday_cache.json')
        .writeAsString(jsonEncode(_build2026Cache()));
  });

  tearDownAll(() {
    tempDir.deleteSync(recursive: true);
  });

  TaskConfig _workdayConfig({required bool eveMode}) {
    final now = DateTime.now();
    return TaskConfig(
      scheduleMode: ScheduleMode.workday,
      targetTime: DateTime(now.year, now.month, now.day, 23, 55),
      workdayEveOnly: eveMode,
    );
  }

  test('eve 模式：接下来 5 个执行时间次日均为工作日', () async {
    final scheduler = SchedulerService();
    final list = await scheduler.getNextExecutions(_workdayConfig(eveMode: true),
        count: 5);

    expect(list.length, 5);
    for (final d in list) {
      final tomorrowIsWorkday =
          await WorkdayService.isWorkday(d.add(const Duration(days: 1)));
      expect(tomorrowIsWorkday, isTrue,
          reason: 'eve 模式执行日 $d 的次日必须是工作日（周五/法定节假日前一天应被跳过）');
    }
    scheduler.dispose();
  });

  test('eve 模式：包含周末/节假日结束当天的晚上执行', () async {
    final scheduler = SchedulerService();
    final list = await scheduler.getNextExecutions(_workdayConfig(eveMode: true),
        count: 5);

    // 普通模式的执行日全部是工作日；eve 模式会额外包含周日、节假日结束当天等非工作日
    var hasNonWorkdayTrigger = false;
    for (final d in list) {
      if (!await WorkdayService.isWorkday(d)) hasNonWorkdayTrigger = true;
    }
    expect(hasNonWorkdayTrigger, isTrue,
        reason: 'eve 模式应包含周日晚上/法定节假日结束当天晚上的执行');
    scheduler.dispose();
  });

  test('普通工作日模式：执行日全部是工作日（回归）', () async {
    final scheduler = SchedulerService();
    final list =
        await scheduler.getNextExecutions(_workdayConfig(eveMode: false), count: 5);

    expect(list.length, 5);
    for (final d in list) {
      expect(await WorkdayService.isWorkday(d), isTrue,
          reason: '普通工作日模式执行日 $d 必须是工作日');
    }
    scheduler.dispose();
  });

  group('任务执行', () {
    late List<String> invokedMethods;

    setUp(() {
      invokedMethods = <String>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(_windowsChannel, (call) async {
        invokedMethods.add(call.method);
        return null;
      });
    });

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(_windowsChannel, null);
    });

    test('周期任务（工作日模式）执行后重新排期，不会消失', () async {
      final scheduler = SchedulerService();
      await scheduler.startTask(TaskConfig(
        taskType: TaskType.shutdown,
        scheduleMode: ScheduleMode.workday,
        targetTime: DateTime(2026, 1, 1, 23, 55),
        workdayEveOnly: false,
      ));

      expect(scheduler.hasActiveTask, isTrue, reason: '启动后应处于活跃状态');
      final firstTrigger = scheduler.nextTriggerTime;
      expect(firstTrigger, isNotNull);

      await scheduler.debugExecuteTask();

      expect(invokedMethods, contains('shutdown'), reason: '应调用关机操作');
      expect(scheduler.hasActiveTask, isTrue,
          reason: '工作日模式是周期任务，执行一次后必须继续排下一次，不能清空');
      expect(scheduler.currentConfig, isNotNull);
      expect(scheduler.nextTriggerTime, isNotNull);
      expect(scheduler.nextTriggerTime, firstTrigger);
      scheduler.dispose();
    });

    test('周期任务（指定时间 + 每天）执行后重新排期', () async {
      final scheduler = SchedulerService();
      final now = DateTime.now();
      await scheduler.startTask(TaskConfig(
        taskType: TaskType.lock,
        scheduleMode: ScheduleMode.specificTime,
        targetTime: DateTime(now.year, now.month, now.day, 23, 55),
        frequency: Frequency.daily,
      ));

      expect(scheduler.hasActiveTask, isTrue);

      await scheduler.debugExecuteTask();

      expect(invokedMethods, contains('lock'));
      expect(scheduler.hasActiveTask, isTrue,
          reason: '指定时间 + 每天是周期任务，执行后应继续保留');
      scheduler.dispose();
    });

    test('一次性倒计时任务执行后清空状态', () async {
      final scheduler = SchedulerService();
      await scheduler.startTask(TaskConfig(
        taskType: TaskType.lock,
        scheduleMode: ScheduleMode.countdown,
        countdownHours: 1,
        countdownMinutes: 0,
      ));

      expect(scheduler.hasActiveTask, isTrue);

      await scheduler.debugExecuteTask();

      expect(invokedMethods, contains('lock'));
      expect(scheduler.hasActiveTask, isFalse,
          reason: '倒计时是一次性任务，执行后应清空');
      expect(scheduler.currentConfig, isNull);
      expect(scheduler.nextTriggerTime, isNull);
      scheduler.dispose();
    });

    test('系统操作抛异常时不会中断调度', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(_windowsChannel, (call) async {
        throw PlatformException(code: 'boom', message: '原生调用失败');
      });

      final scheduler = SchedulerService();
      await scheduler.startTask(TaskConfig(
        taskType: TaskType.shutdown,
        scheduleMode: ScheduleMode.workday,
        targetTime: DateTime(2026, 1, 1, 23, 55),
      ));

      await scheduler.debugExecuteTask();

      expect(scheduler.hasActiveTask, isTrue,
          reason: '单次原生调用失败不应让周期任务彻底消失');
      scheduler.dispose();
    });

    test('每周频率与所选星期矛盾时不会死循环，任务安全失效', () async {
      final scheduler = SchedulerService();
      final now = DateTime.now();
      // targetTime 落在周三，但 weekDays 只勾了周一，且开启仅工作日过滤
      final wednesday = now.subtract(Duration(days: now.weekday - 3));
      await scheduler
          .startTask(TaskConfig(
        taskType: TaskType.lock,
        scheduleMode: ScheduleMode.specificTime,
        targetTime: DateTime(wednesday.year, wednesday.month, wednesday.day, 22, 0),
        frequency: Frequency.weekly,
        weekDays: [1],
        workdayOnly: true,
      ))
          .timeout(const Duration(seconds: 20), onTimeout: () {
        fail('startTask 在矛盾配置下卡住（死循环）');
      });

      expect(scheduler.hasActiveTask, isFalse,
          reason: '找不到合法执行时间时应放弃排期，而不是永久挂起');
      expect(scheduler.currentConfig, isNull);
      scheduler.dispose();
    });
  });

  group('提前提醒', () {
    setUp(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(_windowsChannel, (call) async => null);
    });

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(_windowsChannel, null);
    });

    /// 默认 2 小时后执行的一次性任务
    TaskConfig countdownTask({
      required bool reminderEnabled,
      required int reminderMinutes,
      TaskType taskType = TaskType.shutdown,
      int countdownMinutes = 120,
    }) =>
        TaskConfig(
          taskType: taskType,
          scheduleMode: ScheduleMode.countdown,
          countdownHours: 0,
          countdownMinutes: countdownMinutes,
          reminderEnabled: reminderEnabled,
          reminderMinutes: reminderMinutes,
        );

    test('开启提前提醒且提前量足够时，会装载提醒定时器', () async {
      final scheduler = SchedulerService();
      await scheduler.startTask(countdownTask(reminderEnabled: true, reminderMinutes: 10));

      expect(scheduler.hasActiveTask, isTrue);
      expect(scheduler.hasPendingPreReminder, isTrue,
          reason: '2 小时后执行、提前 10 分钟提醒，应当装上提醒定时器');
      scheduler.dispose();
    });

    test('关闭提前提醒时不装载', () async {
      final scheduler = SchedulerService();
      await scheduler.startTask(countdownTask(reminderEnabled: false, reminderMinutes: 10));

      expect(scheduler.hasActiveTask, isTrue);
      expect(scheduler.hasPendingPreReminder, isFalse);
      scheduler.dispose();
    });

    test('提前量为 0 时不装载', () async {
      final scheduler = SchedulerService();
      await scheduler.startTask(countdownTask(reminderEnabled: true, reminderMinutes: 0));

      expect(scheduler.hasActiveTask, isTrue);
      expect(scheduler.hasPendingPreReminder, isFalse);
      scheduler.dispose();
    });

    test('距执行时间不足提前量时跳过，避免立刻弹窗', () async {
      final scheduler = SchedulerService();
      await scheduler.startTask(countdownTask(
        reminderEnabled: true,
        reminderMinutes: 10,
        countdownMinutes: 5, // 只剩 5 分钟，却要提前 10 分钟提醒
      ));

      expect(scheduler.hasActiveTask, isTrue);
      expect(scheduler.hasPendingPreReminder, isFalse,
          reason: '提前量大于剩余时间时应跳过，而不是立即弹出');
      scheduler.dispose();
    });

    test('提醒类型任务不叠加提前提醒', () async {
      final scheduler = SchedulerService();
      await scheduler.startTask(countdownTask(
        reminderEnabled: true,
        reminderMinutes: 10,
        taskType: TaskType.remind,
      ));

      expect(scheduler.hasActiveTask, isTrue);
      expect(scheduler.hasPendingPreReminder, isFalse,
          reason: '提醒任务本身就是提醒，不应再叠加一层提前提醒');
      scheduler.dispose();
    });

    test('取消任务时一并清掉提前提醒', () async {
      final scheduler = SchedulerService();
      await scheduler.startTask(countdownTask(reminderEnabled: true, reminderMinutes: 10));
      expect(scheduler.hasPendingPreReminder, isTrue);

      await scheduler.cancelTask();

      expect(scheduler.hasPendingPreReminder, isFalse);
      expect(scheduler.hasActiveTask, isFalse);
      scheduler.dispose();
    });

    test('一次性任务执行后清掉提前提醒', () async {
      final scheduler = SchedulerService();
      await scheduler.startTask(countdownTask(reminderEnabled: true, reminderMinutes: 10));
      expect(scheduler.hasPendingPreReminder, isTrue);

      await scheduler.debugExecuteTask();

      expect(scheduler.hasPendingPreReminder, isFalse);
      expect(scheduler.hasActiveTask, isFalse);
      scheduler.dispose();
    });

    test('周期任务执行后重新装载提前提醒', () async {
      final scheduler = SchedulerService();
      final now = DateTime.now();
      final target = now.add(const Duration(hours: 2));
      await scheduler.startTask(TaskConfig(
        taskType: TaskType.lock,
        scheduleMode: ScheduleMode.specificTime,
        targetTime: DateTime(target.year, target.month, target.day, target.hour, target.minute),
        frequency: Frequency.daily,
        reminderEnabled: true,
        reminderMinutes: 10,
      ));

      expect(scheduler.hasPendingPreReminder, isTrue);

      await scheduler.debugExecuteTask();

      expect(scheduler.hasActiveTask, isTrue, reason: '周期任务执行后应重排');
      expect(scheduler.hasPendingPreReminder, isTrue,
          reason: '重排后必须重新装载下一次执行的提前提醒');
      scheduler.dispose();
    });
  });
}
