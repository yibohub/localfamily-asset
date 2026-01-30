import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';

import '../models/asset.dart';
import '../providers/auth_provider.dart';
import '../providers/asset_provider.dart';
import '../providers/custom_type_provider.dart';
import '../core/ffi_bridge.dart';
import '../widgets/asset_summary_card.dart';
import '../widgets/asset_list_item.dart';
import '../widgets/add_asset_dialog.dart';
import 'asset_detail_screen.dart';
import 'auth/lock_screen.dart';

/// 主页
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  DateTime? _pausedAt;
  static const _autoLockDuration = Duration(minutes: 3);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    Future.microtask(() => context.read<AssetProvider>().loadAssets());

    // 监听认证状态变化，当锁定时导航到锁定页面
    context.read<AuthProvider>().addListener(_onAuthStatusChanged);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    context.read<AuthProvider>().removeListener(_onAuthStatusChanged);
    super.dispose();
  }

  /// 监听认证状态变化
  void _onAuthStatusChanged() {
    if (!mounted) return;

    final authStatus = context.read<AuthProvider>().status;
    if (authStatus == AuthStatus.locked) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LockScreen()),
        (route) => false,
      );
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    switch (state) {
      case AppLifecycleState.paused:
      case AppLifecycleState.inactive:
      case AppLifecycleState.detached:
        // 应用进入后台，记录时间
        _pausedAt = DateTime.now();
        debugPrint('应用进入后台，记录时间: $_pausedAt');
        break;
      case AppLifecycleState.resumed:
        // 应用恢复到前台，检查是否超时
        _checkAutoLock();
        break;
      case AppLifecycleState.hidden:
        // 应用隐藏（新的 Flutter 版本）
        _pausedAt = DateTime.now();
        debugPrint('应用隐藏，记录时间: $_pausedAt');
        break;
    }
  }

  /// 检查是否需要自动锁定
  void _checkAutoLock() {
    if (_pausedAt == null) return;

    final pausedDuration = DateTime.now().difference(_pausedAt!);
    debugPrint('应用恢复，后台时长: ${pausedDuration.inSeconds}秒');

    if (pausedDuration >= _autoLockDuration) {
      debugPrint('超过自动锁定时长，锁定应用');
      if (mounted) {
        context.read<AuthProvider>().lock();
      }
    }

    _pausedAt = null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('资产概览'),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () {},
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () => _showSettings(context),
          ),
        ],
      ),
      body: Consumer2<AssetProvider, CustomTypeProvider>(
        builder: (context, provider, customTypeProvider, _) {
          if (provider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (provider.error != null) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 48, color: Colors.red),
                  const SizedBox(height: 16),
                  Text(provider.error!),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: () => provider.loadAssets(),
                    child: const Text('重试'),
                  ),
                ],
              ),
            );
          }

          final customTypes = customTypeProvider.customTypes;
          final summary = provider.getSummaryWithCustomTypes(customTypes);

          return RefreshIndicator(
            onRefresh: () => provider.loadAssets(),
            child: CustomScrollView(
              slivers: [
                // 资产总览卡片
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: AssetSummaryCard(
                      summary: summary,
                      customTypes: customTypes,
                    ),
                  ),
                ),

                // 资产列表
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  sliver: provider.assets.isEmpty
                      ? SliverFillRemaining(
                          child: Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.account_balance_wallet_outlined,
                                  size: 64,
                                  color: Colors.grey[400],
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  '暂无资产',
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleMedium
                                      ?.copyWith(color: Colors.grey[600]),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  '点击右下角按钮添加您的第一个资产',
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodyMedium
                                      ?.copyWith(color: Colors.grey[500]),
                                ),
                              ],
                            ),
                          ),
                        )
                      : SliverList(
                          delegate: SliverChildBuilderDelegate(
                            (context, index) {
                              final asset = provider.assets[index];
                              return AssetListItem(
                                asset: asset,
                                onTap: () => _openAssetDetail(context, asset),
                                onEdit: () => _editAsset(context, asset),
                                onDelete: () => _deleteAsset(context, asset),
                              );
                            },
                            childCount: provider.assets.length,
                          ),
                        ),
                ),

                // 底部间距
                const SliverPadding(padding: EdgeInsets.only(bottom: 88)),
              ],
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _addAsset(context),
        icon: const Icon(Icons.add),
        label: const Text('添加资产'),
      ),
    );
  }

  void _addAsset(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => const AddAssetDialog(),
    );
  }

  void _editAsset(BuildContext context, Asset asset) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => AddAssetDialog(asset: asset),
    );
  }

  void _deleteAsset(BuildContext context, Asset asset) {
    final customTypes = context.read<CustomTypeProvider>().customTypes;
    final isLiability = asset.isLiabilityType(customTypes);
    final itemType = isLiability ? '负债' : '资产';
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('删除$itemType'),
        content: Text('确定要删除 "${asset.name}" 吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () async {
              final provider = context.read<AssetProvider>();
              await provider.deleteAsset(asset.id);
              if (context.mounted) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('$itemType已删除')),
                );
              }
            },
            child: const Text('删除'),
          ),
        ],
      ),
    );
  }

  void _openAssetDetail(BuildContext context, Asset asset) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AssetDetailScreen(assetId: asset.id),
      ),
    );
  }

  void _showSettings(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.lock),
              title: const Text('锁定应用'),
              onTap: () {
                Navigator.pop(context);
                context.read<AuthProvider>().lock();
              },
            ),
            ListTile(
              leading: const Icon(Icons.file_download),
              title: const Text('导出数据'),
              onTap: () {
                Navigator.pop(context);
                _exportData(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.file_upload),
              title: const Text('导入数据'),
              onTap: () {
                Navigator.pop(context);
                _importData(context);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _exportData(BuildContext context) async {
    // 1. 让用户输入密码确认
    final password = await _promptForPassword(context, '请输入密码以确认导出');
    if (password == null) return;

    // 2. 选择保存位置
    final outputPath = await FilePicker.platform.saveFile(
      dialogTitle: '选择导出文件保存位置',
      fileName: 'localfamily_asset_backup.zip',
      type: FileType.any,
    );

    if (outputPath == null || outputPath.isEmpty) {
      return;
    }

    // 3. 显示加载对话框
    if (!context.mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const AlertDialog(
        content: Row(
          children: [
            CircularProgressIndicator(),
            SizedBox(width: 16),
            Text('正在导出...'),
          ],
        ),
      ),
    );

    // 4. 执行导出
    try {
      final ffi = FfiBridge();
      final result = await ffi.exportData(
        password: password,
        outputPath: outputPath,
      );

      if (!context.mounted) return;
      Navigator.pop(context); // 关闭加载对话框

      if (result.containsKey('success')) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('导出成功：$outputPath'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('导出失败：${result['error']}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.pop(context); // 关闭加载对话框
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('导出异常：$e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _importData(BuildContext context) async {
    // 1. 让用户选择文件
    final result = await FilePicker.platform.pickFiles(
      dialogTitle: '选择导入文件',
      type: FileType.custom,
      allowedExtensions: ['zip'],
    );

    if (result == null || result.files.isEmpty) {
      return;
    }

    final inputPath = result.files.single.path;
    if (inputPath == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('无法获取文件路径'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // 2. 让用户输入密码确认
    final password = await _promptForPassword(context, '请输入密码以解密导入');
    if (password == null) return;

    // 3. 显示加载对话框
    if (!context.mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const AlertDialog(
        content: Row(
          children: [
            CircularProgressIndicator(),
            SizedBox(width: 16),
            Text('正在导入...'),
          ],
        ),
      ),
    );

    // 4. 执行导入
    try {
      final ffi = FfiBridge();
      final importResult = await ffi.importData(
        password: password,
        inputPath: inputPath,
      );

      if (!context.mounted) return;
      Navigator.pop(context); // 关闭加载对话框

      if (importResult.containsKey('success')) {
        // 重新加载资产数据
        await context.read<AssetProvider>().loadAssets();

        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('导入成功！数据已恢复'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('导入失败：${importResult['error']}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.pop(context); // 关闭加载对话框
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('导入异常：$e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// 密码输入对话框
  Future<String?> _promptForPassword(BuildContext context, String message) async {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('安全确认'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(message),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              obscureText: true,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: '密码',
                prefixIcon: Icon(Icons.lock),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () {
              if (controller.text.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('请输入密码')),
                );
                return;
              }
              Navigator.pop(context, controller.text);
            },
            child: const Text('确认'),
          ),
        ],
      ),
    );
  }
}
