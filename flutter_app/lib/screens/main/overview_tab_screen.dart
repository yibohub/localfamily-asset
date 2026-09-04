import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/ffi_bridge.dart';
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

              // 净值走势（财富曲线）
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16.0, vertical: 8.0),
                  child: _NetWorthTrendCard(
                    snapshots: provider.netWorthSnapshots,
                  ),
                ),
              ),

              // 资产分布
              if (assets.isNotEmpty)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16.0, vertical: 8.0),
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
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16.0, vertical: 8.0),
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
              color: summary.netAssets >= 0
                  ? Colors.green[400]!
                  : Colors.red[400]!,
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
      children: [
        Expanded(
          child: Row(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 16),
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
            children: [
              Expanded(
                child: Row(
                  children: [
                    Icon(type.icon, size: 16, color: type.color),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        type.displayName,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodyMedium,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
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
      typeGroups[liability.type] =
          (typeGroups[liability.type] ?? 0.0) + liability.amount;
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
            children: [
              Expanded(
                child: Row(
                  children: [
                    Icon(type.icon, size: 16, color: type.color),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        type.displayName,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodyMedium,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
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

/// 净值走势卡片（基于每日快照的财富曲线）
///
/// 打开应用会自动记录当日净值；不足 2 个数据点时显示引导文案
class _NetWorthTrendCard extends StatelessWidget {
  final List<NetWorthSnapshotPoint> snapshots;

  /// 最多展示最近多少天的数据
  static const _maxDays = 90;

  const _NetWorthTrendCard({required this.snapshots});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // 只取最近 N 天
    final points = snapshots.length > _maxDays
        ? snapshots.sublist(snapshots.length - _maxDays)
        : snapshots;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '净值走势',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 180,
              child: points.length < 2
                  ? _buildPlaceholder(context)
                  : _buildChart(context, points),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlaceholder(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.show_chart, size: 40, color: Colors.grey[400]),
          const SizedBox(height: 8),
          Text(
            '每天打开应用会自动记录当日净值',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '积累两天以上即可查看趋势曲线',
            style: theme.textTheme.bodySmall?.copyWith(
              color: Colors.grey[500],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChart(BuildContext context, List<NetWorthSnapshotPoint> points) {
    final theme = Theme.of(context);
    final color = theme.colorScheme.primary;

    final spots = <FlSpot>[
      for (var i = 0; i < points.length; i++)
        FlSpot(i.toDouble(), points[i].netWorth),
    ];

    var minY = spots.map((s) => s.y).reduce((a, b) => a < b ? a : b);
    var maxY = spots.map((s) => s.y).reduce((a, b) => a > b ? a : b);
    // 上下留 10% 余量；两点相同值时避免零区间
    final padding = (maxY - minY).abs() * 0.1 + 1.0;
    minY -= padding;
    maxY += padding;

    String shortDate(String iso) {
      final parts = iso.split('-');
      return parts.length == 3 ? '${parts[1]}/${parts[2]}' : iso;
    }

    return LineChart(
      LineChartData(
        minY: minY,
        maxY: maxY,
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: (maxY - minY) / 4,
          getDrawingHorizontalLine: (value) => FlLine(
            color: theme.dividerColor.withValues(alpha: 0.5),
            strokeWidth: 1,
          ),
        ),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              interval: (points.length / 4).clamp(1, double.infinity).toDouble(),
              getTitlesWidget: (value, meta) {
                final index = value.toInt();
                if (index < 0 || index >= points.length) {
                  return const SizedBox.shrink();
                }
                return Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    shortDate(points[index].date),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: Colors.grey[600],
                    ),
                  ),
                );
              },
            ),
          ),
        ),
        borderData: FlBorderData(show: false),
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            getTooltipItems: (touchedSpots) => touchedSpots.map((spot) {
              final p = points[spot.spotIndex];
              return LineTooltipItem(
                '${shortDate(p.date)}\n${CurrencyUtils.formatAmount(p.netWorth, 'CNY')}',
                theme.textTheme.bodySmall?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ) ??
                    const TextStyle(color: Colors.white),
              );
            }).toList(),
          ),
        ),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            barWidth: 2.5,
            color: color,
            dotData: FlDotData(
              show: points.length <= 31,
              getDotPainter: (spot, percent, bar, index) =>
                  FlDotCirclePainter(radius: 3, color: color),
            ),
            belowBarData: BarAreaData(
              show: true,
              color: color.withValues(alpha: 0.12),
            ),
          ),
        ],
      ),
    );
  }
}
