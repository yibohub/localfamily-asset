import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/ffi_bridge.dart';
import '../../models/financial_models.dart';
import '../../providers/financial_provider.dart';
import '../../utils/currency_utils.dart';
import '../financial_record_detail_screen.dart';

/// 总览标签页 - 显示资产和负债总览
class OverviewTabScreen extends StatelessWidget {
  /// 请求切换底部导航页签（0=资产，2=负债）；typeFilter 为需预设的类型
  /// 筛选 id（null = 显示全部）
  final void Function(int tabIndex, {String? typeFilter})? onNavigateToTab;

  const OverviewTabScreen({super.key, this.onNavigateToTab});

  /// 负债小类 id 集合（这些到期项存在负债记录里，其余为资产）
  static const _liabilityTypeIds = {
    'debt',
    'mortgage',
    'car_loan',
    'credit_card',
    'personal_loan',
    'private_loan',
  };

  void _openDueRecord(BuildContext context, DueItemInfo item) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => FinancialRecordDetailScreen(
          recordId: item.id,
          recordType: _liabilityTypeIds.contains(item.assetType)
              ? RecordType.liability
              : RecordType.asset,
        ),
      ),
    );
  }

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
        final returns = provider.investmentReturns;

        return Scaffold(
          body: CustomScrollView(
            slivers: [
              // 顶部总览卡片
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: _OverviewSummaryCard(
                    summary: summary,
                    onGoToTab: onNavigateToTab,
                  ),
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

              // 到期提醒（未来 30 天内有到期项才显示）
              if (provider.dueItems.isNotEmpty)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16.0, vertical: 8.0),
                    child: _DueRemindersCard(
                      items: provider.dueItems,
                      onOpenRecord: (item) => _openDueRecord(context, item),
                    ),
                  ),
                ),

              // 投资年化（有投资收益数据才显示）
              if (returns != null && returns.items.isNotEmpty)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16.0, vertical: 8.0),
                    child: _InvestmentReturnsCard(returns: returns),
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
                      onGoToTab: onNavigateToTab,
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
                      onGoToTab: onNavigateToTab,
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

  /// 点击总资产/总负债行时切换页签（null 时行不可点击）
  final void Function(int tabIndex, {String? typeFilter})? onGoToTab;

  const _OverviewSummaryCard({required this.summary, this.onGoToTab});

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
            // 总资产（点击跳转资产页签）
            _SummaryRow(
              label: '总资产',
              amount: summary.totalAssets,
              color: colorScheme.primary,
              icon: Icons.account_balance_wallet,
              onTap: onGoToTab == null ? null : () => onGoToTab!(0),
            ),
            const Divider(height: 24),
            // 总负债（点击跳转负债页签）
            _SummaryRow(
              label: '总负债',
              amount: summary.totalLiabilities,
              color: Colors.red[400]!,
              icon: Icons.credit_card,
              onTap: onGoToTab == null ? null : () => onGoToTab!(2),
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
  final VoidCallback? onTap;

  const _SummaryRow({
    required this.label,
    required this.amount,
    required this.color,
    required this.icon,
    this.isBold = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final row = Row(
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
        // 可点击行右侧显示箭头提示可跳转
        if (onTap != null) ...[
          const SizedBox(width: 4),
          Icon(Icons.chevron_right, size: 20, color: Colors.grey[400]),
        ],
      ],
    );

    if (onTap == null) return row;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: row,
    );
  }
}

/// 资产类型分布部分
class _AssetBreakdownSection extends StatelessWidget {
  final List<Asset> assets;
  final double total;

  /// 点击条目切换到资产页签并按该类型筛选
  final void Function(int tabIndex, {String? typeFilter})? onGoToTab;

