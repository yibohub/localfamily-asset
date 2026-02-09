/// 自定义资产类型状态管理
library;

import 'package:flutter/foundation.dart';
import '../core/ffi_bridge.dart';
import '../models/custom_asset_type.dart';

/// 自定义类型提供者
class CustomTypeProvider with ChangeNotifier {
  final List<CustomAssetType> _customTypes = [];
  final FfiBridge _ffi = FfiBridge();

  /// 获取所有自定义类型（不可变列表）
  List<CustomAssetType> get customTypes => List.unmodifiable(_customTypes);

  /// 获取资产类型的自定义类型
  List<CustomAssetType> get assetCustomTypes =>
      _customTypes.where((t) => !t.isLiability).toList();

  /// 获取负债类型的自定义类型
  List<CustomAssetType> get liabilityCustomTypes =>
      _customTypes.where((t) => t.isLiability).toList();

  /// 加载所有自定义类型
  Future<void> loadCustomTypes() async {
    try {
      final typesJson = await _ffi.getCustomAssetTypes();
      _customTypes.clear();
      for (final json in typesJson) {
        _customTypes.add(CustomAssetType.fromJson(json));
      }
      notifyListeners();
    } catch (e) {
      debugPrint('加载自定义类型失败: $e');
    }
  }

  /// 创建自定义类型
  ///
  /// 返回创建的类型 ID，失败返回 null
  Future<String?> createCustomType({
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

      if (result['success'] == true) {
        // 立即保存数据库到磁盘
        await _ffi.saveDatabase();
        await loadCustomTypes();
        return result['id'] as String?;
      }
      debugPrint('创建自定义类型失败: ${result['error']}');
      return null;
    } catch (e) {
      debugPrint('创建自定义类型失败: $e');
      return null;
    }
  }

  /// 删除自定义类型
  Future<bool> deleteCustomType(String id) async {
    try {
      final success = await _ffi.deleteCustomAssetType(id);
      if (success) {
        // 立即保存数据库到磁盘
        await _ffi.saveDatabase();
        await loadCustomTypes();
      }
      return success;
    } catch (e) {
      debugPrint('删除自定义类型失败: $e');
      return false;
    }
  }

  /// 检查类型是否被使用
  Future<bool> isTypeInUse(String id) async {
    try {
      return await _ffi.isCustomTypeInUse(id);
    } catch (e) {
      debugPrint('检查类型使用状态失败: $e');
      return true; // 默认返回 true 防止误删
    }
  }

  /// 根据 ID 获取自定义类型
  CustomAssetType? getById(String id) {
    try {
      return _customTypes.firstWhere((t) => t.id == id);
    } catch (e) {
      return null;
    }
  }

  /// 清空所有类型（用于测试）
  void clear() {
    _customTypes.clear();
    notifyListeners();
  }
}
