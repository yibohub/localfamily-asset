import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';

import '../../core/file_dialogs.dart';
import '../../import/bulk_import_service.dart';
import '../../import/import_file_io.dart';
import '../../import/import_parser.dart';
import '../../models/financial_models.dart';
import '../../providers/custom_type_provider.dart';
import '../../providers/financial_provider.dart';

/// 批量导入页：选文件 → 解析 → 预览 → 导入 → 结果
class BulkImportScreen extends StatefulWidget {
  const BulkImportScreen({super.key});

  @override
  State<BulkImportScreen> createState() => _BulkImportScreenState();
}

class _BulkImportScreenState extends State<BulkImportScreen> {
  bool _loading = false;
  String? _error;
  String? _fileName;
  List<ImportRow>? _rows;
  List<ImportCustomType> _customTypes = [];

  Future<void> _pickAndParse() async {
    final result = await FilePicker.platform.pickFiles(
      dialogTitle: '选择批量导入文件',
      type: FileType.custom,
      allowedExtensions: ['csv', 'xlsx'],
    );
    if (result == null || result.files.isEmpty) return;
    final path = result.files.single.path;
    if (path == null) {
      _showError('无法获取文件路径');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
      _rows = null;
      _fileName = path.split(Platform.pathSeparator).last;
    });

