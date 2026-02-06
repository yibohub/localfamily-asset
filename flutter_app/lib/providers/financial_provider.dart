/// 金融记录状态管理（资产/负债分离模型）
///
/// 使用 financial_models.dart 中定义的 Asset 和 Liability 类

import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../core/ffi_bridge.dart';
import '../models/financial_models.dart';
import '../models/custom_asset_type.dart';

/// 金融记录状态管理
class FinancialProvider with ChangeNotifier {
  final FfiBridge _ffi = FfiBridge();

  // 资产列表（仅资产类型）
  List<Asset> _assets = [];

  // 负债列表
  List<Liability> _liabilities = [];

  // 自定义类型列表
  List<CustomAssetType> _customAssetTypes = [];

  // 负债类型筛选器（支持自定义类型 ID，格式: "custom_xxx"）
  String? _liabilityTypeFilterId;

  // 搜索结果
  final List<Asset> _assetSearchResults = [];
  final List<Liability> _liabilitySearchResults = [];
  bool _isSearching = false;

  // 加载状态
  bool _isLoading = false;
  String? _errorMessage;

  // Getters
  List<Asset> get assets => _assets;
  List<Liability> get liabilities => _liabilities;
  List<CustomAssetType> get customAssetTypes => _customAssetTypes;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  String? get liabilityTypeFilterId => _liabilityTypeFilterId;
  List<Asset> get assetSearchResults => _assetSearchResults;
  List<Liability> get liabilitySearchResults => _liabilitySearchResults;
  bool get isSearching => _isSearching;

  /// 获取自定义资产类型（不包括负债）
  List<CustomAssetType> get customAssetTypesOnly {
    return _customAssetTypes.where((t) => !t.isLiability).toList();
  }

  /// 获取自定义负债类型
  List<CustomAssetType> get customLiabilityTypes {
    return _customAssetTypes.where((t) => t.isLiability).toList();
  }

  /// 获取筛选后的负债列表
  List<Liability> get filteredLiabilities {
    if (_liabilityTypeFilterId == null) return _liabilities;
    return _liabilities.where((l) => l.type.snakeCaseName == _liabilityTypeFilterId).toList();
  }

  /// 计算总资产
  double get totalAssets => _assets.fold(0.0, (sum, asset) => sum + asset.amount);

  /// 计算总负债
  double get totalLiabilities => _liabilities.fold(0.0, (sum, liability) => sum + liability.amount);

  /// 计算净资产
  double get netAssets => totalAssets - totalLiabilities;

  /// 计算投资类资产总成本
  double? get totalInvestmentCost {
    double totalCost = 0.0;
    int count = 0;
    for (var asset in _assets) {
      if (asset.isInvestment && asset.buyPrice != null && asset.quantity != null) {
        totalCost += asset.buyPrice! * asset.quantity!;
        count++;
      }
    }
    return count > 0 ? totalCost : null;
  }

  /// 计算投资类资产总盈亏
  double? get totalInvestmentProfitLoss {
    double totalProfitLoss = 0.0;
    int count = 0;
    for (var asset in _assets) {
      if (asset.isInvestment && asset.profitLossAmount != null) {
        totalProfitLoss += asset.profitLossAmount!;
        count++;
      }
    }
    return count > 0 ? totalProfitLoss : null;
  }

  /// 按类型分组资产
  Map<String, List<Asset>> get assetsByType {
    final grouped = <String, List<Asset>>{};
    for (var asset in _assets) {
      final typeName = asset.type.name;
      grouped.putIfAbsent(typeName, () => []).add(asset);
    }
    return grouped;
  }

  /// 按类型分组负债
  Map<String, List<Liability>> get liabilitiesByType {
    final grouped = <String, List<Liability>>{};
    for (var liability in _liabilities) {
      final typeName = liability.type.name;
      grouped.putIfAbsent(typeName, () => []).add(liability);
    }
    return grouped;
  }

  /// 加载所有金融记录
  Future<bool> loadFinancialRecords() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      // 并行加载资产、负债和自定义类型
      final results = await Future.wait([
        _loadAssets(),
        _loadLiabilities(),
        _loadCustomTypes(),
      ]);

