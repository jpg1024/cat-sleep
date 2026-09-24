import 'package:flutter/material.dart';
import '../services/workday_service.dart';
import '../services/log_service.dart';

/// 节假日日历组件
class HolidayCalendar extends StatefulWidget {
  final Set<DateTime>? executionDates;
  final bool workdayEveOnly;

  const HolidayCalendar({super.key, this.executionDates, this.workdayEveOnly = false});

  @override
  State<HolidayCalendar> createState() => _HolidayCalendarState();
}

class _HolidayCalendarState extends State<HolidayCalendar> {
  final int _currentYear = DateTime.now().year;
  final int _currentMonth = DateTime.now().month;
  late int _year;
  late int _month;
  List<Map<String, dynamic>> _calendarData = [];
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _year = _currentYear;
    _month = _currentMonth;
    _loadMonth();
  }

  @override
  void didUpdateWidget(HolidayCalendar oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 当 executionDates 或 workdayEveOnly 变化时，重新加载当前月份数据
    if (oldWidget.executionDates != widget.executionDates ||
        oldWidget.workdayEveOnly != widget.workdayEveOnly) {
      LogService.write('[HolidayCalendar] Props changed: executionDates=${widget.executionDates?.length ?? 0}, workdayEveOnly=${widget.workdayEveOnly}');
      _loadMonth();
    }
  }

  Future<void> _loadMonth() async {
    setState(() => _loading = true);
    final data = await WorkdayService.getMonthCalendar(_year, _month);
    setState(() {
      _calendarData = data;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 月份导航
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '$_year年$_month月',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: isDark ? const Color(0xFFF9FAFB) : const Color(0xFF111827),
              ),
            ),
            Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.chevron_left, size: 20),
                  // 禁止翻到上个月：最早显示本月
                  onPressed: _month > _currentMonth
                      ? () {
                          setState(() => _month--);
                          _loadMonth();
                        }
                      : null,
                ),
                IconButton(
                  icon: const Icon(Icons.chevron_right, size: 20),
                  // 覆盖到本年年底：最晚显示 12 月
                  onPressed: _month < 12
                      ? () {
                          setState(() => _month++);
                          _loadMonth();
                        }
                      : null,
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 12),

        // 星期标题
        Row(
          children: ['一', '二', '三', '四', '五', '六', '日']
              .map((d) => Expanded(
                    child: Center(
                      child: Text(
                        d,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
                        ),
                      ),
                    ),
                  ))
              .toList(),
        ),
        const SizedBox(height: 8),

        // 日历网格
        if (_loading)
          const SizedBox(height: 200, child: Center(child: CircularProgressIndicator()))
        else
          _buildCalendarGrid(isDark),

        const SizedBox(height: 12),

        // 图例
        Wrap(
          spacing: 16,
          runSpacing: 8,
          children: [
            _buildLegendItem(const Color(0xFF10B981), '放假', isDark),
            _buildLegendItem(const Color(0xFF6B7280), '周末', isDark),
            _buildLegendItem(const Color(0xFF3B82F6), '调休上班', isDark),
            widget.workdayEveOnly
                ? _buildLegendBorderItem(const Color(0xFF6366F1), '计划执行', isDark)
                : _buildLegendBorderItem(const Color(0xFF4F46E5), '计划执行', isDark),
          ],
        ),
      ],
    );
  }

  Widget _buildCalendarGrid(bool isDark) {
    if (_calendarData.isEmpty) return const SizedBox.shrink();

    final firstDay = DateTime(_year, _month, 1);
    int startWeekday = firstDay.weekday - 1; // 0=Mon, 6=Sun

    List<Widget> cells = [];

    // 空白填充（与日期单元格完全一致的结构）
    for (int i = 0; i < startWeekday; i++) {
      cells.add(
        Expanded(
          child: Container(
            height: 48,
            margin: const EdgeInsets.all(2),
          ),
        ),
      );
    }

    // 日期单元格
    for (final dayData in _calendarData) {
      cells.add(_buildDayCell(dayData, isDark));
    }

    // 按行分组，每行 7 个
    List<Widget> rows = [];
    for (int i = 0; i < cells.length; i += 7) {
      final end = (i + 7 > cells.length) ? cells.length : i + 7;
      final rowCells = cells.sublist(i, end);
      // 确保每行都有 7 个单元格
      while (rowCells.length < 7) {
        rowCells.add(
          Expanded(
            child: Container(
              height: 48,
              margin: const EdgeInsets.all(2),
            ),
          ),
        );
      }
      rows.add(Row(children: rowCells));
    }

    return Column(children: rows);
  }

  Widget _buildDayCell(Map<String, dynamic> data, bool isDark) {
    final day = data['day'] as int;
    final type = data['type'] as String;
    final label = data['label'] as String;
    final isPast = data['isPast'] as bool;
    final isToday = data['isToday'] as bool;
    final date = data['date'] as DateTime;

    // 检查是否为执行日期（使用日期字符串比较，更可靠）
    final dateStr = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    final isExecutionDate = widget.executionDates?.any((d) {
      final dStr = '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
      return dStr == dateStr;
    }) ?? false;

    if (isExecutionDate && !isPast && day <= 5) {
      LogService.write('[HolidayCalendar] Date $dateStr: isExecution=$isExecutionDate, workdayEveOnly=${widget.workdayEveOnly}, type=$type');
    }

    Color bgColor;
    Color textColor;
    BoxBorder? border;

    switch (type) {
      case 'holiday':
        bgColor = const Color(0xFF10B981).withOpacity(0.15);
        textColor = const Color(0xFF10B981);
        break;
      case 'weekend':
        bgColor = const Color(0xFF6B7280).withOpacity(0.1);
        textColor = const Color(0xFF6B7280);
        break;
      case 'makeup_workday':
        bgColor = const Color(0xFF3B82F6).withOpacity(0.15);
        textColor = const Color(0xFF3B82F6);
        break;
      case 'workday_override':
      case 'holiday_override':
        bgColor = const Color(0xFF6366F1).withOpacity(0.15);
        textColor = const Color(0xFF6366F1);
        break;
      default:
        bgColor = const Color(0xFF6366F1).withOpacity(0.08);
        textColor = const Color(0xFF6366F1);
        border = null;
    }

    // 根据 workdayEveOnly 模式设置执行日期的边框
    if (isExecutionDate && !isPast) {
      if (widget.workdayEveOnly) {
        // eve模式：紫色边框
        border = Border.all(color: const Color(0xFF6366F1), width: 2);
      } else {
        // 非eve模式：深紫色边框（加粗）+ 轻微背景高亮
        border = Border.all(color: const Color(0xFF4F46E5), width: 3);
        bgColor = bgColor.withOpacity(0.25); // 增强背景对比度
      }
    }

    if (isPast) {
      textColor = textColor.withOpacity(0.4);
    }

    return Expanded(
      child: GestureDetector(
        onTap: isPast ? null : () => _toggleDay(data),
        child: Container(
          height: 48,
          margin: const EdgeInsets.all(2),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(8),
            border: isToday
                ? Border.all(color: const Color(0xFF6366F1), width: 2)
                : (type.contains('override')
                    ? Border.all(color: const Color(0xFF6366F1).withOpacity(0.5), width: 1)
                    : border),
          ),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              // 日期内容（居中）
              Positioned.fill(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        '$day',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: isToday ? FontWeight.w700 : FontWeight.w500,
                          color: textColor,
                        ),
                      ),
                      if (label.isNotEmpty)
                        Text(
                          label,
                          style: TextStyle(
                            fontSize: 9,
                            color: textColor.withOpacity(0.8),
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                    ],
                  ),
                ),
              ),
              // 执行日期标记：仅在eve模式下显示橙色小方块
              if (isExecutionDate && !isPast && widget.workdayEveOnly)
                Positioned(
                  top: 3,
                  left: 3,
                  child: Container(
                    width: 7,
                    height: 7,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF59E0B), // 浅橙色
                      borderRadius: BorderRadius.circular(1.5),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLegendItem(Color color, String label, bool isDark) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color.withOpacity(0.2),
            borderRadius: BorderRadius.circular(3),
            border: Border.all(color: color, width: 1),
          ),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
          ),
        ),
      ],
    );
  }

  /// 图例：边框样式（计划执行）
  Widget _buildLegendBorderItem(Color color, String label, bool isDark) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 14,
          height: 14,
          decoration: BoxDecoration(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(3),
            border: Border.all(color: color, width: 2),
          ),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
          ),
        ),
      ],
    );
  }

  Future<void> _toggleDay(Map<String, dynamic> data) async {
    final date = data['date'] as DateTime;
    final type = data['type'] as String;

    if (type == 'workday' || type == 'makeup_workday') {
      await WorkdayService.removeWorkday(date);
    } else {
      await WorkdayService.addWorkday(date);
    }

    await _loadMonth();
  }
}
