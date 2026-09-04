import '../models/financial_models.dart';

/// ============================================================
/// 批量导入（CSV / Excel）解析与模板
/// ============================================================
///
/// 仅解析与校验，不直接改数据库——上层拿到已解析行后，
/// 逐个调用 provider 的 addAsset / addLiability（复用现有 FFI 链路）。
/// 文档: docs/bulk-import.md

/// 资产类型 - 是否投资类
bool isInvestmentTypeName(String code) =>
    code == 'stock' || code == 'fund';

/// 目标大类
enum ImportTarget { asset, liability }

/// 资产行（可导入）
class ImportedAsset {
  final AssetType type;
  final String name;
  final double amount; // 元（当前价值）
  final String? account;
  final String? note;

  // 投资类
  final double? buyPrice;
  final double? currentPrice;
  final String? code;
  final String? exchange;
  final int? quantity;

  // 房产
  final String? address;
  final double? buildingArea;
  final double? livingArea;
  final String? propertyType;
  final int? rooms;
  final String? floor;
  final int? buildYear;
  final String? ownershipType;
  final String? deedNumber;

  // 存款
  final String? depositAccountType;
  final int? depositPeriod;
  final DateTime? maturityDate;
  final double? depositInterestRate;

  // 保单
  final String? policyNumber;
  final String? insuranceType;
  final String? insured;
  final String? beneficiary;
  final double? coverageAmount;
  final double? premium;
  final String? premiumPeriod;
  final String? coveragePeriod;
  final String? insurer;

  final DateTime? occurrenceDate;

  ImportedAsset({
    required this.type,
    required this.name,
    required this.amount,
    this.account,
    this.note,
    this.buyPrice,
    this.currentPrice,
    this.code,
    this.exchange,
    this.quantity,
    this.address,
    this.buildingArea,
    this.livingArea,
    this.propertyType,
    this.rooms,
    this.floor,
    this.buildYear,
    this.ownershipType,
    this.deedNumber,
    this.depositAccountType,
    this.depositPeriod,
    this.maturityDate,
    this.depositInterestRate,
    this.policyNumber,
    this.insuranceType,
    this.insured,
    this.beneficiary,
    this.coverageAmount,
    this.premium,
    this.premiumPeriod,
    this.coveragePeriod,
    this.insurer,
    this.occurrenceDate,
  });
}

/// 负债行（可导入）
class ImportedLiability {
  final LiabilityType type;
  final String name;
  final double amount; // 元
  final String? lender;
  final String? note;
  final DateTime? dueDate;
  final double? interestRate;
  final RepaymentMethod? repaymentMethod;
  final int? loanTerm;
  final DateTime? occurrenceDate;

  // 信用卡
  final String? lastFourDigits;
  final DateTime? billingDate;
  final DateTime? paymentDueDate;
  final double? creditLimit;
  final double? cashLimit;
  final double? annualFee;
  final String? issuer;

  // 房贷
  final String? propertyAddress;
  final double? originalLoanAmount;
  final double? remainingPrincipal;
  final String? loanType;

  // 车贷
  final String? vehicleBrand;
  final String? vehicleModel;
  final String? licensePlate;

  // 个人/私人借款
  final String? purpose;
  final bool? hasInterest;
  final String? repaymentPlan;

  ImportedLiability({
    required this.type,
    required this.name,
    required this.amount,
    this.lender,
    this.note,
    this.dueDate,
    this.interestRate,
    this.repaymentMethod,
    this.loanTerm,
    this.occurrenceDate,
    this.lastFourDigits,
    this.billingDate,
    this.paymentDueDate,
    this.creditLimit,
    this.cashLimit,
    this.annualFee,
    this.issuer,
    this.propertyAddress,
    this.originalLoanAmount,
    this.remainingPrincipal,
    this.loanType,
    this.vehicleBrand,
    this.vehicleModel,
    this.licensePlate,
    this.purpose,
    this.hasInterest,
    this.repaymentPlan,
  });
}

