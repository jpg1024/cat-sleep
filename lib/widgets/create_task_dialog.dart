import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../models/task_config.dart';
import '../services/workday_service.dart';
import '../services/year_workday_cache_service.dart';
import '../services/log_service.dart';
import 'holiday_calendar.dart';
import 'segmented_control.dart';

/// 新建任务弹窗
class CreateTaskDialog extends StatefulWidget {
  final TaskConfig config;
  final bool lockTaskType;  // 是否锁定操作类型（不允许切换）

  const CreateTaskDialog({
    super.key, 
    required this.config,
    this.lockTaskType = false,  // 默认不锁定
  });

  @override
  State<CreateTaskDialog> createState() => _CreateTaskDialogState();
}

class _CreateTaskDialogState extends State<CreateTaskDialog> {
  late TaskConfig _config;
  Set<DateTime> _executionDates = {};
  late final ValueNotifier<Frequency> _frequencyNotifier;

  @override
  void initState() {
    super.initState();
    _config = widget.config;
    _frequencyNotifier = ValueNotifier(_config.frequency);
    _computeExecutionDates();
  }

  @override
  void dispose() {
    _frequencyNotifier.dispose();
    super.dispose();
  }

  /// 计算从本月到年底的所有执行日期（使用缓存）
  Future<void> _computeExecutionDates() async {
    if (_config.scheduleMode != ScheduleMode.workday) {
      setState(() => _executionDates = {});
      return;
    }

    try {
      final currentYear = DateTime.now().year;
      final dates = _config.workdayEveOnly
          ? await YearWorkdayCacheService.getEveOnlyDates(currentYear)
          : await YearWorkdayCacheService.getAllWorkdays(currentYear);

      await LogService.write('[CreateTaskDialog] year=$currentYear, workdayEveOnly=${_config.workdayEveOnly}, executionDates count=${dates.length}');
      if (dates.isNotEmpty) {
        final sorted = dates.toList()..sort();
        await LogService.write('[CreateTaskDialog] First 5 dates: ${sorted.take(5).map((d) => '${d.month}/${d.day}').join(', ')}');
      }

      setState(() => _executionDates = dates);
    } catch (e, stackTrace) {
      // 缓存未初始化时的降级处理
      await LogService.write('[CreateTaskDialog] Failed to load execution dates from cache: $e');
      await LogService.write('[CreateTaskDialog] Stack trace: $stackTrace');
      setState(() => _executionDates = {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isWorkdayMode = _config.scheduleMode == ScheduleMode.workday;
    final isRemindType = _config.taskType == TaskType.remind;
    
    // 提醒类型不支持工作日模式
    final availableScheduleModes = isRemindType 
        ? [ScheduleMode.countdown, ScheduleMode.specificTime]
        : ScheduleMode.values;
    
    // 工作日模式内含节假日日历，需要更高的弹窗；同时不超过屏幕高度的 92%
    final maxHeight = isWorkdayMode
        ? math.min(860.0, MediaQuery.of(context).size.height * 0.92)
        : 560.0;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.zero),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: 480, maxHeight: maxHeight),
        child: SingleChildScrollView(
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
                    Text('新建任务', style: TextStyle(
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
                const SizedBox(height: 20),

                // 操作类型 + 调度方式 并排下拉
                if (!widget.lockTaskType)
                  Row(
                    children: [
                      Expanded(child: _buildDropdown<TaskType>(
                        label: '操作类型',
                        value: _config.taskType,
                        items: TaskType.values,
                        itemIcon: _getTaskIcon,
                        itemLabel: (t) => t.label,
                        onChanged: (v) => setState(() => _config.taskType = v),
                        isDark: isDark,
                      )),
                      const SizedBox(width: 16),
                      Expanded(child: _buildDropdown<ScheduleMode>(
                        label: '调度方式',
                        value: _config.scheduleMode,
                        items: availableScheduleModes,
                        itemIcon: _getScheduleIcon,
                        itemLabel: (s) => s.label,
                        onChanged: (v) {
                          setState(() => _config.scheduleMode = v);
                          _computeExecutionDates();
                        },
                        isDark: isDark,
                      )),
                    ],
                  )
                else
                  // 锁定模式：只显示调度方式（操作类型固定为提醒）
                  _buildDropdown<ScheduleMode>(
                    label: '调度方式',
                    value: _config.scheduleMode,
                    items: availableScheduleModes,
                    itemIcon: _getScheduleIcon,
                    itemLabel: (s) => s.label,
                    onChanged: (v) {
                      setState(() => _config.scheduleMode = v);
                      _computeExecutionDates();
                    },
                    isDark: isDark,
                  ),
                const SizedBox(height: 20),

                // 联动时间配置区
                _buildTimeConfig(isDark),

                const SizedBox(height: 20),

                // 底部按钮
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                      ),
                      child: const Text('取消'),
                    ),
                    const SizedBox(width: 12),
                    FilledButton(
                      onPressed: _config.taskType == TaskType.remind && 
                                 (_config.reminderText == null || _config.reminderText!.isEmpty)
                          ? null  // 禁用按钮
                          : () => Navigator.pop(context, _config),
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
                      ),
                      child: const Text('确定'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ========== 联动时间配置 ==========
  Widget _buildTimeConfig(bool isDark) {
    // 提醒类型：显示提醒文本输入框
    if (_config.taskType == TaskType.remind) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 调度方式相关的时间配置
          if (_config.scheduleMode == ScheduleMode.countdown)
            Row(children: [
              Expanded(child: _buildNumberField('小时', _config.countdownHours, (v) => setState(() => _config.countdownHours = v))),
              const SizedBox(width: 12),
              Expanded(child: _buildNumberField('分钟', _config.countdownMinutes, (v) => setState(() => _config.countdownMinutes = v))),
            ])
          else if (_config.scheduleMode == ScheduleMode.specificTime)
            _buildDatePickerButton(isDark),
          
          const SizedBox(height: 16),
          
          // 提醒文本输入
          Text('提醒内容', style: TextStyle(
            fontSize: 12, 
            fontWeight: FontWeight.w600,
            color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
          )),
          const SizedBox(height: 8),
          TextFormField(
            maxLines: 3,
            initialValue: _config.reminderText ?? '',
            decoration: InputDecoration(
              hintText: '请输入提醒内容...',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            ),
            onChanged: (v) => setState(() => _config.reminderText = v),
          ),
        ],
      );
    }

    // 其他类型的原有逻辑
    switch (_config.scheduleMode) {
      case ScheduleMode.specificTime:
        return Column(children: [
          _buildDatePickerButton(isDark),
          const SizedBox(height: 16),
          _buildFrequencySection(isDark),
        ]);

      case ScheduleMode.countdown:
        return Row(children: [
          Expanded(child: _buildNumberField('小时', _config.countdownHours, (v) => setState(() => _config.countdownHours = v))),
          const SizedBox(width: 12),
          Expanded(child: _buildNumberField('分钟', _config.countdownMinutes, (v) => setState(() => _config.countdownMinutes = v))),
        ]);

      case ScheduleMode.workday:
        return Column(children: [
          Row(children: [
            Expanded(child: DropdownButtonFormField<int>(
              value: _config.targetTime?.hour ?? 23,
              decoration: const InputDecoration(labelText: '时', contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10)),
              items: List.generate(24, (i) => DropdownMenuItem(value: i, child: Text('${i.toString().padLeft(2, '0')} 时'))),
              onChanged: (v) {
                if (v != null) {
                  final c = _config.targetTime ?? DateTime(2026, 1, 1, 23, 55);
                  setState(() => _config.targetTime = DateTime(c.year, c.month, c.day, v, c.minute));
                }
              },
            )),
            const SizedBox(width: 12),
            Expanded(child: DropdownButtonFormField<int>(
              value: _config.targetTime?.minute ?? 55,
              decoration: const InputDecoration(labelText: '分', contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10)),
              items: List.generate(12, (i) => i * 5).map((m) => DropdownMenuItem(value: m, child: Text('${m.toString().padLeft(2, '0')} 分'))).toList(),
              onChanged: (v) {
                if (v != null) {
                  final c = _config.targetTime ?? DateTime(2026, 1, 1, 23, 55);
                  setState(() => _config.targetTime = DateTime(c.year, c.month, c.day, c.hour, v));
                }
              },
            )),
          ]),
          const SizedBox(height: 8),
          SwitchListTile(
            title: Text('仅在工作日前一晚执行', style: TextStyle(
              fontSize: 13, fontWeight: FontWeight.w500,
              color: isDark ? const Color(0xFFF9FAFB) : const Color(0xFF111827),
            )),
            subtitle: Text('周五、法定节假日前一天晚上不执行；周日、节假日结束当天晚上执行',
                style: TextStyle(
                  fontSize: 11,
                  color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
                )),
            value: _config.workdayEveOnly,
            onChanged: (v) {
              setState(() {
                _config.workdayEveOnly = v;
                _computeExecutionDates();
              });
            },
            activeColor: Theme.of(context).colorScheme.primary,
            contentPadding: EdgeInsets.zero,
            dense: true,
          ),
          const SizedBox(height: 8),
          Builder(
            builder: (context) {
              LogService.write('[CreateTaskDialog] Rendering HolidayCalendar: workdayEveOnly=${_config.workdayEveOnly}, executionDates=${_executionDates.length}');
              return HolidayCalendar(
                key: ValueKey('${_executionDates.length}_${_config.workdayEveOnly}'),
                executionDates: _executionDates,
                workdayEveOnly: _config.workdayEveOnly,
              );
            },
          ),
        ]);
    }
  }

  // ========== 频率区（指定时间模式下） ==========
  Widget _buildFrequencySection(bool isDark) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('频率', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600,
          color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280))),
      const SizedBox(height: 8),
      ValueListenableBuilder<Frequency>(
        valueListenable: _frequencyNotifier,
        builder: (context, freq, _) {
          return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            SegmentedControl<Frequency>(
              options: const {Frequency.daily: '每天', Frequency.weekly: '每周', Frequency.monthly: '每月'},
              value: freq,
              onChanged: (v) {
                _config.frequency = v;
                _frequencyNotifier.value = v;
              },
            ),
            if (freq == Frequency.weekly) ...[
              const SizedBox(height: 10),
              Wrap(spacing: 6, runSpacing: 6, children: List.generate(7, (i) {
                final day = i + 1;
                final selected = _config.weekDays.contains(day);
                return ChoiceChip(
                  label: Text('周${_weekdayLabel(day)}'),
                  selected: selected,
                  onSelected: (_) => setState(() {
                    if (selected) _config.weekDays.remove(day); else _config.weekDays.add(day);
                  }),
                  selectedColor: Theme.of(context).colorScheme.primary,
                  labelStyle: TextStyle(color: selected ? Colors.white : null, fontSize: 11),
                );
              })),
            ],
            if (freq == Frequency.monthly) ...[
              const SizedBox(height: 10),
              Row(children: [
                const Text('每月'),
                const SizedBox(width: 12),
                SizedBox(width: 90, child: DropdownButton<int>(
                  value: _config.monthlyDay ?? 1, isExpanded: true,
                  items: List.generate(31, (i) => i + 1).map((d) => DropdownMenuItem(value: d, child: Text('${d}日'))).toList(),
                  onChanged: (v) => setState(() => _config.monthlyDay = v),
                )),
              ]),
            ],
          ]);
        },
      ),
    ]);
  }

  // ========== 通用下拉选择器（带图标） ==========
  Widget _buildDropdown<T>({
    required String label,
    required T value,
    required List<T> items,
    required IconData Function(T) itemIcon,
    required String Function(T) itemLabel,
    required ValueChanged<T> onChanged,
    required bool isDark,
  }) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600,
          color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280))),
      const SizedBox(height: 6),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFF3F4F6),
          borderRadius: BorderRadius.circular(10),
        ),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<T>(
            value: value,
            isExpanded: true,
            icon: Icon(Icons.expand_more, size: 20,
                color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280)),
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500,
                color: isDark ? const Color(0xFFF9FAFB) : const Color(0xFF111827)),
            items: items.map((item) => DropdownMenuItem<T>(
              value: item,
              child: Row(children: [
                Icon(itemIcon(item), size: 18,
                    color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 8),
                Text(itemLabel(item)),
              ]),
            )).toList(),
            onChanged: (v) { if (v != null) onChanged(v); },
          ),
        ),
      ),
    ]);
  }

  Widget _buildNumberField(String label, int value, ValueChanged<int> onChanged) {
    return TextField(
      keyboardType: TextInputType.number,
      decoration: InputDecoration(labelText: label,
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10)),
      controller: TextEditingController(text: value.toString()),
      onChanged: (v) { final n = int.tryParse(v); if (n != null && n >= 0) onChanged(n); },
    );
  }

  Widget _buildDatePickerButton(bool isDark) {
    return InkWell(
      onTap: () async {
        final date = await showDatePicker(
          context: context,
          initialDate: _config.targetTime ?? DateTime.now(),
          firstDate: DateTime.now(),
          lastDate: DateTime.now().add(const Duration(days: 365)),
        );
        if (date == null) return;
        final time = await showTimePicker(
          context: context,
          initialTime: _config.targetTime != null
              ? TimeOfDay.fromDateTime(_config.targetTime!) : TimeOfDay.now(),
        );
        if (time == null) return;
        setState(() => _config.targetTime = DateTime(
          date.year, date.month, date.day, time.hour, time.minute, 0));
      },
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: '日期和时间',
          prefixIcon: const Icon(Icons.calendar_today, size: 16),
        ),
        child: Text(_config.targetTime != null
            ? '${_config.targetTime!.month}/${_config.targetTime!.day} ${_config.targetTime!.hour.toString().padLeft(2, '0')}:${_config.targetTime!.minute.toString().padLeft(2, '0')}'
            : '点击选择'),
      ),
    );
  }

  IconData _getTaskIcon(TaskType type) {
    switch (type) {
      case TaskType.shutdown: return Icons.power_settings_new;
      case TaskType.restart: return Icons.restart_alt;
      case TaskType.logoff: return Icons.logout;
      case TaskType.hibernate: return Icons.bedtime;
      case TaskType.sleep: return Icons.mode_standby;
      case TaskType.lock: return Icons.lock;
      case TaskType.remind: return Icons.notifications_active;
    }
  }

  IconData _getScheduleIcon(ScheduleMode mode) {
    switch (mode) {
      case ScheduleMode.specificTime: return Icons.calendar_today;
      case ScheduleMode.countdown: return Icons.timer;
      case ScheduleMode.workday: return Icons.business_center;
    }
  }

  String _weekdayLabel(int day) {
    const labels = ['一', '二', '三', '四', '五', '六', '日'];
    return labels[day - 1];
  }
}
