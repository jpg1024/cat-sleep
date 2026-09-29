import 'dart:convert';
import 'dart:io';

import 'package:cat_sleep/models/task_config.dart';
import 'package:cat_sleep/services/remind_task_service.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

const _pathProviderChannel = MethodChannel('plugins.flutter.io/path_provider');

void main() {
  late Directory tempDir;
  late File remindFile;

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    tempDir = await Directory.systemTemp.createTemp('catsleep_remind_test');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_pathProviderChannel, (call) async {
      if (call.method == 'getApplicationDocumentsDirectory') {
        return tempDir.path;
      }
      return null;
    });
    final dir = Directory('${tempDir.path}/CatSleep');
    await dir.create(recursive: true);
    remindFile = File('${dir.path}/remind_tasks.json');
  });

  tearDownAll(() {
    tempDir.deleteSync(recursive: true);
  });

  setUp(() async {
    await remindFile.writeAsString('[]');
  });

  tearDown(() {
    RemindTaskService().dispose();
  });

  Future<void> writeTasks(List<TaskConfig> tasks) async {
    await remindFile.writeAsString(jsonEncode(tasks.map((t) => t.toJson()).toList()));
  }

  TaskConfig remindAt(DateTime time, String text) => TaskConfig(
        taskType: TaskType.remind,
        scheduleMode: ScheduleMode.specificTime,
        targetTime: time,
        reminderText: text,
      );

  test('未到期的提醒任务会被装上定时器', () async {
    final future = DateTime.now().add(const Duration(hours: 2));
    await writeTasks([remindAt(future, '两小时后')]);

    await RemindTaskService().loadAndStartTasks();

    expect(RemindTaskService().activeTimerCount, 1);
  });

  test('已过期的提醒任务不会装定时器', () async {
    await writeTasks([remindAt(DateTime.now().subtract(const Duration(hours: 1)), '过期')]);

    await RemindTaskService().loadAndStartTasks();

    expect(RemindTaskService().activeTimerCount, 0);
  });

  test('targetTime 为空的提醒任务不会被静默装成永不触发的定时器', () async {
    // 主界面"新建任务"曾把倒计时提醒原样存盘（targetTime 为空），
    // 这类任务永远无法调度，必须显式跳过而不是假装已排期。
    await writeTasks([
      TaskConfig(
        taskType: TaskType.remind,
        scheduleMode: ScheduleMode.countdown,
        countdownHours: 0,
        countdownMinutes: 30,
        reminderText: '没有绝对时间',
      ),
    ]);

    await RemindTaskService().loadAndStartTasks();

    expect(RemindTaskService().activeTimerCount, 0);
  });

  test('重新加载会先清掉旧定时器，不会重复排期', () async {
    final future = DateTime.now().add(const Duration(hours: 3));
    await writeTasks([
      remindAt(future, 'A'),
      remindAt(future.add(const Duration(minutes: 10)), 'B'),
    ]);

    final service = RemindTaskService();
    await service.loadAndStartTasks();
    expect(service.activeTimerCount, 2);

    await service.loadAndStartTasks();
    expect(service.activeTimerCount, 2, reason: '重复加载不应叠加定时器');
  });

  test('多条提醒各自独立计时', () async {
    final now = DateTime.now();
    await writeTasks([
      remindAt(now.add(const Duration(hours: 1)), '一小时后'),
      remindAt(now.add(const Duration(days: 1)), '一天后'),
      remindAt(now.subtract(const Duration(minutes: 5)), '已过期'),
    ]);

    await RemindTaskService().loadAndStartTasks();

    expect(RemindTaskService().activeTimerCount, 2);
  });
}
