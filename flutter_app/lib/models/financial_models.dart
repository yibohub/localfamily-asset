/// ============================================================
/// 金融记录数据模型（重构版：资产、负债分离）
/// ============================================================

import 'asset.dart' as legacy; // 导入旧的 Asset 模型以支持 UI 兼容性

/// ============================================================
/// 枚举定义
/// ============================================================

/// 资产类型枚举
enum AssetType {
  property,  // 房产（非投资类）
  deposit,   // 存款（非投资类）
  stock,     // 股票（投资类）
  fund,      // 基金（投资类）
  insurance, // 保单（非投资类）
}

/// 负债类型枚举
enum LiabilityType {
  debt,         // 通用负债
  mortgage,     // 房贷
  carLoan,      // 车贷
  creditCard,   // 信用卡
  personalLoan, // 个人贷款
  privateLoan,  // 私人借款
}

/// 还款方式
enum RepaymentMethod {
  equalPrincipalAndInterest, // 等额本息
  equalPrincipal,            // 等额本金
  bulletPayment,             // 到期还本付息
  monthlyInterest,           // 按月付息到期还本
  custom,                    // 自定义
}

/// ============================================================
/// 资产类型扩展
/// ============================================================
extension AssetTypeExtension on AssetType {
  String get displayName {
    switch (this) {
      case AssetType.property:
        return '房产';
      case AssetType.deposit:
        return '存款';
      case AssetType.stock:
        return '股票';
      case AssetType.fund:
        return '基金';
      case AssetType.insurance:
        return '保单';
    }
  }

  String get iconName {
    switch (this) {
      case AssetType.property:
        return 'home';
      case AssetType.deposit:
        return 'account_balance';
      case AssetType.stock:
        return 'trending_up';
      case AssetType.fund:
        return 'pie_chart';
      case AssetType.insurance:
        return 'security';
    }
  }

  /// 是否为投资类资产（有买入价/现价概念）
  bool get isInvestment {
    return this == AssetType.stock || this == AssetType.fund;
  }

  int get value {
    switch (this) {
      case AssetType.property:
        return 0;
      case AssetType.deposit:
        return 1;
      case AssetType.stock:
        return 2;
      case AssetType.fund:
        return 3;
      case AssetType.insurance:
        return 4;
    }
  }

  static AssetType fromValue(int value) {
    switch (value) {
      case 0:
        return AssetType.property;
      case 1:
        return AssetType.deposit;
      case 2:
        return AssetType.stock;
      case 3:
        return AssetType.fund;
      case 4:
        return AssetType.insurance;
      default:
        return AssetType.deposit;
    }
  }

  static AssetType? fromString(String str) {
    switch (str) {
      case 'property':
        return AssetType.property;
      case 'deposit':
        return AssetType.deposit;
      case 'stock':
        return AssetType.stock;
      case 'fund':
        return AssetType.fund;
      case 'insurance':
        return AssetType.insurance;
      default:
        return null;
    }
  }
}

/// ============================================================
/// 负债类型扩展
/// ============================================================
extension LiabilityTypeExtension on LiabilityType {
  String get displayName {
    switch (this) {
      case LiabilityType.debt:
        return '其他负债';
      case LiabilityType.mortgage:
        return '房贷';
      case LiabilityType.carLoan:
        return '车贷';
      case LiabilityType.creditCard:
        return '信用卡';
      case LiabilityType.personalLoan:
        return '个人贷款';
      case LiabilityType.privateLoan:
        return '私人借款';
    }
  }

  String get iconName {
    switch (this) {
      case LiabilityType.debt:
        return 'credit_card';
      case LiabilityType.mortgage:
        return 'home_work';
      case LiabilityType.carLoan:
        return 'directions_car';
      case LiabilityType.creditCard:
        return 'credit_card';
      case LiabilityType.personalLoan:
        return 'person';
      case LiabilityType.privateLoan:
        return 'handshake';
    }
  }

  /// 是否为信用卡类型
  bool get isCreditCard {
    return this == LiabilityType.creditCard;
  }

  int get value {
    switch (this) {
      case LiabilityType.debt:
        return 0;
      case LiabilityType.mortgage:
        return 1;
      case LiabilityType.carLoan:
        return 2;
      case LiabilityType.creditCard:
        return 3;
      case LiabilityType.personalLoan:
        return 4;
      case LiabilityType.privateLoan:
        return 5;
    }
  }

