/// 金融记录列表页面（资产/负债分离模型）
///
/// 使用 FinancialProvider，支持资产/负债标签页

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/financial_provider.dart';
import '../models/financial_models.dart';
import '../widgets/financial_record_form.dart';
import 'financial_record_detail_screen.dart';

/// 金融记录列表页面
class FinancialListScreen extends StatefulWidget {
  const FinancialListScreen({super.key});

  @override
  State<FinancialListScreen> createState() => _FinancialListScreenState();
}

class _FinancialListScreenState extends State<FinancialListScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    // 加载数据
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<FinancialProvider>().loadFinancialRecords();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('资产与负债'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: '资产'),
            Tab(text: '负债'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _AssetsTab(),
          _LiabilitiesTab(),
        ],
      ),
      floatingActionButton: _buildAddButton(context),
    );
  }

  Widget _buildAddButton(BuildContext context) {
    return FloatingActionButton.extended(
      onPressed: () => _showAddDialog(context),
      icon: const Icon(Icons.add),
      label: const Text('添加'),
    );
  }

  void _showAddDialog(BuildContext context) {
    final currentIndex = _tabController.index;
    final initialType = currentIndex == 0 ? RecordType.asset : RecordType.liability;
    final provider = context.read<FinancialProvider>();

    // 传递 Provider 中保存的最后选择类型
    final initialAssetType = provider.lastSelectedAssetType;
    final initialLiabilityType = provider.lastSelectedLiabilityType;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => FinancialRecordFormDialog(
        initialType: initialType,
        initialAssetType: initialAssetType,
        initialLiabilityType: initialLiabilityType,
      ),
    );
  }
}

