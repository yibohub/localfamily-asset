import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/financial_models.dart';
import '../../providers/financial_provider.dart';
import '../../providers/custom_type_provider.dart';
import '../../utils/currency_utils.dart';
import '../../widgets/liability_grouped_list.dart';
import '../../widgets/asset_type_filter_bar.dart';
import '../../widgets/custom_type_manage_dialog.dart';
import '../asset_form_screen.dart';

/// 负债标签页 - 显示所有负债
class LiabilitiesTabScreen extends StatefulWidget {
  const LiabilitiesTabScreen({super.key});

  @override
  State<LiabilitiesTabScreen> createState() => _LiabilitiesTabScreenState();
}

class _LiabilitiesTabScreenState extends State<LiabilitiesTabScreen> {
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
    return Consumer<FinancialProvider>(
      builder: (context, provider, child) {
        final liabilities = provider.filteredLiabilities;

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
                  child: _LiabilitiesSummaryCard(total: provider.totalLiabilities),
                ),
              ),

              // 类型筛选栏（排除通用负债类型，只显示具体负债小类）
              SliverToBoxAdapter(
                child: AssetTypeFilterBar(
                  builtInTypes: LiabilityType.values
                      .where((t) => t != LiabilityType.debt)
                      .map((t) => t.toAssetType())
                      .toList(),
                  customTypes: context.read<CustomTypeProvider>().liabilityCustomTypes,
                  selectedTypeId: provider.liabilityTypeFilterId,
                  onTypeSelected: (id) => provider.setLiabilityTypeFilterById(id),
                  onManageCustomTypes: () => _showManageDialog(context),
                  allLabel: '全部负债',
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
                      child: provider.liabilityTypeFilterId != null
                          ? _EmptyFilterState(onClear: () => provider.clearLiabilityTypeFilter())
                          : const _EmptyListState(),
                    )
                  : SliverFillRemaining(
                      child: LiabilityGroupedList(liabilities: liabilities),
                    ),
            ],
          ),
          floatingActionButton: FloatingActionButton(
            backgroundColor: Colors.red[400],
            onPressed: () async {
              final result = await Navigator.push<bool>(
                context,
                MaterialPageRoute(
                  builder: (_) => AssetFormScreen(
                    assetTypesFilter: true, // 仅显示负债类型
                    defaultTypeId: provider.liabilityTypeFilterId, // 传递当前筛选的类型 ID（支持自定义类型）
                  ),
                ),
              );
              if (result == true && mounted) {
                context.read<FinancialProvider>().loadFinancialRecords();
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
      builder: (_) => const CustomTypeManageDialog(isLiability: true),
    ).then((result) {
      if (result == true && mounted) {
        if (mounted) {
          context.read<CustomTypeProvider>().loadCustomTypes();
        }
        // TODO: 重新加载负债列表
      }
    });
  }
}

/// 负债统计卡片
class _LiabilitiesSummaryCard extends StatelessWidget {
  final double total;

  const _LiabilitiesSummaryCard({required this.total});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

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
              CurrencyUtils.formatAmount(total, 'CNY'),
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
          Text('该类型下暂无负债', style: TextStyle(fontSize: 16, color: Colors.grey[600])),
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
          Icon(Icons.credit_card_off, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text('还没有负债记录', style: TextStyle(fontSize: 16, color: Colors.grey[600])),
          const SizedBox(height: 8),
          Text('点击右下角按钮添加', style: TextStyle(fontSize: 14, color: Colors.grey[500])),
        ],
      ),
    );
  }
}