  static LiabilityType fromValue(int value) {
    switch (value) {
      case 0:
        return LiabilityType.debt;
      case 1:
        return LiabilityType.mortgage;
      case 2:
        return LiabilityType.carLoan;
      case 3:
        return LiabilityType.creditCard;
      case 4:
        return LiabilityType.personalLoan;
      case 5:
        return LiabilityType.privateLoan;
      default:
        return LiabilityType.debt;
    }
  }

  static LiabilityType? fromString(String str) {
    switch (str) {
      case 'debt':
        return LiabilityType.debt;
      case 'mortgage':
        return LiabilityType.mortgage;
      case 'car_loan':
        return LiabilityType.carLoan;
      case 'credit_card':
        return LiabilityType.creditCard;
      case 'personal_loan':
        return LiabilityType.personalLoan;
      case 'private_loan':
        return LiabilityType.privateLoan;
      default:
        return null;
    }
  }

  /// 转换为旧的 AssetType（用于 UI 组件兼容）
  legacy.AssetType toAssetType() {
    switch (this) {
      case LiabilityType.debt:
        return legacy.AssetType.debt;
      case LiabilityType.mortgage:
        return legacy.AssetType.mortgage;
      case LiabilityType.carLoan:
        return legacy.AssetType.carLoan;
      case LiabilityType.creditCard:
        return legacy.AssetType.creditCard;
      case LiabilityType.personalLoan:
        return legacy.AssetType.personalLoan;
      case LiabilityType.privateLoan:
        return legacy.AssetType.privateLoan;
    }
  }
}

/// ============================================================
/// 还款方式扩展
/// ============================================================
extension RepaymentMethodExtension on RepaymentMethod {
  String get displayName {
    switch (this) {
      case RepaymentMethod.equalPrincipalAndInterest:
        return '等额本息';
      case RepaymentMethod.equalPrincipal:
        return '等额本金';
      case RepaymentMethod.bulletPayment:
        return '到期还本付息';
      case RepaymentMethod.monthlyInterest:
        return '按月付息';
      case RepaymentMethod.custom:
        return '自定义';
    }
  }

  static RepaymentMethod? fromString(String str) {
    switch (str) {
      case 'equal_principal_and_interest':
        return RepaymentMethod.equalPrincipalAndInterest;
      case 'equal_principal':
        return RepaymentMethod.equalPrincipal;
      case 'bullet_payment':
        return RepaymentMethod.bulletPayment;
      case 'monthly_interest':
        return RepaymentMethod.monthlyInterest;
      case 'custom':
        return RepaymentMethod.custom;
      default:
        return null;
    }
  }

  String get value {
    switch (this) {
      case RepaymentMethod.equalPrincipalAndInterest:
        return 'equal_principal_and_interest';
      case RepaymentMethod.equalPrincipal:
        return 'equal_principal';
      case RepaymentMethod.bulletPayment:
        return 'bullet_payment';
      case RepaymentMethod.monthlyInterest:
        return 'monthly_interest';
      case RepaymentMethod.custom:
        return 'custom';
    }
  }
}

/// ============================================================
/// 基础抽象类
/// ============================================================

/// 金融记录基类
abstract class FinancialRecord {
  final String id;
  final String name;
  final double amount;
  final String currency;
  final DateTime occurrenceDate;
  final String? note;
  final DateTime createdAt;
  final DateTime updatedAt;

  FinancialRecord({
    required this.id,
    required this.name,
    required this.amount,
    this.currency = 'CNY',
    required this.occurrenceDate,
    this.note,
    required this.createdAt,
    required this.updatedAt,
  });

  /// 转换为 JSON
  Map<String, dynamic> toJson();

  /// 记录类型标识（'asset' 或 'liability'）
  String get recordType;
}

/// ============================================================
/// 资产模型
/// ============================================================

class Asset extends FinancialRecord {
  final AssetType type;
  final String? account;      // 账户/平台
  final List<String>? tags;

  // 投资类资产专属字段
  final double? buyPrice;     // 买入价（投资类）
  final double? currentPrice; // 现价（投资类）
  final String? code;         // 代码（股票代码、基金代码）
  final String? exchange;     // 交易所
  final int? quantity;        // 数量（通过 amount 和 currentPrice 计算）

