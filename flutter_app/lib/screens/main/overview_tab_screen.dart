import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/financial_models.dart';
import '../../providers/financial_provider.dart';
import '../../utils/currency_utils.dart';

/// 总览标签页 - 显示资产和负债总览
class OverviewTabScreen extends StatelessWidget {
  const OverviewTabScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<FinancialProvider>(
      builder: (context, provider, child) {
        if (provider.isLoading) {
          return const Center(child: CircularProgressIndicator());
        }

        final summary = provider.getPortfolioSummary();
        final assets = provider.assets;
        final liabilities = provider.liabilities;

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
              if (assets.isNotEmpty)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                    child: _AssetBreakdownSection(
                      assets: assets,
                      total: summary.totalAssets,
                    ),
                  ),
                ),

              // 负债分布
              if (liabilities.isNotEmpty)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                    child: _LiabilityBreakdownSection(
                      liabilities: liabilities,
                      total: summary.totalLiabilities,
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
  final PortfolioSummary summary;

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

/// 资产类型分布部分
class _AssetBreakdownSection extends StatelessWidget {
  final List<Asset> assets;
  final double total;

  const _AssetBreakdownSection({
    required this.assets,
    required this.total,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // 按类型分组
    final typeGroups = <AssetType, double>{};
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
              '资产分布',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            ...typeGroups.entries.map((entry) {
              final amount = entry.value;
              final percentage = total > 0 ? (amount / total * 100) : 0.0;
              return _AssetBreakdownItem(
                type: entry.key,
                amount: amount,
                percentage: percentage,
              );
            }),
          ],
        ),
      ),
    );
  }
}

/// 资产类型分布项
class _AssetBreakdownItem extends StatelessWidget {
  final AssetType type;
  final double amount;
  final double percentage;

  const _AssetBreakdownItem({
    required this.type,
    required this.amount,
    required this.percentage,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

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
                  Icon(type.icon, size: 16, color: type.color),
                  const SizedBox(width: 8),
                  Text(
                    type.displayName,
                    style: theme.textTheme.bodyMedium,
                  ),
                ],
              ),
              Text(
                CurrencyUtils.formatAmount(amount, 'CNY'),
                style: theme.textTheme.bodyMedium,
              ),
            ],
          ),
          const SizedBox(height: 4),
          LinearProgressIndicator(
            value: percentage / 100,
            backgroundColor: Colors.grey[200],
            valueColor: AlwaysStoppedAnimation<Color>(type.color),
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
}

/// 负债类型分布部分
class _LiabilityBreakdownSection extends StatelessWidget {
  final List<Liability> liabilities;
  final double total;

  const _LiabilityBreakdownSection({
    required this.liabilities,
    required this.total,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // 按类型分组
    final typeGroups = <LiabilityType, double>{};
    for (final liability in liabilities) {
      typeGroups[liability.type] = (typeGroups[liability.type] ?? 0.0) + liability.amount;
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '负债分布',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            ...typeGroups.entries.map((entry) {
              final amount = entry.value;
              final percentage = total > 0 ? (amount / total * 100) : 0.0;
              return _LiabilityBreakdownItem(
                type: entry.key,
                amount: amount,
                percentage: percentage,
              );
            }),
          ],
        ),
      ),
    );
  }
}

/// 负债类型分布项
class _LiabilityBreakdownItem extends StatelessWidget {
  final LiabilityType type;
  final double amount;
  final double percentage;

  const _LiabilityBreakdownItem({
    required this.type,
    required this.amount,
    required this.percentage,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

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
                  Icon(type.icon, size: 16, color: type.color),
                  const SizedBox(width: 8),
                  Text(
                    type.displayName,
                    style: theme.textTheme.bodyMedium,
                  ),
                ],
              ),
              Text(
                CurrencyUtils.formatAmount(amount, 'CNY'),
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: Colors.red[400],
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          LinearProgressIndicator(
            value: percentage / 100,
            backgroundColor: Colors.grey[200],
            valueColor: AlwaysStoppedAnimation<Color>(type.color),
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
}
