import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/asset_provider.dart';
import '../models/asset.dart';
import '../widgets/grouped_asset_list_item.dart';
import 'asset_form_screen.dart';

/// 资产列表页面（按类型筛选）
class AssetListScreen extends StatelessWidget {
  final AssetType? assetType;

  const AssetListScreen({super.key, this.assetType});

  @override
  Widget build(BuildContext context) {
    final assetProvider = context.watch<AssetProvider>();
    final assets = assetType != null
        ? assetProvider.getAssetsByType(assetType!.snakeCaseName)
        : assetProvider.assets;

    return Scaffold(
      appBar: AppBar(
        title: Text(assetType?.displayName ?? '所有资产'),
        actions: [
          // 切换显示模式的按钮
          IconButton(
            icon: const Icon(Icons.view_list),
            onPressed: () {
              // TODO: 实现显示模式切换
            },
            tooltip: '切换显示模式',
          ),
        ],
      ),
      body: assets.isEmpty
          ? _buildEmptyState()
          : _buildGroupedList(assets),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => AssetFormScreen(defaultType: assetType),
            ),
          );
        },
        backgroundColor: const Color(0xFF2563EB),
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  /// 构建分组列表
  Widget _buildGroupedList(List<Asset> assets) {
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

    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: sortedGroups.length,
      itemBuilder: (context, index) {
        final entry = sortedGroups[index];
        return GroupedAssetListItem(
          groupName: entry.key,
          assets: entry.value,
          onTap: () {
            // 点击任意资产进入详情
            if (entry.value.length == 1) {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => AssetFormScreen(asset: entry.value.first),
                ),
              );
            }
          },
          onAssetTap: (asset) {
            // 对于分组中的每个资产，点击进入编辑页
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => AssetFormScreen(asset: asset),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.inbox,
            size: 80,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            '还没有${assetType?.displayName ?? '资产'}记录',
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '点击右下角的 + 按钮添加',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[500],
            ),
          ),
        ],
      ),
    );
  }
}
