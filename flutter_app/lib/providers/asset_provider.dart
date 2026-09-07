import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import '../models/asset.dart';
import '../models/asset_change.dart';
import '../models/custom_asset_type.dart';
import '../models/portfolio_summary.dart';
import '../core/ffi_bridge.dart';

/// 文件日志（仅桌面端可用；移动端忽略——避免硬编码 Windows 路径）
Future<void> _logToFile(String message) async {
  if (!Platform.isWindows && !Platform.isLinux && !Platform.isMacOS) return;
  try {
    final home = Platform.environment['USERPROFILE'] ??
        Platform.environment['HOME'] ??
        '.';
    final file = File(
        '$home${Platform.pathSeparator}Documents${Platform.pathSeparator}localfamily_asset_dart.log');
    final sink = file.openWrite(mode: FileMode.append);
    final timestamp = DateTime.now().toIso8601String();
    sink.writeln('[$timestamp] $message');
    await sink.flush();
    await sink.close();
  } catch (e) {
    // 忽略日志错误
  }
}

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
  String? _assetTypeFilterId; // 支持自定义类型 ID (格式: "custom_xxx")
  String? _liabilityTypeFilterId; // 支持自定义类型 ID (格式: "custom_xxx")

  List<Asset> get assets => List.unmodifiable(_assets);
  List<AssetChange> get assetChanges => List.unmodifiable(_assetChanges);
  List<Asset> get searchResults => List.unmodifiable(_searchResults);
  bool get isLoading => _isLoading;
  bool get isSearching => _isSearching;
  String? get error => _error;

  /// 获取仅资产（排除负债）- 仅包含内置类型
  @deprecated
  List<Asset> get assetsOnly => _assets.where((a) {
    final builtInType = AssetTypeExtension.fromString(a.type);
    return builtInType != null && !builtInType.isLiability;
  }).toList();

  /// 获取仅负债 - 仅包含内置类型
  @deprecated
  List<Asset> get liabilitiesOnly => _assets.where((a) {
    final builtInType = AssetTypeExtension.fromString(a.type);
    if (builtInType != null) {
      return builtInType.isLiability;
    }
    // 自定义类型暂时排除，需要通过 getAssetsOnly/getLiabilitiesOnly 方法
    return false;
  }).toList();

  /// 获取仅资产（排除负债）- 支持自定义类型
  List<Asset> getAssetsOnly(List<CustomAssetType> customTypes) {
    return _assets.where((a) {
      // 检查是否为内置资产类型
      final builtInType = AssetTypeExtension.fromString(a.type);
      if (builtInType != null) {
        return !builtInType.isLiability;
      }
      // 检查是否为自定义资产类型（非负债）
      final customType = customTypes.cast<CustomAssetType?>().firstWhere(
        (t) => t?.id == a.type,
        orElse: () => null,
      );
      return customType != null && !customType.isLiability;
    }).toList();
  }

  /// 获取仅负债 - 支持自定义类型
  List<Asset> getLiabilitiesOnly(List<CustomAssetType> customTypes) {
    return _assets.where((a) {
      // 检查是否为内置负债类型
      final builtInType = AssetTypeExtension.fromString(a.type);
      if (builtInType != null) {
        return builtInType.isLiability;
      }
      // 检查是否为自定义负债类型
      final customType = customTypes.cast<CustomAssetType?>().firstWhere(
        (t) => t?.id == a.type,
        orElse: () => null,
      );
      return customType?.isLiability ?? false;
    }).toList();
  }

  /// 获取筛选后的资产列表
  List<Asset> get filteredAssetsOnly {
    var assets = assetsOnly;
    // 同时检查字符串 ID 和枚举筛选器
    if (_assetTypeFilterId != null) {
      assets = assets.where((a) => a.type == _assetTypeFilterId).toList();
    } else if (_assetTypeFilter != null) {
      assets = assets.where((a) => a.type == _assetTypeFilter!.snakeCaseName).toList();
    }
    return assets;
  }

  /// 获取筛选后的负债列表
  List<Asset> get filteredLiabilitiesOnly {
    var liabilities = liabilitiesOnly;
    // 同时检查字符串 ID 和枚举筛选器
    if (_liabilityTypeFilterId != null) {
      liabilities = liabilities.where((a) => a.type == _liabilityTypeFilterId).toList();
    } else if (_liabilityTypeFilter != null) {
      liabilities = liabilities.where((a) => a.type == _liabilityTypeFilter!.snakeCaseName).toList();
    }
    return liabilities;
  }

  /// 获取筛选后的资产列表（支持自定义类型）
  List<Asset> getFilteredAssetsOnly(List<CustomAssetType> customTypes) {
    var assets = getAssetsOnly(customTypes);
    // 同时检查字符串 ID 和枚举筛选器
    if (_assetTypeFilterId != null) {
      assets = assets.where((a) => a.type == _assetTypeFilterId).toList();
    } else if (_assetTypeFilter != null) {
      assets = assets.where((a) => a.type == _assetTypeFilter!.snakeCaseName).toList();
    }
    return assets;
  }

  /// 获取筛选后的负债列表（支持自定义类型）
  List<Asset> getFilteredLiabilitiesOnly(List<CustomAssetType> customTypes) {
    var liabilities = getLiabilitiesOnly(customTypes);
    // 同时检查字符串 ID 和枚举筛选器
    if (_liabilityTypeFilterId != null) {
      liabilities = liabilities.where((a) => a.type == _liabilityTypeFilterId).toList();
    } else if (_liabilityTypeFilter != null) {
      liabilities = liabilities.where((a) => a.type == _liabilityTypeFilter!.snakeCaseName).toList();
    }
    return liabilities;
  }

  /// 获取当前资产类型筛选器（枚举）
  AssetType? get assetTypeFilter => _assetTypeFilter;

  /// 获取当前负债类型筛选器（枚举）
  AssetType? get liabilityTypeFilter => _liabilityTypeFilter;

  /// 获取当前资产类型筛选器 ID（支持自定义类型）
  String? get assetTypeFilterId => _assetTypeFilterId ?? _assetTypeFilter?.name;

  /// 获取当前负债类型筛选器 ID（支持自定义类型）
  String? get liabilityTypeFilterId => _liabilityTypeFilterId ?? _liabilityTypeFilter?.name;

  /// 获取投资组合摘要
  PortfolioSummary get summary {
    final breakdown = <String, double>{};
    double totalAssets = 0;
    double totalLiabilities = 0;

    for (final asset in _assets) {
      final value = breakdown[asset.type] ?? 0;
      breakdown[asset.type] = value + asset.amount;

      final builtInType = AssetTypeExtension.fromString(asset.type);
      if (builtInType != null && builtInType.isLiability) {
        totalLiabilities += asset.amount;
      } else if (builtInType != null) {
        // 内置资产类型
        totalAssets += asset.amount;
      } else {
        // 自定义类型 - 暂时假设为资产类型（需要调用方传入 customTypes 更精确判断）
        // 注意：这里使用简化的判断逻辑，因为 summary 是同步 getter
        // 如果需要精确判断，应该使用新的 getSummaryWithCustomTypes 方法
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

  /// 获取投资组合摘要（支持自定义类型精确判断）
  PortfolioSummary getSummaryWithCustomTypes(List<CustomAssetType> customTypes) {
    final breakdown = <String, double>{};
    double totalAssets = 0;
    double totalLiabilities = 0;

    for (final asset in _assets) {
      final value = breakdown[asset.type] ?? 0;
      breakdown[asset.type] = value + asset.amount;

      final builtInType = AssetTypeExtension.fromString(asset.type);
      if (builtInType != null) {
        // 内置类型
        if (builtInType.isLiability) {
          totalLiabilities += asset.amount;
        } else {
          totalAssets += asset.amount;
        }
      } else {
        // 自定义类型 - 根据 CustomAssetType 判断
        final customType = customTypes.cast<CustomAssetType?>().firstWhere(
          (t) => t?.id == asset.type,
          orElse: () => null,
        );
        if (customType?.isLiability ?? false) {
          totalLiabilities += asset.amount;
        } else {
          totalAssets += asset.amount;
        }
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

  /// 按类型获取资产（支持字符串类型）
  List<Asset> getAssetsByType(String typeId) {
    return _assets.where((asset) => asset.type == typeId).toList();
  }

  /// 按内置类型获取资产（向后兼容）
  List<Asset> getAssetsByBuiltInType(AssetType type) {
    return getAssetsByType(type.name);
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
          await _logToFile('解析资产失败: $e, JSON: $json');
        }
      }

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = '加载资产失败: $e';
      _isLoading = false;
      notifyListeners();
      debugPrint(_error);
      await _logToFile('错误: $_error');
    }
  }

  /// 添加资产
  Future<bool> addAsset(Asset asset) async {
    try {
      final logMsg = '===== AssetProvider.addAsset 开始 =====\n资产名称: ${asset.name}\n买入价: ${asset.buyPrice}\n现价: ${asset.currentPrice}';
      debugPrint(logMsg);
      await _logToFile(logMsg);

      // 将 tags 转换为 JSON 字符串
      final tagsJson = asset.tags != null
          ? jsonEncode(asset.tags)
          : null;

      final success = await _ffi.addAssetWithType(
        name: asset.name,
        assetType: asset.type, // 直接使用字符串类型
        amount: asset.amount,
        currency: asset.currency,
        symbol: asset.account,
        notes: asset.note,
        occurrenceDate: asset.occurrenceDate.toIso8601String().split('T')[0],
        buyPrice: asset.buyPrice,
        currentPrice: asset.currentPrice,
        tagsJson: tagsJson,
      );

      await _logToFile('FFI 调用结果: $success');

      if (success) {
        await _logToFile('===== AssetProvider.addAsset 结束（成功）=====\n');
      } else {
        await _logToFile('===== AssetProvider.addAsset 结束（失败）=====\n');
      }

      debugPrint('FFI 调用结果: $success');
      debugPrint('===== AssetProvider.addAsset 结束 =====');

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
      // 将 tags 转换为 JSON 字符串
      final tagsJson = asset.tags != null
          ? jsonEncode(asset.tags)
          : null;

      final success = await _ffi.updateAssetWithType(
        id: asset.id,
        name: asset.name,
        assetType: asset.type, // 直接使用字符串类型
        amount: asset.amount,
        currency: asset.currency,
        symbol: asset.account,
        notes: asset.note,
        occurrenceDate: asset.occurrenceDate.toIso8601String().split('T')[0],
        buyPrice: asset.buyPrice,
        currentPrice: asset.currentPrice,
        tagsJson: tagsJson,
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

  /// 清空明文数据缓存（退出账户时调用）
  void clear() {
    _assets.clear();
    _assetChanges.clear();
    _searchResults.clear();
    _isSearching = false;
    _assetTypeFilter = null;
    _liabilityTypeFilter = null;
    _assetTypeFilterId = null;
    _liabilityTypeFilterId = null;
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
      // 在内存中搜索，因为现在使用字符串类型，而 FFI 仍使用整型类型
      final results = <Asset>[];
      for (final asset in _assets) {
        // 检查名称是否匹配
        if (!asset.name.toLowerCase().contains(namePattern.toLowerCase())) {
          continue;
        }

        // 如果有类型过滤，检查类型是否匹配
        if (types != null && types.isNotEmpty) {
          final builtInType = AssetTypeExtension.fromString(asset.type);
          if (builtInType == null || !types.contains(builtInType)) {
            continue;
          }
        }

        results.add(asset);
      }

      _searchResults.clear();
      _searchResults.addAll(results);

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
  /// [typeIds] 可选的类型 ID 过滤器（支持内置类型名称和自定义类型 ID）
  /// 返回 Map<资产名称, List<资产>>
  Map<String, List<Asset>> groupAssetsByName({List<String>? typeIds}) {
    final filtered = typeIds != null
        ? _assets.where((a) => typeIds.contains(a.type))
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

  /// 设置资产类型筛选器（支持字符串 ID）
  void setAssetTypeFilterById(String? typeId) {
    if (typeId == null) {
      _assetTypeFilter = null;
      _assetTypeFilterId = null;
    } else if (typeId.startsWith('custom_')) {
      // 自定义类型
      _assetTypeFilter = null;
      _assetTypeFilterId = typeId;
    } else {
      // 内置类型
      _assetTypeFilter = AssetTypeExtension.fromString(typeId);
      _assetTypeFilterId = null;
    }
    notifyListeners();
  }

  /// 设置负债类型筛选器（支持字符串 ID）
  void setLiabilityTypeFilterById(String? typeId) {
    if (typeId == null) {
      _liabilityTypeFilter = null;
      _liabilityTypeFilterId = null;
    } else if (typeId.startsWith('custom_')) {
      // 自定义类型
      _liabilityTypeFilter = null;
      _liabilityTypeFilterId = typeId;
    } else {
      // 内置类型
      _liabilityTypeFilter = AssetTypeExtension.fromString(typeId);
      _liabilityTypeFilterId = null;
    }
    notifyListeners();
  }

  /// 设置资产类型筛选器（旧版本兼容）
  void setAssetTypeFilter(AssetType? type) {
    _assetTypeFilter = type;
    _assetTypeFilterId = null;
    notifyListeners();
  }

  /// 设置负债类型筛选器（旧版本兼容）
  void setLiabilityTypeFilter(AssetType? type) {
    _liabilityTypeFilter = type;
    _liabilityTypeFilterId = null;
    notifyListeners();
  }

  /// 清除资产类型筛选器
  void clearAssetTypeFilter() {
    _assetTypeFilter = null;
    _assetTypeFilterId = null;
    notifyListeners();
  }

  /// 清除负债类型筛选器
  void clearLiabilityTypeFilter() {
    _liabilityTypeFilter = null;
    _liabilityTypeFilterId = null;
    notifyListeners();
  }
}
