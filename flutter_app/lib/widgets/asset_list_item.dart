import 'package:flutter/material.dart';
import '../models/asset.dart';

/// 资产列表项
class AssetListItem extends StatelessWidget {
  final Asset asset;
  final VoidCallback? onTap;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  const AssetListItem({
    super.key,
    required this.asset,
    this.onTap,
    this.onEdit,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              _buildTypeIcon(context, asset.type),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      asset.name,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        if (asset.account != null) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.grey.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              asset.account!,
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(
                                    color: Colors.grey[600],
                                    fontWeight: FontWeight.w500,
                                  ),
                            ),
                          ),
                          const SizedBox(width: 8),
                        ],
                        Text(
                          _getTypeName(asset.type),
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: Colors.grey[500],
                              ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    _formatAmount(asset.amount),
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: Theme.of(context).colorScheme.primary,
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  if (asset.currency != null)
                    Text(
                      asset.currency!,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Colors.grey[500],
                          ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTypeIcon(BuildContext context, AssetType type) {
    IconData icon;
    Color color;

    switch (type) {
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
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(icon, color: color, size: 24),
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
    return type.displayName;
  }
}
