import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';

import '../../providers/financial_provider.dart';
import '../../providers/asset_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/custom_type_provider.dart';
import '../../providers/theme_provider.dart';
import '../../core/ffi_bridge.dart';
import '../../core/file_dialogs.dart';
import '../auth/lock_screen.dart';
import '../asset_history_screen.dart';
import 'assets_tab_screen.dart';
import 'overview_tab_screen.dart';
import 'liabilities_tab_screen.dart';
import 'bulk_import_screen.dart';

/// 主导航屏幕 - 底部导航栏（三页签模式）
class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen>
    with WidgetsBindingObserver {
  // 默认显示总览（索引 1）
  int _currentIndex = 1;
  DateTime? _pausedAt;
  AuthStatus? _lastAuthStatus;

  // 从总览分布条目跳转资产页签时预设的类型筛选（null = 全部）及其指令序号
  String? _assetTabTypeFilter;
  int _filterCommandSeq = 0;
  static const Duration _autoLockDuration = Duration(minutes: 3);

  void _onTabTapped(int index) {
    setState(() {
      _currentIndex = index;
    });
  }

  /// 总览页跳转：切换页签并按需预设类型筛选（typeFilter 为 null 时显示全部）。
  /// 资产筛选通过"指令"下发给保活的资产页签，仅资产页签跳转时递增序号；
  /// 负债筛选为 Provider 状态，直接设置
  void _navigateFromOverview(int tabIndex, {String? typeFilter}) {
    setState(() {
      _currentIndex = tabIndex;
      if (tabIndex == 0) {
        _assetTabTypeFilter = typeFilter;
        _filterCommandSeq++;
      }
    });
    if (tabIndex == 2) {
      context.read<FinancialProvider>().setLiabilityTypeFilterById(typeFilter);
    }
  }

  // Tab 顺序：资产 → 总览 → 负债
  // 总览页的统计行与分布条目通过 onNavigateToTab 切换页签（可携带类型筛选）
  List<Widget> get _tabScreens => [
        AssetsTabScreen(
          initialTypeFilter: _assetTabTypeFilter,
          filterCommandSeq: _filterCommandSeq,
        ),
        OverviewTabScreen(onNavigateToTab: _navigateFromOverview),
        const LiabilitiesTabScreen(),
      ];

  static const List<String> _tabTitles = [
    '资产',
    '总览',
    '负债',
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // 加载数据
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _lastDueRefreshDate = DateTime.now();
      context.read<FinancialProvider>().loadFinancialRecords();
      context.read<CustomTypeProvider>().loadCustomTypes();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    switch (state) {
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
      case AppLifecycleState.hidden:
        // 应用进入后台/隐藏，记录时间
        _pausedAt = DateTime.now();
        debugPrint('应用进入后台，记录时间: $_pausedAt');
        break;
      case AppLifecycleState.resumed:
        // 应用恢复到前台，检查是否超时
        _checkAutoLock();
        // 跨天后到期提醒的"剩余天数"会失真，刷新一次（静默）
        if (_lastDueRefreshDate != null &&
            !DateUtils.isSameDay(_lastDueRefreshDate, DateTime.now())) {
          _refreshDueData();
        }
        break;
      case AppLifecycleState.inactive:
        // 应用处于非活动状态
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

  DateTime? _lastDueRefreshDate;

  /// 跨天恢复前台时刷新到期提醒等派生数据（未解锁时跳过）
  Future<void> _refreshDueData() async {
    final auth = context.read<AuthProvider>();
    if (!auth.isUnlocked) return;
    _lastDueRefreshDate = DateTime.now();
    try {
      await context.read<FinancialProvider>().refreshDueItems();
    } catch (e) {
      debugPrint('跨天刷新到期提醒失败（忽略）: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, authProvider, _) {
        // 退出账户（或锁定）后重新解锁：Provider 缓存已清空/需刷新，重新加载
        if (_lastAuthStatus == AuthStatus.locked &&
            authProvider.status == AuthStatus.unlocked) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            context.read<FinancialProvider>().loadFinancialRecords();
            context.read<CustomTypeProvider>().loadCustomTypes();
          });
        }
        _lastAuthStatus = authProvider.status;

        // 如果已锁定，显示锁定屏幕
        if (authProvider.status == AuthStatus.locked) {
          return const LockScreen();
        }

        return Scaffold(
          appBar: AppBar(
            title: Text(_tabTitles[_currentIndex]),
            actions: [
              IconButton(
                icon: const Icon(Icons.settings),
                onPressed: () => _showSettings(context),
              ),
            ],
          ),
          // IndexedStack 保活三个页签：切换不销毁重建，回退时保留滚动位置与筛选状态
          body: IndexedStack(
            index: _currentIndex,
            children: _tabScreens,
          ),
          bottomNavigationBar: NavigationBar(
            selectedIndex: _currentIndex,
            onDestinationSelected: _onTabTapped,
            destinations: const [
              NavigationDestination(
                icon: Icon(Icons.account_balance_wallet),
                selectedIcon: Icon(Icons.account_balance_wallet),
                label: '资产',
              ),
              NavigationDestination(
                icon: Icon(Icons.pie_chart),
                selectedIcon: Icon(Icons.pie_chart),
                label: '总览',
              ),
              NavigationDestination(
                icon: Icon(Icons.credit_card),
                selectedIcon: Icon(Icons.credit_card),
                label: '负债',
              ),
            ],
          ),
        );
      },
    );
  }

  void _showSettings(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (_) => SafeArea(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 主题切换
              Consumer<ThemeProvider>(
                builder: (context, themeProvider, _) {
                  final themeMode = themeProvider.themeMode;
                  final isDark = themeMode == ThemeMode.dark ||
                      (themeMode == ThemeMode.system &&
                          MediaQuery.of(context).platformBrightness ==
                              Brightness.dark);

                  return ListTile(
                    leading: Icon(isDark ? Icons.light_mode : Icons.dark_mode),
                    title: const Text('主题模式'),
                    subtitle: Text(_getThemeModeText(themeMode)),
                    trailing: Switch(
                      value: isDark,
                      onChanged: (_) {
                        themeProvider.toggleTheme();
                      },
                    ),
                  );
                },
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.history),
                title: const Text('操作记录'),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const AssetHistoryScreen(
                        assetId: null, // null = 显示全部操作记录
                      ),
                    ),
                  );
                },
              ),
            ListTile(
              leading: const Icon(Icons.lock),
              title: const Text('锁定应用'),
              onTap: () {
                Navigator.pop(context);
                context.read<AuthProvider>().lock();
              },
            ),
            ListTile(
              leading: const Icon(Icons.logout),
              title: const Text('退出账户'),
              subtitle: const Text('保存并清除内存中的解密数据，下次访问需重新输入密码'),
              onTap: () {
                Navigator.pop(context);
                _logout(context);
              },
            ),
              const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.password),
              title: const Text('修改密码'),
              onTap: () {
                Navigator.pop(context);
                _showChangePasswordDialog(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.settings_backup_restore),
              title: const Text('数据快照'),
              subtitle: const Text('自动备份加密数据库，数据异常时可一键恢复'),
              onTap: () {
                Navigator.pop(context);
                showDialog(
                  context: context,
                  builder: (_) => const _SnapshotsDialog(),
                );
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
                title: const Text('导入数据（整库备份恢复）'),
                onTap: () {
                  Navigator.pop(context);
                  _importData(context);
                },
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.table_view),
                title: const Text('CSV / Excel 批量导入'),
                subtitle: const Text('从表格文件批量添加资产与负债'),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const BulkImportScreen(),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 退出当前账户：清空明文缓存并清除 Rust 侧解密状态，回到锁屏
  void _logout(BuildContext context) {
    // 先清除各 Provider 的明文缓存，再触发状态切换（logout 内部为异步）
    context.read<AuthProvider>().logout();
    context.read<FinancialProvider>().clearAll();
    context.read<AssetProvider>().clear();
    context.read<CustomTypeProvider>().clear();
  }

  String _getThemeModeText(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.light:
        return '浅色';
      case ThemeMode.dark:
        return '深色';
      default:
        return '跟随系统';
    }
  }

  Future<void> _exportData(BuildContext context) async {
    // 1. 让用户输入密码确认
    final password = await _promptForPassword(context, '请输入密码以确认导出');
    if (password == null) return;

    // 2. 选择保存位置（桌面弹窗 / 移动端落应用目录）
    final outputPath = await pickExportPath();

    if (outputPath == null || outputPath.isEmpty) {
      return;
    }

    // 3. 显示加载对话框
    if (!context.mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    try {
      // 4. 调用 Rust Core 导出
      final ffi = FfiBridge();
      final resultMap = await ffi.exportData(
        password: password,
        outputPath: outputPath,
      );

      if (!context.mounted) return;
      Navigator.pop(context); // 关闭加载对话框

      if (resultMap['success'] == true) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('数据导出成功')),
        );
      } else {
        throw Exception(resultMap['error'] ?? '导出失败');
      }
    } catch (e) {
      if (!context.mounted) return;
      Navigator.pop(context); // 关闭加载对话框
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('导出失败: $e'),
          backgroundColor: Colors.red,
        ),
      );
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
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('无法获取文件路径'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // 2. 让用户输入密码
    if (!context.mounted) return;
    final password = await _promptForPassword(context, '请输入密码以解密数据');
    if (password == null) return;

    // 3. 显示加载对话框
    if (!context.mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    try {
      // 4. 调用 Rust Core 导入
      final ffi = FfiBridge();
      final resultMap = await ffi.importData(
        password: password,
        inputPath: inputPath,
      );

      if (!context.mounted) return;
      Navigator.pop(context); // 关闭加载对话框

      if (resultMap['success'] == true) {
        // 重新加载数据（先取 provider 再 await，避免多次跨 gap 使用 context）
        final financialProvider = context.read<FinancialProvider>();
        final customTypeProvider = context.read<CustomTypeProvider>();
        await financialProvider.loadFinancialRecords();
        await customTypeProvider.loadCustomTypes();

        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('数据导入成功，共导入 ${resultMap['imported']} 字节')),
        );
      } else {
        throw Exception(resultMap['error'] ?? '导入失败');
      }
    } catch (e) {
      if (!context.mounted) return;
      Navigator.pop(context); // 关闭加载对话框
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('导入失败: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<String?> _promptForPassword(BuildContext context, String title) async {
    final controller = TextEditingController();

    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Padding(
          padding: const EdgeInsets.all(8.0),
          child: TextField(
            controller: controller,
            obscureText: true,
            autofocus: true,
            decoration: const InputDecoration(
              hintText: '请输入密码',
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('确认'),
          ),
        ],
      ),
    );
  }

  /// 显示修改密码对话框
  void _showChangePasswordDialog(BuildContext context) {
    final oldPasswordController = TextEditingController();
    final newPasswordController = TextEditingController();
    final confirmPasswordController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    bool showOldPassword = true;
    bool showNewPassword = true;
    bool showConfirmPassword = true;

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setState) => Padding(
          // 键盘弹出时抬升对话框，避免输入框被遮挡
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          child: AlertDialog(
            title: const Text('修改密码'),
            content: SingleChildScrollView(
              child: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      controller: oldPasswordController,
                      obscureText: showOldPassword,
                      decoration: InputDecoration(
                        labelText: '当前密码',
                        hintText: '请输入当前密码（如忘记可留空）',
                        border: const OutlineInputBorder(),
                        suffixIcon: IconButton(
                          icon: Icon(showOldPassword
                              ? Icons.visibility_off
                              : Icons.visibility),
                          onPressed: () => setState(
                              () => showOldPassword = !showOldPassword),
                        ),
                      ),
                      validator: (value) {
                        // 允许为空（助记词恢复后使用）
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: newPasswordController,
                      obscureText: showNewPassword,
                      decoration: InputDecoration(
                        labelText: '新密码',
                        hintText: '请输入新密码',
                        border: const OutlineInputBorder(),
                        suffixIcon: IconButton(
                          icon: Icon(showNewPassword
                              ? Icons.visibility_off
                              : Icons.visibility),
                          onPressed: () => setState(
                              () => showNewPassword = !showNewPassword),
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return '请输入新密码';
                        }
                        if (value.length < 6) {
                          return '密码至少需要 6 个字符';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: confirmPasswordController,
                      obscureText: showConfirmPassword,
                      decoration: InputDecoration(
                        labelText: '确认新密码',
                        hintText: '请再次输入新密码',
                        border: const OutlineInputBorder(),
                        suffixIcon: IconButton(
                          icon: Icon(showConfirmPassword
                              ? Icons.visibility_off
                              : Icons.visibility),
                          onPressed: () => setState(
                              () => showConfirmPassword = !showConfirmPassword),
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return '请确认新密码';
                        }
                        if (value != newPasswordController.text) {
                          return '两次输入的密码不一致';
                        }
                        return null;
                      },
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('取消'),
              ),
              TextButton(
                onPressed: () async {
                  if (!formKey.currentState!.validate()) {
                    return;
                  }

                  final oldPassword = oldPasswordController.text.trim();
                  final newPassword = newPasswordController.text.trim();

                  // 显示加载状态
                  showDialog(
                    context: context,
                    barrierDismissible: false,
                    builder: (_) =>
                        const Center(child: CircularProgressIndicator()),
                  );

                  try {
                    final authProvider = context.read<AuthProvider>();
                    bool success = false;

                    // 如果输入了旧密码，使用 changePassword
                    if (oldPassword.isNotEmpty) {
                      success = await authProvider.changePassword(
                          oldPassword, newPassword);
                    } else {
                      // 否则使用 resetPassword（助记词恢复后）
                      success = await authProvider.resetPassword(newPassword);
                    }

                    if (!context.mounted) return;
                    Navigator.pop(context); // 关闭加载对话框
                    Navigator.pop(dialogContext); // 关闭修改密码对话框

                    if (success) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('密码修改成功')),
                      );
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('密码修改失败，请检查当前密码是否正确'),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                  } catch (e) {
                    if (!context.mounted) return;
                    Navigator.pop(context); // 关闭加载对话框
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('密码修改失败: $e'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                },
                child: const Text('确认'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 数据快照管理对话框：列出/创建/恢复加密库快照
class _SnapshotsDialog extends StatefulWidget {
  const _SnapshotsDialog();

  @override
  State<_SnapshotsDialog> createState() => _SnapshotsDialogState();
}

class _SnapshotsDialogState extends State<_SnapshotsDialog> {
  final FfiBridge _ffi = FfiBridge();
  late Future<List<SnapshotInfo>> _snapshots;
  bool _creating = false;
  String? _restoring;

  @override
  void initState() {
    super.initState();
    _snapshots = _ffi.listSnapshots();
  }

  void _reload() {
    setState(() {
      _snapshots = _ffi.listSnapshots();
    });
  }

  Future<void> _create() async {
    setState(() => _creating = true);
    await _ffi.createSnapshot();
    if (!mounted) return;
    _reload();
  }

  Future<void> _confirmRestore(SnapshotInfo info) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('恢复快照'),
        content: Text('确定恢复到 ${_formatTime(info.timestamp)} 的快照吗？\n\n'
            '附件照片将一并恢复到该时点；恢复前会先为当前数据'
            '自动创建一份快照，该快照之后发生的改动将会丢失。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red[400]),
            child: const Text('恢复'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;
    setState(() => _restoring = info.name);
    final ok = await _ffi.restoreSnapshot(info.name);
    if (!mounted) return;
    setState(() => _restoring = null);

    if (ok) {
      // 内存库已由 Rust 端从磁盘重载，刷新界面数据
      context.read<FinancialProvider>().loadFinancialRecords();
      context.read<CustomTypeProvider>().loadCustomTypes();
      // 先取 messenger 再关对话框，避免 pop 后 context 失效
      final messenger = ScaffoldMessenger.of(context);
      Navigator.of(context).pop();
      messenger.showSnackBar(
        const SnackBar(content: Text('已恢复到所选快照')),
      );
    }
  }

  String _formatTime(int seconds) {
    final dt = DateTime.fromMillisecondsSinceEpoch(seconds * 1000);
    final mm = dt.month.toString().padLeft(2, '0');
    final dd = dt.day.toString().padLeft(2, '0');
    final hh = dt.hour.toString().padLeft(2, '0');
    final mi = dt.minute.toString().padLeft(2, '0');
    return '${dt.year}-$mm-$dd $hh:$mi';
  }

  String _formatSize(int bytes) {
    if (bytes >= 1048576) return '${(bytes / 1048576).toStringAsFixed(1)} MB';
    return '${(bytes / 1024).toStringAsFixed(0)} KB';
  }

  String _subtitleOf(SnapshotInfo info) {
    if (info.attachmentFiles > 0) {
      return '${_formatSize(info.size)} · 附件 ${info.attachmentFiles} 个'
          '（${_formatSize(info.attachmentsSize)}）';
    }
    return _formatSize(info.size);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('数据快照'),
      content: SizedBox(
        width: 400,
        height: 360,
        child: FutureBuilder<List<SnapshotInfo>>(
          future: _snapshots,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            final list = snapshot.data ?? const <SnapshotInfo>[];
            if (list.isEmpty) {
              return Center(
                child: Text(
                  '暂无快照\n每天首次保存和导入/改密前会自动创建',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Colors.grey[600],
                      ),
                ),
              );
            }
            return ListView.builder(
              itemCount: list.length,
              itemBuilder: (context, index) {
                final info = list[index];
                final busy = _restoring == info.name;
                return ListTile(
                  dense: true,
                  leading: const Icon(Icons.backup_outlined),
                  title: Text(_formatTime(info.timestamp)),
                  subtitle: Text(_subtitleOf(info)),
                  trailing: busy
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : TextButton(
                          onPressed: () => _confirmRestore(info),
                          child: const Text('恢复'),
                        ),
                );
              },
            );
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: _creating ? null : _create,
          child: Text(_creating ? '创建中…' : '立即创建快照'),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('关闭'),
        ),
      ],
    );
  }
}