/// 资产标签页
class _AssetsTab extends StatelessWidget {
  const _AssetsTab({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<FinancialProvider>();

    if (provider.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    final assets = provider.assets;

    if (assets.isEmpty) {
      return _buildEmptyState(context, '资产', '点击 + 添加您的第一笔资产');
    }

    return Column(
      children: [
        // 资产汇总卡片
        _AssetSummaryCard(provider: provider),
        // 资产列表
        Expanded(
          child: ListView.builder(
            itemCount: assets.length,
            itemBuilder: (context, index) {
              final asset = assets[index];
              return _AssetListItem(asset: asset);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState(BuildContext context, String title, String subtitle) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            title == '资产' ? Icons.account_balance_wallet : Icons.credit_card,
            size: 64,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            '暂无$title',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Colors.grey[600],
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

/// 负债标签页
class _LiabilitiesTab extends StatelessWidget {
  const _LiabilitiesTab({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<FinancialProvider>();

    if (provider.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    final liabilities = provider.liabilities;

    if (liabilities.isEmpty) {
      return _buildEmptyState(context, '负债', '点击 + 添加您的第一笔负债');
    }

    return Column(
      children: [
        // 负债汇总卡片
        _LiabilitySummaryCard(provider: provider),
        // 负债列表
        Expanded(
          child: ListView.builder(
            itemCount: liabilities.length,
            itemBuilder: (context, index) {
              final liability = liabilities[index];
              return _LiabilityListItem(liability: liability);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState(BuildContext context, String title, String subtitle) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            title == '资产' ? Icons.account_balance_wallet : Icons.credit_card,
            size: 64,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            '暂无$title',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Colors.grey[600],
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

/// 资产汇总卡片
class _AssetSummaryCard extends StatelessWidget {
  final FinancialProvider provider;

  const _AssetSummaryCard({required this.provider, super.key});

  @override
  Widget build(BuildContext context) {
    final totalAssets = provider.totalAssets;
    final totalInvestmentCost = provider.totalInvestmentCost;
    final totalProfitLoss = provider.totalInvestmentProfitLoss;

    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '资产总览',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildSummaryItem(context, '总资产', _formatAmount(totalAssets)),
                if (totalInvestmentCost != null && totalInvestmentCost > 0)
                  _buildSummaryItem(context, '投资成本', _formatAmount(totalInvestmentCost)),
              ],
            ),
            if (totalProfitLoss != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: _buildSummaryItem(
                  context,
                  '总盈亏',
                  '${totalProfitLoss >= 0 ? '+' : ''}${_formatAmount(totalProfitLoss)}',
                  color: totalProfitLoss >= 0 ? Colors.green : Colors.red,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryItem(BuildContext context, String label, String value, {Color? color}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Colors.grey[600],
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            color: color ?? Colors.black87,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  String _formatAmount(double amount) {
    if (amount >= 10000) {
      return '¥${(amount / 10000).toStringAsFixed(2)}万';
    } else if (amount >= 1000) {
      return '¥${(amount / 1000).toStringAsFixed(1)}k';
    }
    return '¥${amount.toStringAsFixed(2)}';
  }
}

/// 负债汇总卡片
class _LiabilitySummaryCard extends StatelessWidget {
  final FinancialProvider provider;

  const _LiabilitySummaryCard({required this.provider, super.key});

  @override
  Widget build(BuildContext context) {
    final totalLiabilities = provider.totalLiabilities;
    final netAssets = provider.netAssets;

    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '负债总览',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildSummaryItem(context, '总负债', _formatAmount(totalLiabilities)),
                _buildSummaryItem(context, '净资产', _formatAmount(netAssets)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryItem(BuildContext context, String label, String value, {Color? color}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Colors.grey[600],
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            color: color ?? Colors.black87,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  String _formatAmount(double amount) {
    if (amount >= 10000) {
      return '¥${(amount / 10000).toStringAsFixed(2)}万';
    } else if (amount >= 1000) {
      return '¥${(amount / 1000).toStringAsFixed(1)}k';
    }
    return '¥${amount.toStringAsFixed(2)}';
  }
}

/// 资产列表项
class _AssetListItem extends StatelessWidget {
  final Asset asset;

  const _AssetListItem({required this.asset, super.key});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: _buildTypeIcon(),
      title: Text(asset.name),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(_formatAmount(asset.amount)),
          if (asset.isInvestment && asset.profitLossPercent != null)
            Text(
              '盈亏: ${asset.profitLossPercent!.toStringAsFixed(2)}%',
              style: TextStyle(
                color: asset.profitLossPercent! >= 0 ? Colors.green : Colors.red,
                fontSize: 12,
              ),
            ),
        ],
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(asset.type.displayName),
          const Icon(Icons.chevron_right),
        ],
      ),
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => FinancialRecordDetailScreen(
              recordId: asset.id,
              recordType: RecordType.asset,
            ),
          ),
        );
      },
    );
  }

  Widget _buildTypeIcon() {
    switch (asset.type) {
      case AssetType.property:
        return const CircleAvatar(
          backgroundColor: Colors.blue,
          child: Icon(Icons.home, color: Colors.white, size: 20),
        );
      case AssetType.deposit:
        return const CircleAvatar(
          backgroundColor: Colors.green,
          child: Icon(Icons.account_balance, color: Colors.white, size: 20),
        );
      case AssetType.stock:
        return const CircleAvatar(
          backgroundColor: Colors.orange,
          child: Icon(Icons.trending_up, color: Colors.white, size: 20),
        );
      case AssetType.fund:
        return const CircleAvatar(
          backgroundColor: Colors.purple,
          child: Icon(Icons.pie_chart, color: Colors.white, size: 20),
        );
      case AssetType.insurance:
        return const CircleAvatar(
          backgroundColor: Colors.teal,
          child: Icon(Icons.security, color: Colors.white, size: 20),
        );
    }
  }

  String _formatAmount(double amount) {
    if (amount >= 10000) {
      return '¥${(amount / 10000).toStringAsFixed(2)}万';
    } else if (amount >= 1000) {
      return '¥${(amount / 1000).toStringAsFixed(1)}k';
    }
    return '¥${amount.toStringAsFixed(2)}';
  }
}

/// 负债列表项
class _LiabilityListItem extends StatelessWidget {
  final Liability liability;

  const _LiabilityListItem({required this.liability, super.key});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: _buildTypeIcon(),
      title: Text(liability.name),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(_formatAmount(liability.amount)),
          if (liability.dueDate != null)
            Text(
              '到期日: ${_formatDate(liability.dueDate!)}',
              style: const TextStyle(fontSize: 12),
            ),
        ],
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(liability.type.displayName),
          const Icon(Icons.chevron_right),
        ],
      ),
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => FinancialRecordDetailScreen(
              recordId: liability.id,
              recordType: RecordType.liability,
            ),
          ),
        );
      },
    );
  }

  Widget _buildTypeIcon() {
    switch (liability.type) {
      case LiabilityType.debt:
        return const CircleAvatar(
          backgroundColor: Colors.grey,
          child: Icon(Icons.money_off, color: Colors.white, size: 20),
        );
      case LiabilityType.mortgage:
        return const CircleAvatar(
          backgroundColor: Colors.brown,
          child: Icon(Icons.home_work, color: Colors.white, size: 20),
        );
      case LiabilityType.carLoan:
        return const CircleAvatar(
          backgroundColor: Colors.indigo,
          child: Icon(Icons.directions_car, color: Colors.white, size: 20),
        );
      case LiabilityType.creditCard:
        return const CircleAvatar(
          backgroundColor: Colors.deepOrange,
          child: Icon(Icons.credit_card, color: Colors.white, size: 20),
        );
      case LiabilityType.personalLoan:
        return const CircleAvatar(
          backgroundColor: Colors.cyan,
          child: Icon(Icons.person, color: Colors.white, size: 20),
        );
      case LiabilityType.privateLoan:
        return const CircleAvatar(
          backgroundColor: Colors.lightBlue,
          child: Icon(Icons.handshake, color: Colors.white, size: 20),
        );
    }
  }

  String _formatAmount(double amount) {
    if (amount >= 10000) {
      return '¥${(amount / 10000).toStringAsFixed(2)}万';
    } else if (amount >= 1000) {
      return '¥${(amount / 1000).toStringAsFixed(1)}k';
    }
    return '¥${amount.toStringAsFixed(2)}';
  }

  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }
}
