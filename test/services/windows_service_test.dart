import 'dart:io';

import 'package:cat_sleep/models/task_config.dart';
import 'package:cat_sleep/services/windows_service.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

const _windowsChannel = MethodChannel('cat_sleep/windows');

/// 6 种系统操作在 C++ 侧应执行的命令（提醒除外，它不走原生通道）
/// 关机和重启已改用 Windows API（InitiateSystemShutdownExW），不再走 shutdown.exe
const _expectedNativeCommands = <TaskType, String>{
  TaskType.logoff: 'shutdown.exe /l',
  TaskType.hibernate: 'shutdown.exe /h',
  TaskType.sleep: 'rundll32.exe powrprof.dll,SetSuspendState',
  TaskType.lock: 'rundll32.exe user32.dll,LockWorkStation',
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('任务类型 → Platform Channel 路由', () {
    late List<MethodCall> calls;

    setUp(() {
      calls = <MethodCall>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(_windowsChannel, (call) async {
        calls.add(call);
        return true;
      });
    });

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(_windowsChannel, null);
    });

    for (final entry in _expectedNativeCommands.entries) {
      test('${entry.key.label}（${entry.key.name}）调用原生 ${entry.key.method}', () async {
        await WindowsService.executeTask(entry.key.method);

        expect(calls, hasLength(1), reason: '${entry.key.label} 应恰好触发一次原生调用');
        expect(calls.single.method, entry.key.method);
      });
    }

    test('关机（shutdown）调用原生 shutdown', () async {
      await WindowsService.executeTask(TaskType.shutdown.method);
      expect(calls, hasLength(1));
      expect(calls.single.method, 'shutdown');
    });

    test('重启（restart）调用原生 restart', () async {
      await WindowsService.executeTask(TaskType.restart.method);
      expect(calls, hasLength(1));
      expect(calls.single.method, 'restart');
    });

    test('提醒类型不触发任何原生调用', () async {
      await WindowsService.executeTask(TaskType.remind.method);

      expect(calls, isEmpty, reason: '提醒由 NotificationService 处理，不应执行系统操作');
    });

    test('未识别的方法名静默忽略，不会误触发原生调用', () async {
      await WindowsService.executeTask('closeProgram');

      expect(calls, isEmpty,
          reason: 'closeProgram 已从 TaskType 移除，Dart 侧不应再有入口');
    });

    test('TaskType.method 与枚举名一致，避免路由错位', () {
      for (final type in TaskType.values) {
        expect(type.method, type.name, reason: '${type.name} 的 method 应等于枚举名');
      }
    });

    test('共 7 种任务类型：6 种系统操作 + 提醒', () {
      expect(TaskType.values, hasLength(7));
      expect(TaskType.values.where((t) => t != TaskType.remind), hasLength(6));
    });

    test('cancelShutdown 路由到原生 cancelShutdown', () async {
      await WindowsService.cancelShutdown();

      expect(calls.single.method, 'cancelShutdown');
    });
  });

  group('C++ 侧 handler 完整性（Dart / C++ 必须两侧同步）', () {
    late String mainCpp;

    setUpAll(() {
      final file = File('windows/runner/main.cpp');
      if (!file.existsSync()) {
        fail('找不到 windows/runner/main.cpp，测试必须在包根目录下运行');
      }
      mainCpp = file.readAsStringSync();
    });

    for (final entry in _expectedNativeCommands.entries) {
      test('${entry.key.label} 在 main.cpp 中有 handler 且命令正确', () {
        expect(mainCpp, contains('method == "${entry.key.method}"'),
            reason: 'Dart 调用 "${entry.key.method}" 但 C++ 没有对应分支，'
                '会走到 result->NotImplemented() 静默失败');
        expect(mainCpp, contains(entry.value),
            reason: '${entry.key.label} 的原生命令应为 ${entry.value}');
      });
    }

    test('关机 在 main.cpp 中使用 InitiateSystemShutdownExW（不再依赖 shutdown.exe）', () {
      expect(mainCpp, contains('method == "shutdown"'));
      expect(mainCpp, contains('NativeShutdown()'));
      expect(mainCpp, contains('InitiateSystemShutdownExW'));
    });

    test('重启 在 main.cpp 中使用 InitiateSystemShutdownExW（不再依赖 shutdown.exe）', () {
      expect(mainCpp, contains('method == "restart"'));
      expect(mainCpp, contains('NativeRestart()'));
      expect(mainCpp, contains('InitiateSystemShutdownExW'));
    });

    test('cancelShutdown 在 main.cpp 中有 handler', () {
      expect(mainCpp, contains('method == "cancelShutdown"'));
      expect(mainCpp, contains('shutdown.exe /a'));
    });

    test('showNotification 通道已彻底移除（Toast 方案已废弃）', () {
      expect(mainCpp, isNot(contains('method == "showNotification"')));
      expect(mainCpp, isNot(contains('ToastNotificationManager')));
    });

    test('closeProgram handler 已删除（"关闭程序"任务类型已移除）', () {
      expect(mainCpp, isNot(contains('method == "closeProgram"')));
      expect(mainCpp, isNot(contains('taskkill')));
    });

    test('系统命令的真实退出码会回报给 Dart，而不是无条件 Success', () {
      expect(mainCpp, contains('GetExitCodeProcess'),
          reason: '必须读取子进程退出码，否则命令失败会被当成成功');
      expect(mainCpp, contains('result->Error("CommandFailed"'));
    });

    test('睡眠命令不阻塞平台线程（SetSuspendState 恢复前不会返回）', () {
      // sleep 分支必须以 timeoutMs == 0 的 fire-and-forget 方式启动
      final sleepBranch = mainCpp.split('method == "sleep"').last;
      final call = sleepBranch.split('RunSystemCommand(').skip(1).first;
      expect(call, contains(', 0,'),
          reason: 'sleep 必须用 timeoutMs=0，否则唤醒后消息泵会继续冻结剩余超时时间');
    });
  });

  group('Dart 侧不再有 Toast 残留', () {
    late String notificationService;
    late String windowsService;

    setUpAll(() {
      notificationService =
          File('lib/services/notification_service.dart').readAsStringSync();
      windowsService = File('lib/services/windows_service.dart').readAsStringSync();
    });

    test('NotificationService 不调用 PowerShell', () {
      // 注释里可以提到 PowerShell（解释为什么不用），但代码里不能有真实调用
      expect(notificationService, isNot(contains('powershell.exe')));
      expect(notificationService, isNot(contains('Process.run')));
      expect(notificationService, isNot(contains("import 'dart:io'")));
    });

    test('NotificationService 保持"先弹主界面再弹 Dialog"的顺序', () {
      final bringIndex = notificationService.indexOf('_bringMainWindowToFront()');
      final dialogIndex = notificationService.indexOf('await showDialog(');

      expect(bringIndex, greaterThan(-1), reason: '必须存在拉起主窗口的调用');
      expect(dialogIndex, greaterThan(-1));
      expect(bringIndex, lessThan(dialogIndex),
          reason: '必须先弹出主界面，再弹出 Flutter Dialog');
    });

    test('WindowsService 不再有 showNotification 封装', () {
      expect(windowsService, isNot(contains('showNotification')));
    });
  });
}
