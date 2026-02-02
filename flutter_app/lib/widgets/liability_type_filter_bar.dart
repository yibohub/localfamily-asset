import 'package:flutter/material.dart';
import '../models/financial_models.dart';
import '../models/custom_asset_type.dart';

/// 负债类型筛选栏组件（支持内置类型 + 自定义类型）
class LiabilityTypeFilterBar extends StatelessWidget {
  final List<LiabilityType> builtInTypes;
  final List<CustomAssetType> customTypes;
  final String? selectedTypeId;
  final ValueChanged<String?> onTypeSelected;
  final VoidCallback onManageCustomTypes;
  final String allLabel;

  const LiabilityTypeFilterBar({
    super.key,
    required this.builtInTypes,
    required this.customTypes,
    required this.selectedTypeId,
    required this.onTypeSelected,
    required this.onManageCustomTypes,
    this.allLabel = '全部',
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Card(
        elevation: 2,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildChip(
                allLabel,
                Icons.apps,
                selectedTypeId == null,
                () => onTypeSelected(null),
                theme,
              ),
              ...builtInTypes.map((type) => _buildChip(
                    type.displayName,
                    type.icon,
                    selectedTypeId == type.id,
                    () => onTypeSelected(type.id),
                    theme,
                  )),
              ...customTypes.map((type) => _buildChip(
                    type.name,
                    _getIcon(type.iconName),
                    selectedTypeId == type.id,
                    () => onTypeSelected(type.id),
                    theme,
                  )),
              IconButton(
                icon: const Icon(Icons.add_circle_outline),
                onPressed: onManageCustomTypes,
                tooltip: '管理自定义类型',
                iconSize: 20,
                padding: const EdgeInsets.all(4),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildChip(
    String label,
    IconData icon,
    bool isSelected,
    VoidCallback onTap,
    ThemeData theme,
  ) {
    return FilterChip(
      label: Text(label),
      avatar: Icon(icon, size: 18),
      selected: isSelected,
      onSelected: (_) => onTap(),
      selectedColor: theme.colorScheme.primaryContainer,
      checkmarkColor: theme.colorScheme.primary,
    );
  }

  IconData _getIcon(String name) {
    // 自定义类型常用图标
    switch (name) {
      case 'star':
        return Icons.star;
      case 'favorite':
        return Icons.favorite;
      case 'bookmark':
        return Icons.bookmark;
      case 'label':
        return Icons.label;
      case 'tag':
        return Icons.tag;
      case 'diamond':
        return Icons.diamond;
      case 'pets':
        return Icons.pets;
      case 'flight':
        return Icons.flight;
      case 'restaurant':
        return Icons.restaurant;
      case 'shopping_bag':
        return Icons.shopping_bag;
      default:
        return Icons.category;
    }
  }
}
