import 'asset.dart';

/// 投资组合摘要
class PortfolioSummary {
  final double totalAssets;      // 总资产
  final double totalLiabilities; // 总负债
  final double netAssets;        // 净资产 = totalAssets - totalLiabilities
  final Map<AssetType, double> breakdown;
  final DateTime lastUpdated;

  PortfolioSummary({
    required this.totalAssets,
    required this.totalLiabilities,
    required this.netAssets,
    required this.breakdown,
    required this.lastUpdated,
  });

  /// 获取指定类型的占比（相对于总资产）
  double getPercentage(AssetType type) {
    if (totalAssets == 0) return 0;
    return (breakdown[type] ?? 0) / totalAssets * 100;
  }

  /// 获取负债占比（相对于总资产）
  double get liabilityRatio {
    if (totalAssets == 0) return 0;
    return (totalLiabilities / totalAssets * 100);
  }
}
