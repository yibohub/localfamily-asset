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
      final typeStr = dataSnapshotNew!['type'] as String?;
      if (typeStr != null) {
        final type = AssetTypeExtension.fromString(typeStr);
        if (type != null) {
          return type.isLiability;
        }
      }
    }
    // 其次从旧数据快照获取类型
    if (dataSnapshotOld != null) {
      final typeStr = dataSnapshotOld!['type'] as String?;
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
    switch (changeType) {
      case ChangeType.created:
        return '新增了$_typeName ${nameNew ?? ""}';
      case ChangeType.deleted:
        return '删除了$_typeName ${nameOld ?? ""}';
      case ChangeType.updated:
        if (changedField != null) {
          return '修改了${_typeName}的${_translateField(changedField!)}';
        }
        return '修改了$_typeName';
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
      // 显示买入价变化
      final buyPriceOld = dataSnapshotOld?['buy_price'] as double?;
      final buyPriceNew = dataSnapshotNew?['buy_price'] as double?;
      if (buyPriceOld != null || buyPriceNew != null) {
        if (buyPriceOld != buyPriceNew) {
          final currency = dataSnapshotNew?['currency'] as String? ?? 'CNY';
          if (buyPriceOld != null) {
            buffer.write('买入价从 ${_formatAmount(buyPriceOld, currency)}');
          } else {
            buffer.write('买入价');
          }
          if (buyPriceNew != null) {
            buffer.writeln('改为 ${_formatAmount(buyPriceNew, currency)}');
          } else {
            buffer.writeln('已清除');
          }
        }
      }
      // 显示现价变化
      final currentPriceOld = dataSnapshotOld?['current_price'] as double?;
      final currentPriceNew = dataSnapshotNew?['current_price'] as double?;
      if (currentPriceOld != null || currentPriceNew != null) {
        if (currentPriceOld != currentPriceNew) {
          final currency = dataSnapshotNew?['currency'] as String? ?? 'CNY';
          if (currentPriceOld != null) {
            buffer.write('现价从 ${_formatAmount(currentPriceOld, currency)}');
          } else {
            buffer.write('现价');
          }
          if (currentPriceNew != null) {
            buffer.writeln('改为 ${_formatAmount(currentPriceNew, currency)}');
          } else {
            buffer.writeln('已清除');
          }
        }
      }
      // 显示备注变化
      final noteOld = dataSnapshotOld?['note'] as String?;
      final noteNew = dataSnapshotNew?['note'] as String?;
      if (noteOld != null || noteNew != null) {
        if (noteOld != noteNew) {
          if (noteOld != null && noteOld.isNotEmpty) {
            buffer.writeln('备注从 "$noteOld" 改为 "$noteNew"');
          } else if (noteNew != null && noteNew.isNotEmpty) {
            buffer.writeln('备注添加为 "$noteNew"');
          } else if (noteNew != null) {
            buffer.writeln('备注已清除');
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
