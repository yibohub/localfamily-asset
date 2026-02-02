import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/financial_models.dart';
import '../../providers/financial_provider.dart';
import '../../providers/custom_type_provider.dart';
import '../../utils/currency_utils.dart';
import '../../widgets/asset_type_filter_bar.dart';
import '../../widgets/custom_type_manage_dialog.dart';
import '../../widgets/financial_record_form.dart';
import '../financial_record_detail_screen.dart';

/// 资产标签页 - 显示所有资产（不含负债）
class AssetsTabScreen extends StatefulWidget {
  const AssetsTabScreen({super.key});

  @override
  State<AssetsTabScreen> createState() => _AssetsTabScreenState();
}

class _AssetsTabScreenState extends State<AssetsTabScreen> {
  String? _selectedTypeId;

  @override
  void initState() {
    super.initState();
    // 加载自定义类型和数据
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<FinancialProvider>().loadFinancialRecords();
      context.read<CustomTypeProvider>().loadCustomTypes();
    });
  }

  /// 获取筛选后的资产列表
  List<Asset> _getFilteredAssets(FinancialProvider provider, CustomTypeProvider customTypeProvider) {
    final assets = provider.assets;
    if (_selectedTypeId == null) {
      return assets;
    }

    return assets.where((asset) {
      // 检查内置类型
      if (asset.type.id == _selectedTypeId) {
        return true;
      }
      // TODO: 检查自定义类型
      return false;
    }).toList();
  }

  /// 设置类型筛选
  void _setTypeFilter(String? typeId) {
    setState(() {
      _selectedTypeId = typeId;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer2<FinancialProvider, CustomTypeProvider>(
      builder: (context, financialProvider, customTypeProvider, child) {
        final filteredAssets = _getFilteredAssets(financialProvider, customTypeProvider);

        if (financialProvider.isLoading) {
          return const Center(child: CircularProgressIndicator());
        }

        // 计算总资产
        final totalAssets = filteredAssets.fold<double>(
          0,
          (sum, asset) => sum + asset.amount,
        );

        return Scaffold(
          body: CustomScrollView(
            slivers: [
              // 顶部统计卡片
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: _AssetsSummaryCard(total: totalAssets),
                ),
              ),

              // 类型筛选栏
              SliverToBoxAdapter(
                child: AssetTypeFilterBar(
                  builtInTypes: AssetTypeExtension.assetTypes,
                  customTypes: customTypeProvider.assetCustomTypes,
                  selectedTypeId: _selectedTypeId,
                  onTypeSelected: _setTypeFilter,
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
                        '资产列表 (${filteredAssets.length})',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // 资产列表
              filteredAssets.isEmpty
                  ? SliverFillRemaining(
                      child: _selectedTypeId != null
                          ? _EmptyFilterState(onClear: () => _setTypeFilter(null))
                          : const _EmptyListState(),
                    )
                  : SliverFillRemaining(
                      child: ListView.builder(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        itemCount: filteredAssets.length,
                        itemBuilder: (context, index) {
                          final asset = filteredAssets[index];
                          return _AssetListItem(
                            asset: asset,
                            onTap: () => _openDetail(context, asset),
                          );
                        },
                      ),
                    ),
            ],
          ),
          floatingActionButton: FloatingActionButton(
            onPressed: () => _showAddDialog(context),
            child: const Icon(Icons.add),
          ),
        );
      },
    );
  }

  /// 打开详情页
  void _openDetail(BuildContext context, Asset asset) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => FinancialRecordDetailScreen(
          recordId: asset.id,
          recordType: RecordType.asset,
        ),
      ),
    );
  }

  /// 显示添加对话框
  void _showAddDialog(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => FinancialRecordFormDialog(
        initialType: RecordType.asset,
      ),
    ).then((result) {
      if (result == true && mounted) {
        context.read<FinancialProvider>().loadFinancialRecords();
      }
    });
  }

  /// 显示管理对话框
  void _showManageDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => const CustomTypeManageDialog(isLiability: false),
    ).then((result) {
      if (result == true && mounted) {
        context.read<CustomTypeProvider>().loadCustomTypes();
      }
    });
  }
}

/// 资产列表项
class _AssetListItem extends StatelessWidget {
  final Asset asset;
  final VoidCallback onTap;

  const _AssetListItem({
    required this.asset,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final assetType = asset.type;
    final iconData = assetType.icon;
    final iconColor = assetType.color;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: iconColor.withOpacity(0.1),
          child: Icon(iconData, color: iconColor, size: 20),
        ),
        title: Text(
          asset.name,
          style: const TextStyle(fontWeight: FontWeight.w500),
        ),
        subtitle: _buildSubtitle(context, asset),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              CurrencyUtils.formatAmount(asset.amount, asset.currency),
              style: TextStyle(
                color: Colors.blue[400],
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ],
        ),
        onTap: onTap,
      ),
    );
  }

  Widget? _buildSubtitle(BuildContext context, Asset asset) {
    final parts = <String>[];

    // 添加类型名称
    parts.add(asset.type.displayName);

    // 添加账户
    if (asset.account != null) {
      parts.add(asset.account!);
    }

    // 添加投资类信息
    if (asset.isInvestment) {
      if (asset.buyPrice != null) {
        parts.add('买入价: ${asset.buyPrice!.toStringAsFixed(2)}');
      }
      if (asset.currentPrice != null) {
        parts.add('现价: ${asset.currentPrice!.toStringAsFixed(2)}');
      }
    }

    // 添加房产信息
    if (asset.type == AssetType.property) {
      if (asset.address != null) {
        parts.add(asset.address!);
      }
      if (asset.buildingArea != null) {
        parts.add('${asset.buildingArea!.toStringAsFixed(0)}㎡');
      }
    }

    if (parts.isEmpty) {
      return null;
    }

    return Text(
      parts.join(' · '),
      style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Colors.grey[600],
          ),
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
              CurrencyUtils.formatAmount(total, 'CNY'),
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
