/// 金融记录详情页面（支持资产/负债分离模型）
///
/// 显示资产或负债的完整信息，包括所有扩展字段

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/financial_models.dart';
import '../providers/financial_provider.dart';
import '../widgets/financial_record_form.dart' show RecordType;
import 'financial_record_form_screen.dart';

/// 金融记录详情页
class FinancialRecordDetailScreen extends StatefulWidget {
  final String recordId;
  final RecordType recordType;

  const FinancialRecordDetailScreen({
    super.key,
    required this.recordId,
    required this.recordType,
  });

  @override
  State<FinancialRecordDetailScreen> createState() => _FinancialRecordDetailScreenState();
}

class _FinancialRecordDetailScreenState extends State<FinancialRecordDetailScreen> {
  dynamic _record; // Asset? or Liability?

  @override
  void initState() {
    super.initState();
    _loadRecord();
  }

  void _loadRecord() {
    final provider = context.read<FinancialProvider>();
    setState(() {
      if (widget.recordType == RecordType.asset) {
        _record = provider.assets.firstWhere((a) => a.id == widget.recordId);
      } else {
        _record = provider.liabilities.firstWhere((l) => l.id == widget.recordId);
      }
    });
  }

  /// 获取类型的显示名称（处理 dynamic 类型的扩展方法问题）
  String _getTypeDisplayName() {
    if (widget.recordType == RecordType.asset) {
      final asset = _record as Asset;
      return asset.type.displayName;
    } else {
      final liability = _record as Liability;
      return liability.type.displayName;
    }
  }

  /// 检查是否为投资类资产
  bool _isInvestment() {
    if (widget.recordType == RecordType.asset) {
      final asset = _record as Asset;
      return asset.type.isInvestment;
    }
    return false;
  }

