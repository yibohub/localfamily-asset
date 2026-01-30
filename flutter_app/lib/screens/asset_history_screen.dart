import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/asset_change.dart';
import '../models/asset.dart';
import '../providers/asset_provider.dart';

/// 资产审计日志历史页面
class AssetHistoryScreen extends StatefulWidget {
  final String? assetId;  // null = 显示全部，有值 = 显示单资产

  const AssetHistoryScreen({
    super.key,
    this.assetId,
  });

  @override
  State<AssetHistoryScreen> createState() => _AssetHistoryScreenState();
}

class _AssetHistoryScreenState extends State<AssetHistoryScreen> {
  bool _isLoading = true;
  Asset? _asset;

  @override
  void initState() {
    super.initState();
    _loadChanges();
  }

  Future<void> _loadChanges() async {
    setState(() => _isLoading = true);
    final provider = context.read<AssetProvider>();
    if (widget.assetId == null) {
      await provider.loadAssetChanges();
    } else {
      await provider.loadAssetChangesByAssetId(widget.assetId!);
      // 获取资产信息以确定类型
      _asset = provider.assets.firstWhere((a) => a.id == widget.assetId);
    }
    setState(() => _isLoading = false);
  }

  String _getTitle() {
    if (widget.assetId == null) {
      return '全部操作记录';
    }
    if (_asset != null && _isLiabilityType(_asset!.type)) {
      return '负债修改历史';
    }
    return '资产修改历史';
  }

  /// 判断字符串类型是否为负债
  bool _isLiabilityType(String typeStr) {
    final builtInType = AssetTypeExtension.fromString(typeStr);
    if (builtInType != null) {
      return builtInType.isLiability;
    }
    // 自定义类型暂时当作资产处理
    return false;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_getTitle()),
        actions: [
          if (_isLoading)
            const Center(
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              ),
            )
          else
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _loadChanges,
            ),
        ],
      ),
      body: Consumer<AssetProvider>(
        builder: (context, provider, child) {
          final changes = widget.assetId == null
              ? provider.assetChanges
              : provider.assetChanges.where((c) => c.assetId == widget.assetId).toList();

          if (changes.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.history, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text(
                    '暂无操作记录',
                    style: TextStyle(fontSize: 16, color: Colors.grey),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: changes.length,
            itemBuilder: (context, index) {
              final change = changes[index];
              return AssetChangeListItem(change: change);
            },
          );
        },
      ),
    );
  }
}

/// 审计日志列表项
class AssetChangeListItem extends StatelessWidget {
  final AssetChange change;

  const AssetChangeListItem({
    super.key,
    required this.change,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 0, vertical: 8),
      child: ListTile(
        leading: _buildIcon(context),
        title: Text(
          change.changeDescription,
          style: const TextStyle(fontWeight: FontWeight.w500),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (change.detailDescription.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                change.detailDescription,
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey[600],
                ),
              ),
            ],
            const SizedBox(height: 4),
            Text(
              _formatTimestamp(change.changedAt),
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[500],
              ),
            ),
          ],
        ),
        isThreeLine: change.detailDescription.isNotEmpty,
      ),
    );
  }

  Widget _buildIcon(BuildContext context) {
    Color color;
    IconData icon;

    switch (change.changeType) {
      case ChangeType.created:
        color = Colors.green;
        icon = Icons.add_circle;
      case ChangeType.updated:
        color = Colors.orange;
        icon = Icons.edit;
      case ChangeType.deleted:
        color = Colors.red;
        icon = Icons.delete;
    }

    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Icon(icon, color: color),
    );
  }

  String _formatTimestamp(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inMinutes < 1) {
      return '刚刚';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}分钟前';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}小时前';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}天前';
    } else {
      return '${dateTime.year}年${dateTime.month}月${dateTime.day}日 '
             '${dateTime.hour.toString().padLeft(2, '0')}:'
             '${dateTime.minute.toString().padLeft(2, '0')}';
    }
  }
}