  // 房产专属字段（Property）
  final String? address;           // 地址
  final double? buildingArea;      // 建筑面积（㎡）
  final double? livingArea;        // 使用面积（㎡）
  final String? propertyType;      // 房屋类型：住宅/商业/别墅/公寓等
  final int? rooms;                // 房间数（几室几厅）
  final String? floor;             // 楼层（如：12/32）
  final int? buildYear;            // 建成年份
  final String? ownershipType;     // 产权性质：商品房/经适房/公房等
  final String? deedNumber;        // 不动产证号

  // 存款专属字段（Deposit）
  final String? depositAccountType;   // 账户类型：活期/定期
  final int? depositPeriod;            // 存期（月）
  final DateTime? maturityDate;        // 到期日期
  final double? depositInterestRate;   // 利率（%）

  // 保单专属字段（Insurance）
  final String? policyNumber;      // 保单号
  final String? insuranceType;     // 保险类型：寿险/重疾/医疗/意外
  final String? insured;           // 被保人
  final String? beneficiary;       // 受益人
  final double? coverageAmount;    // 保额
  final double? premium;           // 保费（年/月）
  final String? premiumPeriod;     // 缴费期限：终身/10年/20年等
  final String? coveragePeriod;    // 保险期限：终身/1年/至70岁等
  final String? insurer;           // 保险公司

  Asset({
    required String id,
    required String name,
    required this.type,
    required double amount,
    String currency = 'CNY',
    this.account,
    required DateTime occurrenceDate,
    this.buyPrice,
    this.currentPrice,
    this.code,
    this.exchange,
    this.quantity,
    String? note,
    this.tags,
    // 房产字段
    this.address,
    this.buildingArea,
    this.livingArea,
    this.propertyType,
    this.rooms,
    this.floor,
    this.buildYear,
    this.ownershipType,
    this.deedNumber,
    // 存款字段
    this.depositAccountType,
    this.depositPeriod,
    this.maturityDate,
    this.depositInterestRate,
    // 保单字段
    this.policyNumber,
    this.insuranceType,
    this.insured,
    this.beneficiary,
    this.coverageAmount,
    this.premium,
    this.premiumPeriod,
    this.coveragePeriod,
    this.insurer,
    required DateTime createdAt,
    required DateTime updatedAt,
  }) : super(
          id: id,
          name: name,
          amount: amount,
          currency: currency,
          occurrenceDate: occurrenceDate,
          note: note,
          createdAt: createdAt,
          updatedAt: updatedAt,
        );

  /// 是否为投资类资产
  bool get isInvestment => type.isInvestment;

  /// 计算盈亏百分比
  double? get profitLossPercent {
    if (!isInvestment || buyPrice == null || currentPrice == null || buyPrice! == 0) {
      return null;
    }
    return (currentPrice! - buyPrice!) / buyPrice! * 100;
  }

  /// 计算盈亏金额
  double? get profitLossAmount {
    if (!isInvestment || buyPrice == null || currentPrice == null) {
      return null;
    }
    return currentPrice! - buyPrice!;
  }

  /// 计算持有数量（如果未设置则通过 amount 和 currentPrice 计算）
  double? get calculatedQuantity {
    if (quantity != null) return quantity!.toDouble();
    if (!isInvestment || currentPrice == null || currentPrice == 0) {
      return null;
    }
    return amount / currentPrice!;
  }

  @override
  String get recordType => 'asset';

