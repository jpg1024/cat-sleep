import 'dart:convert';
import 'dart:io';

import 'package:cat_sleep/models/task_config.dart';
import 'package:cat_sleep/widgets/create_task_dialog.dart';
import 'package:cat_sleep/widgets/holiday_calendar.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

const _pathProviderChannel = MethodChannel('plugins.flutter.io/path_provider');

/// 预置 2026 全年节假日缓存，使 isWorkday 完全离线且结果确定
Map<String, dynamic> _build2026Cache() {
  final cache = <String, dynamic>{};
  // 复制 WorkdayService.holidays2026 的数据
  const holidays = {
    '2026-01-01': {'name': '元旦', 'type': 'holiday'},
    '2026-01-02': {'name': '元旦', 'type': 'holiday'},
    '2026-01-03': {'name': '元旦', 'type': 'holiday'},
    '2026-01-04': {'name': '班', 'type': 'workday'},
    '2026-02-14': {'name': '班', 'type': 'workday'},
    '2026-02-15': {'name': '春节', 'type': 'holiday'},
    '2026-02-16': {'name': '春节', 'type': 'holiday'},
    '2026-02-17': {'name': '春节', 'type': 'holiday'},
    '2026-02-18': {'name': '春节', 'type': 'holiday'},
    '2026-02-19': {'name': '春节', 'type': 'holiday'},
    '2026-02-20': {'name': '春节', 'type': 'holiday'},
    '2026-02-21': {'name': '春节', 'type': 'holiday'},
    '2026-02-22': {'name': '春节', 'type': 'holiday'},
    '2026-02-23': {'name': '春节', 'type': 'holiday'},
    '2026-02-28': {'name': '班', 'type': 'workday'},
    '2026-04-04': {'name': '清明', 'type': 'holiday'},
    '2026-04-05': {'name': '清明', 'type': 'holiday'},
    '2026-04-06': {'name': '清明', 'type': 'holiday'},
    '2026-05-01': {'name': '劳动节', 'type': 'holiday'},
    '2026-05-02': {'name': '劳动节', 'type': 'holiday'},
    '2026-05-03': {'name': '劳动节', 'type': 'holiday'},
    '2026-05-04': {'name': '劳动节', 'type': 'holiday'},
    '2026-05-05': {'name': '劳动节', 'type': 'holiday'},
    '2026-05-09': {'name': '班', 'type': 'workday'},
    '2026-06-19': {'name': '端午', 'type': 'holiday'},
    '2026-06-20': {'name': '端午', 'type': 'holiday'},
    '2026-06-21': {'name': '端午', 'type': 'holiday'},
    '2026-09-25': {'name': '中秋', 'type': 'holiday'},
    '2026-09-26': {'name': '中秋', 'type': 'holiday'},
    '2026-09-27': {'name': '中秋', 'type': 'holiday'},
    '2026-09-20': {'name': '班', 'type': 'workday'},
    '2026-10-01': {'name': '国庆', 'type': 'holiday'},
    '2026-10-02': {'name': '国庆', 'type': 'holiday'},
    '2026-10-03': {'name': '国庆', 'type': 'holiday'},
    '2026-10-04': {'name': '国庆', 'type': 'holiday'},
    '2026-10-05': {'name': '国庆', 'type': 'holiday'},
    '2026-10-06': {'name': '国庆', 'type': 'holiday'},
    '2026-10-07': {'name': '国庆', 'type': 'holiday'},
    '2026-10-10': {'name': '班', 'type': 'workday'},
  };
  cache.addAll(holidays);
  // 补齐全年周末
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
    tempDir = await Directory.systemTemp.createTemp('catsleep_test');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_pathProviderChannel, (call) async {
      if (call.method == 'getApplicationDocumentsDirectory') {
        return tempDir.path;
      }
      return null;
    });
    // 预置 CatSleep 目录和节假日缓存文件
    final dir = Directory('${tempDir.path}/CatSleep');
    await dir.create(recursive: true);
    await File('${dir.path}/holiday_cache.json')
        .writeAsString(jsonEncode(_build2026Cache()));
  });

  tearDownAll(() {
    tempDir.deleteSync(recursive: true);
  });

  /// 打开新建任务弹窗并等待节假日日历异步加载完成
  Future<void> openDialog(WidgetTester tester, TaskConfig config) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () => showDialog(
              context: context,
              builder: (_) => CreateTaskDialog(config: config),
            ),
            child: const Text('open'),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('open'));
    await tester.pump();
    // 用 pump 循环等待异步计算完成（最多 5 秒）
    for (int i = 0; i < 100; i++) {
      await tester.pump(const Duration(milliseconds: 50));
      if (find.byType(HolidayCalendar).evaluate().isNotEmpty) break;
    }
  }

  testWidgets('工作日模式弹窗加高，日历完整显示且不溢出', (tester) async {
    tester.view.physicalSize = const Size(1920, 1080);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await openDialog(tester, TaskConfig(scheduleMode: ScheduleMode.workday));

    // 无 RenderFlex 溢出等布局错误
    expect(tester.takeException(), isNull);
    // 节假日日历已加载（图例标签证明网格渲染完成）
    expect(find.byType(HolidayCalendar), findsOneWidget);
    expect(find.text('放假'), findsOneWidget);
    expect(find.text('确定'), findsOneWidget);

    // 弹窗高度应高于旧版 560，且不超过 860 上限
    final size = tester.getSize(find.byType(SingleChildScrollView));
    expect(size.height, greaterThan(560));
    expect(size.height, lessThanOrEqualTo(860));
  });

  testWidgets('小屏幕下工作日模式滚动兜底，不溢出', (tester) async {
    tester.view.physicalSize = const Size(800, 600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await openDialog(tester, TaskConfig(scheduleMode: ScheduleMode.workday));

    expect(tester.takeException(), isNull);
    // 上限为屏幕高度的 92% = 552，超出部分由内部滚动兜底
    final size = tester.getSize(find.byType(SingleChildScrollView));
    expect(size.height, lessThanOrEqualTo(600 * 0.92));
  });

  testWidgets('指定时间模式弹窗正常', (tester) async {
    tester.view.physicalSize = const Size(1920, 1080);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await openDialog(tester, TaskConfig(scheduleMode: ScheduleMode.specificTime));

    expect(tester.takeException(), isNull);
    expect(find.text('日期和时间'), findsOneWidget);
    expect(find.text('确定'), findsOneWidget);
  });

  testWidgets('工作日模式：日历翻页范围为本月至 12 月', (tester) async {
    tester.view.physicalSize = const Size(1920, 1080);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await openDialog(tester, TaskConfig(scheduleMode: ScheduleMode.workday));

    expect(tester.takeException(), isNull);

    IconButton arrowButton(IconData icon) => tester.widget<IconButton>(
          find.ancestor(
            of: find.byIcon(icon),
            matching: find.byType(IconButton),
          ),
        );

    // 左箭头禁用：禁止翻到上个月
    expect(arrowButton(Icons.chevron_left).onPressed, isNull);
    // 右箭头可用：可向后翻至本年 12 月
    expect(arrowButton(Icons.chevron_right).onPressed, isNotNull);

    // 翻到下一月后左箭头应恢复可用
    await tester.tap(find.byIcon(Icons.chevron_right));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(arrowButton(Icons.chevron_left).onPressed, isNotNull);
  });

  testWidgets('工作日模式：仅工作日前一晚开关可切换', (tester) async {
    tester.view.physicalSize = const Size(1920, 1080);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    TaskConfig? result;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () async {
              result = await showDialog<TaskConfig>(
                context: context,
                builder: (_) => CreateTaskDialog(
                  config: TaskConfig(scheduleMode: ScheduleMode.workday),
                ),
              );
            },
            child: const Text('open'),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('open'));
    await tester.pump();
    for (int i = 0; i < 100; i++) {
      await tester.pump(const Duration(milliseconds: 50));
      if (find.byType(HolidayCalendar).evaluate().isNotEmpty) break;
    }

    expect(tester.takeException(), isNull);
    expect(find.text('仅在工作日前一晚执行'), findsOneWidget);

    // 点击开关标题（SwitchListTile 整行可点）
    await tester.tap(find.text('仅在工作日前一晚执行'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    await tester.tap(find.text('确定'));
    await tester.pump();
    await tester.pumpAndSettle();

    expect(result, isNotNull);
    expect(result!.workdayEveOnly, isTrue);
  });
}
