import 'package:flutter/foundation.dart';
import '../models/asset.dart';
import '../models/portfolio_summary.dart';
import '../core/ffi_bridge.dart';

/// 资产数据状态管理
class AssetProvider with ChangeNotifier {
  final List<Asset> _assets = [];
  bool _isLoading = false;
  String? _error;
  final FfiBridge _ffi = FfiBridge();

  List<Asset> get assets => List.unmodifiable(_assets);
  bool get isLoading => _isLoading;
  String? get error => _error;

  /// 获取投资组合摘要
  PortfolioSummary get summary {
    final breakdown = <AssetType, double>{};
    double totalAssets = 0;
    double totalLiabilities = 0;

    for (final asset in _assets) {
      final value = breakdown[asset.type] ?? 0;
      breakdown[asset.type] = value + asset.amount;

      if (asset.type.isLiability) {
        totalLiabilities += asset.amount;
      } else {
        totalAssets += asset.amount;
      }
    }

    return PortfolioSummary(
      totalAssets: totalAssets,
      totalLiabilities: totalLiabilities,
      netAssets: totalAssets - totalLiabilities,
      breakdown: breakdown,
      lastUpdated: DateTime.now(),
    );
  }

  /// 按类型获取资产
  List<Asset> getAssetsByType(AssetType type) {
    return _assets.where((asset) => asset.type == type).toList();
  }

  /// 获取单个资产
  Asset? getAssetById(String id) {
    try {
      return _assets.firstWhere((asset) => asset.id == id);
    } catch (e) {
      return null;
    }
  }

  /// 加载所有资产
  Future<void> loadAssets() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      // 调用 Rust Core 加载数据
      final assetsJson = await _ffi.getAllAssets();

      _assets.clear();
      for (final json in assetsJson) {
        try {
          _assets.add(Asset.fromJson(json));
        } catch (e) {
          debugPrint('解析资产失败: $e, JSON: $json');
        }
      }

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = '加载资产失败: $e';
      _isLoading = false;
      notifyListeners();
      debugPrint(_error);
    }
  }

  /// 添加资产
  Future<bool> addAsset(Asset asset) async {
    try {
      final success = await _ffi.addAsset(
        name: asset.name,
        assetType: asset.type.value,
        amount: asset.amount,
        currency: asset.currency,
        symbol: asset.account,
        notes: asset.note,
      );

      if (success) {
        // 重新加载资产列表
        await loadAssets();
        return true;
      }
      return false;
    } catch (e) {
      _error = '添加资产失败: $e';
      notifyListeners();
      debugPrint(_error);
      return false;
    }
  }

  /// 更新资产
  Future<bool> updateAsset(Asset asset) async {
    try {
      final success = await _ffi.updateAsset(
        id: asset.id,
        name: asset.name,
        assetType: asset.type.value,
        amount: asset.amount,
        currency: asset.currency,
        symbol: asset.account,
        notes: asset.note,
      );

      if (success) {
        // 重新加载资产列表
        await loadAssets();
        return true;
      }
      return false;
    } catch (e) {
      _error = '更新资产失败: $e';
      notifyListeners();
      debugPrint(_error);
      return false;
    }
  }

  /// 删除资产
  Future<bool> deleteAsset(String id) async {
    try {
      final success = await _ffi.deleteAsset(id);

      if (success) {
        _assets.removeWhere((a) => a.id == id);
        notifyListeners();
        return true;
      }
      return false;
    } catch (e) {
      _error = '删除资产失败: $e';
      notifyListeners();
      debugPrint(_error);
      return false;
    }
  }

  /// 清除错误
  void clearError() {
    _error = null;
    notifyListeners();
  }
}
