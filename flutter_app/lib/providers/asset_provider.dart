import 'package:flutter/foundation.dart';
import '../models/asset.dart';
import '../models/portfolio_summary.dart';

/// 资产数据状态管理
class AssetProvider with ChangeNotifier {
  final List<Asset> _assets = [];
  bool _isLoading = false;
  String? _error;

  List<Asset> get assets => List.unmodifiable(_assets);
  bool get isLoading => _isLoading;
  String? get error => _error;

  /// 获取投资组合摘要
  PortfolioSummary get summary {
    final breakdown = <AssetType, double>{};
    double total = 0;

    for (final asset in _assets) {
      final value = breakdown[asset.type] ?? 0;
      breakdown[asset.type] = value + asset.amount;
      total += asset.amount;
    }

    return PortfolioSummary(
      totalValue: total,
      breakdown: breakdown,
      lastUpdated: DateTime.now(),
    );
  }

  /// 加载所有资产
  Future<void> loadAssets() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      // TODO: 调用 Rust Core 加载数据
      // 暂时使用模拟数据
      await Future.delayed(const Duration(milliseconds: 500));

      _assets.clear();
      _assets.addAll(_demoAssets);
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
    }
  }

  /// 添加资产
  Future<bool> addAsset(Asset asset) async {
    try {
      // TODO: 调用 Rust Core 保存数据
      _assets.add(asset);
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  /// 更新资产
  Future<bool> updateAsset(Asset asset) async {
    try {
      final index = _assets.indexWhere((a) => a.id == asset.id);
      if (index >= 0) {
        // TODO: 调用 Rust Core 更新数据
        _assets[index] = asset;
        notifyListeners();
        return true;
      }
      return false;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  /// 删除资产
  Future<bool> deleteAsset(String id) async {
    try {
      // TODO: 调用 Rust Core 删除数据
      _assets.removeWhere((a) => a.id == id);
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  /// 导出加密数据
  Future<String?> exportData(String password) async {
    try {
      // TODO: 调用 Rust Core 导出
      return '/storage/export/backup_${DateTime.now().millisecondsSinceEpoch}.zip';
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return null;
    }
  }

  /// 导入加密数据
  Future<bool> importData(String filePath, String password) async {
    try {
      // TODO: 调用 Rust Core 导入
      await loadAssets();
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  /// Demo 数据
  static List<Asset> get _demoAssets => [
        Asset(
          id: '1',
          name: '伯克希尔哈撒韦 A 类',
          type: AssetType.stock,
          amount: 150000,
          currency: 'USD',
          symbol: 'BRK.A',
          createdAt: DateTime.now().subtract(const Duration(days: 365)),
          updatedAt: DateTime.now(),
        ),
        Asset(
          id: '2',
          name: '现金储备',
          type: AssetType.cash,
          amount: 50000,
          currency: 'USD',
          createdAt: DateTime.now().subtract(const Duration(days: 180)),
          updatedAt: DateTime.now(),
        ),
        Asset(
          id: '3',
          name: '美国国债',
          type: AssetType.bond,
          amount: 100000,
          currency: 'USD',
          createdAt: DateTime.now().subtract(const Duration(days: 90)),
          updatedAt: DateTime.now(),
        ),
      ];
}
