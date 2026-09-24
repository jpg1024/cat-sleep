import 'dart:async';
import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';

/// 桌面右下角通知弹窗
class NotificationOverlay extends StatefulWidget {
  final String title;
  final String message;
  final Duration duration;

  const NotificationOverlay({
    super.key,
    required this.title,
    required this.message,
    this.duration = const Duration(seconds: 5),
  });

  static Future<void> show({
    required String title,
    required String message,
    Duration duration = const Duration(seconds: 5),
  }) async {
    // 创建一个小窗口显示通知
    await windowManager.ensureInitialized();
    
    final windowOptions = WindowOptions(
      size: const Size(300, 120),
      minimumSize: const Size(300, 120),
      maximumSize: const Size(300, 120),
      center: false,
      skipTaskbar: true,
      titleBarStyle: TitleBarStyle.hidden,
      alwaysOnTop: true,
    );
    
    // 获取屏幕工作区大小
    final screen = windowManager.getCurrentScreen();
    final bounds = await screen.getBounds();
    final workArea = await screen.getWorkArea();
    
    // 计算窗口位置（右下角）
    final x = workArea.left + workArea.width - 320;
    final y = workArea.top + workArea.height - 140;
    
    await windowManager.setPosition(Offset(x.toDouble(), y.toDouble()));
    await windowManager.setSize(const Size(300, 120));
    await windowManager.setAlwaysOnTop(true);
    await windowManager.setSkipTaskbar(true);
    
    runApp(NotificationOverlay(
      title: title,
      message: message,
      duration: duration,
    ));
  }

  @override
  State<NotificationOverlay> createState() => _NotificationOverlayState();
}

class _NotificationOverlayState extends State<NotificationOverlay> {
  @override
  void initState() {
    super.initState();
    // 自动关闭
    Timer(widget.duration, () {
      if (mounted) {
        windowManager.close();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        body: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => windowManager.close(),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          widget.title,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF6366F1),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, size: 18),
                          onPressed: () => windowManager.close(),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      widget.message,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF374151),
                      ),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
