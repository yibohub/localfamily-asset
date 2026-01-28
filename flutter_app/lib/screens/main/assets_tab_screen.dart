import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/asset.dart';
import '../../providers/asset_provider.dart';
import '../../providers/custom_type_provider.dart';
import '../../widgets/two_level_grouped_asset_list.dart';
import '../../widgets/asset_type_filter_bar.dart';
import '../../widgets/custom_type_manage_dialog.dart';
import '../asset_form_screen.dart';

/// 资产标签页 - 显示所有资产（不含负债）
class AssetsTabScreen extends StatefulWidget {
  const AssetsTabScreen({super.key});

  @override
  State<AssetsTabScreen> createState() => _AssetsTabScreenState();
}

class _AssetsTabScreenState extends State<AssetsTabScreen> {
  @override
  void initState() {
    super.initState();
    // 加载自定义类型
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<CustomTypeProvider>().loadCustomTypes();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer2<AssetProvider, CustomTypeProvider>(
      builder: (context, assetProvider, customTypeProvider, child) {
        final assets = assetProvider.filteredAssetsOnly;

        if (assetProvider.isLoading) {
          return const Center(child: CircularProgressIndicator());
        }

        return Scaffold(
          body: CustomScrollView(
            slivers: [
              // 顶部统计卡片
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: _AssetsSummaryCard(total: assetProvider.summary.totalAssets),
                ),
              ),

              // 类型筛选栏
              SliverToBoxAdapter(
                child: AssetTypeFilterBar(
                  builtInTypes: AssetTypeExtension.assetTypes,
                  customTypes: customTypeProvider.assetCustomTypes,
                  selectedTypeId: assetProvider.assetTypeFilterId,
                  onTypeSelected: (id) => assetProvider.setAssetTypeFilterById(id),
                  onManageCustomTypes: () => _showManageDialog(context),
                  allLabel: '全部资产',
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
                      child: assetProvider.assetTypeFilterId != null
                          ? _EmptyFilterState(onClear: () => assetProvider.clearAssetTypeFilter())
                          : const _EmptyListState(),
                    )
                  : SliverFillRemaining(
                      child: TwoLevelGroupedAssetList(assets: assets),
                    ),
            ],
          ),
          floatingActionButton: FloatingActionButton(
            onPressed: () async {
              final result = await Navigator.push<bool>(
                context,
                MaterialPageRoute(
                  builder: (_) => AssetFormScreen(
                    assetTypesFilter: false, // 仅显示资产类型
                    defaultType: assetProvider.assetTypeFilter, // 传递当前筛选的类型
                  ),
                ),
              );
              if (result == true && mounted) {
                context.read<AssetProvider>().loadAssets();
              }
            },
            child: const Icon(Icons.add),
          ),
        );
      },
    );
  }

  /// 显示管理对话框
  void _showManageDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => const CustomTypeManageDialog(isLiability: false),
    ).then((result) {
      if (result == true && mounted) {
        if (mounted) {
          context.read<CustomTypeProvider>().loadCustomTypes();
        }
        // TODO: 重新加载资产列表
      }
    });
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

/// 筛选后无结果状态的空状态
class _EmptyFilterState extends StatelessWidget {
  final VoidCallback onClear;
  const _EmptyFilterState({required this.onClear});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.filter_list_off, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text('该类型下暂无资产', style: TextStyle(fontSize: 16, color: Colors.grey[600])),
          const SizedBox(height: 24),
          FilledButton.tonalIcon(
            onPressed: onClear,
            icon: const Icon(Icons.clear_all),
            label: const Text('清除筛选'),
          ),
        ],
      ),
    );
  }
}

/// 默认空状态
class _EmptyListState extends StatelessWidget {
  const _EmptyListState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.account_balance_wallet_outlined, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text('还没有资产记录', style: TextStyle(fontSize: 16, color: Colors.grey[600])),
          const SizedBox(height: 8),
          Text('点击右下角按钮添加', style: TextStyle(fontSize: 14, color: Colors.grey[500])),
        ],
      ),
    );
  }
}
