import 'package:flutter/material.dart';
import '../models/asset.dart';
import '../models/custom_asset_type.dart';

/// 资产类型筛选栏组件（支持内置类型 + 自定义类型）
class AssetTypeFilterBar extends StatelessWidget {
  final List<AssetType> builtInTypes;
  final List<CustomAssetType> customTypes;
  final String? selectedTypeId;
  final ValueChanged<String?> onTypeSelected;
  final VoidCallback onManageCustomTypes;
  final String allLabel;

  const AssetTypeFilterBar({
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
                    _getIcon(type.iconName),
                    selectedTypeId == type.snakeCaseName,
                    () => onTypeSelected(type.snakeCaseName),
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
    // 内置类型图标
    switch (name) {
      case 'home':
        return Icons.home;
      case 'account_balance':
        return Icons.account_balance;
      case 'trending_up':
        return Icons.trending_up;
      case 'pie_chart':
        return Icons.pie_chart;
      case 'security':
        return Icons.security;
      case 'credit_card':
        return Icons.credit_card;
      case 'home_work':
        return Icons.home_work;
      case 'directions_car':
        return Icons.directions_car;
      case 'person':
        return Icons.person;
      case 'handshake':
        return Icons.handshake;
      // 自定义类型常用图标
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
