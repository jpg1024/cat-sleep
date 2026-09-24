import 'package:flutter/material.dart';
import '../services/workday_service.dart';

/// 自定义日期编辑弹窗（支持日期范围选择）
class CustomDateEditor extends StatefulWidget {
  final DateTime? initialDate;
  final String? initialType;
  final String? initialName;

  const CustomDateEditor({
    super.key,
    this.initialDate,
    this.initialType,
    this.initialName,
  });

  @override
  State<CustomDateEditor> createState() => _CustomDateEditorState();
}

class _CustomDateEditorState extends State<CustomDateEditor> {
  late DateTime _startDate;
  DateTime? _endDate;
  late String _type;
  String _name = '';
  final _nameController = TextEditingController();
  bool _isRange = false;

  @override
  void initState() {
    super.initState();
    _startDate = widget.initialDate ?? DateTime.now();
    _type = widget.initialType ?? 'holiday';
    _name = widget.initialName ?? '';
    _nameController.text = _name;
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final effectiveEndDate = _endDate ?? _startDate;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.zero),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 400),
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
                    widget.initialDate != null ? '编辑日期' : '添加日期',
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
              const SizedBox(height: 20),

              // 日期范围选择
              Row(children: [
                Expanded(child: _buildDateField('开始日期', _startDate, isDark, () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: _startDate,
                    firstDate: DateTime(2026, 1, 1),
                    lastDate: DateTime(2026, 12, 31),
                  );
                  if (picked != null) {
                    setState(() {
                      _startDate = picked;
                      if (_endDate != null && _endDate!.isBefore(_startDate)) {
                        _endDate = _startDate;
                      }
                    });
                  }
                })),
                const SizedBox(width: 12),
                Expanded(child: _buildDateField('结束日期', effectiveEndDate, isDark, () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: _endDate ?? _startDate,
                    firstDate: _startDate,
                    lastDate: DateTime(2026, 12, 31),
                  );
                  if (picked != null) {
                    setState(() => _endDate = picked);
                  }
                })),
              ]),
              const SizedBox(height: 8),

              // 范围提示
              if (_endDate != null && _endDate != _startDate)
                Text(
                  '共 ${_endDate!.difference(_startDate).inDays + 1} 天',
                  style: TextStyle(
                    fontSize: 11,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
              const SizedBox(height: 16),

              // 类型选择
              Text('类型', style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
              )),
              const SizedBox(height: 8),
              Row(children: [
                Expanded(child: _buildTypeButton('holiday', '法定节假日', isDark)),
                const SizedBox(width: 12),
                Expanded(child: _buildTypeButton('workday', '调休上班', isDark)),
              ]),
              const SizedBox(height: 16),

              // 节假日名称
              if (_type == 'holiday') ...[
                Text('节假日名称', style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
                )),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF334155) : const Color(0xFFF3F4F6),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: WorkdayService.holidayNames.contains(_name) ? _name : null,
                      isExpanded: true,
                      hint: Text('选择或输入名称', style: TextStyle(
                        fontSize: 13,
                        color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
                      )),
                      icon: Icon(Icons.expand_more, size: 20,
                          color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280)),
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500,
                          color: isDark ? const Color(0xFFF9FAFB) : const Color(0xFF111827)),
                      items: WorkdayService.holidayNames.map((name) => DropdownMenuItem(
                        value: name,
                        child: Text(name),
                      )).toList(),
                      onChanged: (v) {
                        if (v != null) {
                          setState(() {
                            if (v == '其他') {
                              _name = '';
                              _nameController.text = '';
                            } else {
                              _name = v;
                              _nameController.text = v;
                            }
                          });
                        }
                      },
                    ),
                  ),
                ),
                if (_name.isEmpty || (!WorkdayService.holidayNames.contains(_name) && _nameController.text.isNotEmpty)) ...[
                  const SizedBox(height: 8),
                  TextField(
                    controller: _nameController,
                    decoration: InputDecoration(
                      labelText: '自定义名称',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    onChanged: (v) => setState(() => _name = v),
                  ),
                ],
              ],
              const SizedBox(height: 24),

              // 按钮
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('取消'),
                  ),
                  const SizedBox(width: 12),
                  FilledButton(
                    onPressed: () {
                      final finalName = _type == 'workday'
                          ? '班'
                          : (_nameController.text.isNotEmpty ? _nameController.text : _name);
                      Navigator.pop(context, {
                        'startDate': _startDate,
                        'endDate': _endDate ?? _startDate,
                        'type': _type,
                        'name': finalName,
                      });
                    },
                    child: const Text('确定'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDateField(String label, DateTime date, bool isDark, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: const Icon(Icons.calendar_today, size: 16),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        ),
        child: Text(
          '${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}',
          style: TextStyle(
            fontSize: 14,
            color: isDark ? const Color(0xFFF9FAFB) : const Color(0xFF111827),
          ),
        ),
      ),
    );
  }

  Widget _buildTypeButton(String type, String label, bool isDark) {
    final isSelected = _type == type;
    return GestureDetector(
      onTap: () => setState(() => _type = type),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected
              ? Theme.of(context).colorScheme.primary
              : (isDark ? const Color(0xFF334155) : const Color(0xFFF3F4F6)),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: isSelected ? Colors.white : (isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280)),
          ),
        ),
      ),
    );
  }
}
