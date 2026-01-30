import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/asset.dart';
import '../models/custom_asset_type.dart';
import '../providers/custom_type_provider.dart';
import '../utils/currency_utils.dart';
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
  bool _isLiability(BuildContext context) {
    final customTypes = context.read<CustomTypeProvider>().customTypes;
    return assets.first.isLiabilityType(customTypes);
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
              _isLiability(context) ? '负债' : '资产',
              style: TextStyle(
                color: _isLiability(context) ? Colors.red : Colors.green,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '合计 ${CurrencyUtils.formatAmount(_totalAmount, assets.first.currency)}',
              style: TextStyle(
                color: _isLiability(context) ? Colors.red : Colors.green,
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
                    _AssetListItem(
                      asset: asset,
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

/// 内部组件 - 单个资产列表项（支持自定义类型）
class _AssetListItem extends StatelessWidget {
  final Asset asset;
  final VoidCallback onTap;

  const _AssetListItem({
    required this.asset,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final customTypes = context.read<CustomTypeProvider>().customTypes;
    final isLiability = asset.isLiabilityType(customTypes);

    return ListTile(
      dense: true,
      title: Text(asset.account ?? '无账户信息'),
      trailing: Text(
        CurrencyUtils.formatAmount(asset.amount, asset.currency),
        style: TextStyle(
          color: isLiability ? Colors.red : Colors.green,
          fontWeight: FontWeight.bold,
        ),
      ),
      onTap: onTap,
    );
  }
}