      final success = results.every((r) => r);
      _isLoading = false;
      notifyListeners();
      return success;
    } catch (e) {
      _errorMessage = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// 加载自定义类型
  Future<bool> _loadCustomTypes() async {
    try {
      final types = await _ffi.getCustomAssetTypes();
      _customAssetTypes = types.map((json) {
        return CustomAssetType.fromJson(json);
      }).toList();
      return true;
    } catch (e) {
      debugPrint('加载自定义类型失败: $e');
      _customAssetTypes = [];
      return false;
    }
  }

  /// 加载资产
  Future<bool> _loadAssets() async {
    try {
      final jsonStr = await _ffi.getAssetsOnly();
      debugPrint('_loadAssets: 收到数据，长度: ${jsonStr.length}');
      if (jsonStr.isEmpty) {
        _assets = [];
        debugPrint('_loadAssets: 数据为空，返回空数组');
        return true;
      }

      final List<dynamic> jsonList = json.decode(jsonStr);
      _assets = jsonList.map((json) {
        final map = json as Map<String, dynamic>;
        return Asset.fromJson(map);
      }).toList();

      debugPrint('_loadAssets: 成功加载 ${_assets.length} 个资产');
      return true;
    } catch (e) {
      debugPrint('_loadAssets: 加载资产失败: $e');
      _assets = [];
      return false;
    }
  }

  /// 加载负债
  Future<bool> _loadLiabilities() async {
    try {
      final jsonStr = await _ffi.getLiabilitiesOnly();
      if (jsonStr.isEmpty) {
        _liabilities = [];
        return true;
      }

      final List<dynamic> jsonList = json.decode(jsonStr);
      _liabilities = jsonList.map((json) {
        final map = json as Map<String, dynamic>;
        return Liability.fromJson(map);
      }).toList();

      return true;
    } catch (e) {
      debugPrint('加载负债失败: $e');
      _liabilities = [];
      return false;
    }
  }

  /// 添加资产
  Future<bool> addAsset(Asset asset) async {
    _isLoading = true;
    notifyListeners();

    try {
      // 构建扩展字段 JSON
      final extraFields = <String, dynamic>{};

      // 通用字段
      if (asset.account != null) extraFields['account'] = asset.account;
      if (asset.tags != null) extraFields['tags'] = asset.tags;

      // 投资类字段
      if (asset.buyPrice != null) extraFields['buy_price'] = asset.buyPrice;
      if (asset.currentPrice != null) extraFields['current_price'] = asset.currentPrice;
      if (asset.code != null) extraFields['code'] = asset.code;
      if (asset.exchange != null) extraFields['exchange'] = asset.exchange;

      // 房产字段
      if (asset.address != null) extraFields['address'] = asset.address;
      if (asset.buildingArea != null) extraFields['building_area'] = asset.buildingArea;
      if (asset.livingArea != null) extraFields['living_area'] = asset.livingArea;
      if (asset.propertyType != null) extraFields['property_type'] = asset.propertyType;
      if (asset.rooms != null) extraFields['rooms'] = asset.rooms;
      if (asset.floor != null) extraFields['floor'] = asset.floor;
      if (asset.buildYear != null) extraFields['build_year'] = asset.buildYear;
      if (asset.ownershipType != null) extraFields['ownership_type'] = asset.ownershipType;
      if (asset.deedNumber != null) extraFields['deed_number'] = asset.deedNumber;

      // 存款字段
      if (asset.depositAccountType != null) extraFields['deposit_account_type'] = asset.depositAccountType;
      if (asset.depositPeriod != null) extraFields['deposit_period'] = asset.depositPeriod;
      if (asset.maturityDate != null) extraFields['maturity_date'] = asset.maturityDate!.toIso8601String().split('T')[0];
      if (asset.depositInterestRate != null) extraFields['deposit_interest_rate'] = asset.depositInterestRate;

      // 保单字段
      if (asset.policyNumber != null) extraFields['policy_number'] = asset.policyNumber;
      if (asset.insuranceType != null) extraFields['insurance_type'] = asset.insuranceType;
      if (asset.insured != null) extraFields['insured'] = asset.insured;
      if (asset.beneficiary != null) extraFields['beneficiary'] = asset.beneficiary;
      if (asset.coverageAmount != null) extraFields['coverage_amount'] = asset.coverageAmount;
      if (asset.premium != null) extraFields['premium'] = asset.premium;
      if (asset.premiumPeriod != null) extraFields['premium_period'] = asset.premiumPeriod;
      if (asset.coveragePeriod != null) extraFields['coverage_period'] = asset.coveragePeriod;
      if (asset.insurer != null) extraFields['insurer'] = asset.insurer;

      final extraFieldsJson = extraFields.isNotEmpty ? json.encode(extraFields) : null;

      final success = await _ffi.addAssetWithExtraFields(
        name: asset.name,
        assetType: asset.type.name,
        amount: asset.amount,
        currency: asset.currency,
        occurrenceDate: asset.occurrenceDate.toIso8601String().split('T')[0],
        extraFieldsJson: extraFieldsJson,
        note: asset.note,
      );

      if (success) {
        // 立即保存数据库到磁盘
        await _ffi.saveDatabase();
        await _loadAssets();
      }

      _isLoading = false;
      notifyListeners();
      return success;
    } catch (e) {
      debugPrint('添加资产失败: $e');
      _errorMessage = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// 添加负债
  Future<bool> addLiability(Liability liability) async {
    _isLoading = true;
    notifyListeners();

    try {
      // 构建扩展字段 JSON
      final extraFields = <String, dynamic>{};

      // 贷款类通用字段
      if (liability.lender != null) extraFields['lender'] = liability.lender;
      if (liability.dueDate != null) extraFields['due_date'] = liability.dueDate!.toIso8601String();
      if (liability.interestRate != null) extraFields['interest_rate'] = liability.interestRate;
      if (liability.repaymentMethod != null) extraFields['repayment_method'] = liability.repaymentMethod!.value;
      if (liability.loanTerm != null) extraFields['loan_term'] = liability.loanTerm;

      // 信用卡字段
      if (liability.lastFourDigits != null) extraFields['last_four_digits'] = liability.lastFourDigits;
      if (liability.billingDate != null) extraFields['billing_date'] = liability.billingDate!.toIso8601String();
      if (liability.paymentDueDate != null) extraFields['payment_due_date'] = liability.paymentDueDate!.toIso8601String();
      if (liability.creditLimit != null) extraFields['credit_limit'] = liability.creditLimit;
      if (liability.cashLimit != null) extraFields['cash_limit'] = liability.cashLimit;
      if (liability.annualFee != null) extraFields['annual_fee'] = liability.annualFee;
      if (liability.issuer != null) extraFields['issuer'] = liability.issuer;

      // 房贷专属字段
      if (liability.propertyAddress != null) extraFields['property_address'] = liability.propertyAddress;
      if (liability.originalLoanAmount != null) extraFields['original_loan_amount'] = liability.originalLoanAmount;
      if (liability.remainingPrincipal != null) extraFields['remaining_principal'] = liability.remainingPrincipal;
      if (liability.loanType != null) extraFields['loan_type'] = liability.loanType;

      // 车贷专属字段
      if (liability.vehicleBrand != null) extraFields['vehicle_brand'] = liability.vehicleBrand;
      if (liability.vehicleModel != null) extraFields['vehicle_model'] = liability.vehicleModel;
      if (liability.licensePlate != null) extraFields['license_plate'] = liability.licensePlate;

      // 个人/私人借款专属字段
      if (liability.purpose != null) extraFields['purpose'] = liability.purpose;
      if (liability.hasInterest != null) extraFields['has_interest'] = liability.hasInterest;
      if (liability.repaymentPlan != null) extraFields['repayment_plan'] = liability.repaymentPlan;

      final extraFieldsJson = extraFields.isNotEmpty ? json.encode(extraFields) : null;

      final success = await _ffi.addLiabilityWithExtraFields(
        name: liability.name,
        liabilityType: liability.type.snakeCaseName,
        amount: liability.amount,
        currency: liability.currency,
        occurrenceDate: liability.occurrenceDate.toIso8601String().split('T')[0],
        extraFieldsJson: extraFieldsJson,
        note: liability.note,
      );

      if (success) {
        await _loadLiabilities();
      }

      _isLoading = false;
      notifyListeners();
      return success;
    } catch (e) {
      debugPrint('添加负债失败: $e');
      _errorMessage = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// 更新资产
  Future<bool> updateAsset(Asset asset) async {
    _isLoading = true;
    notifyListeners();

    try {
      // 构建扩展字段 JSON
      final extraFields = <String, dynamic>{};

      // 通用字段
      if (asset.account != null) extraFields['account'] = asset.account;
      if (asset.tags != null) extraFields['tags'] = asset.tags;

      // 投资类字段
      if (asset.buyPrice != null) extraFields['buy_price'] = asset.buyPrice;
      if (asset.currentPrice != null) extraFields['current_price'] = asset.currentPrice;
      if (asset.code != null) extraFields['code'] = asset.code;
      if (asset.exchange != null) extraFields['exchange'] = asset.exchange;

      // 房产字段
      if (asset.address != null) extraFields['address'] = asset.address;
      if (asset.buildingArea != null) extraFields['building_area'] = asset.buildingArea;
      if (asset.livingArea != null) extraFields['living_area'] = asset.livingArea;
      if (asset.propertyType != null) extraFields['property_type'] = asset.propertyType;
      if (asset.rooms != null) extraFields['rooms'] = asset.rooms;
      if (asset.floor != null) extraFields['floor'] = asset.floor;
      if (asset.buildYear != null) extraFields['build_year'] = asset.buildYear;
      if (asset.ownershipType != null) extraFields['ownership_type'] = asset.ownershipType;
      if (asset.deedNumber != null) extraFields['deed_number'] = asset.deedNumber;

      // 存款字段
      if (asset.depositAccountType != null) extraFields['deposit_account_type'] = asset.depositAccountType;
      if (asset.depositPeriod != null) extraFields['deposit_period'] = asset.depositPeriod;
      if (asset.maturityDate != null) extraFields['maturity_date'] = asset.maturityDate!.toIso8601String().split('T')[0];
      if (asset.depositInterestRate != null) extraFields['deposit_interest_rate'] = asset.depositInterestRate;

      // 保单字段
      if (asset.policyNumber != null) extraFields['policy_number'] = asset.policyNumber;
      if (asset.insuranceType != null) extraFields['insurance_type'] = asset.insuranceType;
      if (asset.insured != null) extraFields['insured'] = asset.insured;
      if (asset.beneficiary != null) extraFields['beneficiary'] = asset.beneficiary;
      if (asset.coverageAmount != null) extraFields['coverage_amount'] = asset.coverageAmount;
      if (asset.premium != null) extraFields['premium'] = asset.premium;
      if (asset.premiumPeriod != null) extraFields['premium_period'] = asset.premiumPeriod;
      if (asset.coveragePeriod != null) extraFields['coverage_period'] = asset.coveragePeriod;
      if (asset.insurer != null) extraFields['insurer'] = asset.insurer;

      final extraFieldsJson = extraFields.isNotEmpty ? json.encode(extraFields) : null;

      final success = await _ffi.updateAssetWithExtraFields(
        id: asset.id,
        name: asset.name,
        assetType: asset.type.name,
        amount: asset.amount,
        currency: asset.currency,
        occurrenceDate: asset.occurrenceDate.toIso8601String().split('T')[0],
        extraFieldsJson: extraFieldsJson,
        note: asset.note,
      );

      if (success) {
        // 立即保存数据库到磁盘
        await _ffi.saveDatabase();
        await _loadAssets();
      }

      _isLoading = false;
      notifyListeners();
      return success;
    } catch (e) {
      debugPrint('更新资产失败: $e');
      _errorMessage = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// 更新负债
  Future<bool> updateLiability(Liability liability) async {
    _isLoading = true;
    notifyListeners();

    try {
      // 构建扩展字段 JSON
      final extraFields = <String, dynamic>{};

      // 贷款类通用字段
      if (liability.lender != null) extraFields['lender'] = liability.lender;
      if (liability.dueDate != null) extraFields['due_date'] = liability.dueDate!.toIso8601String();
      if (liability.interestRate != null) extraFields['interest_rate'] = liability.interestRate;
      if (liability.repaymentMethod != null) extraFields['repayment_method'] = liability.repaymentMethod!.value;
      if (liability.loanTerm != null) extraFields['loan_term'] = liability.loanTerm;

      // 信用卡字段
      if (liability.lastFourDigits != null) extraFields['last_four_digits'] = liability.lastFourDigits;
      if (liability.billingDate != null) extraFields['billing_date'] = liability.billingDate!.toIso8601String();
      if (liability.paymentDueDate != null) extraFields['payment_due_date'] = liability.paymentDueDate!.toIso8601String();
      if (liability.creditLimit != null) extraFields['credit_limit'] = liability.creditLimit;
      if (liability.cashLimit != null) extraFields['cash_limit'] = liability.cashLimit;
      if (liability.annualFee != null) extraFields['annual_fee'] = liability.annualFee;
      if (liability.issuer != null) extraFields['issuer'] = liability.issuer;

      // 房贷专属字段
      if (liability.propertyAddress != null) extraFields['property_address'] = liability.propertyAddress;
      if (liability.originalLoanAmount != null) extraFields['original_loan_amount'] = liability.originalLoanAmount;
      if (liability.remainingPrincipal != null) extraFields['remaining_principal'] = liability.remainingPrincipal;
      if (liability.loanType != null) extraFields['loan_type'] = liability.loanType;

      // 车贷专属字段
      if (liability.vehicleBrand != null) extraFields['vehicle_brand'] = liability.vehicleBrand;
      if (liability.vehicleModel != null) extraFields['vehicle_model'] = liability.vehicleModel;
      if (liability.licensePlate != null) extraFields['license_plate'] = liability.licensePlate;

      // 个人/私人借款专属字段
      if (liability.purpose != null) extraFields['purpose'] = liability.purpose;
      if (liability.hasInterest != null) extraFields['has_interest'] = liability.hasInterest;
      if (liability.repaymentPlan != null) extraFields['repayment_plan'] = liability.repaymentPlan;

      final extraFieldsJson = extraFields.isNotEmpty ? json.encode(extraFields) : null;

      final success = await _ffi.updateLiabilityWithExtraFields(
        id: liability.id,
        name: liability.name,
        liabilityType: liability.type.snakeCaseName,
        amount: liability.amount,
        currency: liability.currency,
        occurrenceDate: liability.occurrenceDate.toIso8601String().split('T')[0],
        extraFieldsJson: extraFieldsJson,
        note: liability.note,
      );

      if (success) {
        // 立即保存数据库到磁盘
        await _ffi.saveDatabase();
        await _loadLiabilities();
      }

      _isLoading = false;
      notifyListeners();
      return success;
    } catch (e) {
      debugPrint('更新负债失败: $e');
      _errorMessage = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// 删除资产
  Future<bool> deleteAsset(String id) async {
    _isLoading = true;
    notifyListeners();

    try {
      final success = await _ffi.deleteAsset(id);

      if (success) {
        // 立即保存数据库到磁盘
        await _ffi.saveDatabase();
        await _loadAssets();
      }

      _isLoading = false;
      notifyListeners();
      return success;
    } catch (e) {
      debugPrint('删除资产失败: $e');
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// 删除负债
  Future<bool> deleteLiability(String id) async {
    _isLoading = true;
    notifyListeners();

    try {
      final success = await _ffi.deleteLiability(id);

      if (success) {
        // 立即保存数据库到磁盘
        await _ffi.saveDatabase();
        await _loadLiabilities();
      }

      _isLoading = false;
      notifyListeners();
      return success;
    } catch (e) {
      debugPrint('删除负债失败: $e');
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// 根据类型筛选资产
  List<Asset> getAssetsByType(AssetType? type) {
    if (type == null) return _assets;
    return _assets.where((a) => a.type == type).toList();
  }

  /// 根据类型筛选负债
  List<Liability> getLiabilitiesByType(LiabilityType? type) {
    if (type == null) return _liabilities;
    return _liabilities.where((l) => l.type == type).toList();
  }

  /// 获取投资组合摘要
  PortfolioSummary getPortfolioSummary() {
    final assetBreakdown = <String, double>{};
    for (var asset in _assets) {
      final typeName = asset.type.name;
      assetBreakdown[typeName] = (assetBreakdown[typeName] ?? 0) + asset.amount;
    }

    final liabilityBreakdown = <String, double>{};
    for (var liability in _liabilities) {
      final typeName = liability.type.name;
      liabilityBreakdown[typeName] = (liabilityBreakdown[typeName] ?? 0) + liability.amount;
    }

    // 计算投资类资产统计
    final investmentAssets = _assets.where((a) => a.isInvestment).toList();
    final totalInvestments = investmentAssets.fold(0.0, (sum, a) => sum + a.amount);

    return PortfolioSummary(
      totalAssets: totalAssets,
      totalLiabilities: totalLiabilities,
      netAssets: netAssets,
      assetBreakdown: assetBreakdown,
      liabilityBreakdown: liabilityBreakdown,
      lastUpdated: DateTime.now(),
      totalInvestments: totalInvestments,
      totalInvestmentCost: totalInvestmentCost,
      totalInvestmentProfitLoss: totalInvestmentProfitLoss,
    );
  }

  /// 清除错误信息
  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  /// 设置负债类型筛选器（支持自定义类型 ID）
  void setLiabilityTypeFilterById(String? typeId) {
    _liabilityTypeFilterId = typeId;
    notifyListeners();
  }

  /// 清除负债类型筛选器
  void clearLiabilityTypeFilter() {
    _liabilityTypeFilterId = null;
    notifyListeners();
  }

  // 记住最后选择的类型（用于表单默认值）
  AssetType? _lastSelectedAssetType;
  LiabilityType? _lastSelectedLiabilityType;

  /// 获取最后选择的资产类型
  AssetType? get lastSelectedAssetType => _lastSelectedAssetType;

  /// 获取最后选择的负债类型
  LiabilityType? get lastSelectedLiabilityType => _lastSelectedLiabilityType;

  /// 设置最后选择的资产类型
  void setLastSelectedAssetType(AssetType? type) {
    _lastSelectedAssetType = type;
    notifyListeners();
  }

  /// 设置最后选择的负债类型
  void setLastSelectedLiabilityType(LiabilityType? type) {
    _lastSelectedLiabilityType = type;
    notifyListeners();
  }

  /// 创建自定义资产类型
  Future<Map<String, dynamic>> createCustomAssetType({
    required String name,
    required String iconName,
    required bool isLiability,
  }) async {
    try {
      final result = await _ffi.createCustomAssetType(
        name: name,
        iconName: iconName,
        isLiability: isLiability,
      );

      // 如果创建成功，重新加载自定义类型列表
      if (result['success'] == true) {
        await _loadCustomTypes();
        notifyListeners();
      }

      return result;
    } catch (e) {
      debugPrint('创建自定义类型失败: $e');
      return {'error': e.toString()};
    }
  }

  /// 删除自定义资产类型
  Future<bool> deleteCustomAssetType(String id) async {
    try {
      final success = await _ffi.deleteCustomAssetType(id);

      // 如果删除成功，重新加载自定义类型列表
      if (success) {
        await _loadCustomTypes();
        notifyListeners();
      }

      return success;
    } catch (e) {
      debugPrint('删除自定义类型失败: $e');
      return false;
    }
  }

  /// 检查自定义类型是否被使用
  Future<bool> isCustomTypeInUse(String id) async {
    try {
      return await _ffi.isCustomTypeInUse(id);
    } catch (e) {
      debugPrint('检查自定义类型使用情况失败: $e');
      return false;
    }
  }

  /// 按名称搜索资产
  Future<void> searchAssetsByName(String namePattern, {List<AssetType>? types}) async {
    if (namePattern.trim().isEmpty) {
      _assetSearchResults.clear();
      _isSearching = false;
      notifyListeners();
      return;
    }

    _isSearching = true;
    notifyListeners();

    try {
      final results = <Asset>[];
      for (final asset in _assets) {
        // 检查名称是否匹配
        if (!asset.name.toLowerCase().contains(namePattern.toLowerCase())) {
          continue;
        }

        // 如果有类型过滤，检查类型是否匹配
        if (types != null && types.isNotEmpty) {
          if (!types.contains(asset.type)) {
            continue;
          }
        }

        results.add(asset);
      }

      _assetSearchResults.clear();
      _assetSearchResults.addAll(results);
      _isSearching = false;
      notifyListeners();
    } catch (e) {
      debugPrint('搜索资产失败: $e');
      _isSearching = false;
      _assetSearchResults.clear();
      notifyListeners();
    }
  }

  /// 按名称搜索负债
  Future<void> searchLiabilitiesByName(String namePattern, {List<LiabilityType>? types}) async {
    if (namePattern.trim().isEmpty) {
      _liabilitySearchResults.clear();
      _isSearching = false;
      notifyListeners();
      return;
    }

    _isSearching = true;
    notifyListeners();

    try {
      final results = <Liability>[];
      for (final liability in _liabilities) {
        // 检查名称是否匹配
        if (!liability.name.toLowerCase().contains(namePattern.toLowerCase())) {
          continue;
        }

        // 如果有类型过滤，检查类型是否匹配
        if (types != null && types.isNotEmpty) {
          if (!types.contains(liability.type)) {
            continue;
          }
        }

        results.add(liability);
      }

      _liabilitySearchResults.clear();
      _liabilitySearchResults.addAll(results);
      _isSearching = false;
      notifyListeners();
    } catch (e) {
      debugPrint('搜索负债失败: $e');
      _isSearching = false;
      _liabilitySearchResults.clear();
      notifyListeners();
    }
  }

  /// 清除搜索结果
  void clearSearch() {
    _assetSearchResults.clear();
    _liabilitySearchResults.clear();
    _isSearching = false;
    notifyListeners();
  }
}
