import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../models/asset.dart';
import '../providers/asset_provider.dart';

/// 添加/编辑资产表单页面
class AssetFormScreen extends StatefulWidget {
  final Asset? asset;
  final AssetType? defaultType;

  const AssetFormScreen({
    super.key,
    this.asset,
    this.defaultType,
  });

  @override
  State<AssetFormScreen> createState() => _AssetFormScreenState();
}

class _AssetFormScreenState extends State<AssetFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _amountController;
  late final TextEditingController _accountController;
  late final TextEditingController _noteController;

  late AssetType _selectedType;
  String _selectedCurrency = 'CNY';
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.asset?.name);
    _amountController = TextEditingController(
      text: widget.asset?.amount.toString() ?? '',
    );
    _accountController = TextEditingController(text: widget.asset?.account);
    _noteController = TextEditingController(text: widget.asset?.note);
    _selectedType = widget.asset?.type ?? widget.defaultType ?? AssetType.deposit;
    _selectedCurrency = widget.asset?.currency ?? 'CNY';
  }

  @override
  void dispose() {
    _nameController.dispose();
    _amountController.dispose();
    _accountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    final asset = Asset(
      id: widget.asset?.id ?? const Uuid().v4(),
      name: _nameController.text,
      type: _selectedType,
      amount: double.parse(_amountController.text),
      currency: _selectedCurrency,
      account: _accountController.text.isEmpty ? null : _accountController.text,
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
          content: Text(widget.asset == null ? '资产已添加' : '资产已更新'),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('操作失败，请重试')),
      );
    }
  }

  Future<void> _handleDelete() async {
    if (widget.asset == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除资产'),
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('资产已删除')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.asset == null ? '添加资产' : '编辑资产'),
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
            const Text(
              '资产类型',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: AssetType.values.map((type) {
                final isSelected = _selectedType == type;
                return ChoiceChip(
                  label: Text(type.displayName),
                  selected: isSelected,
                  onSelected: (_) => setState(() => _selectedType = type),
                  avatar: Icon(
                    _getIconData(type.iconName),
                    size: 18,
                    color: isSelected ? Colors.white : const Color(0xFF2563EB),
                  ),
                  selectedColor: const Color(0xFF2563EB),
                  labelStyle: TextStyle(
                    color: isSelected ? Colors.white : Colors.black,
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 24),

            // 资产名称
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: '资产名称',
                prefixIcon: Icon(Icons.label),
                hintText: '例如：招商银行储蓄卡',
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return '请输入资产名称';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),

            // 金额
            TextFormField(
              controller: _amountController,
              decoration: const InputDecoration(
                labelText: '金额',
                prefixIcon: Icon(Icons.attach_money),
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
                DropdownMenuItem(value: 'CNY', child: Text('人民币 (CNY)')),
                DropdownMenuItem(value: 'USD', child: Text('美元 (USD)')),
                DropdownMenuItem(value: 'HKD', child: Text('港币 (HKD)')),
                DropdownMenuItem(value: 'EUR', child: Text('欧元 (EUR)')),
              ],
              onChanged: (value) {
                if (value != null) {
                  setState(() => _selectedCurrency = value);
                }
              },
            ),
            const SizedBox(height: 16),

            // 账户/编号（可选）
            TextFormField(
              controller: _accountController,
              decoration: const InputDecoration(
                labelText: '账户/编号（可选）',
                prefixIcon: Icon(Icons.credit_card),
                hintText: '例如：尾号1234',
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
                      widget.asset == null ? '添加资产' : '保存更改',
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
      default:
        return Icons.help_outline;
    }
  }
}
