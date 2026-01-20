import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'dify_settings_screen.dart';
import 'backend_settings_screen.dart';
import 'log_viewer_screen.dart';
import '../services/app_update_service.dart';
import '../widgets/app_update_dialog.dart';
import '../services/api_service_wrapper.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  PackageInfo? _packageInfo;
  bool _isCheckingUpdate = false;

  @override
  void initState() {
    super.initState();
    _loadPackageInfo();
  }

  Future<void> _loadPackageInfo() async {
    final info = await PackageInfo.fromPlatform();
    if (mounted) {
      setState(() {
        _packageInfo = info;
      });
    }
  }

  Future<void> _checkForUpdate() async {
    setState(() {
      _isCheckingUpdate = true;
    });

    try {
      final apiWrapper = ApiServiceWrapper();
      final updateService = AppUpdateService(apiWrapper: apiWrapper);

      final latestVersion = await updateService.checkForUpdate(forceCheck: true);

      if (mounted) {
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
          if (context.mounted) {
            await showAppUpdateDialog(
              context,
              version: latestVersion,
              updateService: updateService,
              isNewVersion: isNewVersion,
            );
          }
        } else {
          // 显示已是最新版本
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('当前已是最新版本')),
            );
          }
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isCheckingUpdate = false;
        });
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('检查更新失败: $e')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
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
            trailing: _isCheckingUpdate ? null : const Icon(Icons.arrow_forward_ios),
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
        ],
      ),
    );
  }
}
