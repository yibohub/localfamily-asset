import 'package:flutter/material.dart';
import '../models/financial_models.dart';
import '../utils/currency_utils.dart';

/// 负债列表项组件
///
/// 显示负债基本信息和负债专属字段（利率、还款方式、到期日等）
class LiabilityListTile extends StatelessWidget {
  final Liability liability;
  final VoidCallback? onTap;

  const LiabilityListTile({
    super.key,
    required this.liability,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: _buildLeading(context),
      title: Text(
        liability.name,
        style: const TextStyle(fontWeight: FontWeight.w500),
      ),
      subtitle: _buildSubtitle(context, liability),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            CurrencyUtils.formatAmount(liability.amount, liability.currency),
            style: TextStyle(
              color: Colors.red[400],
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          if (liability.creditLimit != null && liability.isCreditCard)
            Text(
              '额度: ${CurrencyUtils.formatAmount(liability.creditLimit!, liability.currency)}',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.grey[600],
                  ),
            ),
        ],
      ),
      onTap: onTap,
    );
  }

  /// 构建左侧图标
  Widget? _buildLeading(BuildContext context) {
    IconData iconData;
    Color? iconColor;

    switch (liability.type) {
      case LiabilityType.creditCard:
        iconData = Icons.credit_card;
        iconColor = Colors.blue[400];
        break;
      case LiabilityType.mortgage:
        iconData = Icons.home_work;
        iconColor = Colors.brown[400];
        break;
      case LiabilityType.carLoan:
        iconData = Icons.directions_car;
        iconColor = Colors.purple[400];
        break;
      case LiabilityType.personalLoan:
        iconData = Icons.person;
        iconColor = Colors.orange[400];
        break;
      case LiabilityType.privateLoan:
        iconData = Icons.handshake;
        iconColor = Colors.teal[400];
        break;
      case LiabilityType.debt:
        iconData = Icons.receipt_long;
        iconColor = Colors.grey[400];
        break;
    }

    return CircleAvatar(
      backgroundColor: iconColor?.withOpacity(0.2),
      child: Icon(iconData, color: iconColor, size: 20),
    );
  }

  /// 构建副标题（根据负债类型显示不同信息）
  Widget? _buildSubtitle(BuildContext context, Liability liability) {
    final parts = <String>[];

    // 添加类型名称
    parts.add(liability.type.displayName);

    // 根据负债类型添加专属信息
    switch (liability.type) {
      case LiabilityType.creditCard:
        if (liability.lastFourDigits != null) {
          parts.add('****${liability.lastFourDigits}');
        }
        if (liability.issuer != null) {
          parts.add(liability.issuer!);
        }
        if (liability.billingDate != null) {
          parts.add('账单日${liability.billingDate!.day}日');
        }
        break;

      case LiabilityType.mortgage:
        if (liability.lender != null) {
          parts.add(liability.lender!);
        }
        if (liability.interestRate != null) {
          parts.add('利率${liability.interestRate!.toStringAsFixed(2)}%');
        }
        if (liability.repaymentMethod != null) {
          parts.add(liability.repaymentMethod!.displayName);
        }
        if (liability.dueDate != null) {
          final daysLeft = liability.daysUntilDue;
          if (daysLeft != null && daysLeft > 0) {
            parts.add('剩${daysLeft}天');
          }
        }
        break;

      case LiabilityType.carLoan:
        if (liability.lender != null) {
          parts.add(liability.lender!);
        }
        if (liability.vehicleBrand != null) {
          parts.add(liability.vehicleBrand!);
        }
        if (liability.interestRate != null) {
          parts.add('利率${liability.interestRate!.toStringAsFixed(2)}%');
        }
        break;

      case LiabilityType.personalLoan:
      case LiabilityType.privateLoan:
        if (liability.lender != null) {
          parts.add(liability.lender!);
        }
        if (liability.interestRate != null) {
          parts.add('利率${liability.interestRate!.toStringAsFixed(2)}%');
        }
        if (liability.purpose != null) {
          parts.add(liability.purpose!);
        }
        if (liability.repaymentMethod != null) {
          parts.add(liability.repaymentMethod!.displayName);
        }
        break;

      case LiabilityType.debt:
        if (liability.lender != null) {
          parts.add(liability.lender!);
        }
        if (liability.interestRate != null) {
          parts.add('利率${liability.interestRate!.toStringAsFixed(2)}%');
        }
        break;
    }

    // 添加还款日期信息
    if (liability.dueDate != null && liability.type != LiabilityType.mortgage) {
      final daysLeft = liability.daysUntilDue;
      if (daysLeft != null) {
        if (daysLeft < 0) {
          parts.add('已逾期${-daysLeft}天');
        } else if (daysLeft == 0) {
          parts.add('今日到期');
        } else if (daysLeft <= 7) {
          parts.add('${daysLeft}天后到期');
        }
      }
    }

    return Text(
      parts.join(' · '),
      style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Colors.grey[600],
          ),
    );
  }
}
