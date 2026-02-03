import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'dify_settings_screen.dart';
import 'backend_settings_screen.dart';
import 'log_viewer_screen.dart';
import '../services/app_update_service.dart';
import '../widgets/app_update_dialog.dart';
import '../utils/toast_utils.dart';
import '../core/providers/theme_provider.dart';
import '../core/providers/service_providers.dart';
import '../widgets/backup_confirm_dialog.dart';
import '../widgets/backup_progress_dialog.dart';
import '../utils/format_utils.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  PackageInfo? _packageInfo;
  bool _isCheckingUpdate = false;
  String? _lastBackupTime;

  @override
  void initState() {
    super.initState();
    _loadPackageInfo();
    _loadLastBackupTime();
  }

  Future<void> _loadPackageInfo() async {
    final info = await PackageInfo.fromPlatform();
    if (mounted) {
      setState(() {
        _packageInfo = info;
      });
    }
  }

  /// 加载上次备份时间
  Future<void> _loadLastBackupTime() async {
    final backupService = ref.read(backupServiceProvider);
    final timeText = await backupService.getLastBackupTimeText();
    if (mounted) {
      setState(() {
        _lastBackupTime = timeText;
      });
    }
  }

  Future<void> _checkForUpdate() async {
    setState(() {
      _isCheckingUpdate = true;
    });

    try {
      final apiWrapper = ref.read(apiServiceWrapperProvider);
      final updateService = AppUpdateService(apiWrapper: apiWrapper);

      final latestVersion =
          await updateService.checkForUpdate(forceCheck: true);

      if (!mounted) return;

      setState(() {
        _isCheckingUpdate = false;
      });

      if (latestVersion != null) {
        // 比较当前版本和最新版本
        final currentInfo = await PackageInfo.fromPlatform();
        final isNewVersion = updateService.hasNewVersion(
          currentInfo.version,
          latestVersion.version,
        );

        // 显示更新对话框
        if (mounted) {
          await showAppUpdateDialog(
            context,
            version: latestVersion,
            updateService: updateService,
            isNewVersion: isNewVersion,
          );
        }
      } else {
        // 显示已是最新版本
        if (mounted) {
          ToastUtils.show('当前已是最新版本');
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isCheckingUpdate = false;
        });
        if (mounted) {
          ToastUtils.showError('检查更新失败: $e');
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // 监听主题提供者
    final themeAsync = ref.watch(themeNotifierProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('设置'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: ListView(
        children: [
          // 版本信息
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: const Text('关于应用'),
            subtitle: Text(
              _packageInfo != null
                  ? '版本 ${_packageInfo!.version} (${_packageInfo!.buildNumber})'
                  : '加载中...',
            ),
          ),
          const Divider(),

          // 检查更新
          ListTile(
            leading: _isCheckingUpdate
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.system_update_alt),
            title: const Text('检查更新'),
            subtitle: const Text('查看是否有新版本可用'),
            trailing:
                _isCheckingUpdate ? null : const Icon(Icons.arrow_forward_ios),
            onTap: _isCheckingUpdate ? null : _checkForUpdate,
          ),
          const Divider(),

          ListTile(
            leading: const Icon(Icons.settings_ethernet),
            title: const Text('后端服务配置'),
            subtitle: const Text('设置后端 HOST 与 TOKEN'),
            trailing: const Icon(Icons.arrow_forward_ios),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const BackendSettingsScreen(),
                ),
              );
            },
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.cloud_queue),
            title: const Text('Dify 配置'),
            subtitle: const Text('配置 Dify API 连接信息'),
            trailing: const Icon(Icons.arrow_forward_ios),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const DifySettingsScreen(),
                ),
              );
            },
          ),
          const Divider(),

          // 主题模式设置
          themeAsync.when(
            data: (themeState) {
              return ListTile(
                leading: const Icon(Icons.palette_outlined),
                title: const Text('主题模式'),
                subtitle: Text(_getThemeModeText(themeState.themeMode)),
                trailing: const Icon(Icons.arrow_forward_ios),
                onTap: () => _showThemeModeDialog(themeState),
              );
            },
            loading: () => const ListTile(
              leading: Icon(Icons.palette_outlined),
              title: Text('主题模式'),
              subtitle: Text('加载中...'),
            ),
            error: (_, __) => const ListTile(
              leading: Icon(Icons.palette_outlined),
              title: Text('主题模式'),
              subtitle: Text('加载失败'),
            ),
          ),
          const Divider(),

          // 应用日志入口
          ListTile(
            leading: const Icon(Icons.bug_report_outlined),
            title: const Text('应用日志'),
            subtitle: const Text('查看、复制或清空应用日志'),
            trailing: const Icon(Icons.arrow_forward_ios),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const LogViewerScreen(),
                ),
              );
            },
          ),
          const Divider(),

          // 数据备份入口
          ListTile(
            leading: const Icon(Icons.backup_rounded),
            title: const Text('数据备份'),
            subtitle: Text(_lastBackupTime != null
                ? '上次备份: $_lastBackupTime'
                : '将数据库备份到服务器'),
            trailing: const Icon(Icons.arrow_forward_ios),
            onTap: _handleBackup,
          ),
          const Divider(),
        ],
      ),
    );
  }

  /// 获取主题模式显示文本
  String _getThemeModeText(AppThemeMode mode) {
    switch (mode) {
      case AppThemeMode.light:
        return '亮色模式';
      case AppThemeMode.dark:
        return '暗色模式';
      case AppThemeMode.system:
        return '跟随系统';
    }
  }

  /// 显示主题模式选择对话框
  void _showThemeModeDialog(ThemeState themeState) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('选择主题模式'),
          content: StatefulBuilder(
            builder: (BuildContext context, StateSetter setState) {
              return RadioGroup<AppThemeMode>(
                groupValue: themeState.themeMode,
                onChanged: (AppThemeMode? value) {
                  if (value != null) {
                    ref
                        .read(themeNotifierProvider.notifier)
                        .setThemeMode(value);
                    Navigator.pop(context);
                  }
                },
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    RadioListTile<AppThemeMode>(
                      title: const Text('亮色模式'),
                      subtitle: const Text('使用浅色主题'),
                      value: AppThemeMode.light,
                    ),
                    RadioListTile<AppThemeMode>(
                      title: const Text('暗色模式'),
                      subtitle: const Text('使用深色主题'),
                      value: AppThemeMode.dark,
                    ),
                    RadioListTile<AppThemeMode>(
                      title: const Text('跟随系统'),
                      subtitle: const Text('跟随系统设置自动切换'),
                      value: AppThemeMode.system,
                    ),
                  ],
                ),
              );
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('取消'),
            ),
          ],
        );
      },
    );
  }

  /// 处理数据备份
  Future<void> _handleBackup() async {
    try {
      final backupService = ref.read(backupServiceProvider);

      // 获取数据库文件
      final dbFile = await backupService.getDatabaseFile();
      final fileSize = await dbFile.length();
      final fileName = dbFile.path.split('/').last;
      final fileSizeText = FormatUtils.formatFileSize(fileSize);

      // 显示确认对话框
      if (!mounted) return;
      final confirmed = await BackupConfirmDialog.show(
        context: context,
        fileName: fileName,
        fileSize: fileSizeText,
      );

      if (!confirmed) return;

      // 显示进度对话框并执行上传
      if (!mounted) return;
      final result = await BackupProgressDialog.show(
        context: context,
        uploadTask: () => backupService.uploadBackup(
          dbFile: dbFile,
          onProgress: (sent, total) {
            // 进度回调会在ProgressDialog内部处理
          },
        ),
      );

      if (result != null && mounted) {
        // 上传成功
        ToastUtils.show('备份成功: ${result.storedName}');
        // 刷新备份时间
        _loadLastBackupTime();
      }
    } catch (e) {
      if (mounted) {
        ToastUtils.show('备份失败: $e');
      }
    }
  }
}
