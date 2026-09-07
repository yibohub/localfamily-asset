import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/financial_models.dart';
import '../../providers/financial_provider.dart';
import '../../providers/custom_type_provider.dart';
import '../../utils/currency_utils.dart';
import '../../widgets/asset_type_filter_bar.dart';
import '../../widgets/custom_type_manage_dialog.dart';
import '../financial_record_form_screen.dart';
import '../financial_record_detail_screen.dart';

/// 规范化资产名称用于分组（去除所有可能导致无法匹配的差异）
String _normalizeGroupName(String name) {
  // 去除首尾空格
  var normalized = name.trim();
  // 去除所有内部空格
  normalized = normalized.replaceAll(' ', '');
  // 去除零宽空格和其他不可见字符
  normalized = normalized.replaceAll(RegExp(r'[\u200B\u200C\u200D\uFEFF]'), '');
  return normalized;
}

/// 资产标签页 - 显示所有资产（不含负债）
class AssetsTabScreen extends StatefulWidget {
  /// 从总览跳转时预设的类型筛选 id（null = 全部）
  final String? initialTypeFilter;

  /// 跳转指令序号：总览每次主动下发筛选时递增。
  /// IndexedStack 保活下页签 State 不重建，普通页签切换也会重新下发相同
  /// 配置，只有序号变化才视为一次新的跳转指令
  final int filterCommandSeq;

  const AssetsTabScreen({
    super.key,
    this.initialTypeFilter,
    this.filterCommandSeq = 0,
  });

  @override
  State<AssetsTabScreen> createState() => _AssetsTabScreenState();
}

class _AssetsTabScreenState extends State<AssetsTabScreen> {
  String? _selectedTypeId;
  int _appliedFilterSeq = 0;

  @override
  void initState() {
    super.initState();
    _selectedTypeId = widget.initialTypeFilter;
    _appliedFilterSeq = widget.filterCommandSeq;
  }

  @override
  void didUpdateWidget(covariant AssetsTabScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 只响应总览主动下发的跳转指令（序号变化）：
    // 点分布条目设筛选，点"总资产"行清除；用户手选筛选不受页签切换影响
    if (widget.filterCommandSeq != _appliedFilterSeq) {
      setState(() {
        _selectedTypeId = widget.initialTypeFilter;
      });
      _appliedFilterSeq = widget.filterCommandSeq;
    }
  }

