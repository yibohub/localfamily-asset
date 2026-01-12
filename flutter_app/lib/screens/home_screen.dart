import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/asset.dart';
import '../providers/auth_provider.dart';
import '../providers/asset_provider.dart';
import '../widgets/asset_summary_card.dart';
import '../widgets/asset_list_item.dart';
import '../widgets/add_asset_dialog.dart';
import 'asset_detail_screen.dart';

/// 主页
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() => context.read<AssetProvider>().loadAssets());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('资产概览'),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () {},
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () => _showSettings(context),
          ),
        ],
      ),
      body: Consumer<AssetProvider>(
        builder: (context, provider, _) {
          if (provider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (provider.error != null) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 48, color: Colors.red),
                  const SizedBox(height: 16),
                  Text(provider.error!),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: () => provider.loadAssets(),
                    child: const Text('重试'),
                  ),
                ],
              ),
            );
          }

          final summary = provider.summary;

          return RefreshIndicator(
            onRefresh: () => provider.loadAssets(),
            child: CustomScrollView(
              slivers: [
                // 资产总览卡片
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: AssetSummaryCard(summary: summary),
                  ),
                ),

                // 资产列表
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  sliver: provider.assets.isEmpty
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
                                  '暂无资产',
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleMedium
                                      ?.copyWith(color: Colors.grey[600]),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  '点击右下角按钮添加您的第一个资产',
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodyMedium
                                      ?.copyWith(color: Colors.grey[500]),
                                ),
                              ],
                            ),
                          ),
                        )
                      : SliverList(
                          delegate: SliverChildBuilderDelegate(
                            (context, index) {
                              final asset = provider.assets[index];
                              return AssetListItem(
                                asset: asset,
                                onTap: () => _openAssetDetail(context, asset),
                                onEdit: () => _editAsset(context, asset),
                                onDelete: () => _deleteAsset(context, asset),
                              );
                            },
                            childCount: provider.assets.length,
                          ),
                        ),
                ),

                // 底部间距
                const SliverPadding(padding: EdgeInsets.only(bottom: 88)),
              ],
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _addAsset(context),
        icon: const Icon(Icons.add),
        label: const Text('添加资产'),
      ),
    );
  }

  void _addAsset(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => const AddAssetDialog(),
    );
  }

  void _editAsset(BuildContext context, Asset asset) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => AddAssetDialog(asset: asset),
    );
  }

  void _deleteAsset(BuildContext context, Asset asset) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('删除资产'),
        content: Text('确定要删除 "${asset.name}" 吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () async {
              final provider = context.read<AssetProvider>();
              await provider.deleteAsset(asset.id);
              if (context.mounted) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('资产已删除')),
                );
              }
            },
            child: const Text('删除'),
          ),
        ],
      ),
    );
  }

  void _openAssetDetail(BuildContext context, Asset asset) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AssetDetailScreen(assetId: asset.id),
      ),
    );
  }

  void _showSettings(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.lock),
              title: const Text('锁定应用'),
              onTap: () {
                Navigator.pop(context);
                context.read<AuthProvider>().lock();
              },
            ),
            ListTile(
              leading: const Icon(Icons.file_download),
              title: const Text('导出数据'),
              onTap: () {
                Navigator.pop(context);
                _exportData(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.file_upload),
              title: const Text('导入数据'),
              onTap: () {
                Navigator.pop(context);
                _importData(context);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _exportData(BuildContext context) async {
    // TODO: 实现导出功能
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('导出功能待实现')),
    );
  }

  Future<void> _importData(BuildContext context) async {
    // TODO: 实现导入功能
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('导入功能待实现')),
    );
  }
}
