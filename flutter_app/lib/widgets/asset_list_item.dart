import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/asset.dart';
import '../models/custom_asset_type.dart';
import '../providers/custom_type_provider.dart';

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
                          color: _isLiabilityType(asset.type)
                            ? Colors.red
                            : Theme.of(context).colorScheme.primary,
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  Text(
                    asset.currency,
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

  Widget _buildTypeIcon(BuildContext context, String typeStr) {
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
      // 自定义类型 - 从 CustomTypeProvider 获取图标
      final customTypeProvider = context.watch<CustomTypeProvider>();
      final customTypes = customTypeProvider.customTypes;

      // 调试输出
      debugPrint('查找自定义类型: $typeStr, 可用类型数: ${customTypes.length}');

      // 查找匹配的自定义类型
      CustomAssetType? matchedType;
      for (final type in customTypes) {
        debugPrint('  检查: ${type.id} == $typeStr ? ${type.id == typeStr}');
        if (type.id == typeStr) {
          matchedType = type;
          break;
        }
      }

      if (matchedType != null) {
        debugPrint('  找到匹配类型: ${matchedType.name}, 图标: ${matchedType.iconName}');
        icon = _getCustomIcon(matchedType.iconName);
      } else {
        debugPrint('  未找到匹配类型，使用默认图标');
        icon = Icons.category;
      }
      // 自定义类型使用灰色系
      color = const Color(0xFF6B7280);
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

  IconData _getCustomIcon(String iconName) {
    switch (iconName) {
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
}
