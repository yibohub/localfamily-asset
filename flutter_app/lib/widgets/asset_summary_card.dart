import 'package:flutter/material.dart';
import '../models/portfolio_summary.dart';
import '../models/asset.dart';

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
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '总资产',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: Colors.grey[600],
                      ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.trending_up, size: 16, color: Colors.green),
                      const SizedBox(width: 4),
                      Text(
                        '+2.5%',
                        style: Theme.of(context)
                            .textTheme
                            .bodySmall
                            ?.copyWith(color: Colors.green, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              _formatAmount(summary.totalValue),
              style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                    color: Theme.of(context).colorScheme.primary,
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 20),
            _buildBreakdown(context),
          ],
        ),
      ),
    );
  }

  Widget _buildBreakdown(BuildContext context) {
    if (summary.breakdown.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '资产分布',
          style: Theme.of(context).textTheme.titleSmall,
        ),
        const SizedBox(height: 12),
        ...summary.breakdown.entries.map((entry) {
          final percentage = summary.getPercentage(entry.key);
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _buildBreakdownItem(
              context,
              _getTypeName(entry.key),
              _getTypeColor(entry.key),
              percentage,
              entry.value,
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
  ) {
    return Column(
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
    );
  }

  String _formatAmount(double amount) {
    if (amount >= 1000000) {
      return '\$${(amount / 1000000).toStringAsFixed(2)}M';
    } else if (amount >= 1000) {
      return '\$${(amount / 1000).toStringAsFixed(2)}K';
    }
    return '\$${amount.toStringAsFixed(2)}';
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
    }
  }
}
