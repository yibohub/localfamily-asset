import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:csv/csv.dart';
import 'package:excel/excel.dart' as xl;

import 'import_parser.dart';

/// ============================================================
/// 批量导入文件读取与模板生成
/// ============================================================

/// 文件名 → 是否是 Excel(.xlsx)
bool isExcelFile(String path) =>
    path.toLowerCase().endsWith('.xlsx') || path.toLowerCase().endsWith('.xlsm');

/// 文件名 → 是否是 CSV
bool isCsvFile(String path) => path.toLowerCase().endsWith('.csv');

/// 读取导入文件（.csv / .xlsx），返回行矩阵（每行 List<String>，保留表头）。
/// - .xlsx：读取第一个工作表；sheet 内左上角空行/空列会被跳过；
/// - .csv：UTF-8 解码（含 BOM），自动识别分隔符（, ; tab）。
/// 返回 (所有行, 解析警告)。
({List<List<String>> rows, List<String> warnings}) readImportFile(String path) {
  final lower = path.toLowerCase();
  if (lower.endsWith('.xlsx') || lower.endsWith('.xlsm')) {
    return _readXlsx(path);
  }
  if (lower.endsWith('.csv')) {
    return _readCsv(path);
  }
  throw const FormatException('不支持的文件格式，请选择 .csv 或 .xlsx 文件');
}

({List<List<String>> rows, List<String> warnings}) _readCsv(String path) {
  final bytes = File(path).readAsBytesSync();
  var text = _decodeUtf8(bytes);

  // 嗅探分隔符
  var delimiter = _sniffDelimiter(text);
  List<List<dynamic>> parsed;
  try {
    parsed = CsvToListConverter(
      eol: '\n',
      shouldParseNumbers: false,
      fieldDelimiter: delimiter,
      textDelimiter: '"',
    ).convert(text);
  } catch (_) {
    // 兼容 \r\n
    parsed = CsvToListConverter(
      eol: '\r\n',
      shouldParseNumbers: false,
      fieldDelimiter: delimiter,
      textDelimiter: '"',
    ).convert(text);
  }

  // 规范化：全部字符串，去掉首尾空白，丢弃完全空行
  final rows = <List<String>>[];
  for (final r in parsed) {
    if (r.every((c) => c == null || c.toString().trim().isEmpty)) continue;
    rows.add(r.map((c) => c?.toString().trim() ?? '').toList());
  }
  return (rows: rows, warnings: <String>[]);
}

String _decodeUtf8(List<int> bytes) {
  // BOM
  if (bytes.length >= 3 && bytes[0] == 0xEF && bytes[1] == 0xBB && bytes[2] == 0xBF) {
    return utf8.decode(bytes.sublist(3));
  }
  return utf8.decode(bytes);
}

String _sniffDelimiter(String text) {
  // 只统计表头（前几行）
  final head = text.split('\n').take(5).join('\n');
  final candidates = [',', ';', '\t'];
  String best = ',';
  var bestScore = -1;
  for (final d in candidates) {
    final count = head.split(d).length - 1;
    if (count > bestScore) {
      bestScore = count;
      best = d;
    }
  }
  return best;
}

({List<List<String>> rows, List<String> warnings}) _readXlsx(String path) {
  final bytes = File(path).readAsBytesSync();
  final excel = xl.Excel.decodeBytes(bytes);
  final warnings = <String>[];
  if (excel.tables.isEmpty) {
    throw const FormatException('Excel 文件中没有工作表');
  }

  // 选择工作表：优先第一个「表头含 类型 + 名称」的工作表（支持把负债表放前面/单独文件）；
  // 否则取第一个工作表。
  List<List<String>>? best;
  for (final tableName in excel.tables.keys) {
    final sheet = excel.tables[tableName]!;
    final rows = _sheetToStringRows(sheet);
    if (rows.isEmpty) continue;
    final header = rows.first.join(',');
    best ??= rows;
    if (header.contains('类型') && (header.contains('名称') || header.toLowerCase().contains('name'))) {
      best = rows;
      break;
    }
  }
  if (best == null || best.isEmpty) {
    throw const FormatException('Excel 文件中没有可读取的工作表');
  }
  return (rows: best, warnings: warnings);
}

/// 将工作表转为字符串行（跳过起始与数据间空行）
List<List<String>> _sheetToStringRows(xl.Sheet sheet) {
  final rows = <List<String>>[];
  var started = false;
  for (var r = 0; r < sheet.rows.length; r++) {
    final row = sheet.rows[r];
    final cells = row.map((c) => _cellToString(c?.value)).toList();
    final isEmptyRow = cells.every((c) => c.isEmpty);
    if (!started && isEmptyRow) continue;
    started = true;
    if (isEmptyRow) continue;
    rows.add(cells);
  }
  return rows;
}

