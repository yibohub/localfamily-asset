import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'dart:convert';

import '../../providers/auth_provider.dart';
import '../../providers/asset_provider.dart';
import '../../models/asset.dart';
import '../home_screen.dart';

/// 初始设置页
class SetupScreen extends StatefulWidget {
  const SetupScreen({super.key});

  @override
  State<SetupScreen> createState() => _SetupScreenState();
}

class _SetupScreenState extends State<SetupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  final _hintController = TextEditingController();

  bool _obscurePassword = true;
  bool _obscureConfirm = true;
  bool _isLoading = false;
  String? _selectedDemo; // 'buffett' or 'musk' or null

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmController.dispose();
    _hintController.dispose();
    super.dispose();
  }

  /// 加载 Demo 数据
  Future<void> _loadDemoData() async {
    if (_selectedDemo == null) return;

    try {
      final String jsonString = await rootBundle.loadString(
        'assets/demo/${_selectedDemo}_assets.json',
      );
      final Map<String, dynamic> demoData = jsonDecode(jsonString);
      final List<dynamic> assetsJson = demoData['assets'] as List<dynamic>;

      final assetProvider = context.read<AssetProvider>();

      for (var assetJson in assetsJson) {
        final asset = Asset(
          id: assetJson['id'] as String,
          name: assetJson['name'] as String,
          type: _assetTypeFromString(assetJson['type'] as String),
          amount: (assetJson['amount'] as num).toDouble(),
          currency: assetJson['currency'] as String?,
          account: assetJson['account'] as String?,
          note: assetJson['note'] as String?,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );
        await assetProvider.addAsset(asset);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('已加载 ${demoData['name']}'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      debugPrint('加载 Demo 数据失败: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('加载 Demo 数据失败: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  AssetType _assetTypeFromString(String type) {
    switch (type) {
      case 'property':
        return AssetType.property;
      case 'deposit':
        return AssetType.deposit;
      case 'stock':
        return AssetType.stock;
      case 'fund':
        return AssetType.fund;
      case 'insurance':
        return AssetType.insurance;
      case 'debt':
        return AssetType.debt;
      default:
        return AssetType.deposit;
    }
  }

  Future<void> _setup() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    final authProvider = context.read<AuthProvider>();
    final success = await authProvider.setupPassword(
      _passwordController.text,
      hint: _hintController.text.isEmpty ? null : _hintController.text,
    );

    if (!success) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('设置失败，请重试')),
        );
      }
      return;
    }

    // 如果选择了 Demo 模式，加载演示数据
    if (_selectedDemo != null) {
      await _loadDemoData();
    }

    setState(() => _isLoading = false);

    if (!mounted) return;

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const HomeScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('初始设置'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Icon(
                  Icons.lock_person,
                  size: 64,
                  color: Color(0xFF2563EB),
                ),
                const SizedBox(height: 24),
                Text(
                  '设置主密码',
                  style: Theme.of(context).textTheme.headlineSmall,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                Text(
                  '请设置一个强密码来保护您的资产数据。'
                  '此密码用于加密您的所有数据，请妥善保管。',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Colors.grey,
                      ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),

                // Demo 模式选择
                Card(
                  elevation: 0,
                  color: Colors.blue.withValues(alpha: 0.05),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.lightbulb_outline, color: Colors.amber[700]),
                            const SizedBox(width: 8),
                            Text(
                              '体验 Demo 模式',
                              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                    color: Colors.amber[700],
                                  ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '选择预设的演示数据快速体验应用功能',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: Colors.grey[600],
                              ),
                        ),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            _buildDemoChip(null, '空白数据'),
                            _buildDemoChip('buffett', '巴菲特组合'),
                            _buildDemoChip('musk', '马斯克资产'),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 24),

                // 密码设置部分标题
                if (_selectedDemo == null)
                  Text(
                    '设置安全密码',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                  )
                else
                  Text(
                    '设置 Demo 密码',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _passwordController,
                  obscureText: _obscurePassword,
                  decoration: InputDecoration(
                    labelText: '主密码',
                    suffixIcon: IconButton(
                      icon: Icon(_obscurePassword
                          ? Icons.visibility_off
                          : Icons.visibility),
                      onPressed: () {
                        setState(() => _obscurePassword = !_obscurePassword);
                      },
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.length < 8) {
                      return '密码至少需要8个字符';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _confirmController,
                  obscureText: _obscureConfirm,
                  decoration: InputDecoration(
                    labelText: '确认密码',
                    suffixIcon: IconButton(
                      icon: Icon(_obscureConfirm
                          ? Icons.visibility_off
                          : Icons.visibility),
                      onPressed: () {
                        setState(() => _obscureConfirm = !_obscureConfirm);
                      },
                    ),
                  ),
                  validator: (value) {
                    if (value != _passwordController.text) {
                      return '两次输入的密码不一致';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _hintController,
                  decoration: const InputDecoration(
                    labelText: '密码提示（可选）',
                    hintText: '例如：我最喜欢的城市',
                  ),
                ),
                const SizedBox(height: 32),
                FilledButton(
                  onPressed: _isLoading ? null : _setup,
                  child: _isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('完成设置'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDemoChip(String? value, String label) {
    final isSelected = _selectedDemo == value;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (_) => setState(() => _selectedDemo = value),
      avatar: isSelected
          ? const Icon(Icons.check_circle, size: 18)
          : Icon(value == null ? Icons.add_circle_outline : Icons.person_outline, size: 18),
      selectedColor: value == null ? Colors.grey : Colors.amber,
      labelStyle: TextStyle(
        color: isSelected ? Colors.white : Colors.black87,
        fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
      ),
    );
  }
}
