import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import '../models/asset.dart';
import '../providers/asset_provider.dart';

/// 添加/编辑资产对话框
class AddAssetDialog extends StatefulWidget {
  final Asset? asset;

  const AddAssetDialog({super.key, this.asset});

  @override
  State<AddAssetDialog> createState() => _AddAssetDialogState();
}

class _AddAssetDialogState extends State<AddAssetDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _amountController = TextEditingController();
  final _currencyController = TextEditingController(text: 'CNY');
  final _accountController = TextEditingController();
  final _noteController = TextEditingController();

  AssetType _selectedType = AssetType.stock;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    if (widget.asset != null) {
      _nameController.text = widget.asset!.name;
      _amountController.text = widget.asset!.amount.toString();
      _currencyController.text = widget.asset!.currency ?? 'CNY';
      _accountController.text = widget.asset!.account ?? '';
      _noteController.text = widget.asset!.note ?? '';
      _selectedType = widget.asset!.type;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _amountController.dispose();
    _currencyController.dispose();
    _accountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    final provider = context.read<AssetProvider>();
    final asset = Asset(
      id: widget.asset?.id ?? const Uuid().v4(),
      name: _nameController.text,
      type: _selectedType,
      amount: double.parse(_amountController.text),
      currency: _currencyController.text.isEmpty ? 'CNY' : _currencyController.text,
      account: _accountController.text.isEmpty ? null : _accountController.text,
      createdAt: widget.asset?.createdAt ?? DateTime.now(),
      updatedAt: DateTime.now(),
      note: _noteController.text.isEmpty ? null : _noteController.text,
    );

    final success = widget.asset == null
        ? await provider.addAsset(asset)
        : await provider.updateAsset(asset);

    setState(() => _isLoading = false);

    if (!mounted) return;

    if (success) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(widget.asset == null ? '资产已添加' : '资产已更新'),
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
                // 顶部指示条
                Container(
                  margin: const EdgeInsets.only(top: 12),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.onSurfaceVariant.withOpacity(0.4),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                // 标题
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Row(
                    children: [
                      Text(
                        widget.asset == null ? '添加资产' : '编辑资产',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const Spacer(),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                ),
                // 表单内容
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    children: [
                      TextFormField(
                        controller: _nameController,
                        decoration: const InputDecoration(
                          labelText: '资产名称',
                          hintText: '例如：苹果公司股票',
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return '请输入资产名称';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<AssetType>(
                        value: _selectedType,
                        decoration: const InputDecoration(
                          labelText: '资产类型',
                        ),
                        items: AssetType.values.map((type) {
                          return DropdownMenuItem(
                            value: type,
                            child: Text(_getTypeName(type)),
                          );
                        }).toList(),
                        onChanged: (value) {
                          if (value != null) {
                            setState(() => _selectedType = value);
                          }
                        },
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            flex: 2,
                            child: TextFormField(
                              controller: _amountController,
                              decoration: const InputDecoration(
                                labelText: '金额',
                                hintText: '0.00',
                              ),
                              keyboardType:
                                  const TextInputType.numberWithOptions(decimal: true),
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
                          Expanded(
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
                      TextFormField(
                        controller: _accountController,
                        decoration: const InputDecoration(
                          labelText: '账号（可选）',
                          hintText: '例如：工商银行',
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _noteController,
                        decoration: const InputDecoration(
                          labelText: '备注（可选）',
                        ),
                        maxLines: 3,
                      ),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
                // 保存按钮
                Padding(
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
                        : Text(widget.asset == null ? '添加' : '保存'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _getTypeName(AssetType type) {
    return type.displayName;
  }
}
