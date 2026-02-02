/// 金融记录表单（支持资产/负债分离模型和扩展字段）
///
/// 支持添加/编辑资产和负债，根据类型显示不同的字段

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import '../models/financial_models.dart';
import '../providers/financial_provider.dart';

/// 表单模式
enum FormMode {
  add,
  edit,
}

/// 记录类型选择
enum RecordType { asset, liability }

/// 金融记录表单对话框
class FinancialRecordFormDialog extends StatefulWidget {
  final dynamic record; // Asset? or Liability?
  final RecordType? initialType;

  const FinancialRecordFormDialog({
    super.key,
    this.record,
    this.initialType,
  });

  @override
  State<FinancialRecordFormDialog> createState() => _FinancialRecordFormDialogState();
}

class _FinancialRecordFormDialogState extends State<FinancialRecordFormDialog> {
  final _formKey = GlobalKey<FormState>();

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
  RecordType _selectedRecordType = RecordType.asset;
  AssetType? _selectedAssetType;
  LiabilityType? _selectedLiabilityType;
  bool _isLoading = false;

  FormMode get _mode => widget.record == null ? FormMode.add : FormMode.edit;

  @override
  void initState() {
    super.initState();
    _selectedRecordType = widget.initialType ?? RecordType.asset;
    _selectedAssetType = AssetType.deposit;
    _selectedLiabilityType = LiabilityType.debt;

    // 如果是编辑模式，加载数据
    if (widget.record != null) {
      _loadRecordData();
    }
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

      // 负债字段
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

  @override
  void dispose() {
    // 通用字段
    _nameController.dispose();
    _amountController.dispose();
    _currencyController.dispose();
    _noteController.dispose();

    // 投资类字段
    _buyPriceController.dispose();
    _currentPriceController.dispose();
    _codeController.dispose();
    _exchangeController.dispose();
    _quantityController.dispose();
    _accountController.dispose();

    // 房产字段
    _addressController.dispose();
    _buildingAreaController.dispose();
    _livingAreaController.dispose();
    _propertyTypeController.dispose();
    _roomsController.dispose();
    _floorController.dispose();
    _buildYearController.dispose();
    _ownershipTypeController.dispose();
    _deedNumberController.dispose();

    // 存款字段
    _depositAccountTypeController.dispose();
    _depositPeriodController.dispose();
    _depositInterestRateController.dispose();

    // 保单字段
    _policyNumberController.dispose();
    _insuranceTypeController.dispose();
    _insuredController.dispose();
    _beneficiaryController.dispose();
    _coverageAmountController.dispose();
    _premiumController.dispose();
    _premiumPeriodController.dispose();
    _coveragePeriodController.dispose();
    _insurerController.dispose();

    // 负债字段
    _lenderController.dispose();
    _interestRateController.dispose();
    _creditLimitController.dispose();

    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    final provider = context.read<FinancialProvider>();
    bool success = false;

    if (_selectedRecordType == RecordType.asset && _selectedAssetType != null) {
      final asset = Asset(
        id: widget.record?.id ?? const Uuid().v4(),
        name: _nameController.text,
        type: _selectedAssetType!,
        amount: double.parse(_amountController.text),
        currency: _currencyController.text.isEmpty ? 'CNY' : _currencyController.text,
        account: _accountController.text.isEmpty ? null : _accountController.text,
        occurrenceDate: widget.record?.occurrenceDate ?? DateTime.now(),
        note: _noteController.text.isEmpty ? null : _noteController.text,
        createdAt: widget.record?.createdAt ?? DateTime.now(),
        updatedAt: DateTime.now(),

        // 投资类字段
        buyPrice: _buyPriceController.text.isEmpty ? null : double.tryParse(_buyPriceController.text),
        currentPrice: _currentPriceController.text.isEmpty ? null : double.tryParse(_currentPriceController.text),
        code: _codeController.text.isEmpty ? null : _codeController.text,
        exchange: _exchangeController.text.isEmpty ? null : _exchangeController.text,
        quantity: _quantityController.text.isEmpty ? null : int.tryParse(_quantityController.text),

        // 房产字段
        address: _addressController.text.isEmpty ? null : _addressController.text,
        buildingArea: _buildingAreaController.text.isEmpty ? null : double.tryParse(_buildingAreaController.text),
        livingArea: _livingAreaController.text.isEmpty ? null : double.tryParse(_livingAreaController.text),
        propertyType: _propertyTypeController.text.isEmpty ? null : _propertyTypeController.text,
        rooms: _roomsController.text.isEmpty ? null : int.tryParse(_roomsController.text),
        floor: _floorController.text.isEmpty ? null : _floorController.text,
        buildYear: _buildYearController.text.isEmpty ? null : int.tryParse(_buildYearController.text),
        ownershipType: _ownershipTypeController.text.isEmpty ? null : _ownershipTypeController.text,
        deedNumber: _deedNumberController.text.isEmpty ? null : _deedNumberController.text,

        // 存款字段
        depositAccountType: _depositAccountTypeController.text.isEmpty ? null : _depositAccountTypeController.text,
        depositPeriod: _depositPeriodController.text.isEmpty ? null : int.tryParse(_depositPeriodController.text),
        maturityDate: _maturityDate,
        depositInterestRate: _depositInterestRateController.text.isEmpty ? null : double.tryParse(_depositInterestRateController.text),

        // 保单字段
        policyNumber: _policyNumberController.text.isEmpty ? null : _policyNumberController.text,
        insuranceType: _insuranceTypeController.text.isEmpty ? null : _insuranceTypeController.text,
        insured: _insuredController.text.isEmpty ? null : _insuredController.text,
        beneficiary: _beneficiaryController.text.isEmpty ? null : _beneficiaryController.text,
        coverageAmount: _coverageAmountController.text.isEmpty ? null : double.tryParse(_coverageAmountController.text),
        premium: _premiumController.text.isEmpty ? null : double.tryParse(_premiumController.text),
        premiumPeriod: _premiumPeriodController.text.isEmpty ? null : _premiumPeriodController.text,
        coveragePeriod: _coveragePeriodController.text.isEmpty ? null : _coveragePeriodController.text,
        insurer: _insurerController.text.isEmpty ? null : _insurerController.text,
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
        currency: _currencyController.text.isEmpty ? 'CNY' : _currencyController.text,
        occurrenceDate: widget.record?.occurrenceDate ?? DateTime.now(),
        note: _noteController.text.isEmpty ? null : _noteController.text,
        createdAt: widget.record?.createdAt ?? DateTime.now(),
        updatedAt: DateTime.now(),

        // 负债字段
        lender: _lenderController.text.isEmpty ? null : _lenderController.text,
        dueDate: _dueDate,
        interestRate: _interestRateController.text.isEmpty ? null : double.tryParse(_interestRateController.text),
        repaymentMethod: _repaymentMethod,

        // 信用卡字段
        billingDate: _billingDate,
        paymentDueDate: _paymentDueDate,
        creditLimit: _creditLimitController.text.isEmpty ? null : double.tryParse(_creditLimitController.text),
      );

      success = widget.record == null
          ? await provider.addLiability(liability)
          : await provider.updateLiability(liability);
    }

    setState(() => _isLoading = false);

    if (!mounted) return;

    if (success) {
      Navigator.pop(context);
      final itemType = _selectedRecordType == RecordType.asset ? '资产' : '负债';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_mode == FormMode.add ? '$itemType已添加' : '$itemType已更新'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: SafeArea(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildHeader(context),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Column(
                      children: [
                        _buildRecordTypeSelector(context),
                        const SizedBox(height: 16),
                        _buildCommonFields(context),
                        const SizedBox(height: 16),
                        if (_selectedRecordType == RecordType.asset)
                          _buildAssetFields(context),
                        if (_selectedRecordType == RecordType.liability)
                          _buildLiabilityFields(context),
                        const SizedBox(height: 24),
                      ],
                    ),
                  ),
                ),
                _buildSaveButton(context),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          Text(
            _getTitle(),
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const Spacer(),
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }

  String _getTitle() {
    final type = _selectedRecordType == RecordType.asset ? '资产' : '负债';
    final action = _mode == FormMode.add ? '添加' : '编辑';
    return '$action$type';
  }

  Widget _buildRecordTypeSelector(BuildContext context) {
    if (_mode == FormMode.edit) {
      // 编辑模式不允许更改记录类型
      return const SizedBox.shrink();
    }

    return SegmentedButton<RecordType>(
      segments: const [
        ButtonSegment(
          value: RecordType.asset,
          label: Text('资产'),
          icon: Icon(Icons.account_balance_wallet),
        ),
        ButtonSegment(
          value: RecordType.liability,
          label: Text('负债'),
          icon: Icon(Icons.credit_card),
        ),
      ],
      selected: {_selectedRecordType},
      onSelectionChanged: (Set<RecordType> selected) {
        setState(() {
          _selectedRecordType = selected.first;
        });
      },
    );
  }

  Widget _buildCommonFields(BuildContext context) {
    final typeLabel = _selectedRecordType == RecordType.asset ? '资产' : '负债';

    return Column(
      children: [
        // 名称
        TextFormField(
          controller: _nameController,
          decoration: InputDecoration(
            labelText: '$typeLabel名称',
            hintText: _selectedRecordType == RecordType.asset
                ? '例如：苹果公司股票'
                : '例如：招商银行房贷',
          ),
          validator: (value) {
            if (value == null || value.isEmpty) {
              return '请输入$typeLabel名称';
            }
            return null;
          },
        ),
        const SizedBox(height: 16),

        // 类型选择 + 金额 + 货币
        Row(
          children: [
            Expanded(
              child: _buildTypeDropdown(context),
            ),
            const SizedBox(width: 16),
            Expanded(
              flex: 2,
              child: TextFormField(
                controller: _amountController,
                decoration: const InputDecoration(
                  labelText: '金额',
                  hintText: '0.00',
                ),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return '请输入金额';
                  }
                  final amount = double.tryParse(value);
                  if (amount == null || amount < 0) {
                    return '请输入有效金额';
                  }
                  return null;
                },
              ),
            ),
            const SizedBox(width: 16),
            SizedBox(
              width: 80,
              child: TextFormField(
                controller: _currencyController,
                decoration: const InputDecoration(
                  labelText: '货币',
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // 备注
        TextFormField(
          controller: _noteController,
          decoration: const InputDecoration(
            labelText: '备注（可选）',
          ),
          maxLines: 2,
        ),
      ],
    );
  }

  Widget _buildTypeDropdown(BuildContext context) {
    if (_selectedRecordType == RecordType.asset) {
      return DropdownButtonFormField<AssetType>(
        value: _selectedAssetType,
        decoration: const InputDecoration(labelText: '资产类型'),
        items: AssetType.values.map((type) {
          return DropdownMenuItem(
            value: type,
            child: Text(type.displayName),
          );
        }).toList(),
        onChanged: _mode == FormMode.edit
            ? null
            : (value) {
                if (value != null) {
                  setState(() => _selectedAssetType = value);
                }
              },
      );
    } else {
      return DropdownButtonFormField<LiabilityType>(
        value: _selectedLiabilityType,
        decoration: const InputDecoration(labelText: '负债类型'),
        items: LiabilityType.values.map((type) {
          return DropdownMenuItem(
            value: type,
            child: Text(type.displayName),
          );
        }).toList(),
        onChanged: _mode == FormMode.edit
            ? null
            : (value) {
                if (value != null) {
                  setState(() => _selectedLiabilityType = value);
                }
              },
      );
    }
  }

  Widget _buildAssetFields(BuildContext context) {
    if (_selectedAssetType == null) return const SizedBox.shrink();

    switch (_selectedAssetType!) {
      case AssetType.stock:
      case AssetType.fund:
        return _buildInvestmentFields(context);
      case AssetType.property:
        return _buildPropertyFields(context);
      case AssetType.deposit:
        return _buildDepositFields(context);
      case AssetType.insurance:
        return _buildInsuranceFields(context);
    }
  }

  Widget _buildInvestmentFields(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Divider(),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Text(
            '投资信息',
            style: Theme.of(context).textTheme.titleSmall,
          ),
        ),
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: _codeController,
                decoration: InputDecoration(
                  labelText: _selectedAssetType == AssetType.stock ? '股票代码' : '基金代码',
                  hintText: _selectedAssetType == AssetType.stock ? '例如：600000' : '例如：000001',
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: TextFormField(
                controller: _exchangeController,
                decoration: const InputDecoration(
                  labelText: '交易所/平台',
                  hintText: '例如：上交所',
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: _quantityController,
                decoration: InputDecoration(
                  labelText: '数量',
                  hintText: _selectedAssetType == AssetType.stock ? '股数' : '份额',
                ),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: TextFormField(
                controller: _buyPriceController,
                decoration: const InputDecoration(
                  labelText: '买入价',
                  hintText: '0.00',
                ),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: TextFormField(
                controller: _currentPriceController,
                decoration: const InputDecoration(
                  labelText: '现价',
                  hintText: '0.00',
                ),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _accountController,
          decoration: const InputDecoration(
            labelText: '证券账户/平台',
            hintText: '例如：华泰证券',
          ),
        ),
      ],
    );
  }

  Widget _buildPropertyFields(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Divider(),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Text(
            '房产信息',
            style: Theme.of(context).textTheme.titleSmall,
          ),
        ),
        TextFormField(
          controller: _addressController,
          decoration: const InputDecoration(
            labelText: '地址',
            hintText: '例如：北京市朝阳区XX小区',
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: _buildingAreaController,
                decoration: const InputDecoration(
                  labelText: '建筑面积（㎡）',
                ),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: TextFormField(
                controller: _livingAreaController,
                decoration: const InputDecoration(
                  labelText: '使用面积（㎡）',
                ),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: _propertyTypeController,
                decoration: const InputDecoration(
                  labelText: '房屋类型',
                  hintText: '例如：住宅',
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: TextFormField(
                controller: _roomsController,
                decoration: const InputDecoration(
                  labelText: '房型',
                  hintText: '例如：3室2厅',
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: _floorController,
                decoration: const InputDecoration(
                  labelText: '楼层',
                  hintText: '例如：12/32',
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: TextFormField(
                controller: _buildYearController,
                decoration: const InputDecoration(
                  labelText: '建成年份',
                ),
                keyboardType: TextInputType.number,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: _ownershipTypeController,
                decoration: const InputDecoration(
                  labelText: '产权性质',
                  hintText: '例如：商品房',
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: TextFormField(
                controller: _deedNumberController,
                decoration: const InputDecoration(
                  labelText: '不动产证号',
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildDepositFields(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Divider(),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Text(
            '存款信息',
            style: Theme.of(context).textTheme.titleSmall,
          ),
        ),
        TextFormField(
          controller: _accountController,
          decoration: const InputDecoration(
            labelText: '银行/机构',
            hintText: '例如：工商银行',
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: DropdownButtonFormField<String>(
                value: _depositAccountTypeController.text.isEmpty ? null : _depositAccountTypeController.text,
                decoration: const InputDecoration(labelText: '账户类型'),
                items: const [
                  DropdownMenuItem(value: '活期', child: Text('活期')),
                  DropdownMenuItem(value: '定期', child: Text('定期')),
                  DropdownMenuItem(value: '大额存单', child: Text('大额存单')),
                ],
                onChanged: (value) {
                  _depositAccountTypeController.text = value ?? '';
                },
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: TextFormField(
                controller: _depositPeriodController,
                decoration: const InputDecoration(
                  labelText: '存期（月）',
                ),
                keyboardType: TextInputType.number,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        InkWell(
          onTap: () => _selectDate(context, (date) => setState(() => _maturityDate = date)),
          child: InputDecorator(
            decoration: const InputDecoration(
              labelText: '到期日期',
            ),
            child: Text(
              _maturityDate == null
                  ? '选择到期日期'
                  : '${_maturityDate!.year}-${_maturityDate!.month.toString().padLeft(2, '0')}-${_maturityDate!.day.toString().padLeft(2, '0')}',
            ),
          ),
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _depositInterestRateController,
          decoration: const InputDecoration(
            labelText: '利率（%）',
            hintText: '例如：2.75',
          ),
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
        ),
      ],
    );
  }

  Widget _buildInsuranceFields(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Divider(),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Text(
            '保单信息',
            style: Theme.of(context).textTheme.titleSmall,
          ),
        ),
        TextFormField(
          controller: _policyNumberController,
          decoration: const InputDecoration(
            labelText: '保单号',
          ),
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _insurerController,
          decoration: const InputDecoration(
            labelText: '保险公司',
            hintText: '例如：中国平安',
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: _insuranceTypeController,
                decoration: const InputDecoration(
                  labelText: '保险类型',
                  hintText: '例如：重疾险',
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: TextFormField(
                controller: _insuredController,
                decoration: const InputDecoration(
                  labelText: '被保人',
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _beneficiaryController,
          decoration: const InputDecoration(
            labelText: '受益人',
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: _coverageAmountController,
                decoration: const InputDecoration(
                  labelText: '保额',
                ),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: TextFormField(
                controller: _premiumController,
                decoration: const InputDecoration(
                  labelText: '保费',
                ),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: _premiumPeriodController,
                decoration: const InputDecoration(
                  labelText: '缴费期限',
                  hintText: '例如：20年',
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: TextFormField(
                controller: _coveragePeriodController,
                decoration: const InputDecoration(
                  labelText: '保险期限',
                  hintText: '例如：终身',
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildLiabilityFields(BuildContext context) {
    if (_selectedLiabilityType == null) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Divider(),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Text(
            '负债信息',
            style: Theme.of(context).textTheme.titleSmall,
          ),
        ),
        // 通用负债字段
        TextFormField(
          controller: _lenderController,
          decoration: InputDecoration(
            labelText: _selectedLiabilityType == LiabilityType.creditCard ? '发卡行' : '债权人/机构',
            hintText: '例如：工商银行',
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: _interestRateController,
                decoration: const InputDecoration(
                  labelText: '年利率（%）',
                  hintText: '例如：4.3',
                ),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: DropdownButtonFormField<RepaymentMethod>(
                value: _repaymentMethod,
                decoration: const InputDecoration(labelText: '还款方式'),
                items: RepaymentMethod.values.map((method) {
                  return DropdownMenuItem(
                    value: method,
                    child: Text(method.displayName),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() => _repaymentMethod = value);
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        InkWell(
          onTap: () => _selectDate(context, (date) => setState(() => _dueDate = date)),
          child: InputDecorator(
            decoration: const InputDecoration(
              labelText: '到期日/预计还清日',
            ),
            child: Text(
              _dueDate == null
                  ? '选择到期日期'
                  : '${_dueDate!.year}-${_dueDate!.month.toString().padLeft(2, '0')}-${_dueDate!.day.toString().padLeft(2, '0')}',
            ),
          ),
        ),

        // 信用卡专属字段
        if (_selectedLiabilityType == LiabilityType.creditCard) ...[
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: InkWell(
                  onTap: () => _selectDate(context, (date) => setState(() => _billingDate = date)),
                  child: InputDecorator(
                    decoration: const InputDecoration(labelText: '账单日'),
                    child: Text(
                      _billingDate == null
                          ? '选择账单日'
                          : '${_billingDate!.day}号',
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: InkWell(
                  onTap: () => _selectDate(context, (date) => setState(() => _paymentDueDate = date)),
                  child: InputDecorator(
                    decoration: const InputDecoration(labelText: '还款日'),
                    child: Text(
                      _paymentDueDate == null
                          ? '选择还款日'
                          : '${_paymentDueDate!.day}号',
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _creditLimitController,
            decoration: const InputDecoration(
              labelText: '信用额度',
            ),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
          ),
        ],
      ],
    );
  }

  Widget _buildSaveButton(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: FilledButton(
        onPressed: _isLoading ? null : _save,
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(52),
        ),
        child: _isLoading
            ? const SizedBox(
                height: 24,
                width: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : Text(_mode == FormMode.add ? '添加' : '保存'),
      ),
    );
  }

  Future<void> _selectDate(BuildContext context, Function(DateTime) onSelected) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      onSelected(picked);
    }
  }
}
