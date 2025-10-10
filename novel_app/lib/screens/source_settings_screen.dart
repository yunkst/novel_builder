import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/crawlers/crawler_factory.dart';
import '../services/crawlers/base_crawler.dart';

class SourceSettingsScreen extends StatefulWidget {
  const SourceSettingsScreen({super.key});

  @override
  State<SourceSettingsScreen> createState() => _SourceSettingsScreenState();
}

class _SourceSettingsScreenState extends State<SourceSettingsScreen> {
  final CrawlerFactory _factory = CrawlerFactory();
  late List<BaseCrawler> _crawlers;
  Set<String> _enabledHosts = {};
  bool _isLoading = true;

  static const String _prefsKey = 'enabled_sources';

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    setState(() => _isLoading = true);
    _crawlers = _factory.registered;
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getStringList(_prefsKey);
    if (saved == null || saved.isEmpty) {
      // 默认启用全部站点
      _enabledHosts = _crawlers
          .map((c) => Uri.parse(c.baseUrl).host)
          .toSet();
      await prefs.setStringList(_prefsKey, _enabledHosts.toList());
    } else {
      _enabledHosts = saved.toSet();
    }
    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _toggleHost(String host, bool enabled) async {
    setState(() {
      if (enabled) {
        _enabledHosts.add(host);
      } else {
        _enabledHosts.remove(host);
      }
    });
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_prefsKey, _enabledHosts.toList());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('源站点配置'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView.separated(
              itemCount: _crawlers.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final crawler = _crawlers[index];
                final uri = Uri.parse(crawler.baseUrl);
                final host = uri.host;
                final enabled = _enabledHosts.contains(host);
                return SwitchListTile(
                  title: Text(host),
                  subtitle: Text(crawler.baseUrl),
                  value: enabled,
                  onChanged: (v) => _toggleHost(host, v),
                  secondary: const Icon(Icons.language),
                );
              },
            ),
    );
  }
}