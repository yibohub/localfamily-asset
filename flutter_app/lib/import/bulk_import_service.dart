import 'package:uuid/uuid.dart';

import '../models/financial_models.dart';
import '../providers/financial_provider.dart';
import 'import_parser.dart';

/// ============================================================
/// 批量导入执行服务
/// ============================================================

class ImportReport {
  final int importedAssets;
  final int importedLiabilities;
  final int failed;
  final List<String> errors; // 每行错误信息（含行号）
  ImportReport({
    required this.importedAssets,
    required this.importedLiabilities,
    required this.failed,
    required this.errors,
  });
}

/// 将「已解析行」逐个写入（复用 provider 的 addAsset/addLiability，
/// 每次变更后即时保存，与手动添加保持一致的持久化语义）。
class BulkImportService {
  final FinancialProvider _provider;
  BulkImportService(this._provider);

  Future<ImportReport> run(List<ImportRow> rows, {void Function(int done)? onProgress}) async {
    var importedAssets = 0;
    var importedLiabilities = 0;
    var failed = 0;
    final errors = <String>[];
    var done = 0;

    for (final row in rows) {
      if (row.isSkip) {
        failed++;
        errors.add('第 ${row.rowNumber} 行：${row.skipReason}');
        done++;
        onProgress?.call(done);
        continue;
      }

      try {
        final ok = row.target == ImportTarget.asset
            ? await _provider.addAsset(_toAsset(row.record as ImportedAsset))
            : await _provider.addLiability(_toLiability(row.record as ImportedLiability));
        if (ok) {
          if (row.target == ImportTarget.asset) {
            importedAssets++;
          } else {
            importedLiabilities++;
          }
        } else {
          failed++;
          errors.add('第 ${row.rowNumber} 行：添加失败');
        }
      } catch (e) {
        failed++;
        errors.add('第 ${row.rowNumber} 行：$e');
      }
      done++;
      onProgress?.call(done);
    }
    return ImportReport(
      importedAssets: importedAssets,
      importedLiabilities: importedLiabilities,
      failed: failed,
      errors: errors,
    );
  }

  Asset _toAsset(ImportedAsset a) {
    return Asset(
      id: const Uuid().v4(),
      name: a.name,
      type: a.type,
      amount: a.amount,
      currency: 'CNY', // 文件不含币种列，统一当前默认币种
      account: a.account,
      occurrenceDate: a.occurrenceDate ?? DateTime.now(),
      note: a.note,
      buyPrice: a.buyPrice,
      currentPrice: a.currentPrice,
      code: a.code,
      exchange: a.exchange,
      quantity: a.quantity,
      // 房产
      address: a.address,
      buildingArea: a.buildingArea,
      livingArea: a.livingArea,
      propertyType: a.propertyType,
      rooms: a.rooms,
      floor: a.floor,
      buildYear: a.buildYear,
      ownershipType: a.ownershipType,
      deedNumber: a.deedNumber,
      // 存款
      depositAccountType: a.depositAccountType,
      depositPeriod: a.depositPeriod,
      maturityDate: a.maturityDate,
      depositInterestRate: a.depositInterestRate,
      // 保单
      policyNumber: a.policyNumber,
      insuranceType: a.insuranceType,
      insured: a.insured,
      beneficiary: a.beneficiary,
      coverageAmount: a.coverageAmount,
      premium: a.premium,
      premiumPeriod: a.premiumPeriod,
      coveragePeriod: a.coveragePeriod,
      insurer: a.insurer,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
  }

  Liability _toLiability(ImportedLiability l) {
    return Liability(
      id: const Uuid().v4(),
      name: l.name,
      type: l.type,
      amount: l.amount,
      currency: 'CNY',
      occurrenceDate: l.occurrenceDate ?? DateTime.now(),
      note: l.note,
      lender: l.lender,
      dueDate: l.dueDate,
      interestRate: l.interestRate,
      repaymentMethod: l.repaymentMethod,
      loanTerm: l.loanTerm,
      lastFourDigits: l.lastFourDigits,
      billingDate: l.billingDate,
      paymentDueDate: l.paymentDueDate,
      creditLimit: l.creditLimit,
      cashLimit: l.cashLimit,
      annualFee: l.annualFee,
      issuer: l.issuer,
      propertyAddress: l.propertyAddress,
      originalLoanAmount: l.originalLoanAmount,
      remainingPrincipal: l.remainingPrincipal,
      loanType: l.loanType,
      vehicleBrand: l.vehicleBrand,
      vehicleModel: l.vehicleModel,
      licensePlate: l.licensePlate,
      purpose: l.purpose,
      hasInterest: l.hasInterest,
      repaymentPlan: l.repaymentPlan,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
  }
}
