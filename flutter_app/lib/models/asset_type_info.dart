/// 资产类型信息 - 统一处理内置类型和自定义类型
library;

import 'asset.dart';
import 'custom_asset_type.dart';

/// 资产类型信息类（统一处理内置类型和自定义类型）
class AssetTypeInfo {
  final String id; // 内置类型使用枚举名称，自定义类型使用 "custom_xxx"
  final String displayName;
  final String iconName;
  final bool isLiability;
  final bool isBuiltIn;

  /// 内置类型构造函数
  AssetTypeInfo.builtIn({
    required this.id,
    required this.displayName,
    required this.iconName,
    required this.isLiability,
  }) : isBuiltIn = true;

  /// 自定义类型构造函数
  AssetTypeInfo.custom({
    required this.id,
    required this.displayName,
    required this.iconName,
    required this.isLiability,
  }) : isBuiltIn = false;

  /// 从内置枚举创建
  factory AssetTypeInfo.fromAssetType(AssetType type) {
    return AssetTypeInfo.builtIn(
      id: type.name,
      displayName: type.displayName,
      iconName: type.iconName,
      isLiability: type.isLiability,
    );
  }

  /// 从自定义类型创建
  factory AssetTypeInfo.fromCustomType(CustomAssetType customType) {
    return AssetTypeInfo.custom(
      id: customType.id,
      displayName: customType.name,
      iconName: customType.iconName,
      isLiability: customType.isLiability,
    );
  }

  /// 从字符串 ID 和自定义类型列表创建
  ///
  /// 如果是内置类型名称，返回内置类型信息
  /// 如果是自定义类型 ID，从列表中查找并返回
  /// 如果找不到，返回 null
  static AssetTypeInfo? fromString(
    String typeId,
    List<CustomAssetType> customTypes,
  ) {
    // 检查是否为内置类型（使用动态枚举遍历）
    try {
      for (final type in AssetType.values) {
        if (type.name == typeId) {
          return AssetTypeInfo.fromAssetType(type);
        }
      }
    } catch (e) {
      // 忽略错误，继续查找自定义类型
    }

    // 查找自定义类型
    try {
      final customType = customTypes.firstWhere((t) => t.id == typeId);
      return AssetTypeInfo.fromCustomType(customType);
    } catch (e) {
      return null;
    }
  }

  /// 判断是否为自定义类型
  static bool isCustomTypeId(String id) {
    return id.startsWith('custom_');
  }
}