/// 单行解析结果：要么导入（资产/负债），要么跳过并说明原因
class ImportRow {
  final ImportTarget? target;
  final Object? record; // ImportedAsset | ImportedLiability
  final String? skipReason;
  final int rowNumber; // 源文件行号（1-based，表头行不计）

  ImportRow({
    this.target,
    this.record,
    this.skipReason,
    required this.rowNumber,
  });

  bool get isSkip => skipReason != null;
}

/// 表头列 → 标准字段名的解析结果
class HeaderColumn {
  final String header;
  final String field; // 标准字段名（如 'type'/'name'/'amount'/'buyPrice'）
  HeaderColumn(this.header, this.field);
}

/// 自定义类型解析结果
class ImportCustomType {
  final String name;
  final bool isLiability;
  ImportCustomType(this.name, this.isLiability);
}

/// ============================================================
/// 字段/别名表
/// ============================================================

class ImportFieldDefs {
  static const String fType = 'type';
  static const String fName = 'name';
  static const String fAmount = 'amount';
  static const String fCurrency = 'currency'; // 保留：当前未支持
  static const String fAccount = 'account';
  static const String fNote = 'note';
  static const String fDate = 'occurrenceDate';

  // 投资
  static const String fBuyPrice = 'buyPrice';
  static const String fCurrentPrice = 'currentPrice';
  static const String fCode = 'code';
  static const String fExchange = 'exchange';
  static const String fQuantity = 'quantity';

  // 房产
  static const String fAddress = 'address';
  static const String fBuildingArea = 'buildingArea';
  static const String fLivingArea = 'livingArea';
  static const String fPropertyType = 'propertyType';
  static const String fRooms = 'rooms';
  static const String fFloor = 'floor';
  static const String fBuildYear = 'buildYear';
  static const String fOwnershipType = 'ownershipType';
  static const String fDeedNumber = 'deedNumber';

  // 存款
  static const String fDepositAccountType = 'depositAccountType';
  static const String fDepositPeriod = 'depositPeriod';
  static const String fMaturityDate = 'maturityDate';
  static const String fDepositInterestRate = 'depositInterestRate';

  // 保单
  static const String fPolicyNumber = 'policyNumber';
  static const String fInsuranceType = 'insuranceType';
  static const String fInsured = 'insured';
  static const String fBeneficiary = 'beneficiary';
  static const String fCoverageAmount = 'coverageAmount';
  static const String fPremium = 'premium';
  static const String fPremiumPeriod = 'premiumPeriod';
  static const String fCoveragePeriod = 'coveragePeriod';
  static const String fInsurer = 'insurer';

  // 负债
  static const String fLender = 'lender';
  static const String fDueDate = 'dueDate';
  static const String fInterestRate = 'interestRate';
  static const String fRepaymentMethod = 'repaymentMethod';
  static const String fLoanTerm = 'loanTerm';

  static const String fLastFourDigits = 'lastFourDigits';
  static const String fBillingDate = 'billingDate';
  static const String fPaymentDueDate = 'paymentDueDate';
  static const String fCreditLimit = 'creditLimit';
  static const String fCashLimit = 'cashLimit';
  static const String fAnnualFee = 'annualFee';
  static const String fIssuer = 'issuer';

  static const String fPropertyAddress = 'propertyAddress';
  static const String fOriginalLoanAmount = 'originalLoanAmount';
  static const String fRemainingPrincipal = 'remainingPrincipal';
  static const String fLoanType = 'loanType';

  static const String fVehicleBrand = 'vehicleBrand';
  static const String fVehicleModel = 'vehicleModel';
  static const String fLicensePlate = 'licensePlate';

  static const String fPurpose = 'purpose';
  static const String fHasInterest = 'hasInterest';
  static const String fRepaymentPlan = 'repaymentPlan';

