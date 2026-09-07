import 'package:flutter/material.dart';
import '../models/custom_asset_type.dart';
import 'package:provider/provider.dart';

import '../providers/custom_type_provider.dart';
import 'create_custom_type_dialog.dart';

/// 自定义类型管理对话框
class CustomTypeManageDialog extends StatefulWidget {
  final bool isLiability;

  const CustomTypeManageDialog({super.key, required this.isLiability});

  @override
  State<CustomTypeManageDialog> createState() => _CustomTypeManageDialogState();
}

class _CustomTypeManageDialogState extends State<CustomTypeManageDialog> {
  late List<CustomAssetType> _types;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadTypes();
  }

  void _loadTypes() {
    final provider = context.read<CustomTypeProvider>();
    final types = widget.isLiability
        ? provider.liabilityCustomTypes
        : provider.assetCustomTypes;
    _types = types;
    _isLoading = false;
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: SizedBox(
        width: 400,
        height: 500,
        child: Column(
          children: [
            ListTile(
              title: Text('自定义${widget.isLiability ? "负债" : "资产"}类型'),
              trailing: IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.pop(context),
              ),
            ),
            const Divider(),
            _isLoading
                ? const Expanded(child: Center(child: CircularProgressIndicator()))
                : Expanded(
                    child: Column(
                      children: [
                        // 类型列表
                        Expanded(
                          child: _types.isEmpty
                              ? Center(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      const Text('暂无自定义类型'),
                                      const SizedBox(height: 8),
                                      const Text('点击下方按钮添加'),
                                      const SizedBox(height: 16),
                                      FilledButton.tonal(
                                        onPressed: () => _showCreateDialog(context),
                                        child: const Text('添加类型'),
                                      ),
                                    ],
                                  ),
                                )
                              : ListView.builder(
                                  itemCount: _types.length,
                                  itemBuilder: (context, index) {
                                    final type = _types[index];
                                    return ListTile(
                                      leading: Icon(_getIcon(type.iconName)),
                                      title: Text(type.name),
                                      trailing: IconButton(
                                        icon: const Icon(Icons.delete_outline),
                                        onPressed: () => _deleteType(type),
                                      ),
                                    );
                                  },
                                ),
                        ),
                        // 添加按钮
                        Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: SizedBox(
                            width: double.infinity,
                            child: FilledButton.icon(
                              onPressed: () => _showCreateDialog(context),
                              icon: const Icon(Icons.add),
                              label: Text('添加${widget.isLiability ? "负债" : "资产"}类型'),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
          ],
        ),
      ),
    );
  }

  Future<void> _deleteType(CustomAssetType type) async {
    final provider = context.read<CustomTypeProvider>();

    // 检查是否被使用
    final inUse = await provider.isTypeInUse(type.id);
    if (!mounted) return;

    if (inUse) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('该类型正在使用中，无法删除')),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('确认删除'),
        content: const Text('删除后将保留历史记录中的类型名称'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('删除'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      final success = await provider.deleteCustomType(type.id);
      if (mounted) {
        setState(() {
          _loadTypes();
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(success ? '删除成功' : '删除失败')),
        );
      }
    }
  }

  void _showCreateDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => CreateCustomTypeDialog(isLiability: widget.isLiability),
    ).then((result) {
      if (result == true && mounted) {
        setState(() {
          _loadTypes();
        });
      }
    });
  }

  IconData _getIcon(String name) {
    switch (name) {
      // 资产图标
      case 'account_balance_wallet':
        return Icons.account_balance_wallet;
      case 'account_balance':
        return Icons.account_balance;
      case 'attach_money':
        return Icons.attach_money;
      case 'home':
        return Icons.home;
      case 'trending_up':
        return Icons.trending_up;
      case 'pie_chart':
        return Icons.pie_chart;
      case 'verified_user':
        return Icons.verified_user;
      case 'diamond':
        return Icons.diamond;
      case 'payments':
        return Icons.payments;
      // 负债图标
      case 'handshake':
        return Icons.handshake;
      case 'credit_card':
        return Icons.credit_card;
      case 'home_work':
        return Icons.home_work;
      case 'directions_car':
        return Icons.directions_car;
      case 'person':
        return Icons.person;
      case 'request_quote':
        return Icons.request_quote;
      case 'gavel':
        return Icons.gavel;
      case 'money_off':
        return Icons.money_off;
      default:
        return Icons.category;
    }
  }
}