String _cellToString(xl.CellValue? cell) {
  if (cell == null) return '';
  if (cell is xl.TextCellValue) {
    // TextCellValue.value 是 TextSpan
    return cell.value.text ?? '';
  }
  if (cell is xl.IntCellValue) return cell.value.toString();
  if (cell is xl.DoubleCellValue) return cell.value.toString();
  if (cell is xl.BoolCellValue) return cell.value.toString();
  if (cell is xl.DateCellValue) {
    final dt = cell.asDateTimeUtc();
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
  }
  if (cell is xl.DateTimeCellValue) {
    final dt = cell.asDateTimeUtc();
    final date = '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
    return dt.hour == 0 && dt.minute == 0 ? date : '$date ${dt.hour}:${dt.minute}';
  }
  if (cell is xl.TimeCellValue) {
    return cell.toString();
  }
  final s = cell.toString().trim();
  return (s == 'null') ? '' : s;
}

/// 生成模板 .xlsx（两个工作表：资产 / 负债）
Uint8List buildTemplateXlsx() {
  final excel = xl.Excel.createExcel();
  // 删除默认 Sheet1，改名避免空表被当作第一个工作表读取
  if (excel.tables.containsKey('Sheet1')) {
    excel.rename('Sheet1', '资产');
  }
  final sheetAssets = excel['资产'];
  final sheetLiability = excel['负债'];

  // 写表头
  for (int i = 0; i < SpreadsheetParser.assetTemplateHeaders.length; i++) {
    sheetAssets
        .cell(xl.CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0))
        .value = xl.TextCellValue(SpreadsheetParser.assetTemplateHeaders[i]);
  }
  for (int i = 0; i < SpreadsheetParser.liabilityTemplateHeaders.length; i++) {
    sheetLiability
        .cell(xl.CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0))
        .value = xl.TextCellValue(SpreadsheetParser.liabilityTemplateHeaders[i]);
  }
  // 示例行
  final exampleAsset = <String>[
    '房产', '示例·自住房', '3200000', '2020-06-15', 'XX银行', '备注示例',
    '', '', '', '', '',
    '北京市朝阳区xx路1号', '89', '76', '住宅', '3', '12/32', '2018', '商品房', '京(2020)不动产权第0000000号',
    '', '', '', '',
    '', '', '', '', '', '', '', '', '',
  ];
  for (int i = 0; i < exampleAsset.length && i < SpreadsheetParser.assetTemplateHeaders.length; i++) {
    sheetAssets
        .cell(xl.CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 1))
        .value = xl.TextCellValue(exampleAsset[i]);
  }
  final exampleLiability = <String>[
    '房贷', '示例·房贷', '1500000', '2019-03-01', 'XX银行', '',
    '2039-03-01', '4.2', '等额本息', '240',
    '', '', '', '', '', '', '',
    '北京市朝阳区xx路1号', '3200000', '1500000', '商业贷款',
    '', '', '',
    '', '', '',
  ];
  for (int i = 0; i < exampleLiability.length && i < SpreadsheetParser.liabilityTemplateHeaders.length; i++) {
    sheetLiability
        .cell(xl.CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 1))
        .value = xl.TextCellValue(exampleLiability[i]);
  }

  return excel.save()! as Uint8List;
}

/// 生成模板 .csv（资产工作表）
String buildTemplateCsvAssets() {
  final buf = StringBuffer();
  buf.writeln(SpreadsheetParser.assetTemplateHeaders.join(','));
  buf.writeln('房产,示例·自住房,3200000,2020-06-15,XX银行,备注示例,,,,,');
  return buf.toString();
}

/// 生成模板 .csv（负债工作表）
String buildTemplateCsvLiabilities() {
  final buf = StringBuffer();
  buf.writeln(SpreadsheetParser.liabilityTemplateHeaders.join(','));
  buf.writeln('房贷,示例·房贷,1500000,2019-03-01,XX银行,,2039-03-01,4.2,等额本息,240,,,,,,,,');
  return buf.toString();
}

/// 解析为「导入行」列表
/// [rows] 来自 readImportFile（含表头）；[headerRow] 表头所在行索引
List<ImportRow> parseImportRows(
  List<List<String>> rows,
  List<ImportCustomType> customTypes, {
  int headerRow = 0,
}) {
  if (rows.isEmpty) return [];
  final headerTitles = rows[headerRow];
  final parsed = <ImportRow>[];
  // 数据行从 headerRow+1 开始
  for (int i = headerRow + 1; i < rows.length; i++) {
    final cells = rows[i];
    // 全空行跳过
    if (cells.every((c) => c.trim().isEmpty)) continue;
    final row = SpreadsheetParser.parseRow(
      i + 1, // 源文件行号（1-based）
      headerTitles,
      cells,
      customTypes,
    );
    parsed.add(row);
  }
  return parsed;
}

/// 统计解析结果
({int assets, int liabilities, int skipped}) countParseResult(List<ImportRow> rows) {
  var assets = 0, liabilities = 0, skipped = 0;
  for (final r in rows) {
    if (r.isSkip) {
      skipped++;
    } else if (r.target == ImportTarget.asset) {
      assets++;
    } else {
      liabilities++;
    }
  }
  return (assets: assets, liabilities: liabilities, skipped: skipped);
}
