import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:localfamily_asset/import/import_file_io.dart';
import 'package:localfamily_asset/import/import_parser.dart';
import 'package:localfamily_asset/models/financial_models.dart';

void main() {
  group('SpreadsheetParser.resolveHeaderColumns', () {
    test('识别中文表头与别名', () {
      final headers = ['类型', '名称', '金额', '买入价', '备注'];
      final resolved = SpreadsheetParser.resolveHeaderColumns(headers);
      expect(resolved['类型'], 'type');
      expect(resolved['名称'], 'name');
      expect(resolved['金额'], 'amount');
      expect(resolved['买入价'], 'buyPrice');
      expect(resolved['备注'], 'note');
    });

    test('英文表头大小写不敏感', () {
      final headers = ['Type', 'NAME', 'Amount', 'quantity'];
      final resolved = SpreadsheetParser.resolveHeaderColumns(headers);
      expect(resolved['Type'], 'type');
      expect(resolved['NAME'], 'name');
      expect(resolved['Amount'], 'amount');
      expect(resolved['quantity'], 'quantity');
    });
  });

  group('SpreadsheetParser.parseRow', () {
    const headers = ['类型', '名称', '金额', '日期', '买入价', '现价', '代码', '数量'];

    test('解析资产行（股票）', () {
      final row = SpreadsheetParser.parseRow(
        2,
        headers,
        ['股票', '贵州茅台', '210000', '2024-01-15', '1500', '1700', '600519', '100'],
        const [],
      );
      expect(row.isSkip, false);
      expect(row.target, ImportTarget.asset);
      final a = row.record as ImportedAsset;
      expect(a.type, AssetType.stock);
      expect(a.name, '贵州茅台');
      expect(a.amount, 210000);
      expect(a.buyPrice, 1500);
      expect(a.currentPrice, 1700);
      expect(a.code, '600519');
      expect(a.quantity, 100);
      expect(a.occurrenceDate, DateTime(2024, 1, 15));
    });

    test('解析资产行（存款 万单位金额）', () {
      final row = SpreadsheetParser.parseRow(
        2,
        headers,
        ['存款', '定期存款', '30万', '2023/5/1'],
        const [],
      );
      expect(row.isSkip, false);
      final a = row.record as ImportedAsset;
      expect(a.type, AssetType.deposit);
      expect(a.amount, 300000);
      expect(a.occurrenceDate, DateTime(2023, 5, 1));
    });

    test('解析负债行（房贷）', () {
      const liabHeaders = ['类型', '名称', '金额', '利率', '还款方式'];
      final row = SpreadsheetParser.parseRow(
        2,
        liabHeaders,
        ['房贷', '自住房贷', '1500000', '4.2', '等额本息'],
        const [],
      );
      expect(row.isSkip, false);
      expect(row.target, ImportTarget.liability);
      final l = row.record as ImportedLiability;
      expect(l.type, LiabilityType.mortgage);
      expect(l.amount, 1500000);
      expect(l.interestRate, 4.2);
      expect(l.repaymentMethod, RepaymentMethod.equalPrincipalAndInterest);
    });

    test('无法识别的类型 → 跳过', () {
      final row = SpreadsheetParser.parseRow(
        2,
        headers,
        ['比特币', '钱包', '1000'],
        const [],
      );
      expect(row.isSkip, true);
      expect(row.skipReason, contains('无法识别'));
    });

    test('缺少名称 → 跳过', () {
      final row = SpreadsheetParser.parseRow(
        2,
        headers,
        ['房产', '', '100'],
        const [],
      );
      expect(row.isSkip, true);
      expect(row.skipReason, contains('名称'));
    });

    test('金额非法 → 跳过', () {
      final row = SpreadsheetParser.parseRow(
        2,
        headers,
        ['存款', '零钱', 'abc'],
        const [],
      );
      expect(row.isSkip, true);
    });

    test('自定义类型 → 跳过（暂不支持）', () {
      final row = SpreadsheetParser.parseRow(
        2,
        headers,
        ['黄金', '金条', '50000'],
        [ImportCustomType('黄金', false)],
      );
      expect(row.isSkip, true);
      expect(row.skipReason, contains('自定义类型'));
    });
  });

  group('CSV 读取', () {
    test('逗号分隔 + BOM', () {
      final dir = Directory.systemTemp.createTempSync('lfa_test');
      try {
        final f = File('${dir.path}/in.csv');
        // BOM + UTF-8
        const content = '\uFEFF类型,名称,金额,备注\n房产,自住房,3200000,测试\n';
        f.writeAsBytesSync(utf8.encode(content));
        final r = readImportFile(f.path);
        expect(r.rows.length, 2);
        expect(r.rows[0], ['类型', '名称', '金额', '备注']);
        expect(r.rows[1], ['房产', '自住房', '3200000', '测试']);
      } finally {
        dir.deleteSync(recursive: true);
      }
    });

    test('制表符分隔', () {
      final dir = Directory.systemTemp.createTempSync('lfa_test');
      try {
        final f = File('${dir.path}/tab.csv');
        f.writeAsStringSync('类型\t名称\t金额\n存款\t活期\t10000\n');
        final r = readImportFile(f.path);
        expect(r.rows[1], ['存款', '活期', '10000']);
      } finally {
        dir.deleteSync(recursive: true);
      }
    });
  });

  group('Excel 模板与读取', () {
    test('模板生成后能读回并解析', () {
      final dir = Directory.systemTemp.createTempSync('lfa_test');
      try {
        final f = File('${dir.path}/template.xlsx');
        f.writeAsBytesSync(buildTemplateXlsx());
        final r = readImportFile(f.path);
        expect(r.rows.length, 2); // 表头 + 示例行
        expect(r.rows[0].contains('类型'), true);
        // 示例资产行可解析（读取器按表头自动选择「资产」工作表）
        final parsed = parseImportRows(r.rows, const []);
        expect(parsed.length, 1);
        final assetRow = parsed[0];
        expect(assetRow.isSkip, false);
        expect(assetRow.target, ImportTarget.asset);
        final a = assetRow.record as ImportedAsset;
        expect(a.name, '示例·自住房');
        expect(a.type, AssetType.property);
      } finally {
        dir.deleteSync(recursive: true);
      }
    });
  });
}
