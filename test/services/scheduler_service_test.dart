import 'dart:convert';
import 'dart:io';

import 'package:cat_sleep/models/task_config.dart';
import 'package:cat_sleep/services/scheduler_service.dart';
import 'package:cat_sleep/services/workday_service.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

const _pathProviderChannel = MethodChannel('plugins.flutter.io/path_provider');

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
}
