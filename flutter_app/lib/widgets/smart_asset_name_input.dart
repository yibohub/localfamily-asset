import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/asset.dart';
import '../providers/asset_provider.dart';
import '../utils/debouncer.dart';

/// 智能资产名称输入组件
///
/// 特性：
/// - 输入时自动搜索同名资产
/// - 下拉框显示 "资产名称 (账户)" 格式
/// - 选择后自动填充账户字段
/// - 支持类型过滤
/// - 支持表单验证
class SmartAssetNameInput extends StatefulWidget {
  final TextEditingController nameController;
  final TextEditingController? accountController;
  final List<AssetType>? typeFilter;
  final String? labelText;
  final String? hintText;
  final bool enabled;
  final Function(String)? onFieldSubmitted;

  const SmartAssetNameInput({
    super.key,
    required this.nameController,
    this.accountController,
    this.typeFilter,
    this.labelText,
    this.hintText,
    this.enabled = true,
    this.onFieldSubmitted,
  });

  @override
  State<SmartAssetNameInput> createState() => _SmartAssetNameInputState();
}

class _SmartAssetNameInputState extends State<SmartAssetNameInput> {
  final Debouncer _debouncer = Debouncer(delay: const Duration(milliseconds: 300));
  final List<Asset> _suggestions = [];
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

      // 使用 Provider 搜索资产
      final provider = context.read<AssetProvider>();
      provider.searchAssetsByName(query, types: widget.typeFilter).then((_) {
        if (mounted) {
          setState(() {
            _suggestions.clear();
            _suggestions.addAll(provider.searchResults);
            _isSearching = false;
          });
        }
      });
    });
  }

  void _selectSuggestion(Asset asset) {
    setState(() {
      _isSelecting = true;
    });

    widget.nameController.text = asset.name;
    if (widget.accountController != null) {
      widget.accountController!.text = asset.account ?? '';
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

  String _formatSuggestion(Asset asset) {
    if (asset.account != null && asset.account!.isNotEmpty) {
      return '${asset.name} (${asset.account})';
    }
    return asset.name;
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
            labelText: widget.labelText ?? '资产名称',
            hintText: widget.hintText ?? '输入资产名称，如"招商银行储蓄卡"',
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
                  final asset = _suggestions[index];
                  return ListTile(
                    dense: true,
                    title: Text(_formatSuggestion(asset)),
                    trailing: Text(
                      asset.amount.toStringAsFixed(2),
                      style: TextStyle(
                        color: asset.type.isLiability
                            ? Colors.red
                            : Colors.green,
                      ),
                    ),
                    onTap: () => _selectSuggestion(asset),
                  );
                },
              ),
            ),
          ),
      ],
    );
  }
}