  /// 表头标题 → 标准字段名（不区分大小写，先精确后去除空白后匹配）
  static const Map<String, String> aliases = {
    // 关键字段
    'type': fType,
    '类型': fType,
    '资产类型': fType,
    '负债类型': fType,
    'name': fName,
    '名称': fName,
    '资产名称': fName,
    '负债名称': fName,
    'amount': fAmount,
    '金额': fAmount,
    '价值': fAmount,
    '市值': fAmount,
    '总额': fAmount,
    '欠款': fAmount,
    '当前金额': fAmount,

    // 通用
    'account': fAccount,
    '账户': fAccount,
    '平台': fAccount,
    '存放机构': fAccount,
    '账号': fAccount,
    '开户行': fAccount,
    'note': fNote,
    '备注': fNote,
    '说明': fNote,
    'date': fDate,
    '日期': fDate,
    '起始日期': fDate,
    '记录日期': fDate,
    '获得日期': fDate,
    '买入日期': fDate,
    '借款日期': fDate,
    '发放日期': fDate,

    // 投资
    'buyPrice': fBuyPrice,
    '买入价': fBuyPrice,
    '成本价': fBuyPrice,
    '买入单价': fBuyPrice,
    '成本单价': fBuyPrice,
    'currentPrice': fCurrentPrice,
    '现价': fCurrentPrice,
    '当前价': fCurrentPrice,
    '最新价': fCurrentPrice,
    '现单价': fCurrentPrice,
    'code': fCode,
    '代码': fCode,
    '证券代码': fCode,
    '基金代码': fCode,
    '代码/编号': fCode,
    'exchange': fExchange,
    '交易所': fExchange,
    'quantity': fQuantity,
    '数量': fQuantity,
    '份额': fQuantity,
    '持有份额': fQuantity,
    '股数': fQuantity,
    '份数': fQuantity,

    // 房产
    'address': fAddress,
    '地址': fAddress,
    '房产地址': fAddress,
    '房屋地址': fAddress,
    'buildingArea': fBuildingArea,
    '面积': fBuildingArea,
    '建筑面积': fBuildingArea,
    'livingArea': fLivingArea,
    '套内面积': fLivingArea,
    '使用面积': fLivingArea,
    'propertyType': fPropertyType,
    '物业类型': fPropertyType,
    '房产类型': fPropertyType,
    '房屋类型': fPropertyType,
    'rooms': fRooms,
    '户型': fRooms,
    '房间数': fRooms,
    'floor': fFloor,
    '楼层': fFloor,
    'buildYear': fBuildYear,
    '建成年份': fBuildYear,
    '建造年份': fBuildYear,
    '竣工年份': fBuildYear,
    'ownershipType': fOwnershipType,
    '产权': fOwnershipType,
    '产权性质': fOwnershipType,
    'deedNumber': fDeedNumber,
    '房产证号': fDeedNumber,
    '不动产权证号': fDeedNumber,
    '产权证号': fDeedNumber,

    // 存款
    'depositAccountType': fDepositAccountType,
    '账户类型': fDepositAccountType,
    'depositPeriod': fDepositPeriod,
    '存期': fDepositPeriod,
    '存期(月)': fDepositPeriod,
    '存期月份': fDepositPeriod,
    'maturityDate': fMaturityDate,
    '到期日': fMaturityDate,
    '存款到期日': fMaturityDate,
    'depositInterestRate': fDepositInterestRate,
    '利率': fDepositInterestRate,
    '年利率': fDepositInterestRate,
    '存款利率': fDepositInterestRate,

    // 保单
    'policyNumber': fPolicyNumber,
    '保单号': fPolicyNumber,
    '保单编号': fPolicyNumber,
    'insuranceType': fInsuranceType,
    '保险类型': fInsuranceType,
    'insured': fInsured,
    '被保人': fInsured,
    'beneficiary': fBeneficiary,
    '受益人': fBeneficiary,
    'coverageAmount': fCoverageAmount,
    '保额': fCoverageAmount,
    'premium': fPremium,
    '保费': fPremium,
    'premiumPeriod': fPremiumPeriod,
    '缴费期限': fPremiumPeriod,
    '缴费周期': fPremiumPeriod,
    'coveragePeriod': fCoveragePeriod,
    '保障期限': fCoveragePeriod,
    '保险期限': fCoveragePeriod,
    'insurer': fInsurer,
    '保险公司': fInsurer,
    '承保公司': fInsurer,

    // 负债
    'lender': fLender,
    '债权人': fLender,
    '贷款机构': fLender,
    '放款机构': fLender,
    '债权机构': fLender,
    '借款机构': fLender,
    'dueDate': fDueDate,
    '还款日': fDueDate,
    '到期还款日': fDueDate,
    '预计还清日': fDueDate,
    'interestRate': fInterestRate,
    'repaymentMethod': fRepaymentMethod,
    '还款方式': fRepaymentMethod,
    'loanTerm': fLoanTerm,
    '期限': fLoanTerm,
    '期限(月)': fLoanTerm,
    '贷款期限': fLoanTerm,
    '期限（月）': fLoanTerm,
    'lastFourDigits': fLastFourDigits,
    '卡号后四位': fLastFourDigits,
    '尾号': fLastFourDigits,
    'billingDate': fBillingDate,
    '账单日': fBillingDate,
    'paymentDueDate': fPaymentDueDate,
    '最后还款日': fPaymentDueDate,
    '到期还款日2': fPaymentDueDate, // 避免与 dueDate 冲突的补充
    'creditLimit': fCreditLimit,
    '额度': fCreditLimit,
    '信用额度': fCreditLimit,
    'cashLimit': fCashLimit,
    '取现额度': fCashLimit,
    'annualFee': fAnnualFee,
    '年费': fAnnualFee,
    'issuer': fIssuer,
    '发卡行': fIssuer,
    '发卡银行': fIssuer,
    'propertyAddress': fPropertyAddress,
    '房贷地址': fPropertyAddress,
    'originalLoanAmount': fOriginalLoanAmount,
    '原始贷款金额': fOriginalLoanAmount,
    'remainingPrincipal': fRemainingPrincipal,
    '剩余本金': fRemainingPrincipal,
    'loanType': fLoanType,
    '贷款类型': fLoanType,
    'vehicleBrand': fVehicleBrand,
    '品牌': fVehicleBrand,
    '车辆品牌': fVehicleBrand,
    'vehicleModel': fVehicleModel,
    '车型': fVehicleModel,
    '车辆型号': fVehicleModel,
    'licensePlate': fLicensePlate,
    '车牌号': fLicensePlate,
    'purpose': fPurpose,
    '用途': fPurpose,
    '借款用途': fPurpose,
    'hasInterest': fHasInterest,
    '是否计息': fHasInterest,
    '是否有息': fHasInterest,
    '计息': fHasInterest,
    'repaymentPlan': fRepaymentPlan,
    '还款计划': fRepaymentPlan,
    '还款计划描述': fRepaymentPlan,
  };
}

