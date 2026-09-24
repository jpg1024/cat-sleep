import 'package:flutter/material.dart';
import '../services/startup_service.dart';
import '../services/icon_service.dart';
import '../services/workday_service.dart';
import '../services/year_workday_cache_service.dart';
import '../services/log_service.dart';
import '../models/task_config.dart';
import 'icon_picker_dialog.dart';
import 'custom_date_editor.dart';

/// 系统设置弹窗
class SystemSettingsDialog extends StatefulWidget {
  final TaskConfig config;

  const SystemSettingsDialog({super.key, required this.config});

  @override
  State<SystemSettingsDialog> createState() => _SystemSettingsDialogState();
}

class _SystemSettingsDialogState extends State<SystemSettingsDialog> {
  bool _autoStart = false;
  String _currentIcon = 'cat';
  Map<String, Map<String, String>> _customDates = {};

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final autoStart = await StartupService.checkStatus();
    final icon = await IconService.getCurrentIcon();
    final config = await WorkdayService.getConfig();
    setState(() {
      _autoStart = autoStart;
      _currentIcon = icon;
      _customDates = Map.from(config.customDates);
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.zero),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480, maxHeight: 560),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 标题
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('系统设置', style: TextStyle(
                    fontSize: 18, fontWeight: FontWeight.w600,
                    color: isDark ? const Color(0xFFF9FAFB) : const Color(0xFF111827),
                  )),
                  IconButton(
                    icon: const Icon(Icons.close, size: 20),
                    onPressed: () => Navigator.pop(context),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // 提醒
              _buildSettingRow(
                isDark: isDark,
                icon: Icons.notifications_outlined,
                title: '提前提醒',
                subtitle: '任务执行前发送提醒',
                trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                  SizedBox(width: 56, child: TextField(
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    ),
                    controller: TextEditingController(text: widget.config.reminderMinutes.toString()),
                    onChanged: (v) {
                      final n = int.tryParse(v);
                      if (n != null && n >= 0) widget.config.reminderMinutes = n;
                    },
                  )),
                  const Text(' 分钟'),
                  const SizedBox(width: 8),
                  Switch(
                    value: widget.config.reminderEnabled,
                    onChanged: (v) => setState(() => widget.config.reminderEnabled = v),
                  ),
                ]),
              ),
              const SizedBox(height: 10),

              // 开机自启
              _buildSettingRow(
                isDark: isDark,
                icon: Icons.rocket_launch_outlined,
                title: '开机自启',
                subtitle: '系统启动时自动运行',
                trailing: Switch(
                  value: _autoStart,
                  onChanged: (v) async {
                    final success = v ? await StartupService.enable() : await StartupService.disable();
                    setState(() => _autoStart = success);
                  },
                ),
              ),
              const SizedBox(height: 10),

              // 更换图标
              _buildSettingRow(
                isDark: isDark,
                icon: Icons.palette_outlined,
                title: '更换图标',
                subtitle: '当前：${_currentIcon.replaceAll('_', ' ')}',
                trailing: OutlinedButton(
                  onPressed: _showIconPicker,
                  child: const Text('选择'),
                ),
              ),
              const SizedBox(height: 10),

              // 节假日管理
              _buildSettingRow(
                isDark: isDark,
                icon: Icons.event_note_outlined,
                title: '节假日管理',
                subtitle: '${_customDates.length} 条自定义日期',
                trailing: IconButton(
                  icon: const Icon(Icons.chevron_right, size: 20),
                  onPressed: _showHolidayManager,
                ),
              ),
              const SizedBox(height: 10),

              // 重建缓存
              _buildSettingRow(
                isDark: isDark,
                icon: Icons.refresh_outlined,
                title: '重建工作日缓存',
                subtitle: '清除并重新计算所有年份的工作日数据',
                trailing: OutlinedButton(
                  onPressed: _showRebuildCacheConfirm,
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  ),
                  child: const Text('重建'),
                ),
              ),
              const SizedBox(height: 16),

              // 关闭按钮
              Align(
                alignment: Alignment.centerRight,
                child: OutlinedButton(
                  onPressed: () {
                    Navigator.pop(context, widget.config);
                  },
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
    );
  }

  Widget _buildSettingRow({
    required bool isDark,
    required IconData icon,
    required String title,
    required String subtitle,
    required Widget trailing,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF334155) : const Color(0xFFF3F4F6),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(children: [
        Container(
          width: 34, height: 34,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primary.withOpacity(0.12),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 18, color: Theme.of(context).colorScheme.primary),
        ),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500,
              color: isDark ? const Color(0xFFF9FAFB) : const Color(0xFF111827))),
          const SizedBox(height: 2),
          Text(subtitle, style: TextStyle(fontSize: 11,
              color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280))),
        ])),
        trailing,
      ]),
    );
  }

  Future<void> _showIconPicker() async {
    final selected = await showDialog<String>(
      context: context,
      builder: (context) => IconPickerDialog(currentIcon: _currentIcon),
    );
    
    if (selected != null && selected != _currentIcon) {
      // 仅保存配置，主界面会自动刷新
      await IconService.applyIcon(selected);
      setState(() => _currentIcon = selected);
    }
  }

  Future<void> _showHolidayManager() async {
    await showDialog(
      context: context,
      builder: (context) => _HolidayManagerDialog(
        customDates: _customDates,
        onDatesChanged: (dates) {
          setState(() => _customDates = dates);
        },
      ),
    );
  }

  /// 显示重建缓存确认弹窗
  Future<void> _showRebuildCacheConfirm() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('重建工作日缓存'),
        content: const Text(
          '这将清除所有年份的缓存数据，并根据当前节假日设置重新计算。\n\n'
          '此操作可能需要几分钟时间，确定要继续吗？',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('确定'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _rebuildAllCaches();
    }
  }

  /// 重建所有缓存
  Future<void> _rebuildAllCaches() async {
    await LogService.write('[SystemSettings] User requested cache rebuild');
    
    // 清空所有缓存并删除JSON文件（强制重新计算）
    await YearWorkdayCacheService.invalidateAndDeleteFiles();
    await LogService.write('[SystemSettings] All caches invalidated and files deleted');

    // 获取当前配置中涉及的所有年份
    final config = await WorkdayService.getConfig();
    final years = <int>{};
    
    // 从 customDates 提取年份
    for (final key in config.customDates.keys) {
      final year = int.tryParse(key.split('-')[0]);
      if (year != null) years.add(year);
    }
    
    // 确保包含当前年和下一年
    final currentYear = DateTime.now().year;
    years.add(currentYear);
    years.add(currentYear + 1);
    
    // 重新初始化每个年份（会重新计算）
    for (final year in years.toList()..sort()) {
      await LogService.write('[SystemSettings] Rebuilding cache for year $year');
      await YearWorkdayCacheService.initialize(year);
      await LogService.write('[SystemSettings] Cache rebuilt for year $year');
    }

    // 刷新UI
    await _loadSettings();
    
    // 显示成功提示
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('已重建 ${years.length} 个年份的缓存'),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }
}

