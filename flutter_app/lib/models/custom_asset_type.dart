/// 自定义资产类型模型
///
/// 与 Rust Core 的 CustomAssetType 结构对应
library;

/// 自定义资产类型
class CustomAssetType {
  final String id;
  final String name;
  final String iconName;
  final bool isLiability;
  final DateTime createdAt;

  CustomAssetType({
    required this.id,
    required this.name,
    required this.iconName,
    required this.isLiability,
    required this.createdAt,
  });

  /// 从 JSON 创建
  factory CustomAssetType.fromJson(Map<String, dynamic> json) {
    return CustomAssetType(
      id: json['id'] as String,
      name: json['name'] as String,
      iconName: json['icon_name'] as String,
      isLiability: json['is_liability'] as bool,
      createdAt: DateTime.fromMillisecondsSinceEpoch(
        (json['created_at'] as int) * 1000,
      ),
    );
  }

  /// 转换为 JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'icon_name': iconName,
      'is_liability': isLiability,
      'created_at': createdAt.millisecondsSinceEpoch ~/ 1000,
    };
  }

  /// 复制并修改
  CustomAssetType copyWith({
    String? id,
    String? name,
    String? iconName,
    bool? isLiability,
    DateTime? createdAt,
  }) {
    return CustomAssetType(
      id: id ?? this.id,
      name: name ?? this.name,
      iconName: iconName ?? this.iconName,
      isLiability: isLiability ?? this.isLiability,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  /// 检查是否为自定义类型 ID
  static bool isCustomId(String id) {
    return id.startsWith('custom_');
  }
}
