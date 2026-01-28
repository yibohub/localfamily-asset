import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/asset.dart';
import '../providers/asset_provider.dart';
import 'asset_form_screen.dart';
import 'asset_history_screen.dart';

/// 资产详情页
class AssetDetailScreen extends StatefulWidget {
  final String assetId;

  const AssetDetailScreen({super.key, required this.assetId});

  @override
  State<AssetDetailScreen> createState() => _AssetDetailScreenState();
}

class _AssetDetailScreenState extends State<AssetDetailScreen> {
  Asset? _asset;

  @override
  void initState() {
    super.initState();
    _loadAsset();
  }

  void _loadAsset() {
    final provider = context.read<AssetProvider>();
    setState(() {
      _asset = provider.assets.firstWhere((a) => a.id == widget.assetId);
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_asset == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(_asset!.name),
        actions: [
          IconButton(
            icon: const Icon(Icons.history),
            tooltip: '查看历史',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => AssetHistoryScreen(assetId: _asset!.id),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => AssetFormScreen(asset: _asset),
                ),
              ).then((_) => _loadAsset());
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        _isLiabilityType(_asset!.type) ? '负债金额' : '资产价值',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      _buildTypeIcon(_asset!.type),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _formatAmount(_asset!.amount),
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          color: _isLiabilityType(_asset!.type)
                              ? Colors.red
                              : Theme.of(context).colorScheme.primary,
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          _buildInfoTile(_isLiabilityType(_asset!.type) ? '负债类型' : '资产类型', _getTypeName(_asset!.type)),
          _buildInfoTile('货币', _asset!.currency),
          _buildInfoTile('发生日期', _formatDate(_asset!.occurrenceDate)),
          _buildInfoTile('账号', _asset!.account ?? 'N/A'),
          _buildInfoTile(
            '创建时间',
            _formatDate(_asset!.createdAt),
          ),
          _buildInfoTile(
            '更新时间',
            _formatDate(_asset!.updatedAt),
          ),
          if (_asset!.note != null && _asset!.note!.isNotEmpty) ...[
            const SizedBox(height: 16),
            Card(
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
                    Text(_asset!.note!),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTypeIcon(String typeStr) {
    // 解析类型字符串
    final builtInType = AssetTypeExtension.fromString(typeStr);

    IconData icon;
    Color color;

    if (builtInType != null) {
      // 内置类型
      switch (builtInType) {
        case AssetType.property:
          icon = Icons.home;
          color = const Color(0xFF2563EB);
          break;
        case AssetType.deposit:
          icon = Icons.account_balance;
          color = const Color(0xFF10B981);
          break;
        case AssetType.stock:
          icon = Icons.trending_up;
          color = const Color(0xFFF59E0B);
          break;
        case AssetType.fund:
          icon = Icons.pie_chart;
          color = const Color(0xFF7C3AED);
          break;
        case AssetType.insurance:
          icon = Icons.security;
          color = const Color(0xFF8B5CF6);
          break;
        case AssetType.debt:
          icon = Icons.credit_card;
          color = const Color(0xFFEF4444);
          break;
        case AssetType.mortgage:
          icon = Icons.home_work;
          color = const Color(0xFFDC2626);
          break;
        case AssetType.carLoan:
          icon = Icons.directions_car;
          color = const Color(0xFFEA580C);
          break;
        case AssetType.creditCard:
          icon = Icons.credit_card;
          color = const Color(0xFFF59E0B);
          break;
        case AssetType.personalLoan:
          icon = Icons.person;
          color = const Color(0xFFD97706);
          break;
        case AssetType.privateLoan:
          icon = Icons.handshake;
          color = const Color(0xFFCA8A04);
          break;
      }
    } else {
      // 自定义类型 - 使用默认图标和颜色
      icon = Icons.category;
      color = const Color(0xFF6B7280);
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(icon, color: color, size: 28),
    );
  }

  Widget _buildInfoTile(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
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
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w500,
                ),
          ),
        ],
      ),
    );
  }

  String _formatAmount(double amount) {
    if (amount >= 100000000) {
      return '¥ ${(amount / 100000000).toStringAsFixed(2)} 亿';
    } else if (amount >= 10000) {
      return '¥ ${(amount / 10000).toStringAsFixed(2)} 万';
    }
    return '¥ ${amount.toStringAsFixed(2)}';
  }

  String _getTypeName(String typeStr) {
    final builtInType = AssetTypeExtension.fromString(typeStr);
    if (builtInType != null) {
      return builtInType.displayName;
    }
    // 自定义类型：移除 custom_ 前缀
    return typeStr.replaceAll('custom_', '');
  }

  /// 判断字符串类型是否为负债
  bool _isLiabilityType(String typeStr) {
    final builtInType = AssetTypeExtension.fromString(typeStr);
    if (builtInType != null) {
      return builtInType.isLiability;
    }
    // 自定义类型暂时当作资产处理
    return false;
  }

  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }
}
