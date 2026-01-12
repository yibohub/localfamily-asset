/// 资产类型枚举
enum AssetType {
  cash,
  stock,
  bond,
  fund,
  realEstate,
  crypto,
  commodity,
  other,
}

/// 资产模型
class Asset {
  final String id;
  final String name;
  final AssetType type;
  final double amount;
  final String? currency;
  final String? symbol;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? notes;

  Asset({
    required this.id,
    required this.name,
    required this.type,
    required this.amount,
    this.currency,
    this.symbol,
    required this.createdAt,
    required this.updatedAt,
    this.notes,
  });

  Asset copyWith({
    String? id,
    String? name,
    AssetType? type,
    double? amount,
    String? currency,
    String? symbol,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? notes,
  }) {
    return Asset(
      id: id ?? this.id,
      name: name ?? this.name,
      type: type ?? this.type,
      amount: amount ?? this.amount,
      currency: currency ?? this.currency,
      symbol: symbol ?? this.symbol,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      notes: notes ?? this.notes,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'type': type.name,
      'amount': amount,
      'currency': currency,
      'symbol': symbol,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'notes': notes,
    };
  }

  factory Asset.fromJson(Map<String, dynamic> json) {
    return Asset(
      id: json['id'] as String,
      name: json['name'] as String,
      type: AssetType.values.firstWhere((e) => e.name == json['type']),
      amount: (json['amount'] as num).toDouble(),
      currency: json['currency'] as String?,
      symbol: json['symbol'] as String?,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
      notes: json['notes'] as String?,
    );
  }
}

/// 资产类别（用于分组统计）
class AssetCategory {
  final String id;
  final String name;
  final AssetType type;
  final int order;

  AssetCategory({
    required this.id,
    required this.name,
    required this.type,
    required this.order,
  });
}