/// 节假日管理弹窗
class _HolidayManagerDialog extends StatefulWidget {
  final Map<String, Map<String, String>> customDates;
  final ValueChanged<Map<String, Map<String, String>>> onDatesChanged;

  const _HolidayManagerDialog({
    required this.customDates,
    required this.onDatesChanged,
  });

  @override
  State<_HolidayManagerDialog> createState() => _HolidayManagerDialogState();
}

class _HolidayManagerDialogState extends State<_HolidayManagerDialog> {
  late Map<String, Map<String, String>> _dates;
  late Map<String, Map<String, String>> _originalDates; // 保存原始数据用于比较
  final Set<int> _expandedYears = {}; // 已展开的年份集合

  @override
  void initState() {
    super.initState();
    _dates = Map.from(widget.customDates);
    _originalDates = Map.from(widget.customDates); // 记录初始状态
  }
  
  /// 检查数据是否发生变化
  bool _hasDataChanged() {
    if (_dates.length != _originalDates.length) return true;
    
    for (final key in _dates.keys) {
      if (!_originalDates.containsKey(key)) return true;
      if (_dates[key]?['type'] != _originalDates[key]?['type']) return true;
      if (_dates[key]?['name'] != _originalDates[key]?['name']) return true;
    }
    
    return false;
  }
  
