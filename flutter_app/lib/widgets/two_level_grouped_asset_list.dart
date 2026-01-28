import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/asset.dart';
import '../models/custom_asset_type.dart';
import '../providers/custom_type_provider.dart';
import '../utils/currency_utils.dart';
import 'asset_list_item.dart';
import '../screens/asset_form_screen.dart';
import '../screens/asset_detail_screen.dart';

/// 2级分组资产列表组件
///
/// 第1级：按资产名称分组
/// 第2级：在同名资产下，按账户分组
class TwoLevelGroupedAssetList extends StatelessWidget {
  final List<Asset> assets;

  const TwoLevelGroupedAssetList({
    super.key,
    required this.assets,
  });

  @override
  Widget build(BuildContext context) {
    // 第1级：按资产名称分组
    final byName = <String, List<Asset>>{};
    for (final asset in assets) {
      byName.putIfAbsent(asset.name, () => []).add(asset);
    }

    // 按总金额排序
    final sortedNames = byName.entries.toList()
      ..sort((a, b) {
        final totalA = a.value.fold(0.0, (sum, asset) => sum + asset.amount);
        final totalB = b.value.fold(0.0, (sum, asset) => sum + asset.amount);
        return totalB.compareTo(totalA);
      });

    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: sortedNames.length,
      itemBuilder: (context, index) {
        final entry = sortedNames[index];
        return _AssetGroupCard(
          assetName: entry.key,
          assets: entry.value,
        );
      },
    );
  }
}

/// 资产分组卡片（第1级）
class _AssetGroupCard extends StatelessWidget {
  final String assetName;
  final List<Asset> assets;

  const _AssetGroupCard({
    required this.assetName,
    required this.assets,
  });

  double get _totalAmount {
    return assets.fold(0.0, (sum, asset) => sum + asset.amount);
  }

  /// 判断字符串类型是否为负债
  bool _isLiabilityType(BuildContext context, String typeStr) {
    final builtInType = AssetTypeExtension.fromString(typeStr);
    if (builtInType != null) {
      return builtInType.isLiability;
    }
    // 自定义类型：从 Provider 获取
    final customTypeProvider = context.watch<CustomTypeProvider>();
    for (final type in customTypeProvider.customTypes) {
      if (type.id == typeStr) {
        return type.isLiability;
      }
    }
    // 找不到则当作资产处理
    return false;
  }

  @override
  Widget build(BuildContext context) {
    // 第2级：按账户分组
    final byAccount = <String, List<Asset>>{};
    for (final asset in assets) {
      final accountKey = asset.account ?? '无账户';
      byAccount.putIfAbsent(accountKey, () => []).add(asset);
    }

    final isLiability = _isLiabilityType(context, assets.first.type);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          title: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  assetName,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              Text(
                CurrencyUtils.formatAmount(_totalAmount, assets.first.currency),
                style: TextStyle(
                  color: isLiability ? Colors.red : Colors.green,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          subtitle: Text(
            '${assets.length}笔资产，${byAccount.length}个账户',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          children: [
            const Divider(height: 1),
            ...byAccount.entries.map((entry) {
              return _AccountGroupTile(
                accountName: entry.key,
                assets: entry.value,
              );
            }),
          ],
        ),
      ),
    );
  }

  String _formatAmount(double amount) {
    if (amount >= 100000000) {
      return '${(amount / 100000000).toStringAsFixed(2)} 亿';
    } else if (amount >= 10000) {
      return '${(amount / 10000).toStringAsFixed(2)} 万';
    }
    return amount.toStringAsFixed(2);
  }
}

/// 账户分组项（第2级）
class _AccountGroupTile extends StatelessWidget {
  final String accountName;
  final List<Asset> assets;

  const _AccountGroupTile({
    required this.accountName,
    required this.assets,
  });

  double get _totalAmount {
    return assets.fold(0.0, (sum, asset) => sum + asset.amount);
  }

  @override
  Widget build(BuildContext context) {
    // 如果该账户只有1笔资产，直接显示卡片
    if (assets.length == 1) {
      return AssetListItem(
        asset: assets.first,
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => AssetDetailScreen(assetId: assets.first.id),
            ),
          );
        },
      );
    }

    // 多笔资产，显示可展开的账户分组
    return ExpansionTile(
      leading: Icon(
        accountName == '无账户' ? Icons.help_outline : Icons.account_balance_wallet,
        size: 20,
      ),
      title: Text(accountName),
      trailing: Text(
        CurrencyUtils.formatAmount(_totalAmount, assets.first.currency),
        style: TextStyle(
          color: _isLiabilityType(context, assets.first.type) ? Colors.red : Colors.green,
          fontWeight: FontWeight.bold,
        ),
      ),
      subtitle: Text('${assets.length}笔资产'),
      children: [
        const Divider(height: 1),
        ...assets.map((asset) => Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                children: [
                  ListTile(
                    dense: true,
                    title: Text(_formatAssetInfo(context, asset)),
                    trailing: Text(
                      CurrencyUtils.formatAmount(asset.amount, asset.currency),
                      style: TextStyle(
                        color: _isLiabilityType(context, asset.type)
                            ? Colors.red
                            : Colors.green,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => AssetDetailScreen(assetId: asset.id),
                        ),
                      );
                    },
                  ),
                  if (asset != assets.last) const Divider(height: 1),
                ],
              ),
            )),
      ],
    );
  }

  String _formatAssetInfo(BuildContext context, Asset asset) {
    // 获取类型显示名称
    final typeDisplayName = _getTypeDisplayName(context, asset.type);

    final parts = <String>[
      typeDisplayName,
      if (asset.occurrenceDate != null)
        '发生日期: ${asset.occurrenceDate!.year}-${asset.occurrenceDate!.month.toString().padLeft(2, '0')}-${asset.occurrenceDate!.day.toString().padLeft(2, '0')}',
      if (asset.note != null && asset.note!.isNotEmpty)
        '备注: ${asset.note!}',
    ];
    return parts.join(' | ');
  }

  /// 获取类型的显示名称
  String _getTypeDisplayName(BuildContext context, String typeStr) {
    final builtInType = AssetTypeExtension.fromString(typeStr);
    if (builtInType != null) {
      return builtInType.displayName;
    }
    // 自定义类型：从 Provider 获取名称
    final customTypeProvider = context.watch<CustomTypeProvider>();
    for (final type in customTypeProvider.customTypes) {
      if (type.id == typeStr) {
        return type.name;
      }
    }
    // 找不到则返回原始字符串（移除 custom_ 前缀作为后备）
    return typeStr.replaceAll('custom_', '');
  }

  /// 判断字符串类型是否为负债
  bool _isLiabilityType(BuildContext context, String typeStr) {
    final builtInType = AssetTypeExtension.fromString(typeStr);
    if (builtInType != null) {
      return builtInType.isLiability;
    }
    // 自定义类型：从 Provider 获取
    final customTypeProvider = context.watch<CustomTypeProvider>();
    for (final type in customTypeProvider.customTypes) {
      if (type.id == typeStr) {
        return type.isLiability;
      }
    }
    // 找不到则当作资产处理
    return false;
  }
}
