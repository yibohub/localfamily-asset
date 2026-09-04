/// 金融记录详情页面（支持资产/负债分离模型）
///
/// 显示资产或负债的完整信息，包括所有扩展字段

import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../core/ffi_bridge.dart';
import '../models/financial_models.dart';
import '../providers/financial_provider.dart';
import '../utils/currency_utils.dart';
import 'financial_record_form_screen.dart';
import 'asset_history_screen.dart';

/// 金融记录详情页
class FinancialRecordDetailScreen extends StatefulWidget {
  final String recordId;
  final RecordType recordType;

  const FinancialRecordDetailScreen({
    super.key,
    required this.recordId,
    required this.recordType,
  });

  @override
  State<FinancialRecordDetailScreen> createState() =>
      _FinancialRecordDetailScreenState();
}

class _FinancialRecordDetailScreenState
    extends State<FinancialRecordDetailScreen> {
  dynamic _record; // Asset? or Liability?

  // 附件状态（仅资产支持：保单/房产证等照片）
  final FfiBridge _ffi = FfiBridge();
  List<AttachmentInfo> _attachments = const [];
  bool _attachmentsLoading = false;
  bool _attachmentBusy = false;

  @override
  void initState() {
    super.initState();
    _loadRecord();
    _loadAttachments();
  }

  /// 单个附件解密后的大小上限（与 Rust 端 ATTACHMENT_MAX_SIZE 一致）
  static const int _maxAttachmentSize = 20 * 1024 * 1024;

  Future<void> _loadAttachments() async {
    if (widget.recordType != RecordType.asset) return;
    setState(() => _attachmentsLoading = true);
    try {
      final list = await _ffi.getAttachments(widget.recordId);
      if (mounted) setState(() => _attachments = list);
    } finally {
      if (mounted) setState(() => _attachmentsLoading = false);
    }
  }

  void _loadRecord() {
    final provider = context.read<FinancialProvider>();
    setState(() {
      try {
        if (widget.recordType == RecordType.asset) {
          _record = provider.assets.firstWhere((a) => a.id == widget.recordId);
        } else {
          _record =
              provider.liabilities.firstWhere((l) => l.id == widget.recordId);
        }
      } catch (e) {
        // 记录未找到，可能刚刚被删除或列表未刷新
        debugPrint('记录未找到: $e');
        _record = null;
      }
    });
  }

  /// 获取类型的显示名称（处理 dynamic 类型的扩展方法问题）
  String _getTypeDisplayName() {
    if (widget.recordType == RecordType.asset) {
      final asset = _record as Asset;
      return asset.type.displayName;
    } else {
      final liability = _record as Liability;
      return liability.type.displayName;
    }
  }

  /// 检查是否为投资类资产
  bool _isInvestment() {
    if (widget.recordType == RecordType.asset) {
      final asset = _record as Asset;
      return asset.type.isInvestment;
    }
    return false;
  }

  /// 获取资产类型（用于条件判断）
  AssetType? _getAssetType() {
    if (widget.recordType == RecordType.asset) {
      return (_record as Asset).type;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    if (_record == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('详情')),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.grey),
              const SizedBox(height: 16),
              const Text('记录未找到'),
              const SizedBox(height: 8),
              Text(
                '该记录可能已被删除',
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: Colors.grey[600]),
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('返回'),
              ),
            ],
          ),
        ),
      );
    }

    final isAsset = widget.recordType == RecordType.asset;

    return Scaffold(
      appBar: AppBar(
        title: Text(_record.name),
        actions: [
          IconButton(
            icon: const Icon(Icons.history),
            tooltip: '操作记录',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => AssetHistoryScreen(
                    assetId: widget.recordId, // 显示该记录的历史
                  ),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.edit),
            tooltip: '编辑',
            onPressed: () => _handleEdit(context),
          ),
          IconButton(
            icon: const Icon(Icons.delete),
            tooltip: '删除',
            color: Colors.red,
            onPressed: () => _handleDelete(context),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildAmountCard(context, isAsset),
          const SizedBox(height: 16),
          _buildBasicInfo(context, isAsset),
          // 投资类信息
          if (isAsset && _isInvestment()) ...[
            const SizedBox(height: 16),
            _buildInvestmentInfo(context),
          ],
          // 房产信息
          if (isAsset && _getAssetType() == AssetType.property) ...[
            const SizedBox(height: 16),
            _buildPropertyInfo(context),
          ],
          // 存款信息
          if (isAsset && _getAssetType() == AssetType.deposit) ...[
            const SizedBox(height: 16),
            _buildDepositInfo(context),
          ],
          // 保单信息
          if (isAsset && _getAssetType() == AssetType.insurance) ...[
            const SizedBox(height: 16),
            _buildInsuranceInfo(context),
          ],
          // 负债信息
          if (!isAsset) ...[
            const SizedBox(height: 16),
            _buildLoanBasicInfo(context),
            // 信用卡信息
            if ((_record as Liability).isCreditCard) ...[
              const SizedBox(height: 16),
              _buildCreditCardInfo(context),
            ],
            // 房贷信息
            if ((_record as Liability).type == LiabilityType.mortgage) ...[
              const SizedBox(height: 16),
              _buildMortgageInfo(context),
            ],
            // 车贷信息
            if ((_record as Liability).type == LiabilityType.carLoan) ...[
              const SizedBox(height: 16),
              _buildCarLoanInfo(context),
            ],
            // 个人/私人借款信息
            if ((_record as Liability).type == LiabilityType.personalLoan ||
                (_record as Liability).type == LiabilityType.privateLoan) ...[
              const SizedBox(height: 16),
              _buildPersonalLoanInfo(context),
            ],
          ],
          // 备注信息
          if (_record.note != null && _record.note!.isNotEmpty) ...[
            const SizedBox(height: 16),
            _buildNoteCard(context),
          ],
          // 附件（仅资产：保单/房产证等照片，加密存储）
          if (widget.recordType == RecordType.asset) ...[
            const SizedBox(height: 16),
            _buildAttachmentsSection(context),
          ],
          // 时间信息
          const SizedBox(height: 16),
          _buildTimeInfo(context),
        ],
      ),
    );
  }

  Widget _buildAmountCard(BuildContext context, bool isAsset) {
    final amount = _record.amount;
    final currency = _record.currency;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  isAsset ? '资产价值' : '负债金额',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                _buildTypeIcon(context),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              _formatAmount(amount, currency),
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    color: isAsset
                        ? Theme.of(context).colorScheme.primary
                        : Colors.red,
                    fontWeight: FontWeight.bold,
                  ),
            ),
            // 投资类盈亏信息
            if (isAsset &&
                _record.isInvestment &&
                _record.profitLossPercent != null) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Text(
                    '盈亏: ',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  Text(
                    '${_record.profitLossPercent!.toStringAsFixed(2)}%',
                    style: TextStyle(
                      color: _record.profitLossPercent! >= 0
                          ? Colors.green
                          : Colors.red,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      '(${_record.profitLossAmount != null ? _formatAmount(_record.profitLossAmount!, '') : ''})',
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: _record.profitLossAmount != null &&
                                _record.profitLossAmount! >= 0
                            ? Colors.green
                            : Colors.red,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ],
            // 信用卡使用率
            if (!isAsset &&
                _record.isCreditCard &&
                _record.creditUtilization != null) ...[
              const SizedBox(height: 8),
              Text(
                '使用率: ${_record.creditUtilization!.toStringAsFixed(1)}%',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildBasicInfo(BuildContext context, bool isAsset) {
    return Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              '基本信息',
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          _buildInfoTile(
              context, isAsset ? '资产类型' : '负债类型', _getTypeDisplayName()),
          _buildInfoTile(context, '货币', _record.currency),
          _buildInfoTile(context, '发生日期', _formatDate(_record.occurrenceDate)),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _buildInvestmentInfo(BuildContext context) {
    return Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              '投资信息',
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          if (_record.code != null)
            _buildInfoTile(context, '代码', _record.code!),
          if (_record.exchange != null)
            _buildInfoTile(context, '交易所/平台', _record.exchange!),
          if (_record.quantity != null)
            _buildInfoTile(context, '数量', _record.quantity.toString()),
          if (_record.buyPrice != null)
            _buildInfoTile(
                context, '买入价', '¥${_record.buyPrice!.toStringAsFixed(2)}'),
          if (_record.currentPrice != null)
            _buildInfoTile(
                context, '现价', '¥${_record.currentPrice!.toStringAsFixed(2)}'),
          if (_record.account != null)
            _buildInfoTile(context, '证券账户/平台', _record.account!),
          if (_record.tags != null && _record.tags!.isNotEmpty)
            _buildInfoTile(context, '标签', _record.tags!.join(', ')),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _buildPropertyInfo(BuildContext context) {
    return Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              '房产信息',
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          if (_record.address != null)
            _buildInfoTile(context, '地址', _record.address!),
          if (_record.buildingArea != null)
            _buildInfoTile(context, '建筑面积',
                '${_record.buildingArea!.toStringAsFixed(2)} ㎡'),
          if (_record.livingArea != null)
            _buildInfoTile(
                context, '使用面积', '${_record.livingArea!.toStringAsFixed(2)} ㎡'),
          if (_record.propertyType != null)
            _buildInfoTile(context, '房屋类型', _record.propertyType!),
          if (_record.rooms != null)
            _buildInfoTile(context, '房型', _record.rooms.toString()),
          if (_record.floor != null)
            _buildInfoTile(context, '楼层', _record.floor!),
          if (_record.buildYear != null)
            _buildInfoTile(context, '建成年份', _record.buildYear.toString()),
          if (_record.ownershipType != null)
            _buildInfoTile(context, '产权性质', _record.ownershipType!),
          if (_record.deedNumber != null)
            _buildInfoTile(context, '不动产证号', _record.deedNumber!),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _buildDepositInfo(BuildContext context) {
    return Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              '存款信息',
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          if (_record.account != null)
            _buildInfoTile(context, '银行/机构', _record.account!),
          if (_record.depositAccountType != null)
            _buildInfoTile(context, '账户类型', _record.depositAccountType!),
          if (_record.depositPeriod != null)
            _buildInfoTile(context, '存期', '${_record.depositPeriod} 个月'),
          if (_record.maturityDate != null)
            _buildInfoTile(context, '到期日期', _formatDate(_record.maturityDate!)),
          if (_record.depositInterestRate != null)
            _buildInfoTile(context, '利率',
                '${_record.depositInterestRate!.toStringAsFixed(2)}%'),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _buildInsuranceInfo(BuildContext context) {
    return Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              '保单信息',
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          if (_record.policyNumber != null)
            _buildInfoTile(context, '保单号', _record.policyNumber!),
          if (_record.insurer != null)
            _buildInfoTile(context, '保险公司', _record.insurer!),
          if (_record.insuranceType != null)
            _buildInfoTile(context, '保险类型', _record.insuranceType!),
          if (_record.insured != null)
            _buildInfoTile(context, '被保人', _record.insured!),
          if (_record.beneficiary != null)
            _buildInfoTile(context, '受益人', _record.beneficiary!),
          if (_record.coverageAmount != null)
            _buildInfoTile(
                context, '保额', _formatAmount(_record.coverageAmount!, '')),
          if (_record.premium != null)
            _buildInfoTile(context, '保费', _formatAmount(_record.premium!, '')),
          if (_record.premiumPeriod != null)
            _buildInfoTile(context, '缴费期限', _record.premiumPeriod!),
          if (_record.coveragePeriod != null)
            _buildInfoTile(context, '保险期限', _record.coveragePeriod!),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  /// 贷款/借款基本信息卡片
  Widget _buildLoanBasicInfo(BuildContext context) {
    final liability = _record as Liability;

    return Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              '贷款/借款信息',
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          if (_record.lender != null)
            _buildInfoTile(context, '债权人/机构', liability.lender!),
          if (_record.interestRate != null)
            _buildInfoTile(
                context, '年利率', '${_record.interestRate!.toStringAsFixed(2)}%'),
          if (liability.repaymentMethod != null)
            _buildInfoTile(
                context, '还款方式', liability.repaymentMethod!.displayName),
          if (_record.dueDate != null)
            _buildInfoTile(context, '到期日', _formatDate(_record.dueDate!)),
          if (liability.loanTerm != null)
            _buildInfoTile(context, '贷款期限', '${liability.loanTerm} 个月'),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  /// 信用卡信息卡片
  Widget _buildCreditCardInfo(BuildContext context) {
    final liability = _record as Liability;

    return Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              '信用卡信息',
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          if (liability.lastFourDigits != null)
            _buildInfoTile(context, '卡号后四位', liability.lastFourDigits!),
          if (liability.billingDate != null)
            _buildInfoTile(context, '账单日', '${liability.billingDate!.day}号'),
          if (liability.paymentDueDate != null)
            _buildInfoTile(context, '还款日', '${liability.paymentDueDate!.day}号'),
          if (liability.creditLimit != null) ...[
            _buildInfoTile(
                context, '信用额度', _formatAmount(liability.creditLimit!, '')),
            if (_record.availableCredit != null)
              _buildInfoTile(
                  context, '可用额度', _formatAmount(_record.availableCredit!, '')),
          ],
          if (liability.cashLimit != null)
            _buildInfoTile(
                context, '取现额度', _formatAmount(liability.cashLimit!, '')),
          if (liability.annualFee != null)
            _buildInfoTile(
                context, '年费', _formatAmount(liability.annualFee!, '')),
          if (liability.issuer != null)
            _buildInfoTile(context, '发卡行', liability.issuer!),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  /// 房贷信息卡片
  Widget _buildMortgageInfo(BuildContext context) {
    final liability = _record as Liability;

    return Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              '房贷信息',
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          if (liability.propertyAddress != null)
            _buildInfoTile(context, '房产地址', liability.propertyAddress!),
          if (liability.originalLoanAmount != null)
            _buildInfoTile(context, '原始贷款金额',
                _formatAmount(liability.originalLoanAmount!, '')),
          if (liability.remainingPrincipal != null)
            _buildInfoTile(context, '剩余本金',
                _formatAmount(liability.remainingPrincipal!, '')),
          if (liability.loanType != null)
            _buildInfoTile(context, '贷款类型', liability.loanType!),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  /// 车贷信息卡片
  Widget _buildCarLoanInfo(BuildContext context) {
    final liability = _record as Liability;

    return Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              '车贷信息',
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          if (liability.vehicleBrand != null)
            _buildInfoTile(context, '车辆品牌', liability.vehicleBrand!),
          if (liability.vehicleModel != null)
            _buildInfoTile(context, '车型', liability.vehicleModel!),
          if (liability.licensePlate != null)
            _buildInfoTile(context, '车牌号', liability.licensePlate!),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  /// 个人/私人借款信息卡片
  Widget _buildPersonalLoanInfo(BuildContext context) {
    final liability = _record as Liability;

    return Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              '借款信息',
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          if (liability.purpose != null)
            _buildInfoTile(context, '借款用途', liability.purpose!),
          if (liability.hasInterest != null)
            _buildInfoTile(
                context, '是否有利息', liability.hasInterest == true ? '是' : '否'),
          if (liability.repaymentPlan != null)
            _buildInfoTile(context, '还款计划', liability.repaymentPlan!),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _buildNoteCard(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '备注',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(_record.note!),
          ],
        ),
      ),
    );
  }

  // ==================== 附件（保单/房产证照片，加密存储） ====================

  Widget _buildAttachmentsSection(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text('附件', style: Theme.of(context).textTheme.titleMedium),
                if (_attachments.isNotEmpty) ...[
                  const SizedBox(width: 8),
                  Text('(${_attachments.length})',
                      style: Theme.of(context).textTheme.bodySmall),
                ],
                const Spacer(),
                if (_attachmentBusy)
                  const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                else
                  IconButton(
                    icon: const Icon(Icons.add_a_photo_outlined),
                    tooltip: '添加附件',
                    onPressed: _addAttachmentFlow,
                  ),
              ],
            ),
            const SizedBox(height: 8),
            if (_attachmentsLoading)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: CircularProgressIndicator(),
                ),
              )
            else if (_attachments.isEmpty)
              Text(
                '暂无附件，可添加保单、房产证等照片（加密存储）',
                style: Theme.of(context).textTheme.bodySmall,
              )
            else
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: _attachments
                    .map((a) => _buildAttachmentTile(context, a))
                    .toList(),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildAttachmentTile(BuildContext context, AttachmentInfo info) {
    final isImage = _isImageMime(info.mimeType);
    return SizedBox(
      width: 96,
      child: Column(
        children: [
          Stack(
            children: [
              GestureDetector(
                onTap: () => _previewAttachment(info),
                child: Container(
                  width: 96,
                  height: 96,
                  decoration: BoxDecoration(
                    color: Theme.of(context)
                        .colorScheme
                        .surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: isImage
                      ? const Icon(Icons.image_outlined, size: 32)
                      : const Icon(Icons.insert_drive_file_outlined,
                          size: 32),
                ),
              ),
              Positioned(
                top: 0,
                right: 0,
                child: GestureDetector(
                  onTap: () => _confirmDeleteAttachment(info),
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: const BoxDecoration(
                      color: Colors.black54,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.close,
                        size: 14, color: Colors.white),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            info.fileName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }

  Future<void> _addAttachmentFlow() async {
    final options = <(String, IconData, VoidCallback)>[
      if (Platform.isAndroid || Platform.isIOS)
        (
          '拍照',
          Icons.photo_camera_outlined,
          () => _pickFromImagePicker(ImageSource.camera),
        ),
      if (Platform.isAndroid || Platform.isIOS)
        (
          '从相册选择',
          Icons.photo_library_outlined,
          () => _pickFromImagePicker(ImageSource.gallery),
        ),
      (
        '选择文件',
        Icons.folder_outlined,
        _pickFromFilePicker,
      ),
    ];

    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text('添加附件'),
            ),
            ...options.map(
              (o) => ListTile(
                leading: Icon(o.$2),
                title: Text(o.$1),
                onTap: () {
                  Navigator.pop(sheetContext);
                  o.$3();
                },
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Future<void> _pickFromImagePicker(ImageSource source) async {
    try {
      final picker = ImagePicker();
      final xFile = await picker.pickImage(
        source: source,
        maxWidth: 4096,
        maxHeight: 4096,
        imageQuality: 85,
      );
      if (xFile == null) return;
      final bytes = await xFile.readAsBytes();
      await _saveAttachment(xFile.name, bytes);
    } catch (e) {
      debugPrint('选取图片失败: $e');
      _showSnack('选取图片失败');
    }
  }

  Future<void> _pickFromFilePicker() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.any,
        withData: true,
      );
      final file = result?.files.singleOrNull;
      if (file == null) return;
      final bytes = file.bytes;
      if (bytes == null) {
        _showSnack('读取文件失败');
        return;
      }
      await _saveAttachment(file.name, bytes);
    } catch (e) {
      debugPrint('选择文件失败: $e');
      _showSnack('选择文件失败');
    }
  }

  Future<void> _saveAttachment(String fileName, Uint8List bytes) async {
    if (bytes.isEmpty) {
      _showSnack('文件为空');
      return;
    }
    if (bytes.length > _maxAttachmentSize) {
      _showSnack('附件超过 20MB，请压缩后再添加');
      return;
    }

    setState(() => _attachmentBusy = true);
    try {
      final ok = await _ffi.addAttachment(
        assetId: widget.recordId,
        fileName: fileName,
        mimeType: _guessMimeType(fileName),
        bytes: bytes,
      );
      if (!ok) {
        _showSnack('添加附件失败');
        return;
      }
      // 即时加密落盘（与全局保存策略一致）
      await _ffi.saveDatabase();
      _showSnack('附件已加密保存');
      await _loadAttachments();
    } finally {
      if (mounted) setState(() => _attachmentBusy = false);
    }
  }

  Future<void> _previewAttachment(AttachmentInfo info) async {
    if (_attachmentBusy) return;
    setState(() => _attachmentBusy = true);
    Uint8List? data;
    try {
      data = await _ffi.readAttachmentData(info.id);
    } finally {
      if (mounted) setState(() => _attachmentBusy = false);
    }

    if (data == null) {
      _showSnack('读取附件失败');
      return;
    }
    if (!_isImageMime(info.mimeType)) {
      _showSnack('该文件类型暂不支持预览');
      return;
    }
    if (!mounted) return;
    final imageData = data;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => Dialog.fullscreen(
        child: Column(
          children: [
            AppBar(
              title: Text(info.fileName),
              actions: [
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(dialogContext),
                ),
              ],
            ),
            Expanded(
              child: InteractiveViewer(
                maxScale: 5,
                child: Center(child: Image.memory(imageData)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmDeleteAttachment(AttachmentInfo info) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('删除附件'),
        content: Text('确定删除「${info.fileName}」吗？此操作不可恢复。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _attachmentBusy = true);
    try {
      final ok = await _ffi.deleteAttachment(info.id);
      if (!ok) {
        _showSnack('删除附件失败');
        return;
      }
      await _ffi.saveDatabase();
      _showSnack('附件已删除');
      await _loadAttachments();
    } finally {
      if (mounted) setState(() => _attachmentBusy = false);
    }
  }

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  String? _guessMimeType(String fileName) {
    final ext = fileName.contains('.')
        ? fileName.split('.').last.toLowerCase()
        : '';
    return switch (ext) {
      'jpg' || 'jpeg' => 'image/jpeg',
      'png' => 'image/png',
      'webp' => 'image/webp',
      'gif' => 'image/gif',
      'heic' || 'heif' => 'image/heic',
      'pdf' => 'application/pdf',
      _ => null,
    };
  }

  bool _isImageMime(String? mime) => mime != null && mime.startsWith('image/');

  Widget _buildTimeInfo(BuildContext context) {
    return Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              '时间信息',
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          _buildInfoTile(context, '创建时间', _formatDate(_record.createdAt)),
          _buildInfoTile(context, '更新时间', _formatDate(_record.updatedAt)),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _buildInfoTile(BuildContext context, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.grey[600],
                  ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTypeIcon(BuildContext context) {
    if (widget.recordType == RecordType.asset) {
      final asset = _record as Asset;
      switch (asset.type) {
        case AssetType.property:
          return const CircleAvatar(
            backgroundColor: Colors.blue,
            child: Icon(Icons.home, color: Colors.white, size: 20),
          );
        case AssetType.deposit:
          return const CircleAvatar(
            backgroundColor: Colors.green,
            child: Icon(Icons.account_balance, color: Colors.white, size: 20),
          );
        case AssetType.stock:
          return const CircleAvatar(
            backgroundColor: Colors.orange,
            child: Icon(Icons.trending_up, color: Colors.white, size: 20),
          );
        case AssetType.fund:
          return const CircleAvatar(
            backgroundColor: Colors.purple,
            child: Icon(Icons.pie_chart, color: Colors.white, size: 20),
          );
        case AssetType.insurance:
          return const CircleAvatar(
            backgroundColor: Colors.teal,
            child: Icon(Icons.security, color: Colors.white, size: 20),
          );
      }
    } else {
      final liability = _record as Liability;
      switch (liability.type) {
        case LiabilityType.debt:
          return const CircleAvatar(
            backgroundColor: Colors.grey,
            child: Icon(Icons.money_off, color: Colors.white, size: 20),
          );
        case LiabilityType.mortgage:
          return const CircleAvatar(
            backgroundColor: Colors.brown,
            child: Icon(Icons.home_work, color: Colors.white, size: 20),
          );
        case LiabilityType.carLoan:
          return const CircleAvatar(
            backgroundColor: Colors.indigo,
            child: Icon(Icons.directions_car, color: Colors.white, size: 20),
          );
        case LiabilityType.creditCard:
          return const CircleAvatar(
            backgroundColor: Colors.deepOrange,
            child: Icon(Icons.credit_card, color: Colors.white, size: 20),
          );
        case LiabilityType.personalLoan:
          return const CircleAvatar(
            backgroundColor: Colors.cyan,
            child: Icon(Icons.person, color: Colors.white, size: 20),
          );
        case LiabilityType.privateLoan:
          return const CircleAvatar(
            backgroundColor: Colors.lightBlue,
            child: Icon(Icons.handshake, color: Colors.white, size: 20),
          );
      }
    }
  }

  void _handleEdit(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => FinancialRecordFormScreen(
          record: _record,
          initialType: widget.recordType,
        ),
      ),
    ).then((_) => _loadRecord());
  }

  Future<void> _handleDelete(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('确认删除'),
        content: Text('确定要删除「${_record.name}」吗？此操作无法撤销。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('删除'),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      final provider = context.read<FinancialProvider>();
      bool success;
      if (widget.recordType == RecordType.asset) {
        success = await provider.deleteAsset(_record.id);
      } else {
        success = await provider.deleteLiability(_record.id);
      }

      if (success && context.mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(
                  '已删除${widget.recordType == RecordType.asset ? '资产' : '负债'}')),
        );
      }
    }
  }

  String _formatAmount(double amount, String currency) {
    // 与全项目 CurrencyUtils 一致：货币符号 + 万/亿分级，避免裸代码拼接与单位错乱
    final prefix = currency.isEmpty ? '' : '${CurrencyUtils.getSymbol(currency)} ';
    final absAmount = amount.abs();
    if (absAmount >= 100000000) {
      return '$prefix${(amount / 100000000).toStringAsFixed(2)} 亿';
    } else if (absAmount >= 10000) {
      return '$prefix${(amount / 10000).toStringAsFixed(2)} 万';
    }
    return '$prefix${amount.toStringAsFixed(2)}';
  }

  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }
}
