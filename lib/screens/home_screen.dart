import 'dart:async';
import 'package:flutter/material.dart';
import '../models/task_config.dart';
import '../services/scheduler_service.dart';
import '../services/storage_service.dart';
import '../services/icon_service.dart';
import '../services/log_service.dart';
import '../services/remind_task_service.dart';
import '../services/notification_service.dart';
import '../widgets/status_card.dart';
import '../widgets/create_task_dialog.dart';
import '../widgets/system_settings_dialog.dart';

/// 极简主界面
class HomeScreen extends StatefulWidget {
  final SchedulerService scheduler;
  final VoidCallback onThemeToggle;
  final bool isDarkMode;

  const HomeScreen({
    super.key,
    required this.scheduler,
    required this.onThemeToggle,
    required this.isDarkMode,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late TaskConfig _config;
  String _currentIcon = 'cat'; // 主界面图标，从配置读取
  bool _loading = true;
  Timer? _countdownTimer;
  List<DateTime> _nextExecutions = [];

  @override
  void initState() {
    super.initState();
    // 设置通知服务的上下文（HomeScreen 是第一个显示的页面）
    NotificationService.setContext(context);
    
    _config = TaskConfig();
    _init();
    widget.scheduler.onStatusChanged(_refresh);
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted && widget.scheduler.hasActiveTask) {
        setState(() {});
      }
    });
  }

  void _refresh() {
    if (mounted) {
      setState(() {});
      _loadNextExecutions();
    }
  }

  Future<void> _loadNextExecutions() async {
    if (!widget.scheduler.hasActiveTask) {
      if (mounted) setState(() => _nextExecutions = []);
      return;
    }
    final list = await widget.scheduler.getNextExecutions(_config);
    if (mounted) {
      setState(() => _nextExecutions = list);
    }
  }

  Future<void> _init() async {
    // 从配置读取主界面图标（顶部 AppBar + 中部 StatusCard）
    final icon = await IconService.getCurrentIcon();
    setState(() => _currentIcon = icon);

    final savedConfig = await StorageService.loadTaskConfig();
    if (savedConfig != null) {
      _config = savedConfig;
      await widget.scheduler.restoreFromConfig(_config);
      await _loadNextExecutions();
    }

    setState(() => _loading = false);
  }

  Future<void> _openCreateTask() async {
    // 每次打开新建任务弹窗前，将调度方式重置为"从现在开始"
    setState(() {
      _config.scheduleMode = ScheduleMode.countdown;
    });

    final tempConfig = TaskConfig(
      taskType: _config.taskType,
      scheduleMode: _config.scheduleMode,
      targetTime: _config.targetTime,
      countdownHours: _config.countdownHours,
      countdownMinutes: _config.countdownMinutes,
      frequency: _config.frequency,
      weekDays: List.from(_config.weekDays),
      monthlyDay: _config.monthlyDay,
      idleEnabled: _config.idleEnabled,
      idleHours: _config.idleHours,
      idleMinutes: _config.idleMinutes,
      idleRepeat: _config.idleRepeat,
      reminderEnabled: _config.reminderEnabled,
      reminderMinutes: _config.reminderMinutes,
      passwordProtected: _config.passwordProtected,
      workdayOnly: _config.workdayOnly,
      workdayEveOnly: _config.workdayEveOnly,
      reminderText: _config.reminderText,
    );

    final result = await showDialog<TaskConfig>(
      context: context,
      builder: (context) => CreateTaskDialog(config: tempConfig),
    );

    if (result != null) {
      // 如果是提醒类型，弹出二次确认
      if (result.taskType == TaskType.remind) {
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text('确认创建提醒任务'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('将在 ${_formatTriggerTime(result)} 提醒您：'),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primary.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    result.reminderText ?? '未设置提醒内容',
                    style: const TextStyle(fontSize: 13),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('取消'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('确认'),
              ),
            ],
          ),
        );
        if (confirmed != true) return;
        
        // 保存提醒任务到独立文件
        await StorageService.addRemindTask(result);
      }
      
      _config = result;
      await StorageService.saveTaskConfig(_config);
      await widget.scheduler.startTask(_config);
      _refresh();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result.taskType == TaskType.remind ? '提醒任务已设置' : '任务已设置'),
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  String _formatTriggerTime(TaskConfig config) {
    final now = DateTime.now();
    if (config.scheduleMode == ScheduleMode.countdown) {
      final triggerTime = now.add(Duration(
        hours: config.countdownHours,
        minutes: config.countdownMinutes,
      ));
      return '${triggerTime.month}月${triggerTime.day}日 ${triggerTime.hour.toString().padLeft(2, '0')}:${triggerTime.minute.toString().padLeft(2, '0')}';
    } else if (config.scheduleMode == ScheduleMode.specificTime && config.targetTime != null) {
      return '${config.targetTime!.month}月${config.targetTime!.day}日 ${config.targetTime!.hour.toString().padLeft(2, '0')}:${config.targetTime!.minute.toString().padLeft(2, '0')}';
    }
    return '未知时间';
  }

  /// 打开新建提醒任务弹窗（独立入口，不影响当前活跃任务）
  Future<void> _openCreateRemindTask() async {
    // 创建默认的提醒任务配置
    final remindConfig = TaskConfig(
      taskType: TaskType.remind,
      scheduleMode: ScheduleMode.countdown,
      countdownHours: 0,
      countdownMinutes: 30,
      reminderText: '',
    );

    final result = await showDialog<TaskConfig>(
      context: context,
      builder: (context) => CreateTaskDialog(
        config: remindConfig,
        lockTaskType: true,  // 锁定操作类型为提醒
      ),
    );

    if (result != null && result.taskType == TaskType.remind) {
      // 弹出二次确认
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('确认创建提醒任务'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('将在 ${_formatTriggerTime(result)} 提醒您：'),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  result.reminderText ?? '未设置提醒内容',
                  style: const TextStyle(fontSize: 13),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('确认'),
            ),
          ],
        ),
      );
      if (confirmed != true) return;

      // 保存提醒任务到独立文件（不影响当前活跃任务）
      await StorageService.addRemindTask(result);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('提醒任务已设置'),
            behavior: SnackBarBehavior.floating,
            duration: Duration(seconds: 2),
          ),
        );
      }
    }
  }

  /// 打开提醒任务管理弹窗
  Future<void> _openRemindTaskManager() async {
    await showDialog(
      context: context,
      builder: (context) => const _RemindTaskManagerDialog(),
    );
  }

  Future<void> _openSystemSettings() async {
    await showDialog<TaskConfig>(
      context: context,
      builder: (context) => SystemSettingsDialog(config: _config),
    );
    // 保存可能的提醒配置变更
    await StorageService.saveTaskConfig(_config);
    
    // 重新读取图标配置（用户可能更换了图标）
    final newIcon = await IconService.getCurrentIcon();
    if (mounted && newIcon != _currentIcon) {
      setState(() => _currentIcon = newIcon);
    }
  }

  Future<void> _cancelTask() async {
    // 显示确认弹窗
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('取消任务'),
        content: const Text('确定要取消当前任务吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('不取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('确定取消'),
          ),
        ],
      ),
    );

    // 只有用户确认后才取消
    if (confirmed != true) return;

    await widget.scheduler.cancelTask();
    await StorageService.deleteTaskConfig();
    _refresh();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('任务已取消'),
          behavior: SnackBarBehavior.floating,
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final hasTask = widget.scheduler.hasActiveTask;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 顶部图标：从配置读取，支持动态更换
            Image.asset(
              'assets/animals/$_currentIcon.png',
              width: 24,
              height: 24,
              errorBuilder: (_, __, ___) => const Icon(Icons.pets, size: 24),
            ),
            const SizedBox(width: 8),
            const Text('猫猫睡觉'),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(isDark ? Icons.light_mode : Icons.dark_mode),
            onPressed: widget.onThemeToggle,
            tooltip: '切换主题',
          ),
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed: _openSystemSettings,
            tooltip: '设置',
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Column(
          children: [
            const SizedBox(height: 8),

            // 状态卡片
            StatusCard(
              hasTask: hasTask,
              taskTypeLabel: _config.taskType.label,
              remainingTime: widget.scheduler.getRemainingTime(),
              nextTriggerTime: widget.scheduler.nextTriggerTime?.toString(),
              frequencyInfo: _buildFrequencyInfo(),
              progress: widget.scheduler.getProgress(),
              currentIcon: _currentIcon, // 中部图标：从配置读取，支持动态更换
              onCreateTask: _openCreateTask,
            ),

            const SizedBox(height: 28),

            // 操作按钮
            Row(
              children: [
                if (hasTask)
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _cancelTask,
                      icon: const Icon(Icons.close, size: 16),
                      label: const Text('取消任务'),
                    ),
                  ),
                if (hasTask) const SizedBox(width: 12),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: _openRemindTaskManager,
                    icon: const Icon(Icons.notifications_active, size: 16),
                    label: const Text('提醒任务'),
                  ),
                ),
              ],
            ),

            // 最近 5 次执行时间 - 时间线样式
            if (hasTask && _nextExecutions.isNotEmpty) ...[
              const SizedBox(height: 28),
              _buildExecutionTimeline(isDark),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildExecutionTimeline(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '后续执行时间',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
          ),
        ),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isDark ? const Color(0x0DFFFFFF) : const Color(0xFFE5E7EB),
            ),
          ),
          child: Column(
            children: [
              for (int i = 0; i < _nextExecutions.length; i++)
                _buildTimelineItem(i, isDark),
              const SizedBox(height: 8),
              Center(
                child: TextButton.icon(
                  onPressed: () => _showAllExecutions(isDark),
                  icon: const Icon(Icons.expand_more, size: 16),
                  label: const Text('更多'),
                  style: TextButton.styleFrom(
                    foregroundColor: Theme.of(context).colorScheme.primary,
                    textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _showAllExecutions(bool isDark) async {
    final allExecutions = await widget.scheduler.getNextExecutions(_config, count: 100);
    if (!mounted || allExecutions.isEmpty) return;

    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.zero),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420, maxHeight: 560),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '全部执行计划',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: isDark ? const Color(0xFFF9FAFB) : const Color(0xFF111827),
                      ),
                    ),
                    Text(
                      '共 ${allExecutions.length} 次',
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Flexible(
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: allExecutions.length,
                    itemBuilder: (context, index) {
                      final dt = allExecutions[index];
                      final isFirst = index == 0;
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Row(
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: isFirst
                                    ? Theme.of(context).colorScheme.primary
                                    : (isDark ? const Color(0xFF475569) : const Color(0xFFD1D5DB)),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Text(
                              _formatDateTime(dt),
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: isFirst ? FontWeight.w600 : FontWeight.w400,
                                color: isFirst
                                    ? Theme.of(context).colorScheme.primary
                                    : (isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280)),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 16),
                Align(
                  alignment: Alignment.centerRight,
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    ),
                    child: const Text('关闭'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTimelineItem(int index, bool isDark) {
    final dt = _nextExecutions[index];
    final isFirst = index == 0;
    final isLast = index == _nextExecutions.length - 1;

    return IntrinsicHeight(
      child: Row(
        children: [
          // 时间线指示器
          SizedBox(
            width: 24,
            child: Column(
              children: [
                if (!isFirst)
                  Container(
                    width: 2,
                    height: 8,
                    color: isDark ? const Color(0xFF475569) : const Color(0xFFE5E7EB),
                  ),
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isFirst
                        ? Theme.of(context).colorScheme.primary
                        : (isDark ? const Color(0xFF475569) : const Color(0xFFD1D5DB)),
                  ),
                ),
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 2,
                      color: isDark ? const Color(0xFF475569) : const Color(0xFFE5E7EB),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          // 内容
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(
              _formatDateTime(dt),
              style: TextStyle(
                fontSize: 13,
                fontWeight: isFirst ? FontWeight.w600 : FontWeight.w400,
                color: isFirst
                    ? Theme.of(context).colorScheme.primary
                    : (isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String? _buildFrequencyInfo() {
    if (!widget.scheduler.hasActiveTask) return null;

    // 工作日模式
    if (_config.scheduleMode == ScheduleMode.workday) {
      final eveSuffix = _config.workdayEveOnly ? '（前晚执行）' : '';
      final timeStr = _config.targetTime != null
          ? '${_config.targetTime!.hour.toString().padLeft(2, '0')}:${_config.targetTime!.minute.toString().padLeft(2, '0')}'
          : '23:55';
      return '工作日 $timeStr$eveSuffix';
    }

    // 从现在开始
    if (_config.scheduleMode == ScheduleMode.countdown) {
      return '倒计时 ${_config.countdownHours}时${_config.countdownMinutes}分';
    }

    // 指定时间
    switch (_config.frequency) {
      case Frequency.daily:
        return '每天执行';
      case Frequency.weekly:
        final days = _config.weekDays.map((d) => '周${_weekdayLabel(d)}').join('、');
        return '每周 $days';
      case Frequency.monthly:
        return '每月 ${_config.monthlyDay ?? 1} 日';
    }
  }

  String _weekdayLabel(int day) {
    const labels = ['一', '二', '三', '四', '五', '六', '日'];
    return labels[day - 1];
  }

  String _formatDateTime(DateTime dt) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final target = DateTime(dt.year, dt.month, dt.day);
    final diff = target.difference(today).inDays;

    final timeStr = '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';

    if (diff == 0) return '今天 $timeStr';
    if (diff == 1) return '明天 $timeStr';
    if (diff == 2) return '后天 $timeStr';
    return '${dt.month}月${dt.day}日 $timeStr';
  }
}

/// 提醒任务管理弹窗
class _RemindTaskManagerDialog extends StatefulWidget {
  const _RemindTaskManagerDialog();

  @override
  State<_RemindTaskManagerDialog> createState() => _RemindTaskManagerDialogState();
}

class _RemindTaskManagerDialogState extends State<_RemindTaskManagerDialog> {
  List<TaskConfig> _tasks = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadTasks();
  }

  Future<void> _loadTasks() async {
    final tasks = await StorageService.loadRemindTasks();
    
    // 按时间排序（从早到晚）
    tasks.sort((a, b) {
      if (a.targetTime == null && b.targetTime == null) return 0;
      if (a.targetTime == null) return 1;
      if (b.targetTime == null) return -1;
      return a.targetTime!.compareTo(b.targetTime!);
    });
    
    await LogService.write('[RemindTaskManager] Loaded ${tasks.length} remind tasks');
    for (int i = 0; i < tasks.length; i++) {
      await LogService.write('[RemindTaskManager] Task $i: text="${tasks[i].reminderText}", targetTime=${tasks[i].targetTime}, scheduleMode=${tasks[i].scheduleMode.name}');
    }
    setState(() {
      _tasks = tasks;
      _loading = false;
    });
  }

  Future<void> _addNewTask() async {
    // 不关闭管理弹窗，直接打开新建任务弹窗
    final remindConfig = TaskConfig(
      taskType: TaskType.remind,
      scheduleMode: ScheduleMode.countdown,
      countdownHours: 0,
      countdownMinutes: 30,
      reminderText: '',
    );

    final result = await showDialog<TaskConfig>(
      context: context,
      builder: (context) => CreateTaskDialog(
        config: remindConfig,
        lockTaskType: true,
      ),
    );

    if (result != null && result.taskType == TaskType.remind) {
      // 将倒计时模式转换为固定时间模式（保存绝对时间，秒数归零）
      DateTime targetTime;
      if (result.scheduleMode == ScheduleMode.countdown) {
        final rawTime = DateTime.now().add(Duration(
          hours: result.countdownHours,
          minutes: result.countdownMinutes,
        ));
        // 秒数归零
        targetTime = DateTime(rawTime.year, rawTime.month, rawTime.day, rawTime.hour, rawTime.minute, 0);
      } else {
        // 指定时间模式：秒数也归零
        targetTime = DateTime(
          result.targetTime!.year,
          result.targetTime!.month,
          result.targetTime!.day,
          result.targetTime!.hour,
          result.targetTime!.minute,
          0,
        );
      }

      final fixedTask = TaskConfig(
        taskType: result.taskType,
        scheduleMode: ScheduleMode.specificTime,  // 改为指定时间模式
        targetTime: targetTime,
        reminderText: result.reminderText,
      );

      await LogService.write('[RemindTaskManager] Creating new task: text="${fixedTask.reminderText}", targetTime=${fixedTask.targetTime}');

      // 二次确认
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('确认创建提醒任务'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('将在 ${_formatTriggerTime(fixedTask)} 提醒您：'),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  fixedTask.reminderText ?? '未设置提醒内容',
                  style: const TextStyle(fontSize: 13),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('确认'),
            ),
          ],
        ),
      );
      
      if (confirmed == true) {
        await LogService.write('[RemindTaskManager] Saving new task');
        await StorageService.addRemindTask(fixedTask);

        // 关键修复：通知 RemindTaskService 重新加载提醒任务（启动新定时器）
        try {
          await RemindTaskService().loadAndStartTasks();
          await LogService.write('[RemindTaskManager] Notified RemindTaskService to reload remind tasks');
        } catch (e, stackTrace) {
          await LogService.write('[RemindTaskManager] Failed to notify RemindTaskService: $e\n$stackTrace');
        }

        // 关闭确认对话框后，重新加载任务列表（保持管理弹窗打开）
        await _loadTasks();
      }
    }
  }

  String _formatTriggerTime(TaskConfig config) {
    final now = DateTime.now();
    if (config.scheduleMode == ScheduleMode.countdown) {
      final triggerTime = now.add(Duration(
        hours: config.countdownHours,
        minutes: config.countdownMinutes,
      ));
      return '${triggerTime.month}月${triggerTime.day}日 ${triggerTime.hour.toString().padLeft(2, '0')}:${triggerTime.minute.toString().padLeft(2, '0')}';
    } else if (config.scheduleMode == ScheduleMode.specificTime && config.targetTime != null) {
      return '${config.targetTime!.month}月${config.targetTime!.day}日 ${config.targetTime!.hour.toString().padLeft(2, '0')}:${config.targetTime!.minute.toString().padLeft(2, '0')}';
    }
    return '未知时间';
  }

  Future<void> _deleteTask(int index) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('删除提醒任务'),
        content: const Text('确定要删除这个提醒任务吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('删除'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await StorageService.deleteRemindTask(index);
      
      // 通知 RemindTaskService 重新加载提醒任务（因为删除后需要重新启动其他任务的定时器）
      try {
        await RemindTaskService().loadAndStartTasks();
        await LogService.write('[RemindTaskManager] Notified RemindTaskService to reload after delete');
      } catch (e, stackTrace) {
        await LogService.write('[RemindTaskManager] Failed to notify RemindTaskService after delete: $e\n$stackTrace');
      }
      
      setState(() {
        _tasks.removeAt(index);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.zero),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480, maxHeight: 560),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 标题栏
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '提醒任务管理',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: isDark ? const Color(0xFFF9FAFB) : const Color(0xFF111827),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 20),
                    onPressed: () => Navigator.pop(context),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
            ),

            // 新增按钮
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _addNewTask,
                      icon: const Icon(Icons.add, size: 16),
                      label: const Text('新增提醒任务'),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // 任务列表或空状态
            if (_loading)
              const Expanded(
                child: Center(
                  child: CircularProgressIndicator(),
                ),
              )
            else if (_tasks.isEmpty)
              Expanded(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.notifications_none,
                        size: 48,
                        color: isDark ? const Color(0xFF475569) : const Color(0xFFD1D5DB),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        '暂无提醒任务',
                        style: TextStyle(
                          fontSize: 14,
                          color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  itemCount: _tasks.length,
                  itemBuilder: (context, index) {
                    final task = _tasks[index];
                    final isExpired = task.targetTime != null && task.targetTime!.isBefore(DateTime.now());
                    
                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Row(
                          children: [
                            // 提醒内容
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    task.reminderText ?? '无提醒内容',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                      color: isDark ? const Color(0xFFF9FAFB) : const Color(0xFF111827),
                                      decoration: isExpired ? TextDecoration.lineThrough : null,
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    _formatTriggerTime(task),
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: isExpired 
                                          ? (isDark ? const Color(0xFF6B7280) : const Color(0xFF9CA3AF))
                                          : (isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280)),
                                      decoration: isExpired ? TextDecoration.lineThrough : null,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            // 删除按钮
                            IconButton(
                              icon: const Icon(Icons.delete_outline, size: 20),
                              onPressed: () => _deleteTask(index),
                              tooltip: '删除',
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),

            const SizedBox(height: 16),

            // 底部按钮
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('关闭'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _openRemindTaskManager() {
    Navigator.pop(context);
    // 这里需要通过某种方式重新打开，暂时简化
  }
}
