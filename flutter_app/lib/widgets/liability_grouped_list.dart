import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../models/financial_models.dart';
import '../utils/currency_utils.dart';
import 'liability_list_tile.dart';
import '../screens/financial_record_detail_screen.dart';

/// 规范化负债名称用于分组（去除所有可能导致无法匹配的差异）
String _normalizeGroupName(String name) {
  // 去除首尾空格
  var normalized = name.trim();
  // 去除所有内部空格
  normalized = normalized.replaceAll(' ', '');
  // 去除零宽空格和其他不可见字符
  normalized = normalized.replaceAll(RegExp(r'[\u200B\u200C\u200D\uFEFF]'), '');
  return normalized;
}

/// 2级分组负债列表组件
///
/// 第1级：按负债名称分组
/// 第2级：在同名负债下，按债权人/机构分组
class LiabilityGroupedList extends StatelessWidget {
  final List<Liability> liabilities;

  const LiabilityGroupedList({
    super.key,
    required this.liabilities,
  });

  @override
  Widget build(BuildContext context) {
    if (liabilities.isEmpty) {
      return const SizedBox.shrink();
    }

    // 第1级：按负债名称分组（使用规范化名称）
    final byName = <String, List<Liability>>{};
    for (final liability in liabilities) {
      final normalizedName = _normalizeGroupName(liability.name);
      byName.putIfAbsent(normalizedName, () => []).add(liability);
    }

    // 按总金额排序（金额大的在前）
    final sortedNames = byName.entries.toList()
      ..sort((a, b) {
        final totalA = a.value.fold(0.0, (sum, l) => sum + l.amount);
        final totalB = b.value.fold(0.0, (sum, l) => sum + l.amount);
        return totalB.compareTo(totalA);
      });

    // 调试输出
    if (kDebugMode) {
      debugPrint('🔍 负债分组调试:');
      debugPrint('  总负债数: ${liabilities.length}');
      debugPrint('  分组数: ${sortedNames.length}');
      for (final entry in sortedNames) {
        debugPrint('  "${entry.key}": ${entry.value.length} 笔');
      }
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: sortedNames.length,
      itemBuilder: (context, index) {
        final entry = sortedNames[index];
        return _LiabilityGroupCard(
          liabilityName: entry.key,
          liabilities: entry.value,
        );
      },
    );
  }
}

/// 负债分组卡片（第1级）
class _LiabilityGroupCard extends StatelessWidget {
  final String liabilityName;
  final List<Liability> liabilities;

  const _LiabilityGroupCard({
    required this.liabilityName,
    required this.liabilities,
  });

  double get _totalAmount {
    return liabilities.fold(0.0, (sum, l) => sum + l.amount);
  }

  /// 获取显示名称（使用第一个负债的原始名称）
  String get _displayName {
    return liabilities.first.name;
  }

  @override
  Widget build(BuildContext context) {
    // 第2级：按债权人/机构分组
    final byLender = <String, List<Liability>>{};
    for (final liability in liabilities) {
      final lenderKey = liability.lender ?? liability.issuer ?? '无机构';
      byLender.putIfAbsent(lenderKey, () => []).add(liability);
    }

    // 如果整个分组只有1笔负债且只有1个机构，直接显示为列表项
    if (liabilities.length == 1 && byLender.length == 1) {
      return LiabilityListTile(
        liability: liabilities.first,
        onTap: () => _navigateToDetail(context, liabilities.first),
      );
    }

    // 多笔负债或多机构，显示可展开的分组卡片
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          leading: CircleAvatar(
            backgroundColor: Colors.red[50],
            child: Icon(Icons.credit_card, color: Colors.red[400], size: 20),
          ),
          title: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  _displayName,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              Text(
                CurrencyUtils.formatAmount(
                    _totalAmount, liabilities.first.currency),
                style: TextStyle(
                  color: Colors.red[400],
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          subtitle: Text(
            '${liabilities.length}笔负债，${byLender.length}个机构',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          children: [
            const Divider(height: 1),
            ...byLender.entries.map((entry) {
              return _LenderGroupTile(
                lenderName: entry.key,
                liabilities: entry.value,
              );
            }),
          ],
        ),
      ),
    );
  }

  /// 导航到详情页
  void _navigateToDetail(BuildContext context, Liability liability) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => FinancialRecordDetailScreen(
          recordId: liability.id,
          recordType: RecordType.liability,
        ),
      ),
    );
  }
}

/// 机构分组项（第2级）
class _LenderGroupTile extends StatelessWidget {
  final String lenderName;
  final List<Liability> liabilities;

  const _LenderGroupTile({
    required this.lenderName,
    required this.liabilities,
  });

  double get _totalAmount {
    return liabilities.fold(0.0, (sum, l) => sum + l.amount);
  }

  @override
  Widget build(BuildContext context) {
    // 如果该机构只有1笔负债，直接显示列表项
    if (liabilities.length == 1) {
      return LiabilityListTile(
        liability: liabilities.first,
        onTap: () => _navigateToDetail(context, liabilities.first),
      );
    }

    // 多笔负债，显示可展开的机构分组
    return ExpansionTile(
      leading: Icon(
        lenderName == '无机构' ? Icons.help_outline : Icons.business,
        size: 20,
        color: Colors.grey[600],
      ),
      title: Text(lenderName),
      trailing: Text(
        CurrencyUtils.formatAmount(_totalAmount, liabilities.first.currency),
        style: TextStyle(
          color: Colors.red[400],
          fontWeight: FontWeight.bold,
        ),
      ),
      subtitle: Text('${liabilities.length}笔负债'),
      children: [
        const Divider(height: 1),
        ...liabilities.map((liability) => Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                children: [
                  LiabilityListTile(
                    liability: liability,
                    onTap: () => _navigateToDetail(context, liability),
                  ),
                  if (liability != liabilities.last) const Divider(height: 1),
                ],
              ),
            )),
      ],
    );
  }

  /// 导航到详情页
  void _navigateToDetail(BuildContext context, Liability liability) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => FinancialRecordDetailScreen(
          recordId: liability.id,
          recordType: RecordType.liability,
        ),
      ),
    );
  }
}