/// ============================================================
/// 解析结果
/// ============================================================

class ParseResult {
  final List<HeaderColumn> headers;
  final List<ImportRow> rows;
  final List<String> warnings;
  ParseResult({
    required this.headers,
    required this.rows,
    required this.warnings,
  });
}

/// 解析一个数据表（CSV 行数组 / Excel 首个工作表）为导入行
class SpreadsheetParser {
  /// 标准表头顺序（用于模板生成）
  static const List<String> assetTemplateHeaders = [
    '类型', '名称', '金额', '日期', '账户', '备注',
    // 投资
    '买入价', '现价', '代码', '交易所', '数量',
    // 房产
    '地址', '面积', '套内面积', '物业类型', '户型', '楼层', '建成年份', '产权', '房产证号',
    // 存款
    '账户类型', '存期', '到期日', '利率',
    // 保单
    '保单号', '保险类型', '被保人', '受益人', '保额', '保费', '缴费期限', '保障期限', '保险公司',
  ];

  static const List<String> liabilityTemplateHeaders = [
    '类型', '名称', '金额', '日期', '账户', '备注',
    // 贷款
    '到期日', '利率', '还款方式', '期限',
    // 信用卡
    '卡号后四位', '账单日', '最后还款日', '额度', '取现额度', '年费', '发卡行',
    // 房贷
    '房产地址', '原始贷款金额', '剩余本金', '贷款类型',
    // 车贷
    '车辆品牌', '车型', '车牌号',
    // 借款
    '用途', '是否计息', '还款计划',
  ];

