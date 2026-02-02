/// 金融记录表单页面（全屏模式）
///
/// 支持添加/编辑资产和负债，根据类型显示不同的字段

library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import '../models/financial_models.dart';
import '../providers/financial_provider.dart';
import '../widgets/financial_record_form.dart' show RecordType, FormMode;

/// 表单模式
enum FormMode {
  add,
  edit,
}

/// 金融记录表单页面（全屏）
class FinancialRecordFormScreen extends StatefulWidget {
  final dynamic record; // Asset? or Liability?
  final RecordType initialType;

  const FinancialRecordFormScreen({
    super.key,
    this.record,
    required this.initialType,
  });

  @override
  State<FinancialRecordFormScreen> createState() => _FinancialRecordFormScreenState();
}

class _FinancialRecordFormScreenState extends State<FinancialRecordFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _scrollController = ScrollController();

  // 通用字段控制器
  final _nameController = TextEditingController();
  final _amountController = TextEditingController();
  final _currencyController = TextEditingController(text: 'CNY');
  final _noteController = TextEditingController();

  // 投资类字段控制器
  final _buyPriceController = TextEditingController();
  final _currentPriceController = TextEditingController();
  final _codeController = TextEditingController();
  final _exchangeController = TextEditingController();
  final _quantityController = TextEditingController();
  final _accountController = TextEditingController();

  // 房产字段控制器
  final _addressController = TextEditingController();
  final _buildingAreaController = TextEditingController();
  final _livingAreaController = TextEditingController();
  final _propertyTypeController = TextEditingController();
  final _roomsController = TextEditingController();
  final _floorController = TextEditingController();
  final _buildYearController = TextEditingController();
  final _ownershipTypeController = TextEditingController();
  final _deedNumberController = TextEditingController();

  // 存款字段控制器
  final _depositAccountTypeController = TextEditingController();
  final _depositPeriodController = TextEditingController();
  final _depositInterestRateController = TextEditingController();
  DateTime? _maturityDate;

  // 保单字段控制器
  final _policyNumberController = TextEditingController();
  final _insuranceTypeController = TextEditingController();
  final _insuredController = TextEditingController();
  final _beneficiaryController = TextEditingController();
  final _coverageAmountController = TextEditingController();
  final _premiumController = TextEditingController();
  final _premiumPeriodController = TextEditingController();
  final _coveragePeriodController = TextEditingController();
  final _insurerController = TextEditingController();

  // 负债字段控制器
  final _lenderController = TextEditingController();
  final _interestRateController = TextEditingController();
  DateTime? _dueDate;
  RepaymentMethod? _repaymentMethod;

  // 信用卡字段控制器
  DateTime? _billingDate;
  DateTime? _paymentDueDate;
  final _creditLimitController = TextEditingController();

  // 表单状态
  late RecordType _selectedRecordType;
  AssetType? _selectedAssetType;
  LiabilityType? _selectedLiabilityType;
  bool _isLoading = false;

  FormMode get _mode => widget.record == null ? FormMode.add : FormMode.edit;

  @override
  void initState() {
    super.initState();
    _selectedRecordType = widget.initialType;
    _selectedAssetType = AssetType.deposit;
    _selectedLiabilityType = LiabilityType.debt;

    // 如果是编辑模式，加载数据
    if (widget.record != null) {
      _loadRecordData();
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _nameController.dispose();
    _amountController.dispose();
    _currencyController.dispose();
    _noteController.dispose();
    _buyPriceController.dispose();
    _currentPriceController.dispose();
    _codeController.dispose();
    _exchangeController.dispose();
    _quantityController.dispose();
    _accountController.dispose();
    _addressController.dispose();
    _buildingAreaController.dispose();
    _livingAreaController.dispose();
    _propertyTypeController.dispose();
    _roomsController.dispose();
    _floorController.dispose();
    _buildYearController.dispose();
    _ownershipTypeController.dispose();
    _deedNumberController.dispose();
    _depositAccountTypeController.dispose();
    _depositPeriodController.dispose();
    _depositInterestRateController.dispose();
    _policyNumberController.dispose();
    _insuranceTypeController.dispose();
    _insuredController.dispose();
    _beneficiaryController.dispose();
    _coverageAmountController.dispose();
    _premiumController.dispose();
    _premiumPeriodController.dispose();
    _coveragePeriodController.dispose();
    _insurerController.dispose();
    _lenderController.dispose();
    _interestRateController.dispose();
    _creditLimitController.dispose();
    super.dispose();
  }

  void _loadRecordData() {
    if (widget.record is Asset) {
      final asset = widget.record as Asset;
      _selectedRecordType = RecordType.asset;
      _selectedAssetType = asset.type;

      _nameController.text = asset.name;
      _amountController.text = asset.amount.toString();
      _currencyController.text = asset.currency;
      _noteController.text = asset.note ?? '';

      // 投资类字段
      _accountController.text = asset.account ?? '';
      _buyPriceController.text = asset.buyPrice?.toString() ?? '';
      _currentPriceController.text = asset.currentPrice?.toString() ?? '';
      _codeController.text = asset.code ?? '';
      _exchangeController.text = asset.exchange ?? '';
      _quantityController.text = asset.quantity?.toString() ?? '';

      // 房产字段
      _addressController.text = asset.address ?? '';
      _buildingAreaController.text = asset.buildingArea?.toString() ?? '';
      _livingAreaController.text = asset.livingArea?.toString() ?? '';
      _propertyTypeController.text = asset.propertyType ?? '';
      _roomsController.text = asset.rooms?.toString() ?? '';
      _floorController.text = asset.floor ?? '';
      _buildYearController.text = asset.buildYear?.toString() ?? '';
      _ownershipTypeController.text = asset.ownershipType ?? '';
      _deedNumberController.text = asset.deedNumber ?? '';

      // 存款字段
      _depositAccountTypeController.text = asset.depositAccountType ?? '';
      _depositPeriodController.text = asset.depositPeriod?.toString() ?? '';
      _depositInterestRateController.text = asset.depositInterestRate?.toString() ?? '';
      _maturityDate = asset.maturityDate;

      // 保单字段
      _policyNumberController.text = asset.policyNumber ?? '';
      _insuranceTypeController.text = asset.insuranceType ?? '';
      _insuredController.text = asset.insured ?? '';
      _beneficiaryController.text = asset.beneficiary ?? '';
      _coverageAmountController.text = asset.coverageAmount?.toString() ?? '';
      _premiumController.text = asset.premium?.toString() ?? '';
      _premiumPeriodController.text = asset.premiumPeriod ?? '';
      _coveragePeriodController.text = asset.coveragePeriod ?? '';
      _insurerController.text = asset.insurer ?? '';
    } else if (widget.record is Liability) {
      final liability = widget.record as Liability;
      _selectedRecordType = RecordType.liability;
      _selectedLiabilityType = liability.type;

      _nameController.text = liability.name;
      _amountController.text = liability.amount.toString();
      _currencyController.text = liability.currency;
      _noteController.text = liability.note ?? '';

      // 负债通用字段
      _lenderController.text = liability.lender ?? '';
      _interestRateController.text = liability.interestRate?.toString() ?? '';
      _dueDate = liability.dueDate;
      _repaymentMethod = liability.repaymentMethod;

      // 信用卡字段
      _billingDate = liability.billingDate;
      _paymentDueDate = liability.paymentDueDate;
      _creditLimitController.text = liability.creditLimit?.toString() ?? '';
    }
  }

  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _isLoading = true);

    final provider = context.read<FinancialProvider>();
    bool success = false;

    if (_selectedRecordType == RecordType.asset && _selectedAssetType != null) {
      final asset = Asset(
        id: widget.record?.id ?? const Uuid().v4(),
        name: _nameController.text,
        type: _selectedAssetType!,
        amount: double.parse(_amountController.text),
        currency: _currencyController.text,
        account: _accountController.text.isEmpty ? null : _accountController.text,
        occurrenceDate: DateTime.now(),
        buyPrice: _buyPriceController.text.isEmpty
            ? null
            : double.tryParse(_buyPriceController.text),
        currentPrice: _currentPriceController.text.isEmpty
            ? null
            : double.tryParse(_currentPriceController.text),
        code: _codeController.text.isEmpty ? null : _codeController.text,
        exchange: _exchangeController.text.isEmpty ? null : _exchangeController.text,
        quantity: _quantityController.text.isEmpty ? null : int.tryParse(_quantityController.text),
        note: _noteController.text.isEmpty ? null : _noteController.text,
        // 房产字段
        address: _addressController.text.isEmpty ? null : _addressController.text,
        buildingArea: _buildingAreaController.text.isEmpty
            ? null
            : double.tryParse(_buildingAreaController.text),
        livingArea: _livingAreaController.text.isEmpty
            ? null
            : double.tryParse(_livingAreaController.text),
        propertyType: _propertyTypeController.text.isEmpty ? null : _propertyTypeController.text,
        rooms: _roomsController.text.isEmpty ? null : int.tryParse(_roomsController.text),
        floor: _floorController.text.isEmpty ? null : _floorController.text,
        buildYear: _buildYearController.text.isEmpty ? null : int.tryParse(_buildYearController.text),
        ownershipType: _ownershipTypeController.text.isEmpty ? null : _ownershipTypeController.text,
        deedNumber: _deedNumberController.text.isEmpty ? null : _deedNumberController.text,
        // 存款字段
        depositAccountType: _depositAccountTypeController.text.isEmpty
            ? null
            : _depositAccountTypeController.text,
        depositPeriod: _depositPeriodController.text.isEmpty ? null : int.tryParse(_depositPeriodController.text),
        maturityDate: _maturityDate,
        depositInterestRate: _depositInterestRateController.text.isEmpty
            ? null
            : double.tryParse(_depositInterestRateController.text),
        // 保单字段
        policyNumber: _policyNumberController.text.isEmpty ? null : _policyNumberController.text,
        insuranceType: _insuranceTypeController.text.isEmpty ? null : _insuranceTypeController.text,
        insured: _insuredController.text.isEmpty ? null : _insuredController.text,
        beneficiary: _beneficiaryController.text.isEmpty ? null : _beneficiaryController.text,
        coverageAmount: _coverageAmountController.text.isEmpty
            ? null
            : double.tryParse(_coverageAmountController.text),
        premium: _premiumController.text.isEmpty ? null : double.tryParse(_premiumController.text),
        premiumPeriod: _premiumPeriodController.text.isEmpty ? null : _premiumPeriodController.text,
        coveragePeriod: _coveragePeriodController.text.isEmpty ? null : _coveragePeriodController.text,
        insurer: _insurerController.text.isEmpty ? null : _insurerController.text,
        createdAt: widget.record?.createdAt ?? DateTime.now(),
        updatedAt: DateTime.now(),
      );

      success = widget.record == null
          ? await provider.addAsset(asset)
          : await provider.updateAsset(asset);
    } else if (_selectedRecordType == RecordType.liability && _selectedLiabilityType != null) {
      final liability = Liability(
        id: widget.record?.id ?? const Uuid().v4(),
        name: _nameController.text,
        type: _selectedLiabilityType!,
        amount: double.parse(_amountController.text),
        currency: _currencyController.text,
        occurrenceDate: DateTime.now(),
        dueDate: _dueDate,
        interestRate: _interestRateController.text.isEmpty
            ? null
            : double.tryParse(_interestRateController.text),
        repaymentMethod: _repaymentMethod,
        lender: _lenderController.text.isEmpty ? null : _lenderController.text,
        // 信用卡字段
        billingDate: _billingDate,
        paymentDueDate: _paymentDueDate,
        creditLimit: _creditLimitController.text.isEmpty
            ? null
            : double.tryParse(_creditLimitController.text),
        note: _noteController.text.isEmpty ? null : _noteController.text,
        createdAt: widget.record?.createdAt ?? DateTime.now(),
        updatedAt: DateTime.now(),
      );

      success = widget.record == null
          ? await provider.addLiability(liability)
          : await provider.updateLiability(liability);
    }

    setState(() => _isLoading = false);

    if (success && mounted) {
      Navigator.pop(context, true);
      if (mounted) {
        final itemType = _selectedRecordType == RecordType.asset ? '资产' : '负债';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_mode == FormMode.add ? '$itemType已添加' : '$itemType已更新'),
          ),
        );
      }
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('操作失败，请重试')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_getTitle()),
        actions: [
          if (_isLoading)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(16.0),
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.only(right: 16.0),
              child: FilledButton(
                onPressed: _handleSave,
                child: const Text('保存'),
              ),
            ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          controller: _scrollController,
          padding: const EdgeInsets.all(16),
          children: [
            _buildCommonFields(context),
            const SizedBox(height: 16),
            if (_selectedRecordType == RecordType.asset)
              _buildAssetFields(context),
            if (_selectedRecordType == RecordType.liability)
              _buildLiabilityFields(context),
          ],
        ),
      ),
    );
  }

  String _getTitle() {
    final type = _selectedRecordType == RecordType.asset ? '资产' : '负债';
    final action = _mode == FormMode.add ? '添加' : '编辑';
    return '$action$type';
  }

  Widget _buildCommonFields(BuildContext context) {
    final typeLabel = _selectedRecordType == RecordType.asset ? '资产' : '负债';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 类型选择
        Text(
          '$typeLabel类型',
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 12),
        if (_selectedRecordType == RecordType.asset)
          _buildAssetTypeSelector()
        else
          _buildLiabilityTypeSelector(),
        const SizedBox(height: 16),
        // 名称
        TextFormField(
          controller: _nameController,
          decoration: InputDecoration(
            labelText: '$typeLabel名称',
            hintText: _selectedRecordType == RecordType.asset
                ? '例如：苹果公司股票'
                : '例如：招商银行房贷',
            border: const OutlineInputBorder(),
          ),
          validator: (value) {
            if (value == null || value.isEmpty) {
              return '请输入$typeLabel名称';
            }
            return null;
          },
        ),
        const SizedBox(height: 16),
        // 金额
        TextFormField(
          controller: _amountController,
          decoration: InputDecoration(
            labelText: '金额',
            border: const OutlineInputBorder(),
            prefixText: '¥',
          ),
          keyboardType: TextInputType.number,
          validator: (value) {
            if (value == null || value.isEmpty) {
              return '请输入金额';
            }
            final amount = double.tryParse(value);
            if (amount == null || amount <= 0) {
              return '请输入有效的金额';
            }
            return null;
          },
        ),
        const SizedBox(height: 16),
        // 备注
        TextFormField(
          controller: _noteController,
          decoration: const InputDecoration(
            labelText: '备注（可选）',
            border: OutlineInputBorder(),
          ),
          maxLines: 3,
        ),
      ],
    );
  }

  Widget _buildAssetTypeSelector() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: AssetType.values.map((type) {
        final isSelected = _selectedAssetType == type;
        return ChoiceChip(
          label: Text(type.displayName),
          selected: isSelected,
          onSelected: (_) => setState(() => _selectedAssetType = type),
          avatar: Icon(
            type.icon,
            size: 18,
            color: isSelected ? Colors.white : type.color,
          ),
          selectedColor: type.color,
          labelStyle: TextStyle(
            color: isSelected ? Colors.white : Colors.black,
          ),
        );
      }).toList(),
    );
  }

  Widget _buildLiabilityTypeSelector() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: LiabilityType.values.map((type) {
        final isSelected = _selectedLiabilityType == type;
        return ChoiceChip(
          label: Text(type.displayName),
          selected: isSelected,
          onSelected: (_) => setState(() => _selectedLiabilityType = type),
          avatar: Icon(
            type.icon,
            size: 18,
            color: isSelected ? Colors.white : type.color,
          ),
          selectedColor: type.color,
          labelStyle: TextStyle(
            color: isSelected ? Colors.white : Colors.black,
          ),
        );
      }).toList(),
    );
  }

  Widget _buildAssetFields(BuildContext context) {
    if (_selectedAssetType == null) return const SizedBox.shrink();

    // 投资类字段
    if (_selectedAssetType!.isInvestment) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '投资信息',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _accountController,
            decoration: const InputDecoration(
              labelText: '账户/平台',
              hintText: '例如：华泰证券',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _codeController,
            decoration: const InputDecoration(
              labelText: '代码',
              hintText: '例如：600519',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _buyPriceController,
            decoration: const InputDecoration(
              labelText: '买入价',
              border: OutlineInputBorder(),
              prefixText: '¥',
            ),
            keyboardType: TextInputType.number,
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _currentPriceController,
            decoration: const InputDecoration(
              labelText: '现价',
              border: OutlineInputBorder(),
              prefixText: '¥',
            ),
            keyboardType: TextInputType.number,
          ),
        ],
      );
    }

    // 房产字段
    if (_selectedAssetType == AssetType.property) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '房产信息',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _addressController,
            decoration: const InputDecoration(
              labelText: '地址',
              hintText: '例如：北京市朝阳区xxx',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _buildingAreaController,
            decoration: const InputDecoration(
              labelText: '建筑面积（㎡）',
              border: OutlineInputBorder(),
            ),
            keyboardType: TextInputType.number,
          ),
        ],
      );
    }

    // 存款字段
    if (_selectedAssetType == AssetType.deposit) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '存款信息',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _accountController,
            decoration: const InputDecoration(
              labelText: '账户/银行',
              hintText: '例如：招商银行',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _depositInterestRateController,
            decoration: const InputDecoration(
              labelText: '利率（%）',
              hintText: '例如：3.5',
              border: OutlineInputBorder(),
            ),
            keyboardType: TextInputType.number,
          ),
        ],
      );
    }

    // 保单字段
    if (_selectedAssetType == AssetType.insurance) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '保单信息',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _policyNumberController,
            decoration: const InputDecoration(
              labelText: '保单号',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _insuredController,
            decoration: const InputDecoration(
              labelText: '被保人',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _coverageAmountController,
            decoration: const InputDecoration(
              labelText: '保额',
              border: OutlineInputBorder(),
              prefixText: '¥',
            ),
            keyboardType: TextInputType.number,
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _premiumController,
            decoration: const InputDecoration(
              labelText: '保费（年/月）',
              border: OutlineInputBorder(),
              prefixText: '¥',
            ),
            keyboardType: TextInputType.number,
          ),
        ],
      );
    }

    return const SizedBox.shrink();
  }

  Widget _buildLiabilityFields(BuildContext context) {
    if (_selectedLiabilityType == null) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '负债信息',
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _lenderController,
          decoration: InputDecoration(
            labelText: _selectedLiabilityType == LiabilityType.creditCard
                ? '发卡行'
                : '债权人/机构',
            hintText: _selectedLiabilityType == LiabilityType.creditCard
                ? '例如：招商银行'
                : '例如：招商银行',
            border: const OutlineInputBorder(),
          ),
        ),
        if (_selectedLiabilityType!.isCreditCard) ...[
          const SizedBox(height: 16),
          TextFormField(
            controller: _creditLimitController,
            decoration: const InputDecoration(
              labelText: '信用额度',
              border: OutlineInputBorder(),
              prefixText: '¥',
            ),
            keyboardType: TextInputType.number,
          ),
        ],
        if (_selectedLiabilityType != LiabilityType.creditCard) ...[
          const SizedBox(height: 16),
          TextFormField(
            controller: _interestRateController,
            decoration: const InputDecoration(
              labelText: '年利率（%）',
              hintText: '例如：4.35',
              border: OutlineInputBorder(),
            ),
            keyboardType: TextInputType.number,
          ),
        ],
      ],
    );
  }
}
