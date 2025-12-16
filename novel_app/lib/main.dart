import 'package:flutter/material.dart';
import 'dart:async';
import 'screens/bookshelf_screen.dart';
import 'screens/search_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/illustration_debug_screen.dart';
import 'services/cache_manager.dart';
import 'core/di/api_service_provider.dart';

void main() async {
  // 确保 Flutter 初始化完成
  WidgetsFlutterBinding.ensureInitialized();

  // 启用详细的错误日志 - 全局错误处理器
  FlutterError.onError = (FlutterErrorDetails details) {
    debugPrint('=== Flutter Error ===');
    debugPrint('Exception: ${details.exception}');
    debugPrint('Stack trace: ${details.stack}');
    debugPrint('Library: ${details.library}');
    debugPrint('Context: ${details.context}');
    debugPrint('Information Collector: ${details.informationCollector}');
    debugPrint('==================');
  };

  // 设置平台错误处理
  // 注释掉PlatformDispatcher，因为某些Flutter版本不支持
  // PlatformDispatcher.instance.onError = (error, stack) {
  //   debugPrint('=== Platform Error ===');
  //   debugPrint('Error: $error');
  //   debugPrint('Stack trace: $stack');
  //   debugPrint('====================');
  //
  //   print('=== Platform Error (print) ===');
  //   print('Error: $error');
  //   print('Stack trace: $stack');
  //   print('==============================');
  //
  //   return true;
  // };

  // 捕获未处理的异步错误
  runZonedGuarded(() async {
    // 初始化 API 服务
    try {
      await ApiServiceProvider.initialize();
    } catch (e, stackTrace) {
      debugPrint('=== API Service Error ===');
      debugPrint('Exception: $e');
      debugPrint('Stack trace: $stackTrace');
      debugPrint('========================');

      // 继续运行，用户可以在设置中配置
    }

    runApp(const NovelReaderApp());
  }, (error, stackTrace) {
    debugPrint('=== Unhandled Async Error ===');
    debugPrint('Error: $error');
    debugPrint('Stack trace: $stackTrace');
    debugPrint('==============================');

  });
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
      builder: (context, child) {
        // 捕获并记录所有Widget错误
        ErrorWidget.builder = (FlutterErrorDetails errorDetails) {
          debugPrint('=== Widget Error ===');
          debugPrint('Exception: ${errorDetails.exception}');
          debugPrint('Stack: ${errorDetails.stack}');
          debugPrint('==================');
          return MaterialApp(
            home: Scaffold(
              appBar: AppBar(title: const Text('Error Occurred')),
              body: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error, size: 64, color: Colors.red),
                    const SizedBox(height: 16),
                    const Text('An error occurred. Check console for details.'),
                    const SizedBox(height: 8),
                    Text(
                      errorDetails.exception.toString(),
                      style: const TextStyle(fontSize: 12),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          );
        };
        return child!;
      },
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
    IllustrationDebugScreen(),
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
            icon: Icon(Icons.image),
            label: '生图调试',
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
