import 'dart:convert';
import 'asset.dart';
import '../utils/currency_utils.dart';

/// 变更类型枚举
enum ChangeType {
  created,  // 新增
  updated,  // 修改
  deleted,  // 删除
}

/// 变更类型扩展
extension ChangeTypeExtension on ChangeType {
  /// 获取中文名称
  String get displayName {
    switch (this) {
      case ChangeType.created:
        return '新增';
      case ChangeType.updated:
        return '修改';
      case ChangeType.deleted:
        return '删除';
    }
  }

  /// 从字符串创建枚举
  static ChangeType fromString(String str) {
    switch (str) {
      case 'created':
        return ChangeType.created;
      case 'updated':
        return ChangeType.updated;
      case 'deleted':
        return ChangeType.deleted;
      default:
        return ChangeType.created;
    }
  }
}

/// 资产变更记录（审计日志）
class AssetChange {
  final String id;
  final String assetId;
  final ChangeType changeType;
  final DateTime? occurrenceDateOld;
  final DateTime? occurrenceDateNew;
  final double? amountOld;
  final double? amountNew;
  final String? nameOld;
  final String? nameNew;
  final Map<String, dynamic>? dataSnapshotOld;
  final Map<String, dynamic>? dataSnapshotNew;
  final String? changedField;
  final DateTime changedAt;

  AssetChange({
    required this.id,
    required this.assetId,
    required this.changeType,
    this.occurrenceDateOld,
    this.occurrenceDateNew,
    this.amountOld,
    this.amountNew,
    this.nameOld,
    this.nameNew,
    this.dataSnapshotOld,
    this.dataSnapshotNew,
    this.changedField,
    required this.changedAt,
  });

  /// 判断是否为负债类型
  bool get _isLiability {
    // 优先从新数据快照获取类型
    if (dataSnapshotNew != null) {
      // 先检查 liability_type（负债专用字段）
      final liabilityTypeStr = dataSnapshotNew!['liability_type'] as String?;
      if (liabilityTypeStr != null) {
        return true; // 有 liability_type 字段就是负债
      }
      // 再检查 asset_type（资产字段，但也包含负债类型）
      final typeStr = dataSnapshotNew!['asset_type'] as String?;
      if (typeStr != null) {
        final type = AssetTypeExtension.fromString(typeStr);
        if (type != null) {
          return type.isLiability;
        }
      }
    }
    // 其次从旧数据快照获取类型
    if (dataSnapshotOld != null) {
      final liabilityTypeStr = dataSnapshotOld!['liability_type'] as String?;
      if (liabilityTypeStr != null) {
        return true;
      }
      final typeStr = dataSnapshotOld!['asset_type'] as String?;
      if (typeStr != null) {
        final type = AssetTypeExtension.fromString(typeStr);
        if (type != null) {
          return type.isLiability;
        }
      }
    }
    // 默认为资产类型
    return false;
  }

  /// 获取类型名称（资产或负债）
  String get _typeName => _isLiability ? '负债' : '资产';

  /// 获取变更描述
  String get changeDescription {
    // 获取名称（优先使用新名称，其次使用旧名称）
    final String? displayName = nameNew ?? nameOld;

    switch (changeType) {
      case ChangeType.created:
        return '新增了$_typeName ${nameNew ?? ""}';
      case ChangeType.deleted:
        return '删除了$_typeName ${nameOld ?? ""}';
      case ChangeType.updated:
        final recordName = displayName != null && displayName.isNotEmpty ? '「$displayName」' : '';
        if (changedField != null) {
          return '修改了${_typeName}$recordName的${_translateField(changedField!)}';
        }
        return '修改了${_typeName}$recordName';
    }
  }

  /// 翻译字段名
  String _translateField(String field) {
    switch (field) {
      case 'name':
        return '名称';
      case 'amount':
        return '金额';
      case 'account':
        return '账户/编号';
      case 'occurrence_date':
        return '发生日期';
      case 'type':
        return '类型';
      case 'currency':
        return '币种';
      case 'buy_price':
        return '买入价';
      case 'current_price':
        return '现价';
      case 'note':
        return '备注';
      case 'tags':
        return '标签';
      default:
        return field;
    }
  }

