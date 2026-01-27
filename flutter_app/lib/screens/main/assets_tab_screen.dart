import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/asset.dart';
import '../../providers/asset_provider.dart';
import '../../widgets/asset_summary_card.dart';
import '../../widgets/asset_list_item.dart';
import '../../widgets/grouped_asset_list_item.dart';
import '../asset_form_screen.dart';
import '../asset_detail_screen.dart';

/// 资产标签页 - 显示所有资产（不含负债）
class AssetsTabScreen extends StatelessWidget {
  const AssetsTabScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AssetProvider>(
      builder: (context, provider, child) {
        final assets = provider.assetsOnly;

        if (provider.isLoading) {
          return const Center(child: CircularProgressIndicator());
        }

        return Scaffold(
          body: CustomScrollView(
            slivers: [
              // 顶部统计卡片
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: _AssetsSummaryCard(total: provider.summary.totalAssets),
                ),
              ),

              // 资产列表标题
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                  child: Row(
                    children: [
                      Text(
                        '资产列表 (${assets.length})',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // 资产列表
              assets.isEmpty
                  ? SliverFillRemaining(
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.account_balance_wallet_outlined,
                              size: 64,
                              color: Colors.grey[400],
                            ),
                            const SizedBox(height: 16),
                            Text(
                              '还没有资产记录',
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.grey[600],
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              '点击右下角按钮添加',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey[500],
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  : _buildGroupedAssetList(assets),
            ],
          ),
          floatingActionButton: FloatingActionButton(
            onPressed: () async {
              final result = await Navigator.push<bool>(
                context,
                MaterialPageRoute(
                  builder: (_) => const AssetFormScreen(
                    assetTypesFilter: false, // 仅显示资产类型
                  ),
                ),
              );
              if (result == true && context.mounted) {
                context.read<AssetProvider>().loadAssets();
              }
            },
            child: const Icon(Icons.add),
          ),
        );
      },
    );
  }
}

/// 资产统计卡片
class _AssetsSummaryCard extends StatelessWidget {
  final double total;

  const _AssetsSummaryCard({required this.total});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.account_balance_wallet,
                  color: colorScheme.primary,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  '总资产',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              '¥ ${_formatAmount(total)}',
              style: theme.textTheme.headlineMedium?.copyWith(
                color: colorScheme.primary,
                fontWeight: FontWeight.bold,
              ),
            ),
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
    } else {
      return amount.toStringAsFixed(2);
    }
  }
}

/// 构建分组资产列表
Widget _buildGroupedAssetList(List<Asset> assets) {
  // 按名称分组
  final grouped = <String, List<Asset>>{};
  for (final asset in assets) {
    grouped.putIfAbsent(asset.name, () => []).add(asset);
  }

  // 转换为列表并按总金额排序
  final sortedGroups = grouped.entries.toList()
    ..sort((a, b) {
      final totalA = a.value.fold(0.0, (sum, asset) => sum + asset.amount);
      final totalB = b.value.fold(0.0, (sum, asset) => sum + asset.amount);
      return totalB.compareTo(totalA);
    });

  return SliverList(
    delegate: SliverChildBuilderDelegate(
      (context, index) {
        final entry = sortedGroups[index];
        return GroupedAssetListItem(
          groupName: entry.key,
          assets: entry.value,
          onTap: () {
            // 对于单个资产，点击进入详情页
            if (entry.value.length == 1) {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => AssetDetailScreen(assetId: entry.value.first.id),
                ),
              );
            }
          },
          onAssetTap: (asset) {
            // 对于分组中的每个资产，点击进入详情页
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => AssetDetailScreen(assetId: asset.id),
              ),
            );
          },
        );
      },
      childCount: sortedGroups.length,
    ),
  );
}