  /// 表头标题 → 字段名解析（别名归一）
  static Map<String, String> resolveHeaderColumns(List<String> headers) {
    final map = <String, String>{};
    for (final h in headers) {
      final t = h.trim();
      if (t.isEmpty) continue;
      String? field = ImportFieldDefs.aliases[t];
      if (field == null) {
        // 大小写不敏感匹配
        final lower = t.toLowerCase();
        for (final entry in ImportFieldDefs.aliases.entries) {
          if (entry.key.toLowerCase() == lower) {
            field = entry.value;
            break;
          }
        }
      }
      if (field != null && !map.containsValue(field)) {
        map[t] = field;
      }
    }
    return map;
  }

  /// 从表头行定位「数据开始行」：
  /// 找到第一个包含「名称」或「name」的列所在行，其上一行若全为列标题则从该行开始。
  static int findHeaderRow(List<List<String>> matrix) {
    int best = 0;
    for (int i = 0; i < matrix.length && i < 20; i++) {
      final row = matrix[i];
      for (final cell in row) {
        final t = cell.trim();
        if (t == '名称' || t.toLowerCase() == 'name' || t == '资产名称') {
          best = i;
          return best;
        }
      }
    }
    return best;
  }

  static double? _parseAmount(dynamic raw) {
    if (raw == null) return null;
    var s = raw.toString().trim();
    if (s.isEmpty) return null;
    // 纯数字 / 千分位 / 万
    s = s.replaceAll(RegExp(r'[,，\s]'), '');
    // 处理 1.5万 / 2万 / 3000元
    if (s.endsWith('万')) {
      final numPart = s.substring(0, s.length - 1);
      final v = double.tryParse(numPart);
      if (v != null) return v * 10000;
      return null;
    }
    if (s.endsWith('元')) s = s.substring(0, s.length - 1);
    final v = double.tryParse(s);
    if (v != null && v >= 0) return v;
    return null;
  }

  static int? _parseInt(dynamic raw) {
    if (raw == null) return null;
    final s = raw.toString().trim();
    if (s.isEmpty) return null;
    // 户型 "3" / "3室" / "3室2厅" → 3
    final m = RegExp(r'\d+').firstMatch(s);
    if (m != null) {
      final v = int.tryParse(m.group(0)!);
      if (v != null) return v;
    }
    return int.tryParse(s);
  }

  static double? _parseDouble(dynamic raw) {
    if (raw == null) return null;
    final s = raw.toString().trim();
    if (s.isEmpty) return null;
    final cleaned = s.replaceAll(RegExp(r'[,，%]'), '');
    final v = double.tryParse(cleaned);
    return v;
  }

  static DateTime? _parseDate(dynamic raw) {
    if (raw == null) return null;
    if (raw is DateTime) return raw;
    final s = raw.toString().trim();
    if (s.isEmpty) return null;
    // Excel 序列号 (如 45292)
    if (RegExp(r'^\d{5}$').hasMatch(s)) {
      final serial = int.parse(s);
      if (serial > 20000 && serial < 60000) {
        // 1900 日期系统
        return DateTime(1899, 12, 30).add(Duration(days: serial));
      }
    }
    final formats = [
      'yyyy-MM-dd',
      'yyyy/M/d',
      'yyyy-M-d',
      'yyyy.MM.dd',
      'yyyy年M月d日',
    ];
    for (final f in formats) {
      try {
        final dt = _parseFlexible(s, f);
        if (dt != null) return dt;
      } catch (_) {}
    }
    return null;
  }