  /// 获取详细信息
  String get detailDescription {
    final buffer = StringBuffer();

    if (changeType == ChangeType.updated) {
      // 手动处理的常见字段（保持原有逻辑）
      if (nameOld != null && nameNew != null && nameOld != nameNew) {
        buffer.writeln('名称从 "$nameOld" 改为 "$nameNew"');
      }
      if (amountOld != null && amountNew != null && amountOld != amountNew) {
        final currency = dataSnapshotNew?['currency'] as String? ?? 'CNY';
        buffer.writeln('金额从 ${_formatAmount(amountOld!, currency)} 改为 ${_formatAmount(amountNew!, currency)}');
      }
      if (occurrenceDateOld != null && occurrenceDateNew != null && occurrenceDateOld != occurrenceDateNew) {
        buffer.writeln('发生日期从 ${_formatDate(occurrenceDateOld!)} 改为 ${_formatDate(occurrenceDateNew!)}');
      }

      // 自动检测其他字段的变化
      if (dataSnapshotOld != null && dataSnapshotNew != null) {
        final oldData = dataSnapshotOld!;
        final newData = dataSnapshotNew!;

        // 获取所有可能的字段键（合并新旧数据的键）
        final allKeys = {...oldData.keys, ...newData.keys};

        // 排除已经手动处理的字段和系统字段
        final handledFields = {
          'id', 'name', 'amount', 'currency', 'occurrence_date',
          'created_at', 'updated_at',
        };

        // 字段名中文映射
        final fieldNames = {
          'asset_type': '资产类型',
          'liability_type': '负债类型',
          'account': '账户',
          'tags': '标签',
          'buy_price': '买入价',
          'current_price': '现价',
          'code': '代码',
          'exchange': '交易所',
          'quantity': '数量',
          'address': '地址',
          'building_area': '建筑面积',
          'living_area': '使用面积',
          'property_type': '房屋类型',
          'rooms': '房间数',
          'floor': '楼层',
          'build_year': '建成年份',
          'ownership_type': '产权性质',
          'deed_number': '不动产证号',
          'deposit_account_type': '账户类型',
          'deposit_period': '存期',
          'maturity_date': '到期日期',
          'deposit_interest_rate': '利率',
          'policy_number': '保单号',
          'insurance_type': '保险类型',
          'insured': '被保人',
          'beneficiary': '受益人',
          'coverage_amount': '保额',
          'premium': '保费',
          'premium_period': '缴费期限',
          'coverage_period': '保险期限',
          'insurer': '保险公司',
          'lender': '债权人',
          'due_date': '到期日',
          'interest_rate': '年利率',
          'repayment_method': '还款方式',
          'loan_term': '贷款期限',
          'last_four_digits': '卡号后四位',
          'billing_date': '账单日',
          'payment_due_date': '还款日',
          'credit_limit': '信用额度',
          'cash_limit': '取现额度',
          'annual_fee': '年费',
          'issuer': '发卡行',
          'property_address': '房产地址',
          'original_loan_amount': '原始贷款金额',
          'remaining_principal': '剩余本金',
          'loan_type': '贷款类型',
          'vehicle_brand': '车辆品牌',
          'vehicle_model': '车型',
          'license_plate': '车牌号',
          'purpose': '借款用途',
          'has_interest': '是否有利息',
          'repayment_plan': '还款计划',
          'note': '备注',
        };

        for (final key in allKeys) {
          if (handledFields.contains(key)) continue;

          final oldValue = oldData[key];
          final newValue = newData[key];

          // 只有值不同时才记录
          if (!_valuesEqual(oldValue, newValue)) {
            final fieldName = fieldNames[key] ?? key;
            buffer.writeln('${_formatFieldValueChange(fieldName, oldValue, newValue)}');
          }
        }
      }
    } else if (changeType == ChangeType.created) {
      if (amountNew != null) {
        final currency = dataSnapshotNew?['currency'] as String? ?? 'CNY';
        buffer.writeln('金额：${_formatAmount(amountNew!, currency)}');
      }
      if (occurrenceDateNew != null) {
        buffer.writeln('发生日期：${_formatDate(occurrenceDateNew!)}');
      }
      final buyPriceNew = dataSnapshotNew?['buy_price'] as double?;
      if (buyPriceNew != null) {
        final currency = dataSnapshotNew?['currency'] as String? ?? 'CNY';
        buffer.writeln('买入价：${_formatAmount(buyPriceNew, currency)}');
      }
      final currentPriceNew = dataSnapshotNew?['current_price'] as double?;
      if (currentPriceNew != null) {
        final currency = dataSnapshotNew?['currency'] as String? ?? 'CNY';
        buffer.writeln('现价：${_formatAmount(currentPriceNew, currency)}');
      }
    } else if (changeType == ChangeType.deleted) {
      if (amountOld != null) {
        final currency = dataSnapshotOld?['currency'] as String? ?? 'CNY';
        buffer.writeln('金额：${_formatAmount(amountOld!, currency)}');
      }
      if (occurrenceDateOld != null) {
        buffer.writeln('发生日期：${_formatDate(occurrenceDateOld!)}');
      }
    }

    return buffer.toString().trim();
  }

  /// 比较两个值是否相等
  bool _valuesEqual(dynamic a, dynamic b) {
    if (a == null && b == null) return true;
    if (a == null || b == null) return false;
    return a.toString() == b.toString();
  }