    try {
      if (!mounted) return;
      // 自定义类型（用于识别类型列的“自定义”并跳过）
      final assetCustom =
          context.read<CustomTypeProvider>().assetCustomTypes.map((t) {
        return ImportCustomType(t.name, false);
      }).toList();
      final liabilityCustom = context
          .read<CustomTypeProvider>()
          .liabilityCustomTypes
          .map((t) {
        return ImportCustomType(t.name, true);
      }).toList();
      _customTypes = [...assetCustom, ...liabilityCustom];

      // 读取并解析（后台 isolate 太复杂，文件通常不大，直接同步读）
      final data = readImportFile(path);
      final parsed = parseImportRows(data.rows, _customTypes, headerRow: 0);
      final summary = countParseResult(parsed);
      if (parsed.isEmpty) {
        _showError('文件中没有可导入的数据行（需要「类型/名称/金额」等列）');
        setState(() {
          _loading = false;
          _fileName = null;
        });
        return;
      }
      setState(() {
        _rows = parsed;
        _loading = false;
      });
      // 提示概要
      if (!mounted) return;
      final sb = StringBuffer('共 ${parsed.length} 行：');
      sb.write('资产 ${summary.assets} 行');
      if (summary.liabilities > 0) sb.write('、负债 ${summary.liabilities} 行');
      if (summary.skipped > 0) sb.write('、跳过 ${summary.skipped} 行');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(sb.toString())),
      );
    } catch (e) {
      debugPrint('解析导入文件失败: $e');
      _showError('解析文件失败：$e');
      setState(() {
        _loading = false;
        _rows = null;
        _fileName = null;
      });
    }
  }

  void _showError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: Colors.red),
    );
  }

  /// 下载模板（桌面保存对话框；移动端落到文档目录）
  Future<void> _downloadTemplate() async {
    // 构建 xlsx
    final Uint8List bytes = buildTemplateXlsx();
    String? path;
    if (isDesktopPlatform) {
      path = await FilePicker.platform.saveFile(
        dialogTitle: '保存导入模板',
        fileName: 'import_template.xlsx',
        type: FileType.any,
      );
    } else {
      final dir = await getApplicationDocumentsDirectory();
      path = '${dir.path}/import_template.xlsx';
    }
    if (path == null) return;
    try {
      final file = File(path);
      await file.writeAsBytes(bytes);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('模板已保存到 $path')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('保存模板失败：$e'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _confirmImport() async {
    final rows = _rows;
    if (rows == null || rows.isEmpty) return;

    // 统计可导入数
    var valid = 0;
    for (final r in rows) {
      if (!r.isSkip) valid++;
    }
    if (valid == 0) {
      _showError('没有可导入的行（请检查文件格式）');
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('确认导入'),
        content: Text('将导入 $valid 条记录（资产/负债），跳过 ${rows.length - valid} 条无效行。\n导入后不可自动撤销。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('开始导入'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _loading = true);
    if (!mounted) return;
    final provider = context.read<FinancialProvider>();
    final service = BulkImportService(provider);
    try {
      final report = await service.run(rows.where((r) => !r.isSkip).toList());
      // 刷新
      await provider.loadFinancialRecords();
      if (!mounted) return;
      setState(() => _loading = false);
      _showResultDialog(report);
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      _showError('导入失败：$e');
    }
  }

  void _showResultDialog(ImportReport report) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('导入完成'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('成功导入资产 ${report.importedAssets} 条'),
              Text('成功导入负债 ${report.importedLiabilities} 条'),
              if (report.failed > 0) ...[
                const SizedBox(height: 8),
                Text('失败 ${report.failed} 条', style: const TextStyle(color: Colors.red)),
                const SizedBox(height: 4),
                for (final e in report.errors.take(20))
                  Text('• $e', style: const TextStyle(fontSize: 12)),
                if (report.errors.length > 20)
                  Text('… 以及另外 ${report.errors.length - 20} 条错误', style: const TextStyle(fontSize: 12)),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('完成'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('批量导入')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // 说明卡片
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('支持 CSV / Excel（.xlsx）批量导入资产与负债',
                            style: Theme.of(context).textTheme.titleSmall),
                        const SizedBox(height: 8),
                        const Text('模板要求：首行为列名（类型/名称/金额…）。'
                            '类型列填「房产/存款/股票/基金/保单/房贷/信用卡…」；'
                            '金额为元（纯数字）；可下载模板参考示例。',
                            style: TextStyle(fontSize: 13, height: 1.5)),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            OutlinedButton.icon(
                              onPressed: _downloadTemplate,
                              icon: const Icon(Icons.download),
                              label: const Text('下载导入模板'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                // 选择文件按钮
                FilledButton.icon(
                  onPressed: _pickAndParse,
                  icon: const Icon(Icons.upload_file),
                  label: const Text('选择 CSV / Excel 文件'),
                ),
                if (_fileName != null) ...[
                  const SizedBox(height: 8),
                  Text('已选择：$_fileName', style: const TextStyle(fontSize: 13)),
                ],
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Text(_error!, style: const TextStyle(color: Colors.red)),
                ],
                if (_rows != null) ...[
                  const SizedBox(height: 16),
                  _PreviewSection(rows: _rows!),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: _confirmImport,
                    icon: const Icon(Icons.play_arrow),
                    label: const Text('确认导入'),
                  ),
                ],
              ],
            ),
    );
  }
}

class _PreviewSection extends StatelessWidget {
  final List<ImportRow> rows;
  const _PreviewSection({required this.rows});

  @override
  Widget build(BuildContext context) {
    var assetCount = 0, liabilityCount = 0, skipCount = 0;
    for (final r in rows) {
      if (r.isSkip) {
        skipCount++;
      } else if (r.target == ImportTarget.asset) {
        assetCount++;
      } else {
        liabilityCount++;
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('解析结果（第 ${rows.length} 行）', style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 8),
        Text('将导入资产 $assetCount 条、负债 $liabilityCount 条${skipCount > 0 ? '、跳过 $skipCount 条' : ''}'),
        const SizedBox(height: 8),
        if (skipCount > 0)
          Container(
            constraints: const BoxConstraints(maxHeight: 150),
            child: ListView(
              shrinkWrap: true,
              children: [
                for (final r in rows.where((r) => r.isSkip).take(50))
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Text('跳过 第${r.rowNumber}行：${r.skipReason}',
                        style: const TextStyle(fontSize: 12, color: Colors.orange)),
                  ),
              ],
            ),
          ),
        const SizedBox(height: 8),
        Container(
          constraints: const BoxConstraints(maxHeight: 220),
          child: ListView(
            shrinkWrap: true,
            children: [
              for (final r in rows.where((r) => !r.isSkip).take(100))
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Text(
                    '第${r.rowNumber}行  ${r.target == ImportTarget.asset ? "资产" : "负债"}  ${_displayName(r)}',
                    style: const TextStyle(fontSize: 12),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  String _displayName(ImportRow r) {
    if (r.record is ImportedAsset) {
      final a = r.record as ImportedAsset;
      return '[${a.type.displayName}] ${a.name}  ${a.amount.toStringAsFixed(2)}元';
    }
    final l = r.record as ImportedLiability;
    return '[${l.type.displayName}] ${l.name}  ${l.amount.toStringAsFixed(2)}元';
  }
}