  static DateTime? _parseFlexible(String s, String format) {
    // 手工解析几种常见格式（不引入 intl 之外的依赖）
    if (format == 'yyyy-MM-dd' || format == 'yyyy/M/d' || format == 'yyyy-M-d' || format == 'yyyy.MM.dd') {
      final sep = format.substring(4, 5);
      // 支持 1 位月/日
      final parts = s.split(RegExp(sep == '.' ? r'\.' : RegExp.escape(sep)));
      // 也接受 yyyy/M/d 等
      if (parts.length == 3) {
        final y = int.tryParse(parts[0]);
        final m = int.tryParse(parts[1]);
        final d = int.tryParse(parts[2]);
        if (y != null && m != null && d != null && m >= 1 && m <= 12 && d >= 1 && d <= 31) {
          return DateTime(y, m, d);
        }
      }
    } else if (format == 'yyyy年M月d日') {
      final m = RegExp(r'(\d{4})年(\d{1,2})月(\d{1,2})日').firstMatch(s);
      if (m != null) {
        final y = int.tryParse(m.group(1)!);
        final mo = int.tryParse(m.group(2)!);
        final d = int.tryParse(m.group(3)!);
        if (y != null && mo != null && d != null && mo >= 1 && mo <= 12 && d >= 1 && d <= 31) {
          return DateTime(y, mo, d);
        }
      }
    }
    return null;
  }

  /// 类型解析：
  /// 返回 (目标, 内置类型代码或 null, 是否为自定义)
  static ({ImportTarget? target, String? code, String? customName}) resolveType(
    String rawType,
    List<ImportCustomType> customTypes,
  ) {
    final t = rawType.trim();
    if (t.isEmpty) return (target: null, code: null, customName: null);

    // 1. 资产内置类型（中文 / 代码）
    for (final at in AssetType.values) {
      if (t == at.displayName || t == at.snakeCaseName) {
        return (target: ImportTarget.asset, code: at.snakeCaseName, customName: null);
      }
    }
    // 2. 负债内置类型
    for (final lt in LiabilityType.values) {
      if (t == lt.displayName || t == lt.snakeCaseName || t == lt.id) {
        return (target: ImportTarget.liability, code: lt.snakeCaseName, customName: null);
      }
    }
    // 3. 自定义类型（仅识别以作提示；当前 UI 无自定义类型添加链路，首版不支持导入自定义类型）
    final norm = t.toLowerCase();
    final matchedCustom = customTypes
        .where((ct) => t == ct.name || norm == ct.name.toLowerCase())
        .toList();
    if (matchedCustom.isNotEmpty) {
      final ct = matchedCustom.first;
      return (
        target: ct.isLiability ? ImportTarget.liability : ImportTarget.asset,
        code: null,
        customName: ct.name,
      );
    }
    // 4. custom_xxx 形式 id
    if (norm.startsWith('custom_')) {
      final match = norm.substring(7);
      final ct = customTypes
          .where((c) => c.name.toLowerCase() == match)
          .toList();
      if (ct.isNotEmpty) {
        return (
          target: ct.first.isLiability
              ? ImportTarget.liability
              : ImportTarget.asset,
          code: null,
          customName: ct.first.name,
        );
      }
    }
    return (target: null, code: null, customName: null);
  }