  /// 关闭弹窗前检查并处理数据变化
  Future<void> _closeDialog() async {
    // 仅关闭，不保存（用户点击X或取消按钮时调用）
    Navigator.pop(context);
  }
  
  /// 保存并关闭弹窗
  Future<void> _saveAndClose() async {
    if (!_hasDataChanged()) {
      // 数据未变化，直接关闭
      Navigator.pop(context);
      return;
    }
    
    // 显示确认弹窗
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('保存节假日设置'),
        content: const Text(
          '修改节假日数据将会清除缓存并重新计算所有年份的工作日。\n\n'
          '此操作可能需要几分钟时间，是否确认保存？',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('确定'),
          ),
        ],
      ),
    );
    
    if (confirmed != true) return;
    
    // 执行保存：先清空再批量写入
    await LogService.write('[HolidayManager] Saving changes and rebuilding cache');
    
    // 1. 删除所有旧的自定义日期
    for (final key in _originalDates.keys) {
      final parts = key.split('-');
      final date = DateTime(int.parse(parts[0]), int.parse(parts[1]), int.parse(parts[2]));
      await WorkdayService.removeCustomDate(date);
    }
    
    // 2. 添加所有新的自定义日期
    for (final entry in _dates.entries) {
      final key = entry.key;
      final type = entry.value['type'] ?? '';
      final name = entry.value['name'] ?? '';
      final parts = key.split('-');
      final date = DateTime(int.parse(parts[0]), int.parse(parts[1]), int.parse(parts[2]));
      await WorkdayService.setCustomDate(date, type: type, name: name);
    }
    
    // 3. 清空所有缓存并删除JSON文件
    await YearWorkdayCacheService.invalidateAndDeleteFiles();
    
    // 4. 提取涉及的年份
    final affectedYears = <int>{};
    for (final key in _dates.keys) {
      final year = int.tryParse(key.split('-')[0]);
      if (year != null) affectedYears.add(year);
    }
    for (final key in _originalDates.keys) {
      final year = int.tryParse(key.split('-')[0]);
      if (year != null) affectedYears.add(year);
    }
    
    // 5. 重新初始化每个年份（会重新计算）
    for (final year in affectedYears.toList()..sort()) {
      await LogService.write('[HolidayManager] Reinitializing cache for year $year');
      await YearWorkdayCacheService.initialize(year);
    }
    
    // 6. 通知父组件数据已变化
    widget.onDatesChanged(_dates);
    
    await LogService.write('[HolidayManager] Cache rebuilt successfully');
    
    // 7. 关闭弹窗
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final sortedDates = _dates.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.zero),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480, maxHeight: 500),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('节假日管理', style: TextStyle(
                    fontSize: 18, fontWeight: FontWeight.w600,
                    color: isDark ? const Color(0xFFF9FAFB) : const Color(0xFF111827),
                  )),
                  IconButton(
                    icon: const Icon(Icons.close, size: 20),
                    onPressed: _closeDialog, // 改为调用_closeDialog
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // 添加按钮
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _addDate,
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('添加日期'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // 日期列表 - 按年分组
              if (sortedDates.isEmpty)
                Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 32),
                    child: Text('暂无自定义日期', style: TextStyle(
                      fontSize: 13,
                      color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
                    )),
                  ),
                )
              else
                Flexible(
                  child: _buildYearGroupedList(sortedDates, isDark),
                ),
              
              const SizedBox(height: 16),
              
              // 底部按钮区：取消 + 保存
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton(
                    onPressed: () => Navigator.pop(context), // 直接关闭，不保存
                    child: const Text('取消'),
                  ),
                  const SizedBox(width: 12),
                  FilledButton(
                    onPressed: _saveAndClose,
                    child: const Text('保存'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _addDate() async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => const CustomDateEditor(),
    );
    if (result != null) {
      final startDate = result['startDate'] as DateTime;
      final endDate = result['endDate'] as DateTime;
      final type = result['type'] as String;
      final name = result['name'] as String;

      // 遍历日期范围，逐个添加到内存（不立即保存）
      var current = startDate;
      while (!current.isAfter(endDate)) {
        final key = '${current.year}-${current.month.toString().padLeft(2, '0')}-${current.day.toString().padLeft(2, '0')}';
        setState(() {
          _dates[key] = {'type': type, 'name': name};
        });
        current = current.add(const Duration(days: 1));
      }
    }
  }

  Future<void> _deleteDate(String dateKey) async {
    setState(() {
      _dates.remove(dateKey);
    });
  }

  /// 构建按年分组的日期列表
  Widget _buildYearGroupedList(List<MapEntry<String, Map<String, String>>> sortedDates, bool isDark) {
    // 按年份分组
    final Map<int, List<MapEntry<String, Map<String, String>>>> yearGroups = {};
    for (final entry in sortedDates) {
      final year = int.parse(entry.key.split('-')[0]);
      yearGroups.putIfAbsent(year, () => []).add(entry);
    }

    // 按年份排序
    final sortedYears = yearGroups.keys.toList()..sort();

    return ListView.builder(
      shrinkWrap: true,
      itemCount: sortedYears.length,
      itemBuilder: (context, index) {
        final year = sortedYears[index];
        final dates = yearGroups[year]!;
        final isExpanded = _expandedYears.contains(year);

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF334155) : const Color(0xFFF3F4F6),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Column(
            children: [
              // 年份标题行
              InkWell(
                onTap: () {
                  setState(() {
                    if (isExpanded) {
                      _expandedYears.remove(year);
                    } else {
                      _expandedYears.add(year);
                    }
                  });
                },
                borderRadius: BorderRadius.vertical(top: Radius.circular(10)),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  child: Row(
                    children: [
                      Icon(
                        isExpanded ? Icons.expand_less : Icons.expand_more,
                        size: 18,
                        color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '$year 年',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: isDark ? const Color(0xFFF9FAFB) : const Color(0xFF111827),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '${dates.length} 条',
                          style: TextStyle(
                            fontSize: 11,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        icon: const Icon(Icons.add, size: 18),
                        onPressed: _addDate,
                        tooltip: '添加日期',
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    ],
                  ),
                ),
              ),

              // 展开的日期列表
              if (isExpanded)
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
                  child: Column(
                    children: [
                      for (int i = 0; i < dates.length; i++)
                        _buildDateItem(dates[i], isDark, i < dates.length - 1),
                    ],
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  /// 构建单个日期项
  Widget _buildDateItem(MapEntry<String, Map<String, String>> entry, bool isDark, bool showDivider) {
    final dateKey = entry.key;
    final type = entry.value['type'] ?? '';
    final name = entry.value['name'] ?? '';
    final isWorkday = type == 'workday';

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      dateKey.substring(5), // 只显示月-日
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: isDark ? const Color(0xFFF9FAFB) : const Color(0xFF111827),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            color: isWorkday ? const Color(0xFFF59E0B) : const Color(0xFF10B981),
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          isWorkday ? '调休上班' : (name.isNotEmpty ? name : '法定节假日'),
                          style: TextStyle(
                            fontSize: 11,
                            color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: Icon(
                  Icons.delete_outlined,
                  size: 16,
                  color: const Color(0xFFEF4444),
                ),
                onPressed: () => _deleteDate(dateKey),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
        ),
        if (showDivider)
          Divider(
            height: 1,
            color: isDark ? const Color(0x1AFFFFFF) : const Color(0x1A000000),
          ),
      ],
    );
  }
}