  /// 格式化字段值变化
  String _formatFieldValueChange(String fieldName, dynamic oldValue, dynamic newValue) {
    final oldStr = _formatFieldValue(oldValue);
    final newStr = _formatFieldValue(newValue);

    if (oldStr.isEmpty) {
      return '$fieldName：设置为 $newStr';
    } else if (newStr.isEmpty) {
      return '$fieldName：已清除（原值：$oldStr）';
    } else {
      return '$fieldName：$oldStr → $newStr';
    }
  }

  /// 格式化单个字段值
  String _formatFieldValue(dynamic value) {
    if (value == null) return '';
    if (value is bool) return value ? '是' : '否';
    if (value is double || value is int) return value.toString();
    if (value is List) return (value as List).join(', ');
    // 翻译枚举值
    if (value is String) {
      return _translateEnumValue(value);
    }
    return value.toString();
  }

  /// 翻译枚举值为中文
  String _translateEnumValue(String value) {
    // 还款方式
    const repaymentMethodMap = {
      'equal_principal_and_interest': '等额本息',
      'equal_principal': '等额本金',
      'bullet_payment': '到期还本付息',
      'monthly_interest': '按月付息到期还本',
      'custom': '自定义',
    };

    // 资产类型
    const assetTypeMap = {
      'property': '房产',
      'deposit': '存款',
      'stock': '股票',
      'fund': '基金',
      'insurance': '保单',
    };

    // 负债类型
    const liabilityTypeMap = {
      'debt': '其他负债',
      'mortgage': '房贷',
      'car_loan': '车贷',
      'credit_card': '信用卡',
      'personal_loan': '个人贷款',
      'private_loan': '私人借款',
    };

    // 存款账户类型
    const depositAccountTypeMap = {
      'checking': '活期',
      'savings': '定期',
    };

    return repaymentMethodMap[value] ??
           assetTypeMap[value] ??
           liabilityTypeMap[value] ??
           depositAccountTypeMap[value] ??
           value;
  }

  String _formatAmount(double amount, String currency) {
    return CurrencyUtils.formatAmount(amount, currency);
  }

  String _formatDate(DateTime date) {
    return '${date.year}年${date.month}月${date.day}日';
  }

  /// 从 JSON 创建
  factory AssetChange.fromJson(Map<String, dynamic> json) {
    // 解析 data_snapshot_old（如果存在）
    Map<String, dynamic>? snapshotOld;
    if (json['data_snapshot_old'] != null) {
      final snapshotStr = json['data_snapshot_old'] as String;
      try {
        snapshotOld = Map<String, dynamic>.from(jsonDecode(snapshotStr));
      } catch (_) {
        snapshotOld = null;
      }
    }

    // 解析 data_snapshot_new（如果存在）
    Map<String, dynamic>? snapshotNew;
    if (json['data_snapshot_new'] != null) {
      final snapshotStr = json['data_snapshot_new'] as String;
      try {
        snapshotNew = Map<String, dynamic>.from(jsonDecode(snapshotStr));
      } catch (_) {
        snapshotNew = null;
      }
    }

    return AssetChange(
      id: json['id'] as String,
      assetId: json['asset_id'] as String,
      changeType: ChangeTypeExtension.fromString(json['change_type'] as String),
      occurrenceDateOld: json['occurrence_date_old'] != null
          ? _parseDate(json['occurrence_date_old'] as String)
          : null,
      occurrenceDateNew: json['occurrence_date_new'] != null
          ? _parseDate(json['occurrence_date_new'] as String)
          : null,
      amountOld: json['amount_old'] != null
          ? (json['amount_old'] as num).toDouble()
          : null,
      amountNew: json['amount_new'] != null
          ? (json['amount_new'] as num).toDouble()
          : null,
      nameOld: json['name_old'] as String?,
      nameNew: json['name_new'] as String?,
      dataSnapshotOld: snapshotOld,
      dataSnapshotNew: snapshotNew,
      changedField: json['changed_field'] as String?,
      changedAt: DateTime.fromMillisecondsSinceEpoch(
        (json['changed_at'] as int) * 1000,
      ),
    );
  }

  /// 解析日期字符串（支持多种格式）
  static DateTime? _parseDate(String dateStr) {
    try {
      return DateTime.parse(dateStr);
    } catch (_) {
      // 尝试解析 YYYY-MM-DD 格式
      final regExp = RegExp(r'^\d{4}-\d{2}-\d{2}$');
      if (regExp.hasMatch(dateStr)) {
        final parts = dateStr.split('-');
        if (parts.length == 3) {
          try {
            return DateTime(
              int.parse(parts[0]),
              int.parse(parts[1]),
              int.parse(parts[2]),
            );
          } catch (_) {
            return null;
          }
        }
      }
      return null;
    }
  }
}
