import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/financial_models.dart';
import '../providers/financial_provider.dart';
import '../utils/debouncer.dart';

/// 智能金融记录名称输入组件（支持新模型）
///
/// 特性：
/// - 输入时自动搜索同名资产/负债
/// - 资产显示 "资产名称 (账户)" 格式
/// - 负债显示 "负债名称 (债权人)" 格式
/// - 选择后自动填充账户/债权人字段
/// - 支持资产/负债类型过滤
/// - 支持自定义类型过滤
class SmartFinancialRecordNameInput extends StatefulWidget {
  final TextEditingController nameController;
  final TextEditingController? subAccountController;
  final List<AssetType>? assetTypeFilter;
  final List<LiabilityType>? liabilityTypeFilter;
  final String? customTypeIdFilter;
  final String? labelText;
  final String? hintText;
  final bool enabled;
  final Function(String)? onFieldSubmitted;

  const SmartFinancialRecordNameInput({
    super.key,
    required this.nameController,
    this.subAccountController,
    this.assetTypeFilter,
    this.liabilityTypeFilter,
    this.customTypeIdFilter,
    this.labelText,
    this.hintText,
    this.enabled = true,
    this.onFieldSubmitted,
  });

  @override
  State<SmartFinancialRecordNameInput> createState() => _SmartFinancialRecordNameInputState();
}

class _SmartFinancialRecordNameInputState extends State<SmartFinancialRecordNameInput> {
  final Debouncer _debouncer = Debouncer(delay: const Duration(milliseconds: 300));
  final List<Object> _suggestions = []; // 混合 Asset 和 Liability
  final FocusNode _focusNode = FocusNode();
  bool _isSearching = false;
  bool _isSelecting = false;

  @override
  void initState() {
    super.initState();
    widget.nameController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    widget.nameController.removeListener(_onSearchChanged);
    _debouncer.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    // 如果正在选择，不触发搜索
    if (_isSelecting) {
      return;
    }

    _debouncer(() {
      final query = widget.nameController.text;
      if (query.trim().isEmpty) {
        setState(() {
          _suggestions.clear();
          _isSearching = false;
        });
        return;
      }

      setState(() {
        _isSearching = true;
      });

      // 使用 FinancialProvider 搜索
      final provider = context.read<FinancialProvider>();

      // 根据类型过滤器决定搜索资产还是负债
      if (widget.assetTypeFilter != null) {
        // 搜索资产
        provider.searchAssetsByName(query, types: widget.assetTypeFilter).then((_) {
          if (mounted) {
            setState(() {
              _suggestions.clear();
              _suggestions.addAll(provider.assetSearchResults);
              _isSearching = false;
            });
          }
        });
      } else if (widget.liabilityTypeFilter != null) {
        // 搜索负债
        provider.searchLiabilitiesByName(query, types: widget.liabilityTypeFilter).then((_) {
          if (mounted) {
            setState(() {
              _suggestions.clear();
              _suggestions.addAll(provider.liabilitySearchResults);
              _isSearching = false;
            });
          }
        });
      } else {
        // 同时搜索资产和负债
        Future.wait([
          provider.searchAssetsByName(query),
          provider.searchLiabilitiesByName(query),
        ]).then((_) {
          if (mounted) {
            setState(() {
              _suggestions.clear();
              _suggestions.addAll(provider.assetSearchResults);
              _suggestions.addAll(provider.liabilitySearchResults);
              _isSearching = false;
            });
          }
        });
      }
    });
  }

  void _selectSuggestion(Object record) {
    setState(() {
      _isSelecting = true;
    });

    if (record is Asset) {
      widget.nameController.text = record.name.trim();  // 去除首尾空格
      if (widget.subAccountController != null) {
        widget.subAccountController!.text = record.account ?? '';
      }
    } else if (record is Liability) {
      widget.nameController.text = record.name.trim();  // 去除首尾空格
      if (widget.subAccountController != null) {
        // 负债用债权人字段
        widget.subAccountController!.text = record.lender ?? '';
      }
    }

    // 延迟清除建议列表，确保文本更新完成
    Future.microtask(() {
      if (mounted) {
        setState(() {
          _suggestions.clear();
          _isSelecting = false;
        });
        // 移除焦点，关闭键盘
        _focusNode.unfocus();
      }
    });
  }

  String _formatSuggestion(Object record) {
    if (record is Asset) {
      if (record.account != null && record.account!.isNotEmpty) {
        return '${record.name} (${record.account})';
      }
      return record.name;
    } else if (record is Liability) {
      if (record.lender != null && record.lender!.isNotEmpty) {
        return '${record.name} (${record.lender})';
      }
      return record.name;
    }
    return record.toString();
  }

  String _getSubtitle(Object record) {
    if (record is Asset) {
      switch (record.type) {
        case AssetType.property:
          return '房产';
        case AssetType.deposit:
          return '存款';
        case AssetType.stock:
          return '股票';
        case AssetType.fund:
          return '基金';
        case AssetType.insurance:
          return '保单';
      }
    } else if (record is Liability) {
      switch (record.type) {
        case LiabilityType.debt:
          return '其他负债';
        case LiabilityType.mortgage:
          return '房贷';
        case LiabilityType.carLoan:
          return '车贷';
        case LiabilityType.creditCard:
          return '信用卡';
        case LiabilityType.personalLoan:
          return '个人贷款';
        case LiabilityType.privateLoan:
          return '私人借款';
      }
    }
    return '';
  }

  double _getAmount(Object record) {
    if (record is Asset) {
      return record.amount;
    } else if (record is Liability) {
      return record.amount;
    }
    return 0.0;
  }

  bool _isLiability(Object record) {
    return record is Liability;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: widget.nameController,
          focusNode: _focusNode,
          enabled: widget.enabled,
          decoration: InputDecoration(
            labelText: widget.labelText ?? '名称',
            hintText: widget.hintText ?? '输入名称进行搜索',
            border: const OutlineInputBorder(),
            suffixIcon: _isSearching
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: Padding(
                      padding: EdgeInsets.all(12.0),
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                : null,
          ),
          autofocus: false,
          onTap: () {
            // 当点击输入框时，清除建议列表
            if (_suggestions.isNotEmpty) {
              setState(() {
                _suggestions.clear();
              });
            }
          },
          onSubmitted: (value) {
            // 清除建议列表
            setState(() {
              _suggestions.clear();
            });
            // 调用外部回调
            if (widget.onFieldSubmitted != null) {
              widget.onFieldSubmitted!(value);
            }
          },
        ),
        if (_suggestions.isNotEmpty)
          GestureDetector(
            onTap: () {
              // 点击建议列表外部时，清除建议
              setState(() {
                _suggestions.clear();
              });
              _focusNode.unfocus();
            },
            child: Container(
              margin: const EdgeInsets.only(top: 8),
              constraints: const BoxConstraints(maxHeight: 200),
              decoration: BoxDecoration(
                border: Border.all(color: Theme.of(context).dividerColor),
                borderRadius: BorderRadius.circular(4),
                color: Theme.of(context).cardColor,
              ),
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: _suggestions.length,
                itemBuilder: (context, index) {
                  final record = _suggestions[index];
                  return ListTile(
                    dense: true,
                    title: Text(_formatSuggestion(record)),
                    subtitle: Text(_getSubtitle(record)),
                    trailing: Text(
                      _getAmount(record).toStringAsFixed(2),
                      style: TextStyle(
                        color: _isLiability(record)
                            ? Colors.red
                            : Colors.green,
                      ),
                    ),
                    onTap: () => _selectSuggestion(record),
                  );
                },
              ),
            ),
          ),
      ],
    );
  }
}
