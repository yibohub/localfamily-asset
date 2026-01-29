import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../models/asset.dart';
import '../providers/asset_provider.dart';
import '../providers/custom_type_provider.dart';
import '../utils/currency_utils.dart';
import '../widgets/smart_asset_name_input.dart';

/// 添加/编辑资产表单页面
class AssetFormScreen extends StatefulWidget {
  final Asset? asset;
  final AssetType? defaultType;
  /// 资产类型筛选：true=仅负债类型，false=仅资产类型，null=显示所有类型
  final bool? assetTypesFilter;

  const AssetFormScreen({
    super.key,
    this.asset,
    this.defaultType,
    this.assetTypesFilter,
  });

  @override
  State<AssetFormScreen> createState() => _AssetFormScreenState();
}

class _AssetFormScreenState extends State<AssetFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _amountController;
  late final TextEditingController _accountController;
  late final TextEditingController _buyPriceController;
  late final TextEditingController _currentPriceController;
  late final TextEditingController _noteController;

  late String _selectedTypeId; // 改为 String 类型，支持内置类型名称和自定义类型 ID
  String _selectedCurrency = 'CNY';
  late DateTime _occurrenceDate;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.asset?.name);
    _amountController = TextEditingController(
      text: widget.asset?.amount.toString() ?? '',
    );
    _accountController = TextEditingController(text: widget.asset?.account);
    _buyPriceController = TextEditingController(
      text: widget.asset?.buyPrice?.toString() ?? '',
    );
    _currentPriceController = TextEditingController(
      text: widget.asset?.currentPrice?.toString() ?? '',
    );
    _noteController = TextEditingController(text: widget.asset?.note);

    // 确定默认类型
    String defaultTypeId = 'deposit';
    if (widget.asset?.type != null) {
      defaultTypeId = widget.asset!.type;
    } else if (widget.defaultType != null) {
      defaultTypeId = widget.defaultType!.name;
    } else if (widget.assetTypesFilter == true) {
      // 负债类型筛选，默认选房贷
      defaultTypeId = 'mortgage';
    } else if (widget.assetTypesFilter == false) {
      // 资产类型筛选，默认选存款
      defaultTypeId = 'deposit';
    }

    _selectedTypeId = defaultTypeId;
    _selectedCurrency = widget.asset?.currency ?? 'CNY';
    _occurrenceDate = widget.asset?.occurrenceDate ?? DateTime.now();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _amountController.dispose();
    _accountController.dispose();
    _buyPriceController.dispose();
    _currentPriceController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    final asset = Asset(
      id: widget.asset?.id ?? const Uuid().v4(),
      name: _nameController.text,
      type: _selectedTypeId, // 直接使用字符串类型
      amount: double.parse(_amountController.text),
      currency: _selectedCurrency,
      account: _accountController.text.isEmpty ? null : _accountController.text,
      occurrenceDate: _occurrenceDate,
      buyPrice: _buyPriceController.text.isEmpty
          ? null
          : double.tryParse(_buyPriceController.text),
      currentPrice: _currentPriceController.text.isEmpty
          ? null
          : double.tryParse(_currentPriceController.text),
      note: _noteController.text.isEmpty ? null : _noteController.text,
      createdAt: widget.asset?.createdAt ?? DateTime.now(),
      updatedAt: DateTime.now(),
    );

    final assetProvider = context.read<AssetProvider>();
    final success = widget.asset == null
        ? await assetProvider.addAsset(asset)
        : await assetProvider.updateAsset(asset);

    setState(() => _isLoading = false);

    if (!mounted) return;

    if (success) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_getSuccessMessage()),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('操作失败，请重试')),
      );
    }
  }

  Future<void> _pickOccurrenceDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _occurrenceDate,
      firstDate: DateTime(1900),
      lastDate: DateTime.now().add(const Duration(days: 365 * 50)),
      locale: const Locale('zh', 'CN'),
    );
    if (picked != null) {
      setState(() => _occurrenceDate = picked);
    }
  }

  Future<void> _handleDelete() async {
    if (widget.asset == null) return;

    final isLiability = _isLiabilityType(widget.asset!.type);
    final itemType = isLiability ? '负债' : '资产';

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('删除$itemType'),
        content: Text('确定要删除 "${widget.asset!.name}" 吗？'),
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

    if (confirmed != true) return;

    setState(() => _isLoading = true);

    final assetProvider = context.read<AssetProvider>();
    final success = await assetProvider.deleteAsset(widget.asset!.id);

    setState(() => _isLoading = false);

    if (!mounted) return;

    if (success) {
      Navigator.pop(context);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$itemType 已删除')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final customTypeProvider = context.watch<CustomTypeProvider>();
    final customTypes = widget.assetTypesFilter == true
        ? customTypeProvider.liabilityCustomTypes
        : customTypeProvider.assetCustomTypes;

    return Scaffold(
      appBar: AppBar(
        title: Text(_getPageTitle()),
        actions: widget.asset != null
            ? [
                IconButton(
                  icon: const Icon(Icons.delete, color: Colors.red),
                  onPressed: _isLoading ? null : _handleDelete,
                ),
              ]
            : null,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // 资产类型选择
            Text(
              _getTypeTitle(),
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                // 内置类型
                ..._getFilteredTypes().map((type) {
                  final isSelected = _selectedTypeId == type.name;
                  return ChoiceChip(
                    label: Text(type.displayName),
                    selected: isSelected,
                    onSelected: (_) => setState(() => _selectedTypeId = type.name),
                    avatar: Icon(
                      _getIconData(type.iconName),
                      size: 18,
                      color: isSelected ? Colors.white : const Color(0xFF2563EB),
                    ),
                    selectedColor: widget.assetTypesFilter == true
                        ? Colors.red[400]
                        : const Color(0xFF2563EB),
                    labelStyle: TextStyle(
                      color: isSelected ? Colors.white : Colors.black,
                    ),
                  );
                }),
                // 自定义类型
                ...customTypes.map((type) {
                  final isSelected = _selectedTypeId == type.id;
                  return ChoiceChip(
                    label: Text(type.name),
                    selected: isSelected,
                    onSelected: (_) => setState(() => _selectedTypeId = type.id),
                    avatar: Icon(
                      _getIconData(type.iconName),
                      size: 18,
                      color: isSelected ? Colors.white : const Color(0xFF2563EB),
                    ),
                    selectedColor: widget.assetTypesFilter == true
                        ? Colors.red[400]
                        : const Color(0xFF2563EB),
                    labelStyle: TextStyle(
                      color: isSelected ? Colors.white : Colors.black,
                    ),
                  );
                }),
              ],
            ),
            const SizedBox(height: 24),

            // 智能资产名称输入（包含账户自动填充）
            SmartAssetNameInput(
              nameController: _nameController,
              accountController: _accountController,
              typeFilter: _getFilteredTypes(),
              labelText: _getNameLabel(),
              hintText: _getNameHint(),
            ),
            const SizedBox(height: 16),

            // 账户/编号（可选）- 移到名称下方
            TextFormField(
              controller: _accountController,
              decoration: const InputDecoration(
                labelText: '账户/编号（可选）',
                prefixIcon: Icon(Icons.credit_card),
                hintText: '例如：尾号1234',
              ),
            ),
            const SizedBox(height: 16),

            // 金额
            TextFormField(
              controller: _amountController,
              decoration: InputDecoration(
                labelText: '金额',
                prefixIcon: const Icon(Icons.attach_money),
                prefixText: CurrencyUtils.getSymbol(_selectedCurrency) + ' ',
                hintText: '0.00',
              ),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return '请输入金额';
                }
                if (double.tryParse(value) == null) {
                  return '请输入有效的数字';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),

            // 币种选择
            DropdownButtonFormField<String>(
              value: _selectedCurrency,
              decoration: const InputDecoration(
                labelText: '币种',
                prefixIcon: Icon(Icons.currency_exchange),
              ),
              items: const [
                DropdownMenuItem(
                  value: 'CNY',
                  child: Row(
                    children: [
                      Text('¥', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      SizedBox(width: 8),
                      Text('人民币 (CNY)'),
                    ],
                  ),
                ),
                DropdownMenuItem(
                  value: 'USD',
                  child: Row(
                    children: [
                      Text('\$', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      SizedBox(width: 8),
                      Text('美元 (USD)'),
                    ],
                  ),
                ),
                DropdownMenuItem(
                  value: 'HKD',
                  child: Row(
                    children: [
                      Text('HK\$', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      SizedBox(width: 8),
                      Text('港币 (HKD)'),
                    ],
                  ),
                ),
                DropdownMenuItem(
                  value: 'EUR',
                  child: Row(
                    children: [
                      Text('€', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      SizedBox(width: 8),
                      Text('欧元 (EUR)'),
                    ],
                  ),
                ),
              ],
              onChanged: (value) {
                if (value != null) {
                  setState(() => _selectedCurrency = value);
                }
              },
            ),
            const SizedBox(height: 16),

            // 买入价（可选）
            TextFormField(
              controller: _buyPriceController,
              decoration: InputDecoration(
                labelText: '买入价（可选）',
                prefixIcon: const Icon(Icons.show_chart),
                prefixText: CurrencyUtils.getSymbol(_selectedCurrency) + ' ',
                hintText: '0.00',
                helperText: '适用于股票、基金等投资类资产',
              ),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
            ),
            const SizedBox(height: 16),

            // 现价（可选）
            TextFormField(
              controller: _currentPriceController,
              decoration: InputDecoration(
                labelText: '现价（可选）',
                prefixIcon: const Icon(Icons.trending_up),
                prefixText: CurrencyUtils.getSymbol(_selectedCurrency) + ' ',
                hintText: '0.00',
                helperText: '填写后可自动计算盈亏',
              ),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
            ),
            const SizedBox(height: 16),

            // 发生日期选择器
            InkWell(
              onTap: _pickOccurrenceDate,
              child: InputDecorator(
                decoration: const InputDecoration(
                  labelText: '发生日期',
                  prefixIcon: Icon(Icons.calendar_today),
                ),
                child: Text(
                  '${_occurrenceDate.year}年${_occurrenceDate.month}月${_occurrenceDate.day}日',
                ),
              ),
            ),
            const SizedBox(height: 16),

            // 备注（可选）
            TextFormField(
              controller: _noteController,
              decoration: const InputDecoration(
                labelText: '备注（可选）',
                prefixIcon: Icon(Icons.note),
                hintText: '输入备注信息',
              ),
              maxLines: 3,
            ),
            const SizedBox(height: 32),

            // 保存按钮
            ElevatedButton(
              onPressed: _isLoading ? null : _handleSave,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                backgroundColor: const Color(0xFF2563EB),
                foregroundColor: Colors.white,
              ),
              child: _isLoading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : Text(
                      _getButtonTitle(),
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  /// 根据筛选条件获取可用的内置类型列表
  List<AssetType> _getFilteredTypes() {
    // 编辑现有资产时，根据当前资产类型判断
    if (widget.asset != null) {
      return _isLiabilityType(widget.asset!.type)
          ? AssetTypeExtension.liabilityTypes
          : AssetTypeExtension.assetTypes;
    }

    // 新增时，根据筛选器判断
    if (widget.assetTypesFilter == true) {
      // 仅显示负债类型
      return AssetTypeExtension.liabilityTypes;
    } else if (widget.assetTypesFilter == false) {
      // 仅显示资产类型
      return AssetTypeExtension.assetTypes;
    } else {
      // 显示所有类型
      return AssetType.values;
    }
  }

  /// 判断是否为负债类型
  bool _isLiabilityType(String typeId) {
    final builtInType = AssetTypeExtension.fromString(typeId);
    if (builtInType != null) {
      return builtInType.isLiability;
    }
    // 自定义类型需要查询 CustomTypeProvider
    return typeId.startsWith('custom_');
  }

  /// 获取页面标题
  String _getPageTitle() {
    if (widget.asset != null) {
      return _isLiabilityType(widget.asset!.type) ? '编辑负债' : '编辑资产';
    } else {
      if (widget.assetTypesFilter == true) {
        return '添加负债';
      } else if (widget.assetTypesFilter == false) {
        return '添加资产';
      } else {
        return '添加资产';
      }
    }
  }

  /// 获取按钮文字
  String _getButtonTitle() {
    if (widget.asset != null) {
      return '保存更改';
    } else {
      if (widget.assetTypesFilter == true) {
        return '添加负债';
      } else if (widget.assetTypesFilter == false) {
        return '添加资产';
      } else {
        return '添加资产';
      }
    }
  }

  /// 获取成功消息
  String _getSuccessMessage() {
    if (widget.asset != null) {
      return _isLiabilityType(widget.asset!.type) ? '负债已更新' : '资产已更新';
    } else {
      if (widget.assetTypesFilter == true) {
        return '负债已添加';
      } else if (widget.assetTypesFilter == false) {
        return '资产已添加';
      } else {
        return '资产已添加';
      }
    }
  }

  /// 获取类型标题
  String _getTypeTitle() {
    // 编辑现有资产时，根据当前资产类型判断
    if (widget.asset != null) {
      return _isLiabilityType(widget.asset!.type) ? '负债类型' : '资产类型';
    }
    // 新增时，根据筛选器判断
    if (widget.assetTypesFilter == true) {
      return '负债类型';
    } else {
      return '资产类型';
    }
  }

  /// 获取名称标签
  String _getNameLabel() {
    // 编辑现有资产时，根据当前资产类型判断
    if (widget.asset != null) {
      return _isLiabilityType(widget.asset!.type) ? '负债名称' : '资产名称';
    }
    // 新增时，根据筛选器判断
    if (widget.assetTypesFilter == true) {
      return '负债名称';
    } else {
      return '资产名称';
    }
  }

  /// 获取名称提示
  String _getNameHint() {
    // 编辑现有资产时，不显示提示
    if (widget.asset != null) {
      return '';
    }
    // 新增时，根据筛选器判断
    if (widget.assetTypesFilter == true) {
      return '例如：招商银行房贷';
    } else {
      return '例如：招商银行储蓄卡';
    }
  }

  IconData _getIconData(String name) {
    switch (name) {
      case 'home':
        return Icons.home;
      case 'account_balance':
        return Icons.account_balance;
      case 'trending_up':
        return Icons.trending_up;
      case 'pie_chart':
        return Icons.pie_chart;
      case 'security':
        return Icons.security;
      case 'credit_card':
        return Icons.credit_card;
      case 'home_work':
        return Icons.home_work;
      case 'directions_car':
        return Icons.directions_car;
      case 'person':
        return Icons.person;
      case 'handshake':
        return Icons.handshake;
      // 自定义类型图标
      case 'star':
        return Icons.star;
      case 'favorite':
        return Icons.favorite;
      case 'bookmark':
        return Icons.bookmark;
      case 'label':
        return Icons.label;
      case 'tag':
        return Icons.tag;
      case 'diamond':
        return Icons.diamond;
      case 'pets':
        return Icons.pets;
      case 'flight':
        return Icons.flight;
      case 'restaurant':
        return Icons.restaurant;
      case 'shopping_bag':
        return Icons.shopping_bag;
      default:
        return Icons.help_outline;
    }
  }
}
