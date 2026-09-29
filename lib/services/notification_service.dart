import 'dart:async';
import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';
import '../services/log_service.dart';

/// 通知服务：提醒触发时强制弹出 Flutter Dialog
///
/// 顺序固定为「先弹出主界面，再弹出 Dialog」，确保应用最小化到托盘、
/// 隐藏或被其他窗口遮住时，用户也一定能看到并必须点「确定」才能关闭。
///
/// 不再尝试 Windows Toast：Toast 要求开始菜单里存在带
/// `System.AppUserModel.ID` 的快捷方式，本项目只创建了桌面/Startup 快捷方式
/// 且从未写入 AUMID，Toast 必然投递失败，只会白白增加约 1 秒的
/// PowerShell 冷启动延迟。
class NotificationService {
  static BuildContext? _context;

  /// 设置上下文（用于弹出 Dialog）
  static void setContext(BuildContext context) {
    _context = context;
  }

  /// 显示一个提醒通知（强制弹窗）
  static Future<void> showNotification({
    required String title,
    required String message,
  }) async {
    await LogService.write('[NotificationService] Showing notification: $title - $message');
    await _showDialog(title, message);
  }

  /// 强制弹出提醒 Dialog
  ///
  /// 第一步弹出主界面，第二步在主界面上弹出 Flutter Dialog。
  static Future<void> _showDialog(String title, String message) async {
    // ---- 第一步：弹出主界面 ----
    await _bringMainWindowToFront();

    final context = _context;
    if (context == null) {
      await LogService.write('[NotificationService] No context available for Dialog');
      return;
    }

    await LogService.write('[NotificationService] Main window shown, opening Dialog');

    if (!context.mounted) {
      await LogService.write('[NotificationService] Context is defunct, cannot show Dialog');
      return;
    }

    // ---- 第二步：在主界面上弹出 Flutter Dialog ----
    try {
      await showDialog(
        context: context,
        barrierDismissible: false, // 不允许点击外部关闭
        builder: (dialogContext) => AlertDialog(
          title: Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          content: Text(message, style: const TextStyle(fontSize: 14)),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('确定', style: TextStyle(fontSize: 16)),
            ),
          ],
        ),
      );
    } catch (e) {
      await LogService.write('[NotificationService] Failed to show Dialog: $e');
    }

    // 恢复窗口状态
    try {
      await windowManager.setAlwaysOnTop(false);
    } catch (_) {}
  }

  /// 把主窗口从托盘/最小化状态拉回前台，并等它真正可见后返回
  static Future<void> _bringMainWindowToFront() async {
    try {
      if (await windowManager.isMinimized()) {
        await windowManager.restore();
      }
      await windowManager.show();
      await windowManager.focus();
      await windowManager.setAlwaysOnTop(true);

      // 轮询等待窗口真正可见，最多 500ms，避免 Dialog 挂在尚未显示的窗口上
      for (int i = 0; i < 10; i++) {
        if (await windowManager.isVisible()) break;
        await Future.delayed(const Duration(milliseconds: 50));
      }
      // 再留一帧时间让主界面完成绘制
      await Future.delayed(const Duration(milliseconds: 150));

      await LogService.write(
        '[NotificationService] Main window front: visible=${await windowManager.isVisible()}',
      );
    } catch (e) {
      await LogService.write('[NotificationService] Failed to bring main window to front: $e');
    }
  }
}
