import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/asset.dart';
import '../providers/asset_provider.dart';
import '../utils/currency_utils.dart';
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
                    _formatAmount(_asset!.amount, _asset!.currency),
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
          // 盈亏信息（仅在有买入价和现价时显示）
          if (_asset!.buyPrice != null || _asset!.currentPrice != null) ...[
            const SizedBox(height: 16),
            _buildProfitLossCard(),
          ],
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

  String _formatAmount(double amount, String currency) {
    return CurrencyUtils.formatAmount(amount, currency);
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

  /// 构建盈亏信息卡片
  Widget _buildProfitLossCard() {
    final buyPrice = _asset!.buyPrice;
    final currentPrice = _asset!.currentPrice;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.show_chart,
                  color: Theme.of(context).colorScheme.primary,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  '价格信息',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (buyPrice != null)
              _buildInfoTile(
                '买入价',
                _formatAmount(buyPrice, _asset!.currency),
              ),
            if (currentPrice != null)
              _buildInfoTile(
                '现价',
                _formatAmount(currentPrice, _asset!.currency),
              ),
            // 显示盈亏
            if (buyPrice != null && currentPrice != null) ...[
              const Divider(height: 24),
              _buildProfitLossInfo(),
            ],
          ],
        ),
      ),
    );
  }

  /// 构建盈亏信息
  Widget _buildProfitLossInfo() {
    final profitLossPercent = _asset!.profitLossPercent;
    final profitLossAmount = _asset!.profitLossAmount;

    if (profitLossPercent == null || profitLossAmount == null) {
      return const SizedBox.shrink();
    }

    final isProfit = profitLossAmount >= 0;
    final profitText = isProfit ? '盈利' : '亏损';
    final profitColor = isProfit ? Colors.red : Colors.green; // 中国股市：红涨绿跌

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          '盈亏',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Colors.grey[600],
              ),
        ),
        Row(
          children: [
            Text(
              '$profitText ${_formatAmount(profitLossAmount.abs(), _asset!.currency)}',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: profitColor,
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: profitColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                '${profitLossPercent >= 0 ? '+' : ''}${profitLossPercent.toStringAsFixed(2)}%',
                style: TextStyle(
                  color: profitColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
