import 'package:flutter/material.dart';
import '../models/asset.dart';

/// 资产类型筛选栏组件
class AssetTypeFilterBar extends StatelessWidget {
  final List<AssetType> availableTypes;
  final AssetType? selectedType;
  final ValueChanged<AssetType?> onTypeSelected;
  final String allLabel;

  const AssetTypeFilterBar({
    super.key,
    required this.availableTypes,
    required this.selectedType,
    required this.onTypeSelected,
    this.allLabel = '全部',
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      color: theme.colorScheme.surface,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          children: [
            _buildChip(
              allLabel,
              Icons.apps,
              selectedType == null,
              () => onTypeSelected(null),
              theme,
            ),
            const SizedBox(width: 8),
            ...availableTypes.map((type) => Padding(
              padding: const EdgeInsets.only(right: 8),
              child: _buildChip(
                type.displayName,
                _getIcon(type.iconName),
                selectedType == type,
                () => onTypeSelected(type),
                theme,
              ),
            )),
          ],
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
      default:
        return Icons.help;
    }
  }
}
