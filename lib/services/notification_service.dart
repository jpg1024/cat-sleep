import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';
import '../services/log_service.dart';

/// 通知服务：使用 PowerShell Toast + Flutter Dialog 回退方案
class NotificationService {
  static BuildContext? _context;
  
  /// 设置上下文（用于 Dialog 回退方案）
  static void setContext(BuildContext context) {
    _context = context;
  }

  /// 显示一个 Windows 系统通知
  static Future<void> showNotification({
    required String title,
    required String message,
  }) async {
    try {
      await LogService.write('[NotificationService] Sending notification: $title - $message');
      
      // 转义特殊字符（PowerShell 单引号需要双写）
      final escapedTitle = title.replaceAll("'", "''");
      final escapedBody = message.replaceAll("'", "''");
      
      // 构建 PowerShell 脚本
      final psScript = '''
try {
  [Windows.UI.Notifications.ToastNotificationManager, Windows.UI.Notifications, ContentType = WindowsRuntime] | Out-Null;
  \$template = [Windows.UI.Notifications.ToastTemplateType]::toastText02;
  \$xml = [Windows.UI.Notifications.ToastNotificationManager]::GetTemplateContent(\$template).GetXml();
  \$xml.GetElementsByTagName('text')[0].AppendChild(\$xml.CreateTextNode('$escapedTitle'));
  \$xml.GetElementsByTagName('text')[1].AppendChild(\$xml.CreateTextNode('$escapedBody'));
  \$notifier = [Windows.UI.Notifications.ToastNotificationManager]::CreateToastNotifier('CatSleep');
  \$notifier.Show([Windows.UI.Notifications.ToastNotification]::CreateFromXml(\$xml));
} catch {
  # Silent fail
}
      '''.trim();
      
      // 使用 PowerShell 直接调用 Windows Toast API
      final result = await Process.run(
        'powershell.exe',
        [
          '-NoProfile',
          '-WindowStyle', 'Hidden',
          '-ExecutionPolicy', 'Bypass',
          '-Command',
          psScript,
        ],
      ).timeout(const Duration(seconds: 5));
      
      if (result.exitCode == 0) {
        await LogService.write('[NotificationService] PowerShell Toast sent successfully');
      } else {
        await LogService.write('[NotificationService] PowerShell failed, using Dialog fallback');
        await _showDialog(title, message);
      }
    } catch (e) {
      await LogService.write('[NotificationService] Failed to send via PowerShell: $e, using Dialog');
      await _showDialog(title, message);
    }
  }
  
  /// 显示 Flutter Dialog 作为回退方案（强制弹出）
  static Future<void> _showDialog(String title, String message) async {
    if (_context == null) {
      await LogService.write('[NotificationService] No context available for Dialog');
      return;
    }
    
    // 先确保窗口显示并聚焦
    try {
      await windowManager.show();
      await windowManager.focus();
      await windowManager.setAlwaysOnTop(true);
      await Future.delayed(const Duration(milliseconds: 100));
    } catch (_) {}
    
    await showDialog(
      context: _context!,
      barrierDismissible: false, // 不允许点击外部关闭
      builder: (context) => AlertDialog(
        title: Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        content: Text(message, style: const TextStyle(fontSize: 14)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('确定', style: TextStyle(fontSize: 16)),
          ),
        ],
      ),
    );
    
    // 恢复窗口状态
    try {
      await windowManager.setAlwaysOnTop(false);
    } catch (_) {}
  }
}