  /// 是否为不支持导入的自定义类型（解析后置判断用）
  static bool isCustomTarget(ImportRow row) {
    return row.skipReason == null && row.record == null;
  }
  /// 行单元格 → 导入行；返回 skip 行说明原因
  static ImportRow parseRow(
    int rowNumber,
    List<String> headerTitles, // 按原始顺序的表头
    List<dynamic> cells,
    List<ImportCustomType> customTypes, {
    String defaultCurrency = 'CNY',
  }) {
    // 构建字段别名 → 列索引（第一个出现的为准）
    final fieldColumn = <String, int>{};
    for (int i = 0; i < headerTitles.length; i++) {
      final title = headerTitles[i];
      final field = ImportFieldDefs.aliases[title];
      if (field != null && !fieldColumn.containsKey(field)) {
        fieldColumn[field] = i;
      }
    }

    String? cellOf(String field) {
      final idx = fieldColumn[field];
      if (idx == null || idx >= cells.length) return null;
      final c = cells[idx];
      if (c == null) return null;
      final s = c.toString().trim();
      return s.isEmpty ? null : s;
    }

    final typeVal = cellOf('type');
    if (typeVal == null) {
      return ImportRow(skipReason: '缺少「类型」列', rowNumber: rowNumber);
    }

    final resolved = resolveType(typeVal, customTypes);
    if (resolved.target == null) {
      return ImportRow(
        skipReason: '无法识别的类型「$typeVal」',
        rowNumber: rowNumber,
      );
    }
    // 自定义类型（资产或负债）：当前版本不支持自定义类型批量导入
    if (resolved.code == null) {
      return ImportRow(
        skipReason: '暂不支持自定义类型「${resolved.customName}」的批量导入，请在应用内手动添加',
        rowNumber: rowNumber,
      );
    }

    final nameVal = cellOf('name');
    if (nameVal == null || nameVal.isEmpty) {
      return ImportRow(skipReason: '缺少「名称」', rowNumber: rowNumber);
    }
    final amountVal = _parseAmount(cellOf('amount'));
    if (amountVal == null) {
      return ImportRow(skipReason: '「金额」不是有效数字', rowNumber: rowNumber);
    }

    final dateVal = _parseDate(cellOf('occurrenceDate'));

    // 「利率」列既可表示存款利率也可表示贷款利率：两种字段都尝试
    final interestVal =
        _parseDouble(cellOf('interestRate')) ?? _parseDouble(cellOf('depositInterestRate'));

    // 负债（内置类型）
    if (resolved.target == ImportTarget.liability) {
      final type = LiabilityType.values.firstWhere(
        (t) => t.snakeCaseName == resolved.code,
        orElse: () => LiabilityType.debt,
      );
      return ImportRow(
        target: ImportTarget.liability,
        rowNumber: rowNumber,
        record: ImportedLiability(
          type: type,
          name: nameVal,
          amount: amountVal,
          occurrenceDate: dateVal,
          lender: _strOrNull(cellOf('lender')),
          note: _strOrNull(cellOf('note')),
          dueDate: _parseDate(cellOf('dueDate')),
          interestRate: interestVal,
          repaymentMethod: _parseRepaymentMethod(cellOf('repaymentMethod')),
          loanTerm: _parseInt(cellOf('loanTerm')),
          lastFourDigits: _strOrNull(cellOf('lastFourDigits')),
          billingDate: _parseDate(cellOf('billingDate')),
          paymentDueDate: _parseDate(cellOf('paymentDueDate')),
          creditLimit: _parseAmount(cellOf('creditLimit')),
          cashLimit: _parseAmount(cellOf('cashLimit')),
          annualFee: _parseAmount(cellOf('annualFee')),
          issuer: _strOrNull(cellOf('issuer')),
          propertyAddress: _strOrNull(cellOf('propertyAddress')),
          originalLoanAmount: _parseAmount(cellOf('originalLoanAmount')),
          remainingPrincipal: _parseAmount(cellOf('remainingPrincipal')),
          loanType: _strOrNull(cellOf('loanType')),
          vehicleBrand: _strOrNull(cellOf('vehicleBrand')),
          vehicleModel: _strOrNull(cellOf('vehicleModel')),
          licensePlate: _strOrNull(cellOf('licensePlate')),
          purpose: _strOrNull(cellOf('purpose')),
          hasInterest: _parseBool(cellOf('hasInterest')),
          repaymentPlan: _strOrNull(cellOf('repaymentPlan')),
        ),
      );
    }

    // 资产（内置类型）
    final assetType = AssetType.values.firstWhere(
      (t) => t.snakeCaseName == resolved.code,
      orElse: () => AssetType.deposit,
    );

    return ImportRow(
      target: ImportTarget.asset,
      rowNumber: rowNumber,
      record: ImportedAsset(
        type: assetType,
        name: nameVal,
        amount: amountVal,
        account: _strOrNull(cellOf('account')),
        note: _strOrNull(cellOf('note')),
        occurrenceDate: dateVal,
        buyPrice: _parseDouble(cellOf('buyPrice')),
        currentPrice: _parseDouble(cellOf('currentPrice')),
        code: _strOrNull(cellOf('code')),
        exchange: _strOrNull(cellOf('exchange')),
        quantity: _parseInt(cellOf('quantity')),
        address: _strOrNull(cellOf('address')),
        buildingArea: _parseDouble(cellOf('buildingArea')),
        livingArea: _parseDouble(cellOf('livingArea')),
        propertyType: _strOrNull(cellOf('propertyType')),
        rooms: _parseInt(cellOf('rooms')),
        floor: _strOrNull(cellOf('floor')),
        buildYear: _parseInt(cellOf('buildYear')),
        ownershipType: _strOrNull(cellOf('ownershipType')),
        deedNumber: _strOrNull(cellOf('deedNumber')),
        depositAccountType: _strOrNull(cellOf('depositAccountType')),
        depositPeriod: _parseInt(cellOf('depositPeriod')),
        maturityDate: _parseDate(cellOf('maturityDate')),
        depositInterestRate:
            _parseDouble(cellOf('depositInterestRate')) ?? interestVal,
        policyNumber: _strOrNull(cellOf('policyNumber')),
        insuranceType: _strOrNull(cellOf('insuranceType')),
        insured: _strOrNull(cellOf('insured')),
        beneficiary: _strOrNull(cellOf('beneficiary')),
        coverageAmount: _parseAmount(cellOf('coverageAmount')),
        premium: _parseAmount(cellOf('premium')),
        premiumPeriod: _strOrNull(cellOf('premiumPeriod')),
        coveragePeriod: _strOrNull(cellOf('coveragePeriod')),
        insurer: _strOrNull(cellOf('insurer')),
      ),
    );
  }

  static String? _strOrNull(dynamic v) {
    if (v == null) return null;
    final s = v.toString().trim();
    return s.isEmpty ? null : s;
  }

  static bool? _parseBool(dynamic raw) {
    if (raw == null) return null;
    final s = raw.toString().trim();
    if (s.isEmpty) return null;
    if (s == '是' || s == '有' || s == 'yes' || s == 'true' || s == '1' || s == 'y') return true;
    if (s == '否' || s == '无' || s == 'no' || s == 'false' || s == '0' || s == 'n') return false;
    return null;
  }

  static RepaymentMethod? _parseRepaymentMethod(dynamic raw) {
    if (raw == null) return null;
    final s = raw.toString().trim();
    if (s.isEmpty) return null;
    switch (s) {
      case '等额本息':
        return RepaymentMethod.equalPrincipalAndInterest;
      case '等额本金':
        return RepaymentMethod.equalPrincipal;
      case '到期还本付息':
        return RepaymentMethod.bulletPayment;
      case '按月付息到期还本':
        return RepaymentMethod.monthlyInterest;
      case 'custom':
      case '自定义':
        return RepaymentMethod.custom;
      default:
        return null;
    }
  }
}