  @override
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'record_type': recordType,
      'type': type.name,
      'name': name,
      'amount': amount,
      'currency': currency,
      'account': account,
      'occurrence_date': occurrenceDate.toIso8601String(),
      'buy_price': buyPrice,
      'current_price': currentPrice,
      'note': note,
      'tags': tags,
      // 投资类字段
      'code': code,
      'exchange': exchange,
      // 房产字段
      'address': address,
      'building_area': buildingArea,
      'living_area': livingArea,
      'property_type': propertyType,
      'rooms': rooms,
      'floor': floor,
      'build_year': buildYear,
      'ownership_type': ownershipType,
      'deed_number': deedNumber,
      // 存款字段
      'account_type': depositAccountType,
      'deposit_period': depositPeriod,
      'maturity_date': maturityDate?.toIso8601String(),
      'deposit_interest_rate': depositInterestRate,
      // 保单字段
      'policy_number': policyNumber,
      'insurance_type': insuranceType,
      'insured': insured,
      'beneficiary': beneficiary,
      'coverage_amount': coverageAmount,
      'premium': premium,
      'premium_period': premiumPeriod,
      'coverage_period': coveragePeriod,
      'insurer': insurer,
      'created_at': createdAt.millisecondsSinceEpoch ~/ 1000,
      'updated_at': updatedAt.millisecondsSinceEpoch ~/ 1000,
    };
  }

  factory Asset.fromJson(Map<String, dynamic> json) {
    return Asset(
      id: json['id'] as String,
      name: json['name'] as String,
      type: AssetType.values.firstWhere(
        (e) => e.name == json['type'],
        orElse: () => AssetType.deposit,
      ),
      amount: (json['amount'] as num).toDouble(),
      currency: json['currency'] as String? ?? 'CNY',
      account: json['account'] as String?,
      occurrenceDate: json['occurrence_date'] != null
          ? DateTime.parse(json['occurrence_date'] as String)
          : DateTime.now(),
      buyPrice: json['buy_price'] != null
          ? (json['buy_price'] as num).toDouble()
          : null,
      currentPrice: json['current_price'] != null
          ? (json['current_price'] as num).toDouble()
          : null,
      note: json['note'] as String?,
      tags: json['tags'] != null
          ? List<String>.from(json['tags'] as List)
          : null,
      // 投资类字段
      code: json['code'] as String?,
      exchange: json['exchange'] as String?,
      quantity: json['quantity'] as int?,
      // 房产字段
      address: json['address'] as String?,
      buildingArea: json['building_area'] != null
          ? (json['building_area'] as num).toDouble()
          : null,
      livingArea: json['living_area'] != null
          ? (json['living_area'] as num).toDouble()
          : null,
      propertyType: json['property_type'] as String?,
      rooms: json['rooms'] as int?,
      floor: json['floor'] as String?,
      buildYear: json['build_year'] as int?,
      ownershipType: json['ownership_type'] as String?,
      deedNumber: json['deed_number'] as String?,
      // 存款字段
      depositAccountType: json['account_type'] as String?,
      depositPeriod: json['deposit_period'] as int?,
      maturityDate: json['maturity_date'] != null
          ? DateTime.parse(json['maturity_date'] as String)
          : null,
      depositInterestRate: json['deposit_interest_rate'] != null
          ? (json['deposit_interest_rate'] as num).toDouble()
          : null,
      // 保单字段
      policyNumber: json['policy_number'] as String?,
      insuranceType: json['insurance_type'] as String?,
      insured: json['insured'] as String?,
      beneficiary: json['beneficiary'] as String?,
      coverageAmount: json['coverage_amount'] != null
          ? (json['coverage_amount'] as num).toDouble()
          : null,
      premium: json['premium'] != null
          ? (json['premium'] as num).toDouble()
          : null,
      premiumPeriod: json['premium_period'] as String?,
      coveragePeriod: json['coverage_period'] as String?,
      insurer: json['insurer'] as String?,
      createdAt: DateTime.fromMillisecondsSinceEpoch(
        (json['created_at'] as int) * 1000,
      ),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(
        (json['updated_at'] as int) * 1000,
      ),
    );
  }

  /// 复制并修改
  Asset copyWith({
    String? id,
    String? name,
    AssetType? type,
    double? amount,
    String? currency,
    String? account,
    DateTime? occurrenceDate,
    double? buyPrice,
    double? currentPrice,
    String? note,
    List<String>? tags,
    // 投资类字段
    String? code,
    String? exchange,
    int? quantity,
    // 房产字段
    String? address,
    double? buildingArea,
    double? livingArea,
    String? propertyType,
    int? rooms,
    String? floor,
    int? buildYear,
    String? ownershipType,
    String? deedNumber,
    // 存款字段
    String? depositAccountType,
    int? depositPeriod,
    DateTime? maturityDate,
    double? depositInterestRate,
    // 保单字段
    String? policyNumber,
    String? insuranceType,
    String? insured,
    String? beneficiary,
    double? coverageAmount,
    double? premium,
    String? premiumPeriod,
    String? coveragePeriod,
    String? insurer,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Asset(
      id: id ?? this.id,
      name: name ?? this.name,
      type: type ?? this.type,
      amount: amount ?? this.amount,
      currency: currency ?? this.currency,
      account: account ?? this.account,
      occurrenceDate: occurrenceDate ?? this.occurrenceDate,
      buyPrice: buyPrice ?? this.buyPrice,
      currentPrice: currentPrice ?? this.currentPrice,
      note: note ?? this.note,
      tags: tags ?? this.tags,
      // 投资类字段
      code: code ?? this.code,
      exchange: exchange ?? this.exchange,
      quantity: quantity ?? this.quantity,
      // 房产字段
      address: address ?? this.address,
      buildingArea: buildingArea ?? this.buildingArea,
      livingArea: livingArea ?? this.livingArea,
      propertyType: propertyType ?? this.propertyType,
      rooms: rooms ?? this.rooms,
      floor: floor ?? this.floor,
      buildYear: buildYear ?? this.buildYear,
      ownershipType: ownershipType ?? this.ownershipType,
      deedNumber: deedNumber ?? this.deedNumber,
      // 存款字段
      depositAccountType: depositAccountType ?? this.depositAccountType,
      depositPeriod: depositPeriod ?? this.depositPeriod,
      maturityDate: maturityDate ?? this.maturityDate,
      depositInterestRate: depositInterestRate ?? this.depositInterestRate,
      // 保单字段
      policyNumber: policyNumber ?? this.policyNumber,
      insuranceType: insuranceType ?? this.insuranceType,
      insured: insured ?? this.insured,
      beneficiary: beneficiary ?? this.beneficiary,
      coverageAmount: coverageAmount ?? this.coverageAmount,
      premium: premium ?? this.premium,
      premiumPeriod: premiumPeriod ?? this.premiumPeriod,
      coveragePeriod: coveragePeriod ?? this.coveragePeriod,
      insurer: insurer ?? this.insurer,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

/// ============================================================
/// 负债模型
/// ============================================================

class Liability extends FinancialRecord {
  final LiabilityType type;

  // 通用负债字段
  final DateTime? dueDate;         // 还债期限/到期日
  final double? interestRate;      // 年利率 (%)
  final RepaymentMethod? repaymentMethod; // 还款方式
  final String? lender;            // 债权人/机构

  // 信用卡专属字段
  final DateTime? billingDate;     // 账单日
  final DateTime? paymentDueDate;  // 还款日
  final double? creditLimit;       // 信用额度
  final String? lastFourDigits;    // 卡号后四位
  final double? cashLimit;         // 取现额度
  final double? annualFee;         // 年费
  final String? issuer;            // 发卡行
  final int? loanTerm;             // 贷款期限（月）

  // 房贷专属字段
  final String? propertyAddress;   // 房产地址
  final double? originalLoanAmount; // 原始贷款金额
  final double? remainingPrincipal;  // 剩余本金
  final String? loanType;          // 贷款类型

  // 车贷专属字段
  final String? vehicleBrand;      // 车辆品牌
  final String? vehicleModel;      // 车型
  final String? licensePlate;      // 车牌号

  // 个人/私人借款专属字段
  final String? purpose;           // 借款用途
  final bool? hasInterest;         // 是否有利息
  final String? repaymentPlan;     // 还款计划描述

  Liability({
    required String id,
    required String name,
    required this.type,
    required double amount,
    String currency = 'CNY',
    required DateTime occurrenceDate,
    this.dueDate,
    this.interestRate,
    this.repaymentMethod,
    this.lender,
    this.loanTerm,
    this.lastFourDigits,
    this.billingDate,
    this.paymentDueDate,
    this.creditLimit,
    this.cashLimit,
    this.annualFee,
    this.issuer,
    this.propertyAddress,
    this.originalLoanAmount,
    this.remainingPrincipal,
    this.loanType,
    this.vehicleBrand,
    this.vehicleModel,
    this.licensePlate,
    this.purpose,
    this.hasInterest,
    this.repaymentPlan,
    String? note,
    required DateTime createdAt,
    required DateTime updatedAt,
  }) : super(
          id: id,
          name: name,
          amount: amount,
          currency: currency,
          occurrenceDate: occurrenceDate,
          note: note,
          createdAt: createdAt,
          updatedAt: updatedAt,
        );

  /// 是否为信用卡类型
  bool get isCreditCard => type == LiabilityType.creditCard;

  /// 计算已使用额度百分比（仅信用卡有效）
  double? get creditUtilization {
    if (!isCreditCard || creditLimit == null || creditLimit == 0) {
      return null;
    }
    return (amount / creditLimit!) * 100;
  }

  /// 计算剩余额度（仅信用卡有效）
  double? get availableCredit {
    if (!isCreditCard || creditLimit == null) {
      return null;
    }
    return creditLimit! - amount;
  }

  /// 计算剩余天数
  int? get daysUntilDue {
    if (dueDate == null) return null;
    return dueDate!.difference(DateTime.now()).inDays;
  }

  @override
  String get recordType => 'liability';

  @override
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'record_type': recordType,
      'type': type.name,
      'name': name,
      'amount': amount,
      'currency': currency,
      'occurrence_date': occurrenceDate.toIso8601String(),
      'due_date': dueDate?.toIso8601String(),
      'interest_rate': interestRate,
      'repayment_method': repaymentMethod?.value,
      'lender': lender,
      'loan_term': loanTerm,
      'last_four_digits': lastFourDigits,
      'billing_date': billingDate?.toIso8601String(),
      'payment_due_date': paymentDueDate?.toIso8601String(),
      'credit_limit': creditLimit,
      'cash_limit': cashLimit,
      'annual_fee': annualFee,
      'issuer': issuer,
      'property_address': propertyAddress,
      'original_loan_amount': originalLoanAmount,
      'remaining_principal': remainingPrincipal,
      'loan_type': loanType,
      'vehicle_brand': vehicleBrand,
      'vehicle_model': vehicleModel,
      'license_plate': licensePlate,
      'purpose': purpose,
      'has_interest': hasInterest,
      'repayment_plan': repaymentPlan,
      'note': note,
      'created_at': createdAt.millisecondsSinceEpoch ~/ 1000,
      'updated_at': updatedAt.millisecondsSinceEpoch ~/ 1000,
    };
  }

  factory Liability.fromJson(Map<String, dynamic> json) {
    return Liability(
      id: json['id'] as String,
      name: json['name'] as String,
      type: LiabilityType.values.firstWhere(
        (e) => e.name == json['type'],
        orElse: () => LiabilityType.debt,
      ),
      amount: (json['amount'] as num).toDouble(),
      currency: json['currency'] as String? ?? 'CNY',
      occurrenceDate: json['occurrence_date'] != null
          ? DateTime.parse(json['occurrence_date'] as String)
          : DateTime.now(),
      dueDate: json['due_date'] != null
          ? DateTime.parse(json['due_date'] as String)
          : null,
      interestRate: json['interest_rate'] != null
          ? (json['interest_rate'] as num).toDouble()
          : null,
      repaymentMethod: json['repayment_method'] != null
          ? RepaymentMethodExtension.fromString(json['repayment_method'] as String)
          : null,
      lender: json['lender'] as String?,
      loanTerm: json['loan_term'] as int?,
      lastFourDigits: json['last_four_digits'] as String?,
      billingDate: json['billing_date'] != null
          ? DateTime.parse(json['billing_date'] as String)
          : null,
      paymentDueDate: json['payment_due_date'] != null
          ? DateTime.parse(json['payment_due_date'] as String)
          : null,
      creditLimit: json['credit_limit'] != null
          ? (json['credit_limit'] as num).toDouble()
          : null,
      cashLimit: json['cash_limit'] != null
          ? (json['cash_limit'] as num).toDouble()
          : null,
      annualFee: json['annual_fee'] != null
          ? (json['annual_fee'] as num).toDouble()
          : null,
      issuer: json['issuer'] as String?,
      propertyAddress: json['property_address'] as String?,
      originalLoanAmount: json['original_loan_amount'] != null
          ? (json['original_loan_amount'] as num).toDouble()
          : null,
      remainingPrincipal: json['remaining_principal'] != null
          ? (json['remaining_principal'] as num).toDouble()
          : null,
      loanType: json['loan_type'] as String?,
      vehicleBrand: json['vehicle_brand'] as String?,
      vehicleModel: json['vehicle_model'] as String?,
      licensePlate: json['license_plate'] as String?,
      purpose: json['purpose'] as String?,
      hasInterest: json['has_interest'] as bool?,
      repaymentPlan: json['repayment_plan'] as String?,
      note: json['note'] as String?,
      createdAt: DateTime.fromMillisecondsSinceEpoch(
        (json['created_at'] as int) * 1000,
      ),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(
        (json['updated_at'] as int) * 1000,
      ),
    );
  }

  /// 复制并修改
  Liability copyWith({
    String? id,
    String? name,
    LiabilityType? type,
    double? amount,
    String? currency,
    DateTime? occurrenceDate,
    DateTime? dueDate,
    double? interestRate,
    RepaymentMethod? repaymentMethod,
    String? lender,
    int? loanTerm,
    String? lastFourDigits,
    DateTime? billingDate,
    DateTime? paymentDueDate,
    double? creditLimit,
    double? cashLimit,
    double? annualFee,
    String? issuer,
    String? propertyAddress,
    double? originalLoanAmount,
    double? remainingPrincipal,
    String? loanType,
    String? vehicleBrand,
    String? vehicleModel,
    String? licensePlate,
    String? purpose,
    bool? hasInterest,
    String? repaymentPlan,
    String? note,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Liability(
      id: id ?? this.id,
      name: name ?? this.name,
      type: type ?? this.type,
      amount: amount ?? this.amount,
      currency: currency ?? this.currency,
      occurrenceDate: occurrenceDate ?? this.occurrenceDate,
      dueDate: dueDate ?? this.dueDate,
      interestRate: interestRate ?? this.interestRate,
      repaymentMethod: repaymentMethod ?? this.repaymentMethod,
      lender: lender ?? this.lender,
      loanTerm: loanTerm ?? this.loanTerm,
      lastFourDigits: lastFourDigits ?? this.lastFourDigits,
      billingDate: billingDate ?? this.billingDate,
      paymentDueDate: paymentDueDate ?? this.paymentDueDate,
      creditLimit: creditLimit ?? this.creditLimit,
      cashLimit: cashLimit ?? this.cashLimit,
      annualFee: annualFee ?? this.annualFee,
      issuer: issuer ?? this.issuer,
      propertyAddress: propertyAddress ?? this.propertyAddress,
      originalLoanAmount: originalLoanAmount ?? this.originalLoanAmount,
      remainingPrincipal: remainingPrincipal ?? this.remainingPrincipal,
      loanType: loanType ?? this.loanType,
      vehicleBrand: vehicleBrand ?? this.vehicleBrand,
      vehicleModel: vehicleModel ?? this.vehicleModel,
      licensePlate: licensePlate ?? this.licensePlate,
      purpose: purpose ?? this.purpose,
      hasInterest: hasInterest ?? this.hasInterest,
      repaymentPlan: repaymentPlan ?? this.repaymentPlan,
      note: note ?? this.note,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  /// 转换为旧的 Asset 模型（用于 UI 组件兼容）
  legacy.Asset toAsset() {
    return legacy.Asset(
      id: id,
      name: name,
      type: type.name, // 使用 enum name (snake_case)
      amount: amount,
      currency: currency,
      occurrenceDate: occurrenceDate,
      note: note,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }
}

/// ============================================================
/// 投资组合摘要（支持分离模型）
/// ============================================================

class PortfolioSummary {
  final double totalAssets;
  final double totalLiabilities;
  final double netAssets;
  final Map<String, double> assetBreakdown;
  final Map<String, double> liabilityBreakdown;
  final DateTime lastUpdated;

  // 投资类资产统计
  final double totalInvestments;
  final double? totalInvestmentCost;    // 总成本
  final double? totalInvestmentProfitLoss; // 总盈亏金额

  PortfolioSummary({
    required this.totalAssets,
    required this.totalLiabilities,
    required this.netAssets,
    required this.assetBreakdown,
    required this.liabilityBreakdown,
    required this.lastUpdated,
    this.totalInvestments = 0,
    this.totalInvestmentCost,
    this.totalInvestmentProfitLoss,
  });
}