  /// 获取筛选后的资产列表
  List<Asset> _getFilteredAssets(
      FinancialProvider provider, CustomTypeProvider customTypeProvider) {
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
    // 同时保存到 Provider，以便添加时使用
    if (typeId != null) {
      final assetType = AssetTypeExtension.fromString(typeId);
      if (assetType != null) {
        context.read<FinancialProvider>().setLastSelectedAssetType(assetType);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer2<FinancialProvider, CustomTypeProvider>(
      builder: (context, financialProvider, customTypeProvider, child) {
        final filteredAssets =
            _getFilteredAssets(financialProvider, customTypeProvider);

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
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16.0, vertical: 8.0),
                  child: Row(
                    children: [
                      Text(
                        '资产列表 (${filteredAssets.length})',
                        style:
                            Theme.of(context).textTheme.titleMedium?.copyWith(
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
                          ? _EmptyFilterState(
                              onClear: () => _setTypeFilter(null))
                          : const _EmptyListState(),
                    )
                  : SliverFillRemaining(
                      child: _AssetGroupedList(assets: filteredAssets),
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

  /// 显示添加页面
  void _showAddDialog(BuildContext context) {
    // 从筛选器或 Provider 获取初始类型
    AssetType? initialAssetType;
    if (_selectedTypeId != null) {
      initialAssetType = AssetTypeExtension.fromString(_selectedTypeId!);
    }
    if (initialAssetType == null) {
      initialAssetType =
          context.read<FinancialProvider>().lastSelectedAssetType;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => FinancialRecordFormScreen(
          initialType: RecordType.asset,
          initialAssetType: initialAssetType,
        ),
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
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
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
          Text('该类型下暂无资产',
              style: TextStyle(fontSize: 16, color: Colors.grey[600])),
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
          Icon(Icons.account_balance_wallet_outlined,
              size: 64, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text('还没有资产记录',
              style: TextStyle(fontSize: 16, color: Colors.grey[600])),
          const SizedBox(height: 8),
          Text('点击右下角按钮添加',
              style: TextStyle(fontSize: 14, color: Colors.grey[500])),
        ],
      ),
    );
  }
}

/// 资产分组列表（同名资产合并显示）
class _AssetGroupedList extends StatelessWidget {
  final List<Asset> assets;

  const _AssetGroupedList({required this.assets});

  @override
  Widget build(BuildContext context) {
    // 按名称分组
    final grouped = <String, List<Asset>>{};
    for (final asset in assets) {
      final normalizedName = _normalizeGroupName(asset.name);
      if (!grouped.containsKey(normalizedName)) {
        grouped[normalizedName] = [];
      }
      grouped[normalizedName]!.add(asset);
    }

    // 转换为列表并按总金额排序
    final sortedGroups = grouped.entries.toList()
      ..sort((a, b) {
        final totalA =
            a.value.fold<double>(0.0, (sum, asset) => sum + asset.amount);
        final totalB =
            b.value.fold<double>(0.0, (sum, asset) => sum + asset.amount);
        return totalB.compareTo(totalA);
      });

    // 调试输出
    if (kDebugMode) {
      debugPrint('🔍 资产分组调试:');
      debugPrint('  总资产数: ${assets.length}');
      debugPrint('  分组数: ${sortedGroups.length}');
      for (final entry in sortedGroups) {
        debugPrint('  "${entry.key}": ${entry.value.length} 个账户');
      }
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: sortedGroups.length,
      itemBuilder: (context, index) {
        final entry = sortedGroups[index];
        return _AssetGroupListItem(
          groupName: entry.key,
          assets: entry.value,
        );
      },
    );
  }
}

/// 资产分组列表项
class _AssetGroupListItem extends StatelessWidget {
  final String groupName;
  final List<Asset> assets;

  const _AssetGroupListItem({
    required this.groupName,
    required this.assets,
  });

  /// 计算分组总金额
  double get _totalAmount {
    return assets.fold(0.0, (sum, asset) => sum + asset.amount);
  }

  /// 获取分组显示名称（使用第一个资产的原始名称）
  String get _displayName {
    return assets.first.name;
  }

  @override
  Widget build(BuildContext context) {
    // 单个资产：直接显示
    if (assets.length == 1) {
      return _AssetListItem(
        asset: assets.first,
        onTap: () => _openDetail(context, assets.first),
      );
    }

    // 多个同名资产：显示可展开的分组
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: ExpansionTile(
        leading: CircleAvatar(
          backgroundColor: assets.first.type.color.withOpacity(0.1),
          child: Icon(assets.first.type.icon,
              color: assets.first.type.color, size: 20),
        ),
        title: Text(
          _displayName,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Row(
          children: [
            Text(
              '${assets.length}个账户',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                '合计 ${CurrencyUtils.formatAmount(_totalAmount, 'CNY')}',
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.blue,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        children: [
          const Divider(height: 1),
          ...assets.asMap().entries.map((entry) {
            final index = entry.key;
            final asset = entry.value;
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                children: [
                  _AssetSubListItem(
                    asset: asset,
                    onTap: () => _openDetail(context, asset),
                  ),
                  if (index < assets.length - 1) const Divider(height: 1),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

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
}

/// 资产子列表项（分组内显示）
class _AssetSubListItem extends StatelessWidget {
  final Asset asset;
  final VoidCallback onTap;

  const _AssetSubListItem({
    required this.asset,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      dense: true,
      title: Text(asset.account ?? '无账户'),
      subtitle: _buildSubtitle(context, asset),
      trailing: Text(
        CurrencyUtils.formatAmount(asset.amount, asset.currency),
        style: const TextStyle(
          color: Colors.blue,
          fontWeight: FontWeight.bold,
        ),
      ),
      onTap: onTap,
    );
  }

  Widget? _buildSubtitle(BuildContext context, Asset asset) {
    final parts = <String>[];

    // 添加类型名称
    parts.add(asset.type.displayName);

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
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
      style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Colors.grey[600],
          ),
    );
  }
}
