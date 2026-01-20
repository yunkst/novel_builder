import 'package:flutter/material.dart';
import 'dart:async';
import 'screens/bookshelf_screen.dart';
import 'screens/search_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/illustration_debug_screen.dart';
import 'core/di/api_service_provider.dart';
import 'utils/video_cache_manager.dart';
import 'services/logger_service.dart';

void main() async {
  // 确保 Flutter 初始化完成
  WidgetsFlutterBinding.ensureInitialized();

  // 初始化日志服务
  await LoggerService.instance.init();

  // 启用详细的错误日志 - 全局错误处理器
  FlutterError.onError = (FlutterErrorDetails details) {
    final stackTrace = details.stack?.toString() ?? '';
    final error = 'Flutter Error: ${details.exception}';
    LoggerService.instance.e(error, stackTrace: stackTrace);
    debugPrint('=== $error ===');
    debugPrint('Stack trace: $stackTrace');
    debugPrint('Library: ${details.library}');
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
      LoggerService.instance.e('API Service Error: $e', stackTrace: stackTrace.toString());
      debugPrint('=== API Service Error ===');
      debugPrint('Exception: $e');
      debugPrint('Stack trace: $stackTrace');
      debugPrint('========================');

      // 继续运行，用户可以在设置中配置
    }

    runApp(const NovelReaderApp());
  }, (error, stackTrace) {
    LoggerService.instance.e('Unhandled Async Error: $error', stackTrace: stackTrace.toString());
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
          final stackTrace = errorDetails.stack?.toString() ?? '';
          LoggerService.instance.e(
            'Widget Error: ${errorDetails.exception}',
            stackTrace: stackTrace,
          );
          debugPrint('=== Widget Error ===');
          debugPrint('Exception: ${errorDetails.exception}');
          debugPrint('Stack: $stackTrace');
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

class _HomePageState extends State<HomePage> with WidgetsBindingObserver {
  int _selectedIndex = 0;

  // 为生图调试页面创建 GlobalKey，用于调用刷新方法
  final GlobalKey<State<StatefulWidget>> _debugScreenKey = GlobalKey();

  // 移除静态 _pages 列表，将在 build 方法中动态创建

  void _onItemTapped(int index) {
    setState(() {
      final previousIndex = _selectedIndex;
      _selectedIndex = index;

      // 当切换到生图调试页面（索引2）且之前不在该页面时，触发刷新
      if (index == 2 && previousIndex != 2) {
        _refreshIllustrationDebugScreen();
      }
    });
  }

  /// 刷新生图调试页面列表
  void _refreshIllustrationDebugScreen() {
    final debugScreenState = _debugScreenKey.currentState;
    if (debugScreenState != null) {
      // 通过动态调用刷新方法（不依赖具体类型）
      (debugScreenState as dynamic).refreshData?.call();
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    debugPrint('HomePage: 初始化并添加生命周期监听器');
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // 应用生命周期标记不再需要（CacheManager已删除）
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    // 应用退出时清理所有视频控制器
    VideoCacheManager.disposeAll();
    debugPrint('HomePage: 移除生命周期监听器并清理资源');
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    debugPrint('HomePage: 应用生命周期状态变化: $state');

    switch (state) {
      case AppLifecycleState.paused:
        // 应用进入后台时，暂停所有视频播放
        VideoCacheManager.pauseAllExcept(null);
        debugPrint('HomePage: 应用进入后台，暂停所有视频播放');
        break;
      case AppLifecycleState.resumed:
        // 应用恢复前台时，不自动恢复播放，让可见性检测器处理
        debugPrint('HomePage: 应用恢复前台');
        break;
      case AppLifecycleState.inactive:
        // 应用不活跃时，暂停所有视频播放
        VideoCacheManager.pauseAllExcept(null);
        debugPrint('HomePage: 应用变为不活跃，暂停所有视频播放');
        break;
      case AppLifecycleState.detached:
        // 应用分离时，清理所有视频控制器
        VideoCacheManager.disposeAll();
        debugPrint('HomePage: 应用分离，清理所有视频控制器');
        break;
      case AppLifecycleState.hidden:
        // 应用隐藏时，暂停所有视频播放
        VideoCacheManager.pauseAllExcept(null);
        debugPrint('HomePage: 应用隐藏，暂停所有视频播放');
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    // 定义页面列表，使用 IndexedStack 保持所有页面状态
    final List<Widget> pages = [
      const BookshelfScreen(),
      const SearchScreen(),
      IllustrationDebugScreen(key: _debugScreenKey),
      const SettingsScreen(),
    ];

    return Scaffold(
      body: IndexedStack(
        index: _selectedIndex,
        children: pages,
      ),
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
