import 'package:flutter/material.dart';
import 'dify_settings_screen.dart';
import 'backend_settings_screen.dart';
import 'cache_management_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('设置'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: ListView(
        children: [
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
          ListTile(
            leading: const Icon(Icons.storage),
            title: const Text('缓存管理'),
            subtitle: const Text('查看和管理缓存任务'),
            trailing: const Icon(Icons.arrow_forward_ios),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const CacheManagementScreen(),
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
