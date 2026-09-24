import 'package:flutter/services.dart';

/// Windows 原生操作服务
class WindowsService {
  static const MethodChannel _channel = MethodChannel('cat_sleep/windows');

  /// 关机
  static Future<void> shutdown() async {
    await _channel.invokeMethod('shutdown');
  }

  /// 重启
  static Future<void> restart() async {
    await _channel.invokeMethod('restart');
  }

  /// 注销
  static Future<void> logoff() async {
    await _channel.invokeMethod('logoff');
  }

  /// 休眠
  static Future<void> hibernate() async {
    await _channel.invokeMethod('hibernate');
  }

  /// 睡眠
  static Future<void> sleep() async {
    await _channel.invokeMethod('sleep');
  }

  /// 锁定
  static Future<void> lock() async {
    await _channel.invokeMethod('lock');
  }

  /// 取消关机/定时任务
  static Future<void> cancelShutdown() async {
    await _channel.invokeMethod('cancelShutdown');
  }

  /// 创建开机自启快捷方式
  static Future<bool> createStartupShortcut() async {
    final result = await _channel.invokeMethod<bool>('createStartupShortcut');
    return result ?? false;
  }

  /// 创建带图标的开机自启快捷方式
  static Future<bool> createStartupShortcutWithIcon(String iconPath) async {
    final result = await _channel.invokeMethod<bool>(
      'createStartupShortcutWithIcon',
      {'iconPath': iconPath},
    );
    return result ?? false;
  }

  /// 删除开机自启快捷方式
  static Future<bool> removeStartupShortcut() async {
    final result = await _channel.invokeMethod<bool>('removeStartupShortcut');
    return result ?? false;
  }

  /// 检查是否已设置开机自启
  static Future<bool> hasStartupShortcut() async {
    final result = await _channel.invokeMethod<bool>('hasStartupShortcut');
    return result ?? false;
  }

  /// 创建桌面快捷方式
  static Future<bool> createDesktopShortcut() async {
    final result = await _channel.invokeMethod<bool>('createDesktopShortcut');
    return result ?? false;
  }

  /// 创建带图标的桌面快捷方式
  static Future<bool> createDesktopShortcutWithIcon(String iconPath) async {
    final result = await _channel.invokeMethod<bool>(
      'createDesktopShortcutWithIcon',
      {'iconPath': iconPath},
    );
    return result ?? false;
  }

  /// 删除桌面快捷方式
  static Future<bool> removeDesktopShortcut() async {
    final result = await _channel.invokeMethod<bool>('removeDesktopShortcut');
    return result ?? false;
  }

  /// 检查桌面快捷方式是否存在
  static Future<bool> hasDesktopShortcut() async {
    final result = await _channel.invokeMethod<bool>('hasDesktopShortcut');
    return result ?? false;
  }

  /// 设置窗口图标（任务栏图标）
  static Future<bool> setWindowIcon(String iconPath) async {
    final result = await _channel.invokeMethod<bool>(
      'setWindowIcon',
      {'iconPath': iconPath},
    );
    return result ?? false;
  }

  /// 显示系统通知
  static Future<void> showNotification(String title, String body) async {
    try {
      await _channel.invokeMethod('showNotification', {
        'title': title,
        'body': body,
      });
    } catch (e) {
      print('Failed to show notification: $e');
    }
  }

  /// 执行任务
  static Future<void> executeTask(String method) async {
    switch (method) {
      case 'shutdown':
        await shutdown();
        break;
      case 'restart':
        await restart();
        break;
      case 'logoff':
        await logoff();
        break;
      case 'hibernate':
        await hibernate();
        break;
      case 'sleep':
        await sleep();
        break;
      case 'lock':
        await lock();
        break;
      case 'remind':
        // 提醒类型不执行系统操作，由 SchedulerService 处理
        break;
    }
  }
}
