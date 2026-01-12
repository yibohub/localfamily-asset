import 'asset.dart';

/// 投资组合摘要
class PortfolioSummary {
  final double totalValue;
  final Map<AssetType, double> breakdown;
  final DateTime lastUpdated;

  PortfolioSummary({
    required this.totalValue,
    required this.breakdown,
    required this.lastUpdated,
  });

  /// 获取指定类型的占比
  double getPercentage(AssetType type) {
    if (totalValue == 0) return 0;
    return (breakdown[type] ?? 0) / totalValue * 100;
  }
}
