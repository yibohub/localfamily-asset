import 'package:flutter/foundation.dart';
import '../models/asset.dart';
import '../models/asset_change.dart';
import '../models/portfolio_summary.dart';
import '../core/ffi_bridge.dart';

/// 资产数据状态管理
class AssetProvider with ChangeNotifier {
  final List<Asset> _assets = [];
  final List<AssetChange> _assetChanges = [];
  final List<Asset> _searchResults = [];
  bool _isLoading = false;
  bool _isSearching = false;
  String? _error;
  final FfiBridge _ffi = FfiBridge();

  // 类型筛选状态
  AssetType? _assetTypeFilter;
  AssetType? _liabilityTypeFilter;

  List<Asset> get assets => List.unmodifiable(_assets);
  List<AssetChange> get assetChanges => List.unmodifiable(_assetChanges);
  List<Asset> get searchResults => List.unmodifiable(_searchResults);
  bool get isLoading => _isLoading;
  bool get isSearching => _isSearching;
  String? get error => _error;

  /// 获取仅资产（排除负债）
  List<Asset> get assetsOnly => _assets.where((a) => !a.type.isLiability).toList();

  /// 获取仅负债
  List<Asset> get liabilitiesOnly => _assets.where((a) => a.type.isLiability).toList();

  /// 获取筛选后的资产列表
  List<Asset> get filteredAssetsOnly {
    var assets = assetsOnly;
    if (_assetTypeFilter != null) {
      assets = assets.where((a) => a.type == _assetTypeFilter).toList();
    }
    return assets;
  }

  /// 获取筛选后的负债列表
  List<Asset> get filteredLiabilitiesOnly {
    var liabilities = liabilitiesOnly;
    if (_liabilityTypeFilter != null) {
      liabilities = liabilities.where((a) => a.type == _liabilityTypeFilter).toList();
    }
    return liabilities;
  }

  /// 获取当前资产类型筛选器
  AssetType? get assetTypeFilter => _assetTypeFilter;

  /// 获取当前负债类型筛选器
  AssetType? get liabilityTypeFilter => _liabilityTypeFilter;

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
        occurrenceDate: asset.occurrenceDate.toIso8601String().split('T')[0],
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
        occurrenceDate: asset.occurrenceDate.toIso8601String().split('T')[0],
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

  /// 加载所有审计日志
  Future<void> loadAssetChanges() async {
    try {
      final changesJson = await _ffi.getAssetChanges();

      _assetChanges.clear();
      for (final json in changesJson) {
        try {
          _assetChanges.add(AssetChange.fromJson(json));
        } catch (e) {
          debugPrint('解析审计日志失败: $e, JSON: $json');
        }
      }

      notifyListeners();
    } catch (e) {
      _error = '加载审计日志失败: $e';
      notifyListeners();
      debugPrint(_error);
    }
  }

  /// 加载指定资产的审计日志
  Future<void> loadAssetChangesByAssetId(String assetId) async {
    try {
      final changesJson = await _ffi.getAssetChangesByAssetId(assetId);

      _assetChanges.clear();
      for (final json in changesJson) {
        try {
          _assetChanges.add(AssetChange.fromJson(json));
        } catch (e) {
          debugPrint('解析审计日志失败: $e, JSON: $json');
        }
      }

      notifyListeners();
    } catch (e) {
      _error = '加载审计日志失败: $e';
      notifyListeners();
      debugPrint(_error);
    }
  }

  /// 按名称搜索资产
  Future<void> searchAssetsByName(String namePattern, {List<AssetType>? types}) async {
    if (namePattern.trim().isEmpty) {
      _searchResults.clear();
      _isSearching = false;
      notifyListeners();
      return;
    }

    _isSearching = true;
    notifyListeners();

    try {
      final typeFilter = types?.map((t) => t.value).toList();
      final assetsJson = await _ffi.searchAssetsByName(
        namePattern: namePattern,
        typeFilter: typeFilter,
      );

      _searchResults.clear();
      for (final json in assetsJson) {
        try {
          _searchResults.add(Asset.fromJson(json));
        } catch (e) {
          debugPrint('解析搜索结果失败: $e');
        }
      }

      _isSearching = false;
      notifyListeners();
    } catch (e) {
      _error = '搜索失败: $e';
      _isSearching = false;
      _searchResults.clear();
      notifyListeners();
    }
  }

  /// 按名称分组资产
  ///
  /// [types] 可选的类型过滤器
  /// 返回 Map<资产名称, List<资产>>
  Map<String, List<Asset>> groupAssetsByName({List<AssetType>? types}) {
    final filtered = types != null
        ? _assets.where((a) => types.contains(a.type))
        : _assets;

    final grouped = <String, List<Asset>>{};
    for (final asset in filtered) {
      grouped.putIfAbsent(asset.name, () => []).add(asset);
    }
    return grouped;
  }

  /// 清除搜索结果
  void clearSearch() {
    _searchResults.clear();
    _isSearching = false;
    notifyListeners();
  }

  /// 设置资产类型筛选器
  void setAssetTypeFilter(AssetType? type) {
    _assetTypeFilter = type;
    notifyListeners();
  }

  /// 设置负债类型筛选器
  void setLiabilityTypeFilter(AssetType? type) {
    _liabilityTypeFilter = type;
    notifyListeners();
  }

  /// 清除资产类型筛选器
  void clearAssetTypeFilter() {
    _assetTypeFilter = null;
    notifyListeners();
  }

  /// 清除负债类型筛选器
  void clearLiabilityTypeFilter() {
    _liabilityTypeFilter = null;
    notifyListeners();
  }
}
