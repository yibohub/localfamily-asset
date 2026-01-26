import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/asset.dart';
import '../../providers/asset_provider.dart';
import '../../widgets/asset_list_item.dart';
import '../asset_form_screen.dart';
import '../asset_detail_screen.dart';

/// 负债标签页 - 显示所有负债
class LiabilitiesTabScreen extends StatelessWidget {
  const LiabilitiesTabScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AssetProvider>(
      builder: (context, provider, child) {
        final liabilities = provider.liabilitiesOnly;

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
                  child: _LiabilitiesSummaryCard(total: provider.summary.totalLiabilities),
                ),
              ),

              // 负债列表标题
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                  child: Row(
                    children: [
                      Text(
                        '负债列表 (${liabilities.length})',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // 负债列表
              liabilities.isEmpty
                  ? SliverFillRemaining(
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.credit_card_off,
                              size: 64,
                              color: Colors.grey[400],
                            ),
                            const SizedBox(height: 16),
                            Text(
                              '还没有负债记录',
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
                  : SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          final asset = liabilities[index];
                          return AssetListItem(
                            asset: asset,
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => AssetDetailScreen(assetId: asset.id),
                                ),
                              );
                            },
                          );
                        },
                        childCount: liabilities.length,
                      ),
                    ),
            ],
          ),
          floatingActionButton: FloatingActionButton(
            backgroundColor: Colors.red[400],
            onPressed: () async {
              final result = await Navigator.push<bool>(
                context,
                MaterialPageRoute(
                  builder: (_) => const AssetFormScreen(
                    assetTypesFilter: true, // 仅显示负债类型
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

/// 负债统计卡片
class _LiabilitiesSummaryCard extends StatelessWidget {
  final double total;

  const _LiabilitiesSummaryCard({required this.total});

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
                  Icons.credit_card,
                  color: Colors.red[400],
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  '总负债',
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
                color: Colors.red[400],
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
