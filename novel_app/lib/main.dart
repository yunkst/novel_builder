import 'package:flutter/material.dart';
import 'screens/bookshelf_screen.dart';
import 'screens/search_screen.dart';
import 'screens/settings_screen.dart';
import 'services/cache_manager.dart';
import 'services/api_service_wrapper.dart';

void main() async {
  // 确保 Flutter 初始化完成
  WidgetsFlutterBinding.ensureInitialized();

  // 初始化 API 服务
  try {
    await ApiServiceWrapper().init();
  } catch (e) {
    debugPrint('API 服务初始化失败: $e');
    // 继续运行，用户可以在设置中配置
  }

  runApp(const NovelReaderApp());
}

class NovelReaderApp extends StatelessWidget {
  const NovelReaderApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Novel App',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
            seedColor: Colors.blue, brightness: Brightness.light),
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
            seedColor: Colors.blue, brightness: Brightness.dark),
        useMaterial3: true,
      ),
      themeMode: ThemeMode.dark,
      home: const HomePage(),
      debugShowCheckedModeBanner: true,
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _selectedIndex = 0;
  final CacheManager _cacheManager = CacheManager();

  static const List<Widget> _pages = <Widget>[
    BookshelfScreen(),
    SearchScreen(),
    SettingsScreen(),
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // 标记应用活跃
    _cacheManager.setAppActive(true);

    // 应用启动时同步服务端缓存（异步执行，不阻塞UI）
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _cacheManager.syncOnAppStart();
    });
  }

  @override
  void dispose() {
    _cacheManager.setAppActive(false);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _pages[_selectedIndex],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: _onItemTapped,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.book),
            label: '书架',
          ),
          NavigationDestination(
            icon: Icon(Icons.search),
            label: '搜索',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings),
            label: '设置',
          ),
        ],
      ),
    );
  }
}
