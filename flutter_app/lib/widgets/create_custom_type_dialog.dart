import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/custom_type_provider.dart';

/// 创建自定义类型对话框
class CreateCustomTypeDialog extends StatefulWidget {
  final bool isLiability;

  const CreateCustomTypeDialog({super.key, required this.isLiability});

  @override
  State<CreateCustomTypeDialog> createState() =>
      _CreateCustomTypeDialogState();
}

class _CreateCustomTypeDialogState extends State<CreateCustomTypeDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  late String _selectedIcon;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    // 根据类型设置默认图标
    _selectedIcon = widget.isLiability ? 'handshake' : 'account_balance_wallet';
  }

  // 资产类型图标
  static const _assetIcons = [
    'account_balance_wallet',  // 钱包
    'account_balance',          // 银行
    'attach_money',            // 现金
    'home',                    // 房产
    'trending_up',             // 股票
    'pie_chart',               // 基金
    'verified_user',           // 保险
    'diamond',                 // 珠宝
    'payments',                // 款项
  ];

  // 负债类型图标
  static const _liabilityIcons = [
    'handshake',               // 借款
    'credit_card',             // 信用卡
    'home_work',               // 房贷
    'directions_car',          // 车贷
    'person',                  // 个人借贷
    'account_balance',         // 银行贷款
    'request_quote',           // 分期付款
    'gavel',                   // 欠款
    'money_off',               // 债务
  ];

  static const _iconLabels = {
    // 资产图标标签
    'account_balance_wallet': '钱包',
    'account_balance': '银行',
    'attach_money': '现金',
    'home': '房产',
    'trending_up': '股票',
    'pie_chart': '基金',
    'verified_user': '保险',
    'diamond': '珠宝',
    'payments': '款项',
    // 负债图标标签
    'handshake': '借款',
    'credit_card': '信用卡',
    'home_work': '房贷',
    'directions_car': '车贷',
    'person': '个人借贷',
    'request_quote': '分期付款',
    'gavel': '欠款',
    'money_off': '债务',
  };

  /// 根据是否为负债类型获取可用图标列表
  List<String> _getAvailableIcons() {
    return widget.isLiability ? _liabilityIcons : _assetIcons;
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: SizedBox(
        width: 350,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                title: Text('添加自定义${widget.isLiability ? "负债" : "资产"}类型'),
                trailing: IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    TextFormField(
                      controller: _nameController,
                      decoration: InputDecoration(
                        labelText: '类型名称',
                        hintText: widget.isLiability ? '如：私人借款' : '如：理财产品',
                      ),
                      validator: (v) {
                        if (v?.trim().isEmpty ?? true) {
                          return '请输入名称';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      '选择图标',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _getAvailableIcons().map((icon) {
                        return InkWell(
                          onTap: () => setState(() => _selectedIcon = icon),
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              border: Border.all(
                                color: _selectedIcon == icon
                                    ? Theme.of(context).colorScheme.primary
                                    : Colors.grey,
                              ),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Column(
                              children: [
                                Icon(_getIcon(icon)),
                                const SizedBox(height: 4),
                                Text(
                                  _iconLabels[icon] ?? icon,
                                  style: const TextStyle(fontSize: 12),
                                ),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
              const Divider(),
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: _isSaving ? null : _submit,
                    child: _isSaving
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('创建'),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    final provider = context.read<CustomTypeProvider>();
    final id = await provider.createCustomType(
      name: _nameController.text.trim(),
      iconName: _selectedIcon,
      isLiability: widget.isLiability,
    );

    if (!mounted) return;

    setState(() => _isSaving = false);

    if (id != null) {
      Navigator.pop(context, true);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('创建成功')),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('创建失败')),
      );
    }
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