  const _AssetBreakdownSection({
    required this.assets,
    required this.total,
    this.onGoToTab,
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
                onTap: onGoToTab == null
                    ? null
                    : () => onGoToTab!(0, typeFilter: entry.key.id),
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
  final VoidCallback? onTap;

  const _AssetBreakdownItem({
    required this.type,
    required this.amount,
    required this.percentage,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final content = Padding(
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

    if (onTap == null) return content;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: content,
    );
  }
}

/// 负债类型分布部分
class _LiabilityBreakdownSection extends StatelessWidget {
  final List<Liability> liabilities;
  final double total;

  /// 点击条目切换到负债页签并按该类型筛选
  final void Function(int tabIndex, {String? typeFilter})? onGoToTab;

  const _LiabilityBreakdownSection({
    required this.liabilities,
    required this.total,
    this.onGoToTab,
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
                onTap: onGoToTab == null
                    ? null
                    : () => onGoToTab!(2, typeFilter: entry.key.id),
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
  final VoidCallback? onTap;

  const _LiabilityBreakdownItem({
    required this.type,
    required this.amount,
    required this.percentage,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final content = Padding(
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

    if (onTap == null) return content;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: content,
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

/// 投资年化卡片（组合 XIRR + 各投资资产明细）
class _InvestmentReturnsCard extends StatelessWidget {
  final PortfolioReturns returns;

  const _InvestmentReturnsCard({required this.returns});

  /// 年化收益率着色：正绿负红
  static Color _xirrColor(double? xirr) {
    if (xirr == null) return Colors.grey[500]!;
    return xirr >= 0 ? Colors.green[400]! : Colors.red[400]!;
  }

  static String _formatXirr(double? xirr) {
    if (xirr == null) return '—';
    final pct = xirr * 100;
    return '${pct >= 0 ? '+' : ''}${pct.toStringAsFixed(1)}%';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final xirrColor = _xirrColor(returns.portfolioXirr);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '投资年化',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            // 组合年化大字
            Row(
              children: [
                Text(
                  '组合年化 XIRR',
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(color: Colors.grey[600]),
                ),
                const Spacer(),
                Text(
                  _formatXirr(returns.portfolioXirr),
                  style: theme.textTheme.headlineSmall?.copyWith(
                    color: xirrColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const Divider(height: 20),
            _SummaryRow(
              label: '投入成本',
              amount: returns.totalCost,
              color: theme.colorScheme.onSurface,
              icon: Icons.payments_outlined,
            ),
            const SizedBox(height: 8),
            _SummaryRow(
              label: '当前市值',
              amount: returns.totalValue,
              color: theme.colorScheme.onSurface,
              icon: Icons.pie_chart_outline,
            ),
            const SizedBox(height: 8),
            _SummaryRow(
              label: '累计盈亏',
              amount: returns.totalProfit,
              color: returns.totalProfit >= 0
                  ? Colors.green[400]!
                  : Colors.red[400]!,
              icon: returns.totalProfit >= 0
                  ? Icons.trending_up
                  : Icons.trending_down,
            ),
            // 各资产年化明细
            ...returns.items.map((item) => Padding(
                  padding: const EdgeInsets.only(top: 8.0),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          item.name,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${item.profitPercent >= 0 ? '+' : ''}${item.profitPercent.toStringAsFixed(1)}%',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: item.profit >= 0
                              ? Colors.green[400]
                              : Colors.red[400],
                        ),
                      ),
                      const SizedBox(width: 12),
                      SizedBox(
                        width: 64,
                        child: Text(
                          _formatXirr(item.xirr),
                          textAlign: TextAlign.right,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: _xirrColor(item.xirr),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                )),
            const SizedBox(height: 4),
            Text(
              'XIRR：考虑每笔买入时点的年化内部收益率',
              style: theme.textTheme.bodySmall?.copyWith(
                color: Colors.grey[500],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 到期提醒卡片（保单/存款/信用卡/贷款的未来 30 天到期项，含已逾期）
class _DueRemindersCard extends StatelessWidget {
  final List<DueItemInfo> items;

  /// 点击条目打开对应记录详情（null 时不可点击）
  final void Function(DueItemInfo item)? onOpenRecord;

  const _DueRemindersCard({required this.items, this.onOpenRecord});

  Color _urgencyColor(int days) {
    if (days < 0) return const Color(0xFFD32F2F); // 已逾期
    if (days <= 3) return const Color(0xFFE65100); // 3 天内
    if (days <= 7) return const Color(0xFFF57C00); // 一周内
    return const Color(0xFF1565C0); // 常规
  }

  String _daysLabel(int days) {
    if (days < 0) return '已逾期 ${-days} 天';
    if (days == 0) return '今天到期';
    return '剩 $days 天';
  }

  IconData _typeIcon(String type) {
    switch (type) {
      case 'deposit':
        return Icons.savings_outlined;
      case 'credit_card':
        return Icons.credit_card;
      case 'insurance':
        return Icons.verified_user_outlined;
      default:
        return Icons.account_balance_outlined; // 贷款类
    }
  }

  String _typeLabel(String type) {
    switch (type) {
      case 'deposit':
        return '存款';
      case 'credit_card':
        return '信用卡';
      case 'insurance':
        return '保单';
      case 'debt':
        return '其他负债';
      case 'mortgage':
        return '房贷';
      case 'car_loan':
        return '车贷';
      case 'personal_loan':
        return '个人借款';
      case 'private_loan':
        return '私人借款';
      default:
        return type;
    }
  }

  @override
  Widget build(BuildContext context) {
    const maxShow = 5;
    final shown = items.take(maxShow).toList();
    final overflow = items.length - shown.length;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text('到期提醒',
                    style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(width: 8),
                Text('(${items.length})',
                    style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
            const SizedBox(height: 8),
            ...shown.map((item) {
              final row = Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Icon(_typeIcon(item.assetType),
                        size: 20, color: _urgencyColor(item.remainingDays)),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                          Text(
                            '${_typeLabel(item.assetType)} · ${item.dueDate}',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color:
                            _urgencyColor(item.remainingDays).withAlpha(26),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        _daysLabel(item.remainingDays),
                        style: Theme.of(context)
                            .textTheme
                            .bodySmall
                            ?.copyWith(
                              color: _urgencyColor(item.remainingDays),
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                    ),
                    if (onOpenRecord != null)
                      Icon(Icons.chevron_right,
                          size: 18, color: Colors.grey[400]),
                  ],
                ),
              );

              if (onOpenRecord == null) return row;
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 0),
                child: InkWell(
                  onTap: () => onOpenRecord!(item),
                  borderRadius: BorderRadius.circular(8),
                  child: row,
                ),
              );
            }),
            if (overflow > 0)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text('还有 $overflow 项…',
                    style: Theme.of(context).textTheme.bodySmall),
              ),
          ],
        ),
      ),
    );
  }
}
