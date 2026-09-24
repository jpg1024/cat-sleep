import 'package:flutter/material.dart';

/// 图标选择对话框
class IconPickerDialog extends StatefulWidget {
  final String? currentIcon;

  const IconPickerDialog({super.key, this.currentIcon});

  @override
  State<IconPickerDialog> createState() => _IconPickerDialogState();
}

class _IconPickerDialogState extends State<IconPickerDialog> {
  String? _selectedIcon;

  // 动物图标列表（文件名，不含扩展名）
  static const List<String> _animalIcons = [
    'albatross',
    'cat',
    'dog',
    'eagle',
    'elephant',
    'giraffe',
    'grouse',
    'heron',
    'hippo',
    'hummingbird',
    'kangaroo',
    'lion',
    'mandarin_duck',
    'monkey',
    'orangutan',
    'ostrich',
    'otter',
    'panda',
    'parrot',
    'penguin',
    'red_panda',
    'seagull',
    'seal',
    'swan',
    'tiger',
    'woodpecker',
  ];

  @override
  void initState() {
    super.initState();
    _selectedIcon = widget.currentIcon ?? 'cat';
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 500, maxHeight: 600),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '选择图标',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Text(
                '选择一个动物图标作为应用图标',
                style: TextStyle(color: Colors.grey),
              ),
              const SizedBox(height: 20),
              Expanded(
                child: GridView.builder(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 4,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                  ),
                  itemCount: _animalIcons.length,
                  itemBuilder: (context, index) {
                    final iconName = _animalIcons[index];
                    final isSelected = _selectedIcon == iconName;
                    return _buildIconItem(context, iconName, isSelected);
                  },
                ),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('取消'),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    onPressed: _selectedIcon != null
                        ? () => Navigator.pop(context, _selectedIcon)
                        : null,
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

  Widget _buildIconItem(BuildContext context, String iconName, bool isSelected) {
    return GestureDetector(
      onTap: () {
        setState(() => _selectedIcon = iconName);
      },
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(
            color: isSelected
                ? Theme.of(context).colorScheme.primary
                : Colors.grey.withOpacity(0.3),
            width: isSelected ? 3 : 1,
          ),
          borderRadius: BorderRadius.circular(12),
          color: isSelected
              ? Theme.of(context).colorScheme.primary.withOpacity(0.1)
              : null,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset(
              'assets/animals/$iconName.png',
              width: 48,
              height: 48,
              errorBuilder: (context, error, stackTrace) {
                return const Icon(Icons.image_not_supported, size: 48);
              },
            ),
            const SizedBox(height: 4),
            Text(
              _formatName(iconName),
              style: TextStyle(
                fontSize: 11,
                color: isSelected
                    ? Theme.of(context).colorScheme.primary
                    : null,
                fontWeight: isSelected ? FontWeight.bold : null,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  String _formatName(String name) {
    // 将 snake_case 转换为空格分隔
    return name.replaceAll('_', ' ');
  }
}
