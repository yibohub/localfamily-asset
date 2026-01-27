import 'package:flutter/material.dart';
import '../models/asset.dart';
import 'asset_list_item.dart';

/// 分组资产列表项组件
///
/// 用于显示同名资产的分组视图：
/// - 单个资产：直接显示卡片
/// - 多个同名资产：显示汇总 + 可展开详情
class GroupedAssetListItem extends StatelessWidget {
  final String groupName;
  final List<Asset> assets;
  final VoidCallback? onTap;
  final Function(Asset)? onAssetTap;

  const GroupedAssetListItem({
    super.key,
    required this.groupName,
    required this.assets,
    this.onTap,
    this.onAssetTap,
  });

  /// 计算分组总金额
  double get _totalAmount {
    return assets.fold(0.0, (sum, asset) => sum + asset.amount);
  }

  /// 判断是否为负债
  bool get _isLiability {
    return assets.first.type.isLiability;
  }

  @override
  Widget build(BuildContext context) {
    // 单个资产：直接显示
    if (assets.length == 1) {
      return AssetListItem(
        asset: assets.first,
        onTap: onTap,
      );
    }

    // 多个同名资产：显示可展开的分组
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: ExpansionTile(
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                groupName,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            Text(
              '${assets.length}个账户',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
        subtitle: Row(
          children: [
            Text(
              _isLiability ? '负债' : '资产',
              style: TextStyle(
                color: _isLiability ? Colors.red : Colors.green,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '合计 ¥${_totalAmount.toStringAsFixed(2)}',
              style: TextStyle(
                color: _isLiability ? Colors.red : Colors.green,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        children: [
          const Divider(height: 1),
          ...assets.map((asset) => Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  children: [
                    ListTile(
                      dense: true,
                      title: Text(asset.account ?? '无账户信息'),
                      trailing: Text(
                        '¥${asset.amount.toStringAsFixed(2)}',
                        style: TextStyle(
                          color: asset.type.isLiability
                              ? Colors.red
                              : Colors.green,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      onTap: () {
                        if (onAssetTap != null) {
                          onAssetTap!(asset);
                        } else if (onTap != null) {
                          onTap!();
                        }
                      },
                    ),
                    if (asset != assets.last) const Divider(height: 1),
                  ],
                ),
              )),
        ],
      ),
    );
  }
}
