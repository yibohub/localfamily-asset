import 'asset.dart';

/// 投资组合摘要
class PortfolioSummary {
  final double totalAssets;      // 总资产
  final double totalLiabilities; // 总负债
  final double netAssets;        // 净资产 = totalAssets - totalLiabilities
  final Map<String, double> breakdown; // 改为 String 类型，支持自定义类型
  final DateTime lastUpdated;

  PortfolioSummary({
    required this.totalAssets,
    required this.totalLiabilities,
    required this.netAssets,
    required this.breakdown,
    required this.lastUpdated,
  });

  /// 获取指定类型的占比（相对于总资产）
  double getPercentage(String typeId) {
    if (totalAssets == 0) return 0;
    return (breakdown[typeId] ?? 0) / totalAssets * 100;
  }

  /// 获取指定内置类型的占比（向后兼容）
  double getPercentageByType(AssetType type) {
    return getPercentage(type.name);
  }

  /// 获取负债占比（相对于总资产）
  double get liabilityRatio {
    if (totalAssets == 0) return 0;
    return (totalLiabilities / totalAssets * 100);
  }
}
