import 'package:flutter/material.dart';

/// 状态大卡片 - 显示当前任务状态和倒计时
class StatusCard extends StatelessWidget {
  final bool hasTask;
  final String taskTypeLabel;
  final String? remainingTime;
  final String? nextTriggerTime;
  final String? frequencyInfo;
  final double progress;
  final String currentIcon;
  final VoidCallback? onCreateTask;

  const StatusCard({
    super.key,
    required this.hasTask,
    required this.taskTypeLabel,
    this.remainingTime,
    this.nextTriggerTime,
    this.frequencyInfo,
    this.progress = 0,
    required this.currentIcon,
    this.onCreateTask,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      switchInCurve: Curves.easeOut,
      switchOutCurve: Curves.easeIn,
      child: hasTask ? _buildActiveState(context, isDark) : _buildEmptyState(context, isDark),
    );
  }

  Widget _buildEmptyState(BuildContext context, bool isDark) {
    return Container(
      key: const ValueKey('empty'),
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 32),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? const Color(0x14FFFFFF) : const Color(0xFFE5E7EB),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          // 动物图标带呼吸动画
          _BreathingIcon(iconPath: 'assets/animals/$currentIcon.png'),
          const SizedBox(height: 24),
          Text(
            '暂无定时任务',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: isDark ? const Color(0xFFF9FAFB) : const Color(0xFF111827),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '点击下方按钮创建您的第一个定时任务',
            style: TextStyle(
              fontSize: 14,
              color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
            ),
          ),
          if (onCreateTask != null) ...[
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: onCreateTask,
              icon: const Icon(Icons.add, size: 18),
              label: const Text('创建任务'),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildActiveState(BuildContext context, bool isDark) {
    return Container(
      key: const ValueKey('active'),
      width: double.infinity,
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? [const Color(0xFF4F46E5), const Color(0xFF7C3AED)]
              : [const Color(0xFF6366F1), const Color(0xFF8B5CF6)],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF6366F1).withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          // 图标
          Image.asset(
            'assets/animals/$currentIcon.png',
            width: 56,
            height: 56,
            errorBuilder: (_, __, ___) => const Icon(Icons.pets, size: 56, color: Colors.white70),
          ),
          const SizedBox(height: 20),

          // 倒计时 - 大字突出
          if (remainingTime != null) ...[
            Text(
              remainingTime!,
              style: const TextStyle(
                fontSize: 36,
                fontWeight: FontWeight.w700,
                color: Colors.white,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              '后自动$taskTypeLabel',
              style: const TextStyle(
                fontSize: 14,
                color: Colors.white70,
              ),
            ),
          ],

          const SizedBox(height: 24),

          // 进度条 - 真实进度
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: progress),
              duration: const Duration(milliseconds: 500),
              curve: Curves.easeOut,
              builder: (context, value, _) => LinearProgressIndicator(
                value: value,
                backgroundColor: Colors.white24,
                valueColor: AlwaysStoppedAnimation(Colors.white.withOpacity(0.9)),
                minHeight: 6,
              ),
            ),
          ),

          const SizedBox(height: 16),

          // 频率信息
          if (frequencyInfo != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                frequencyInfo!,
                style: const TextStyle(
                  fontSize: 12,
                  color: Colors.white70,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// 呼吸动画图标
class _BreathingIcon extends StatefulWidget {
  final String iconPath;

  const _BreathingIcon({required this.iconPath});

  @override
  State<_BreathingIcon> createState() => _BreathingIconState();
}

class _BreathingIconState extends State<_BreathingIcon>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 3),
      vsync: this,
    )..repeat(reverse: true);
    _scaleAnimation = Tween(begin: 1.0, end: 1.05).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _scaleAnimation,
      builder: (context, child) => Transform.scale(
        scale: _scaleAnimation.value,
        child: child,
      ),
      child: Image.asset(
        widget.iconPath,
        width: 88,
        height: 88,
        errorBuilder: (_, __, ___) => const Icon(Icons.pets, size: 88, color: Color(0xFFD1D5DB)),
      ),
    );
  }
}
