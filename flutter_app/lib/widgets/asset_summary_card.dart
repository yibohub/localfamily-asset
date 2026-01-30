import 'package:flutter/material.dart';
import '../models/portfolio_summary.dart';
import '../models/asset.dart';
import '../utils/currency_utils.dart';
import '../screens/asset_list_screen.dart';

/// 资产总览卡片
class AssetSummaryCard extends StatelessWidget {
  final PortfolioSummary summary;

  const AssetSummaryCard({super.key, required this.summary});

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
    final assetBreakdown = summary.breakdown.entries
        .map((e) => MapEntry(e.key, e.value))
        .where((e) {
          final assetType = AssetTypeExtension.fromString(e.key);
          return assetType != null && !assetType.isLiability;
        })
        .toList();

    if (assetBreakdown.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('资产分布', style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 12),
        ...assetBreakdown.map((entry) {
          final assetType = AssetTypeExtension.fromString(entry.key)!;
          final percentage = summary.getPercentage(entry.key);
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _buildBreakdownItem(
              context,
              _getTypeName(assetType),
              _getTypeColor(assetType),
              percentage,
              entry.value,
              assetType,
            ),
          );
        }),
      ],
    );
  }

  Widget _buildLiabilityBreakdown(BuildContext context) {
    final liabilityBreakdown = summary.breakdown.entries
        .map((e) => MapEntry(e.key, e.value))
        .where((e) {
          final assetType = AssetTypeExtension.fromString(e.key);
          return assetType != null && assetType.isLiability;
        })
        .toList();

    if (liabilityBreakdown.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 12),
        Text('负债分布', style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 12),
        ...liabilityBreakdown.map((entry) {
          final assetType = AssetTypeExtension.fromString(entry.key)!;
          final percentage = summary.getPercentage(entry.key);
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _buildBreakdownItem(
              context,
              _getTypeName(assetType),
              _getTypeColor(assetType),
              percentage,
              entry.value,
              assetType,
            ),
          );
        }),
      ],
    );
  }

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
}
