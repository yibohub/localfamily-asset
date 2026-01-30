import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/asset.dart';
import '../../models/custom_asset_type.dart';
import '../../providers/asset_provider.dart';
import '../../providers/custom_type_provider.dart';
import '../../utils/currency_utils.dart';

/// 总览标签页 - 显示资产和负债总览
class OverviewTabScreen extends StatelessWidget {
  const OverviewTabScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer2<AssetProvider, CustomTypeProvider>(
      builder: (context, assetProvider, customTypeProvider, child) {
        if (assetProvider.isLoading) {
          return const Center(child: CircularProgressIndicator());
        }

        final customTypes = customTypeProvider.customTypes;
        final summary = assetProvider.getSummaryWithCustomTypes(customTypes);
        final assetsOnly = assetProvider.getAssetsOnly(customTypes);
        final liabilitiesOnly = assetProvider.getLiabilitiesOnly(customTypes);

        return Scaffold(
          body: CustomScrollView(
            slivers: [
              // 顶部总览卡片
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: _OverviewSummaryCard(summary: summary),
                ),
              ),

              // 资产分布
              if (assetsOnly.isNotEmpty)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                    child: _TypeBreakdownSection(
                      title: '资产分布',
                      assets: assetsOnly,
                      total: summary.totalAssets,
                      isLiability: false,
                      customTypes: customTypes,
                    ),
                  ),
                ),

              // 负债分布
              if (liabilitiesOnly.isNotEmpty)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                    child: _TypeBreakdownSection(
                      title: '负债分布',
                      assets: liabilitiesOnly,
                      total: summary.totalLiabilities,
                      isLiability: true,
                      customTypes: customTypes,
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

/// 总览统计卡片
class _OverviewSummaryCard extends StatelessWidget {
  final dynamic summary;

  const _OverviewSummaryCard({required this.summary});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // 总资产
            _SummaryRow(
              label: '总资产',
              amount: summary.totalAssets,
              color: colorScheme.primary,
              icon: Icons.account_balance_wallet,
            ),
            const Divider(height: 24),
            // 总负债
            _SummaryRow(
              label: '总负债',
              amount: summary.totalLiabilities,
              color: Colors.red[400]!,
              icon: Icons.credit_card,
            ),
            const Divider(height: 24),
            // 净资产
            _SummaryRow(
              label: '净资产',
              amount: summary.netAssets,
              color: summary.netAssets >= 0 ? Colors.green[400]! : Colors.red[400]!,
              icon: Icons.savings,
              isBold: true,
            ),
          ],
        ),
      ),
    );
  }
}

/// 统计行
class _SummaryRow extends StatelessWidget {
  final String label;
  final double amount;
  final Color color;
  final IconData icon;
  final bool isBold;

  const _SummaryRow({
    required this.label,
    required this.amount,
    required this.color,
    required this.icon,
    this.isBold = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: 8),
            Text(
              label,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
        Text(
          CurrencyUtils.formatAmount(amount, 'CNY'),
          style: theme.textTheme.titleLarge?.copyWith(
            color: color,
            fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ],
    );
  }
}

/// 类型分布部分
class _TypeBreakdownSection extends StatelessWidget {
  final String title;
  final List<Asset> assets;
  final double total;
  final bool isLiability;
  final List<CustomAssetType> customTypes;

  const _TypeBreakdownSection({
    required this.title,
    required this.assets,
    required this.total,
    required this.isLiability,
    required this.customTypes,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // 按类型分组（使用 String 作为键）
    final typeGroups = <String, double>{};
    for (final asset in assets) {
      typeGroups[asset.type] = (typeGroups[asset.type] ?? 0.0) + asset.amount;
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            ...typeGroups.entries.map((entry) {
              final amount = entry.value;
              final percentage = total > 0 ? (amount / total * 100) : 0.0;
              return _TypeBreakdownItem(
                type: entry.key,
                amount: amount,
                percentage: percentage,
                isLiability: isLiability,
                customTypes: customTypes,
              );
            }).toList(),
          ],
        ),
      ),
    );
  }
}

/// 类型分布项
class _TypeBreakdownItem extends StatelessWidget {
  final String type;
  final double amount;
  final double percentage;
  final bool isLiability;
  final List<CustomAssetType> customTypes;

  const _TypeBreakdownItem({
    required this.type,
    required this.amount,
    required this.percentage,
    required this.isLiability,
    required this.customTypes,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // 从字符串类型获取显示名称和图标
    final typeInfo = _getTypeInfo(type, customTypes);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(
                    typeInfo.icon,
                    size: 16,
                    color: isLiability ? Colors.red[400] : null,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    typeInfo.name,
                    style: theme.textTheme.bodyMedium,
                  ),
                ],
              ),
              Text(
                CurrencyUtils.formatAmount(amount, 'CNY'),
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: isLiability ? Colors.red[400] : null,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          LinearProgressIndicator(
            value: percentage / 100,
            backgroundColor: Colors.grey[200],
            valueColor: AlwaysStoppedAnimation<Color>(
              isLiability ? Colors.red[400]! : theme.colorScheme.primary,
            ),
          ),
          const SizedBox(height: 2),
          Align(
            alignment: Alignment.centerRight,
            child: Text(
              '${percentage.toStringAsFixed(1)}%',
              style: theme.textTheme.bodySmall?.copyWith(
                color: Colors.grey[600],
              ),
            ),
          ),
        ],
      ),
    );
  }

  IconData _getIconData(String iconName) {
    switch (iconName) {
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
        return Icons.help_outline;
    }
  }

  /// 从字符串类型获取类型信息
  _TypeInfo _getTypeInfo(String typeStr, List<CustomAssetType> customTypes) {
    // 尝试解析为内置类型
    final builtInType = AssetTypeExtension.fromString(typeStr);
    if (builtInType != null) {
      return _TypeInfo(
        name: builtInType.displayName,
        icon: _getIconData(builtInType.iconName),
      );
    }

    // 查找自定义类型
    final customType = customTypes.cast<CustomAssetType?>().firstWhere(
      (t) => t?.id == typeStr,
      orElse: () => null,
    );
    if (customType != null) {
      return _TypeInfo(
        name: customType.name,
        icon: _getIconData(customType.iconName),
      );
    }

    // 未知类型 - 使用字符串本身
    return _TypeInfo(
      name: typeStr.replaceAll('custom_', ''),
      icon: Icons.category,
    );
  }
}

/// 类型信息（名称和图标）
class _TypeInfo {
  final String name;
  final IconData icon;

  const _TypeInfo({required this.name, required this.icon});
}
