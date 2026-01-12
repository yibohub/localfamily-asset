import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/asset.dart';
import '../providers/asset_provider.dart';

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
            icon: const Icon(Icons.edit),
            onPressed: () {},
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
                        '资产价值',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      _buildTypeIcon(_asset!.type),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _formatAmount(_asset!.amount),
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          color: Theme.of(context).colorScheme.primary,
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          _buildInfoTile('资产类型', _getTypeName(_asset!.type)),
          _buildInfoTile('货币', _asset!.currency ?? 'N/A'),
          _buildInfoTile('代码', _asset!.symbol ?? 'N/A'),
          _buildInfoTile(
            '创建时间',
            _formatDate(_asset!.createdAt),
          ),
          _buildInfoTile(
            '更新时间',
            _formatDate(_asset!.updatedAt),
          ),
          if (_asset!.notes != null && _asset!.notes!.isNotEmpty) ...[
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
                    Text(_asset!.notes!),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTypeIcon(AssetType type) {
    IconData icon;
    Color color;

    switch (type) {
      case AssetType.cash:
        icon = Icons.money;
        color = const Color(0xFF10B981);
        break;
      case AssetType.stock:
        icon = Icons.show_chart;
        color = const Color(0xFF2563EB);
        break;
      case AssetType.bond:
        icon = Icons.description;
        color = const Color(0xFF7C3AED);
        break;
      case AssetType.fund:
        icon = Icons.pie_chart;
        color = const Color(0xFFF59E0B);
        break;
      case AssetType.realEstate:
        icon = Icons.home;
        color = const Color(0xFF8B5CF6);
        break;
      case AssetType.crypto:
        icon = Icons.currency_bitcoin;
        color = const Color(0xFFEF4444);
        break;
      case AssetType.commodity:
        icon = Icons.diamond;
        color = const Color(0xFFEC4899);
        break;
      default:
        icon = Icons.category;
        color = Colors.grey;
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
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
    if (amount >= 1000000) {
      return '\$${(amount / 1000000).toStringAsFixed(2)}M';
    } else if (amount >= 1000) {
      return '\$${(amount / 1000).toStringAsFixed(2)}K';
    }
    return '\$${amount.toStringAsFixed(2)}';
  }

  String _getTypeName(AssetType type) {
    switch (type) {
      case AssetType.cash:
        return '现金';
      case AssetType.stock:
        return '股票';
      case AssetType.bond:
        return '债券';
      case AssetType.fund:
        return '基金';
      case AssetType.realEstate:
        return '房地产';
      case AssetType.crypto:
        return '加密货币';
      case AssetType.commodity:
        return '商品';
      default:
        return '其他';
    }
  }

  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }
}
