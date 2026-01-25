/// 资产类型枚举（与 Rust Core 保持一致）
enum AssetType {
  property,   // 房产
  deposit,    // 存款
  stock,      // 股票
  fund,       // 基金
  insurance,  // 保单
  debt,       // 负债
}

/// 资产类型扩展 - 提供本地化和图标
extension AssetTypeExtension on AssetType {
  /// 获取资产类型的中文名称
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
      case AssetType.debt:
        return '负债';
    }
  }

  /// 获取资产类型的图标名称
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
      case AssetType.debt:
        return 'credit_card';
    }
  }

  /// 获取对应的整数值（与 Rust 枚举对应）
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
      case AssetType.debt:
        return 5;
    }
  }

  /// 从整数值创建枚举
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
      case 5:
        return AssetType.debt;
      default:
        return AssetType.deposit;
    }
  }

  /// 从字符串创建枚举
  static AssetType fromString(String str) {
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
      case 'debt':
        return AssetType.debt;
      default:
        return AssetType.deposit;
    }
  }
}

/// 资产模型
class Asset {
  final String id;
  final String name;
  final AssetType type;
  final double amount;
  final String currency;
  final String? account;
  final DateTime? buyDate;
  final double? buyPrice;
  final double? currentPrice;
  final String? note;
  final List<String>? tags;
  final DateTime createdAt;
  final DateTime updatedAt;

  Asset({
    required this.id,
    required this.name,
    required this.type,
    required this.amount,
    this.currency = 'CNY',
    this.account,
    this.buyDate,
    this.buyPrice,
    this.currentPrice,
    this.note,
    this.tags,
    required this.createdAt,
    required this.updatedAt,
  });

  /// 计算盈亏百分比
  double? get profitLossPercent {
    if (buyPrice != null && currentPrice != null && buyPrice! > 0) {
      return (currentPrice! - buyPrice!) / buyPrice! * 100;
    }
    return null;
  }

  /// 计算盈亏金额
  double? get profitLossAmount {
    if (buyPrice != null && currentPrice != null) {
      return currentPrice! - buyPrice!;
    }
    return null;
  }

  /// 复制并修改
  Asset copyWith({
    String? id,
    String? name,
    AssetType? type,
    double? amount,
    String? currency,
    String? account,
    DateTime? buyDate,
    double? buyPrice,
    double? currentPrice,
    String? note,
    List<String>? tags,
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
      buyDate: buyDate ?? this.buyDate,
      buyPrice: buyPrice ?? this.buyPrice,
      currentPrice: currentPrice ?? this.currentPrice,
      note: note ?? this.note,
      tags: tags ?? this.tags,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  /// 转换为 JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type.name,
      'name': name,
      'amount': amount,
      'currency': currency,
      'account': account,
      'buy_date': buyDate?.toIso8601String(),
      'buy_price': buyPrice,
      'current_price': currentPrice,
      'note': note,
      'tags': tags,
      'created_at': createdAt.millisecondsSinceEpoch ~/ 1000,
      'updated_at': updatedAt.millisecondsSinceEpoch ~/ 1000,
    };
  }

  /// 从 JSON 创建
  factory Asset.fromJson(Map<String, dynamic> json) {
    return Asset(
      id: json['id'] as String,
      name: json['name'] as String,
      type: AssetTypeExtension.fromString(json['type'] as String),
      amount: (json['amount'] as num).toDouble(),
      currency: json['currency'] as String? ?? 'CNY',
      account: json['account'] as String?,
      buyDate: json['buy_date'] != null
          ? DateTime.parse(json['buy_date'] as String)
          : null,
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
      createdAt: DateTime.fromMillisecondsSinceEpoch(
        (json['created_at'] as int) * 1000,
      ),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(
        (json['updated_at'] as int) * 1000,
      ),
    );
  }
}