  /// 获取资产类型（用于条件判断）
  AssetType? _getAssetType() {
    if (widget.recordType == RecordType.asset) {
      return (_record as Asset).type;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    if (_record == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('详情')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final isAsset = widget.recordType == RecordType.asset;

    return Scaffold(
      appBar: AppBar(
        title: Text(_record.name),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            tooltip: '编辑',
            onPressed: () => _handleEdit(context),
          ),
          IconButton(
            icon: const Icon(Icons.delete),
            tooltip: '删除',
            color: Colors.red,
            onPressed: () => _handleDelete(context),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildAmountCard(context, isAsset),
          const SizedBox(height: 16),
          _buildBasicInfo(context, isAsset),
          // 投资类信息
          if (isAsset && _isInvestment()) ...[
            const SizedBox(height: 16),
            _buildInvestmentInfo(context),
          ],
          // 房产信息
          if (isAsset && _getAssetType() == AssetType.property) ...[
            const SizedBox(height: 16),
            _buildPropertyInfo(context),
          ],
          // 存款信息
          if (isAsset && _getAssetType() == AssetType.deposit) ...[
            const SizedBox(height: 16),
            _buildDepositInfo(context),
          ],
          // 保单信息
          if (isAsset && _getAssetType() == AssetType.insurance) ...[
            const SizedBox(height: 16),
            _buildInsuranceInfo(context),
          ],
          // 负债信息
          if (!isAsset) ...[
            const SizedBox(height: 16),
            _buildLiabilityInfo(context),
          ],
          // 备注信息
          if (_record.note != null && _record.note!.isNotEmpty) ...[
            const SizedBox(height: 16),
            _buildNoteCard(context),
          ],
          // 时间信息
          const SizedBox(height: 16),
          _buildTimeInfo(context),
        ],
      ),
    );
  }

  Widget _buildAmountCard(BuildContext context, bool isAsset) {
    final amount = _record.amount;
    final currency = _record.currency;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  isAsset ? '资产价值' : '负债金额',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                _buildTypeIcon(context),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              _formatAmount(amount, currency),
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    color: isAsset
                        ? Theme.of(context).colorScheme.primary
                        : Colors.red,
                    fontWeight: FontWeight.bold,
                  ),
            ),
            // 投资类盈亏信息
            if (isAsset && _record.isInvestment && _record.profitLossPercent != null) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Text(
                    '盈亏: ',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  Text(
                    '${_record.profitLossPercent!.toStringAsFixed(2)}%',
                    style: TextStyle(
                      color: _record.profitLossPercent! >= 0 ? Colors.green : Colors.red,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '(${_record.profitLossAmount != null ? _formatAmount(_record.profitLossAmount!, '') : ''})',
                    style: TextStyle(
                      color: _record.profitLossAmount != null && _record.profitLossAmount! >= 0 ? Colors.green : Colors.red,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ],
            // 信用卡使用率
            if (!isAsset && _record.isCreditCard && _record.creditUtilization != null) ...[
              const SizedBox(height: 8),
              Text(
                '使用率: ${_record.creditUtilization!.toStringAsFixed(1)}%',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildBasicInfo(BuildContext context, bool isAsset) {
    return Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              '基本信息',
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          _buildInfoTile(context, isAsset ? '资产类型' : '负债类型', _getTypeDisplayName()),
          _buildInfoTile(context, '货币', _record.currency),
          _buildInfoTile(context, '发生日期', _formatDate(_record.occurrenceDate)),
          if (!isAsset && _record.lender != null)
            _buildInfoTile(context, '债权人/机构', _record.lender!),
          if (!isAsset && _record.interestRate != null)
            _buildInfoTile(context, '年利率', '${_record.interestRate!.toStringAsFixed(2)}%'),
          if (!isAsset && _record.repaymentMethod != null)
            _buildInfoTile(context, '还款方式', _record.repaymentMethod!.displayName),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _buildInvestmentInfo(BuildContext context) {
    return Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              '投资信息',
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          if (_record.code != null)
            _buildInfoTile(context, '代码', _record.code!),
          if (_record.exchange != null)
            _buildInfoTile(context, '交易所/平台', _record.exchange!),
          if (_record.quantity != null)
            _buildInfoTile(context, '数量', _record.quantity.toString()),
          if (_record.buyPrice != null)
            _buildInfoTile(context, '买入价', '¥${_record.buyPrice!.toStringAsFixed(2)}'),
          if (_record.currentPrice != null)
            _buildInfoTile(context, '现价', '¥${_record.currentPrice!.toStringAsFixed(2)}'),
          if (_record.account != null)
            _buildInfoTile(context, '证券账户/平台', _record.account!),
          if (_record.tags != null && _record.tags!.isNotEmpty)
            _buildInfoTile(context, '标签', _record.tags!.join(', ')),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _buildPropertyInfo(BuildContext context) {
    return Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              '房产信息',
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          if (_record.address != null)
            _buildInfoTile(context, '地址', _record.address!),
          if (_record.buildingArea != null)
            _buildInfoTile(context, '建筑面积', '${_record.buildingArea!.toStringAsFixed(2)} ㎡'),
          if (_record.livingArea != null)
            _buildInfoTile(context, '使用面积', '${_record.livingArea!.toStringAsFixed(2)} ㎡'),
          if (_record.propertyType != null)
            _buildInfoTile(context, '房屋类型', _record.propertyType!),
          if (_record.rooms != null)
            _buildInfoTile(context, '房型', _record.rooms.toString()),
          if (_record.floor != null)
            _buildInfoTile(context, '楼层', _record.floor!),
          if (_record.buildYear != null)
            _buildInfoTile(context, '建成年份', _record.buildYear.toString()),
          if (_record.ownershipType != null)
            _buildInfoTile(context, '产权性质', _record.ownershipType!),
          if (_record.deedNumber != null)
            _buildInfoTile(context, '不动产证号', _record.deedNumber!),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _buildDepositInfo(BuildContext context) {
    return Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              '存款信息',
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          if (_record.account != null)
            _buildInfoTile(context, '银行/机构', _record.account!),
          if (_record.depositAccountType != null)
            _buildInfoTile(context, '账户类型', _record.depositAccountType!),
          if (_record.depositPeriod != null)
            _buildInfoTile(context, '存期', '${_record.depositPeriod} 个月'),
          if (_record.maturityDate != null)
            _buildInfoTile(context, '到期日期', _formatDate(_record.maturityDate!)),
          if (_record.depositInterestRate != null)
            _buildInfoTile(context, '利率', '${_record.depositInterestRate!.toStringAsFixed(2)}%'),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _buildInsuranceInfo(BuildContext context) {
    return Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              '保单信息',
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          if (_record.policyNumber != null)
            _buildInfoTile(context, '保单号', _record.policyNumber!),
          if (_record.insurer != null)
            _buildInfoTile(context, '保险公司', _record.insurer!),
          if (_record.insuranceType != null)
            _buildInfoTile(context, '保险类型', _record.insuranceType!),
          if (_record.insured != null)
            _buildInfoTile(context, '被保人', _record.insured!),
          if (_record.beneficiary != null)
            _buildInfoTile(context, '受益人', _record.beneficiary!),
          if (_record.coverageAmount != null)
            _buildInfoTile(context, '保额', _formatAmount(_record.coverageAmount!, '')),
          if (_record.premium != null)
            _buildInfoTile(context, '保费', _formatAmount(_record.premium!, '')),
          if (_record.premiumPeriod != null)
            _buildInfoTile(context, '缴费期限', _record.premiumPeriod!),
          if (_record.coveragePeriod != null)
            _buildInfoTile(context, '保险期限', _record.coveragePeriod!),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _buildLiabilityInfo(BuildContext context) {
    return Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              '负债信息',
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          if (_record.dueDate != null)
            _buildInfoTile(context, '到期日', _formatDate(_record.dueDate!)),
          if (_record.isCreditCard && _record.billingDate != null)
            _buildInfoTile(context, '账单日', '${_record.billingDate!.day}号'),
          if (_record.isCreditCard && _record.paymentDueDate != null)
            _buildInfoTile(context, '还款日', '${_record.paymentDueDate!.day}号'),
          if (_record.isCreditCard && _record.creditLimit != null) ...[
            _buildInfoTile(context, '信用额度', _formatAmount(_record.creditLimit!, '')),
            if (_record.availableCredit != null)
              _buildInfoTile(context, '可用额度', _formatAmount(_record.availableCredit!, '')),
          ],
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _buildNoteCard(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '备注',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(_record.note!),
          ],
        ),
      ),
    );
  }

  Widget _buildTimeInfo(BuildContext context) {
    return Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              '时间信息',
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          _buildInfoTile(context, '创建时间', _formatDate(_record.createdAt)),
          _buildInfoTile(context, '更新时间', _formatDate(_record.updatedAt)),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _buildInfoTile(BuildContext context, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.grey[600],
                ),
          ),
          Text(
            value,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }

  Widget _buildTypeIcon(BuildContext context) {
    if (widget.recordType == RecordType.asset) {
      final asset = _record as Asset;
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
    } else {
      final liability = _record as Liability;
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
  }

  void _handleEdit(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => FinancialRecordFormScreen(
          record: _record,
          initialType: widget.recordType,
        ),
      ),
    ).then((_) => _loadRecord());
  }

  Future<void> _handleDelete(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('确认删除'),
        content: Text('确定要删除「${_record.name}」吗？此操作无法撤销。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('删除'),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      final provider = context.read<FinancialProvider>();
      bool success;
      if (widget.recordType == RecordType.asset) {
        success = await provider.deleteAsset(_record.id);
      } else {
        success = await provider.deleteLiability(_record.id);
      }

      if (success && context.mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('已删除${widget.recordType == RecordType.asset ? '资产' : '负债'}')),
        );
      }
    }
  }

  String _formatAmount(double amount, String currency) {
    if (amount >= 10000) {
      return '$currency${(amount / 10000).toStringAsFixed(2)}万';
    } else if (amount >= 1000) {
      return '$currency${(amount / 1000).toStringAsFixed(1)}k';
    }
    return '$currency${amount.toStringAsFixed(2)}';
  }

  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }
}
