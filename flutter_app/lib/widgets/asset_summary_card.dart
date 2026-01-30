import 'package:flutter/material.dart';
import '../models/portfolio_summary.dart';
import '../models/asset.dart';
import '../models/custom_asset_type.dart';
import '../utils/currency_utils.dart';
import '../screens/asset_list_screen.dart';

/// 资产总览卡片
class AssetSummaryCard extends StatelessWidget {
  final PortfolioSummary summary;
  final List<CustomAssetType> customTypes;

  const AssetSummaryCard({
    super.key,
    required this.summary,
    this.customTypes = const [],
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // 标题栏
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '资产负债总览',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
            const SizedBox(height: 20),

            // 三栏显示：总资产 | 总负债 | 净资产
            Row(
              children: [
                Expanded(child: _buildMetricCard(
                  context,
                  '总资产',
                  summary.totalAssets,
                  Colors.green,
                )),
                const SizedBox(width: 12),
                Expanded(child: _buildMetricCard(
                  context,
                  '总负债',
                  summary.totalLiabilities,
                  Colors.red,
                )),
                const SizedBox(width: 12),
                Expanded(child: _buildMetricCard(
                  context,
                  '净资产',
                  summary.netAssets,
                  Colors.blue,
                )),
              ],
            ),
            const SizedBox(height: 20),

            // 资产分布
            if (summary.totalAssets > 0) _buildAssetBreakdown(context),

            // 负债分布（如果存在）
            if (summary.totalLiabilities > 0) _buildLiabilityBreakdown(context),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricCard(
    BuildContext context,
    String label,
    double value,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _formatAmount(value),
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: color,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAssetBreakdown(BuildContext context) {
    final assetBreakdown = <MapEntry<String, double>>[];

    for (final entry in summary.breakdown.entries) {
      final assetType = AssetTypeExtension.fromString(entry.key);
      if (assetType != null && !assetType.isLiability) {
        // 内置资产类型
        assetBreakdown.add(MapEntry(entry.key, entry.value));
      } else if (assetType == null) {
        // 检查是否为自定义资产类型（非负债）
        final customType = customTypes.cast<CustomAssetType?>().firstWhere(
          (t) => t?.id == entry.key,
          orElse: () => null,
        );
        if (customType != null && !customType.isLiability) {
          assetBreakdown.add(MapEntry(entry.key, entry.value));
        }
      }
    }

    if (assetBreakdown.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('资产分布', style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 12),
        ...assetBreakdown.map((entry) {
          final percentage = summary.getPercentage(entry.key);
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _buildBreakdownItemForType(
              context,
              entry.key,
              percentage,
              entry.value,
              isLiability: false,
            ),
          );
        }),
      ],
    );
  }

  Widget _buildLiabilityBreakdown(BuildContext context) {
    final liabilityBreakdown = <MapEntry<String, double>>[];

    for (final entry in summary.breakdown.entries) {
      final assetType = AssetTypeExtension.fromString(entry.key);
      if (assetType != null && assetType.isLiability) {
        // 内置负债类型
        liabilityBreakdown.add(MapEntry(entry.key, entry.value));
      } else if (assetType == null) {
        // 检查是否为自定义负债类型
        final customType = customTypes.cast<CustomAssetType?>().firstWhere(
          (t) => t?.id == entry.key,
          orElse: () => null,
        );
        if (customType != null && customType.isLiability) {
          liabilityBreakdown.add(MapEntry(entry.key, entry.value));
        }
      }
    }

    if (liabilityBreakdown.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 12),
        Text('负债分布', style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 12),
        ...liabilityBreakdown.map((entry) {
          final percentage = summary.getPercentage(entry.key);
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _buildBreakdownItemForType(
              context,
              entry.key,
              percentage,
              entry.value,
              isLiability: true,
            ),
          );
        }),
      ],
    );
  }

  /// 构建分布项（支持内置类型和自定义类型）
  Widget _buildBreakdownItemForType(
    BuildContext context,
    String typeId,
    double percentage,
    double value, {
    required bool isLiability,
  }) {
    // 尝试解析为内置类型
    final assetType = AssetTypeExtension.fromString(typeId);
    String label;
    Color color;
    IconData icon;

    if (assetType != null) {
      // 内置类型
      label = assetType.displayName;
      color = _getTypeColor(assetType);
      icon = _getIconData(assetType.iconName);
    } else {
      // 自定义类型
      final customType = customTypes.cast<CustomAssetType?>().firstWhere(
        (t) => t?.id == typeId,
        orElse: () => null,
      );
      if (customType != null) {
        label = customType.name;
        icon = _getIconData(customType.iconName);
      } else {
        label = typeId.replaceAll('custom_', '');
        icon = Icons.category;
      }
      // 自定义类型的颜色
      color = isLiability ? const Color(0xFFEF4444) : const Color(0xFF2563EB);
    }

    return InkWell(
      onTap: () {
        // 只支持内置类型的导航
        if (assetType != null) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => AssetListScreen(assetType: assetType),
            ),
          );
        }
        // TODO: 自定义类型的导航可以后续实现
      },
      borderRadius: BorderRadius.circular(8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(icon, size: 16, color: color),
                  const SizedBox(width: 8),
                  Text(
                    label,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
              Text(
                '${percentage.toStringAsFixed(1)}%',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: percentage / 100,
              backgroundColor: color.withOpacity(0.1),
              valueColor: AlwaysStoppedAnimation<Color>(color),
              minHeight: 6,
            ),
          ),
        ],
      ),
    );
  }

  /// 构建分布项（旧版本，仅支持内置类型）
  Widget _buildBreakdownItem(
    BuildContext context,
    String label,
    Color color,
    double percentage,
    double value,
    AssetType assetType,
  ) {
    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => AssetListScreen(assetType: assetType),
          ),
        );
      },
      borderRadius: BorderRadius.circular(8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    label,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
              Text(
                '${percentage.toStringAsFixed(1)}%',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: percentage / 100,
              backgroundColor: color.withOpacity(0.1),
              valueColor: AlwaysStoppedAnimation<Color>(color),
              minHeight: 6,
            ),
          ),
        ],
      ),
    );
  }

  String _formatAmount(double amount) {
    return CurrencyUtils.formatAmount(amount, 'CNY');
  }

  String _getTypeName(AssetType type) {
    return type.displayName;
  }

  Color _getTypeColor(AssetType type) {
    switch (type) {
      case AssetType.property:
        return const Color(0xFF2563EB);
      case AssetType.deposit:
        return const Color(0xFF10B981);
      case AssetType.stock:
        return const Color(0xFFF59E0B);
      case AssetType.fund:
        return const Color(0xFF7C3AED);
      case AssetType.insurance:
        return const Color(0xFF8B5CF6);
      case AssetType.debt:
        return const Color(0xFFEF4444);
      case AssetType.mortgage:
        return const Color(0xFFDC2626);
      case AssetType.carLoan:
        return const Color(0xFFEA580C);
      case AssetType.creditCard:
        return const Color(0xFFF59E0B);
      case AssetType.personalLoan:
        return const Color(0xFFD97706);
      case AssetType.privateLoan:
        return const Color(0xFFCA8A04);
    }
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
