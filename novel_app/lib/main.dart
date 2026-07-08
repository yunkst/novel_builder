import 'package:flutter/material.dart';
import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'screens/bookshelf_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/webview_browser_screen.dart';
import 'screens/onboarding/onboarding_screen.dart';
import 'core/providers/service_providers.dart';
import 'core/providers/theme_provider.dart';
import 'core/providers/onboarding_providers.dart';
import 'core/providers/ui_providers.dart';
import 'core/providers/agent_scenario_provider.dart';
import 'core/theme/app_colors.dart';
import 'core/theme/app_typography.dart';
import 'utils/toast_utils.dart';
import 'services/logger_service.dart';
import 'services/llm_logger/llm_logger.dart';
import 'services/log_reporter_service.dart';
import 'services/novel_agent/agent_scenario.dart';
import 'widgets/agent_chat/agent_floating_button.dart';

void main() async {
  // 确保 Flutter 初始化完成
  WidgetsFlutterBinding.ensureInitialized();

  // 初始化日志服务
  await LoggerService.instance.init();
  LoggerService.instance.i(
    'LoggerService 初始化完成',
    category: LogCategory.general,
    tags: ['startup', 'logger'],
  );

  // 初始化 LLM 调用日志服务（拦截器在 llm_provider.dart 中调用，失败不阻塞）
  await LlmLogger.instance.initialize();
  LoggerService.instance.i(
    'LlmLogger 初始化完成',
    category: LogCategory.general,
    tags: ['startup', 'llm-logger'],
  );

  // 初始化日志上报服务（在 LoggerService 之后）
  try {
    await LogReporterService.instance.init();
    LoggerService.instance.i(
      'LogReporterService 初始化完成',
      category: LogCategory.general,
      tags: ['startup', 'log-reporter'],
    );
  } catch (e, stackTrace) {
    LoggerService.instance.e(
      'LogReporterService 初始化失败: $e',
      stackTrace: stackTrace.toString(),
      category: LogCategory.general,
      tags: ['startup', 'log-reporter', 'error'],
    );
  }

  // 启用详细的错误日志 - 全局错误处理器
  FlutterError.onError = (FlutterErrorDetails details) {
    final stackTrace = details.stack?.toString() ?? '';
    final error = 'Flutter Error: ${details.exception}';
    LoggerService.instance.e(
      error,
      stackTrace: stackTrace,
      category: LogCategory.general,
      tags: ['flutter-error', 'crash'],
    );
  };

  // 捕获未处理的异步错误
  runZonedGuarded(() async {
    // 初始化 API 服务 - 使用Provider容器
    final container = ProviderContainer();
    try {
      await container.read(apiServiceWrapperProvider).init();
    } catch (e, stackTrace) {
      LoggerService.instance.e(
        'API Service Error: $e',
        stackTrace: stackTrace.toString(),
        category: LogCategory.network,
        tags: ['api', 'service', 'error'],
      );

      // 继续运行，用户可以在设置中配置
    }

    runApp(UncontrolledProviderScope(
      container: container,
      child: const NovelReaderApp(),
    ));
  }, (error, stackTrace) {
    LoggerService.instance.e(
      'Unhandled Async Error: $error',
      stackTrace: stackTrace.toString(),
      category: LogCategory.general,
      tags: ['async', 'unhandled', 'error'],
    );
  });
}

class NovelReaderApp extends ConsumerWidget {
  const NovelReaderApp({super.key});

  /// 构建 Material 3 主题数据（统一 light/dark 两套 + loading/error 兜底）
  ///
  /// 亮/暗主题分别通过 [ThemeState] 提供（含 AppColors 扩展）；
  /// loading/error 兜底场景使用固定 dark 主题（同样注入 AppColors.dark），
  /// 保证 `context.appColors` 永远命中真实扩展而非兜底值。
  ThemeData _buildFallbackThemeData() {
    return ThemeData(
      colorScheme: ColorScheme.fromSeed(
        // 书馆美学种子色，与 ThemeState 默认一致，避免启动闪蓝
        seedColor: const Color(0xFFB8843A),
        brightness: Brightness.dark,
      ),
      useMaterial3: true,
      fontFamily: AppTypography.sans,
      fontFamilyFallback: AppTypography.sansFallback,
      extensions: const <ThemeExtension<dynamic>>[AppColors.dark],
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 监听主题提供者
    final themeAsync = ref.watch(themeNotifierProvider);

    // 系统主题下 Toast 颜色跟随平台亮度，保持与 MaterialApp 实际渲染一致
    final platformBrightness = MediaQuery.platformBrightnessOf(context);
    return themeAsync.when(
      data: (themeState) {
        final isLight = themeState.flutterThemeMode == ThemeMode.light ||
            (themeState.flutterThemeMode == ThemeMode.system &&
                platformBrightness == Brightness.light);
        // 同步主题色到 Toast 工具，使其能感知当前主题
        ToastUtils.setThemeColors(isLight ? AppColors.light : AppColors.dark);
        return MaterialApp(
          title: 'Novel App',
          theme: themeState.getLightTheme(),
          darkTheme: themeState.getDarkTheme(),
          themeMode: themeState.flutterThemeMode,
          home: const _AppRoot(),
          debugShowCheckedModeBanner: true,
          builder: (context, child) {
            // 捕获并记录所有Widget错误
            ErrorWidget.builder = (FlutterErrorDetails errorDetails) {
              final stackTrace = errorDetails.stack?.toString() ?? '';
              LoggerService.instance.e(
                'Widget Error: ${errorDetails.exception}',
                stackTrace: stackTrace,
                category: LogCategory.ui,
                tags: ['widget', 'error', 'crash'],
              );
              final theme = Theme.of(context);
              return MaterialApp(
                home: Scaffold(
                  appBar: AppBar(title: const Text('Error Occurred')),
                  body: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.error,
                            size: 64, color: context.appColors.error),
                        const SizedBox(height: 16),
                        const Text(
                            'An error occurred. Check console for details.'),
                        const SizedBox(height: 8),
                        Text(
                          errorDetails.exception.toString(),
                          style: theme.textTheme.bodySmall,
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
      },
      loading: () {
        // 加载中显示默认主题
        return MaterialApp(
          title: 'Novel App',
          theme: _buildFallbackThemeData(),
          home: const Center(
            child: CircularProgressIndicator(),
          ),
          debugShowCheckedModeBanner: true,
        );
      },
      error: (error, stack) {
        LoggerService.instance.e(
          '主题加载失败: $error',
          stackTrace: stack.toString(),
          category: LogCategory.ui,
          tags: ['theme', 'load', 'error'],
        );
        // 错误时显示错误信息
        return MaterialApp(
          title: 'Novel App',
          theme: _buildFallbackThemeData(),
          home: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error, size: 64, color: context.appColors.error),
                const SizedBox(height: 16),
                Text('主题加载失败: $error'),
                const SizedBox(height: 8),
                const Text('使用默认主题继续运行'),
              ],
            ),
          ),
          debugShowCheckedModeBanner: true,
        );
      },
    );
  }
}

/// 应用根 Widget，根据 Onboarding 状态决定显示引导页还是主页
class _AppRoot extends ConsumerWidget {
  const _AppRoot();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final onboardingAsync = ref.watch(onboardingNotifierProvider);

    return onboardingAsync.when(
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      data: (onboardingState) {
        if (onboardingState.onboardingCompleted) {
          return const HomePage();
        }
        return const OnboardingScreen();
      },
      error: (error, stack) {
        // 加载失败时直接进入主页
        LoggerService.instance.e(
          '加载 Onboarding 状态失败，直接进入主页: $error',
          stackTrace: stack.toString(),
          category: LogCategory.general,
          tags: ['onboarding', 'error', 'fallback'],
        );
        return const HomePage();
      },
    );
  }
}

class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> with WidgetsBindingObserver {
  /// 浏览器 Tab 索引（统一进 IndexedStack 后也用于场景切换判定）
  static const int _browserTabIndex = 1;

  void _onItemTapped(int index, WidgetRef ref) {
    // 更新 Tab 索引（单一真相源：homeTabIndexNotifierProvider）
    ref.read(homeTabIndexNotifierProvider.notifier).switchTo(index);

    // 根据当前 Tab 切换 AI Agent 场景：
    // 浏览器 Tab 用网页提取场景，其余 Tab 用写作场景。
    ref.read(currentAgentScenarioProvider.notifier).state =
        index == _browserTabIndex
            ? ScenarioIds.webviewExtract
            : ScenarioIds.writing;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    LoggerService.instance.i(
      'HomePage: 初始化并添加生命周期监听器',
      category: LogCategory.ui,
      tags: ['lifecycle', 'init'],
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // 应用生命周期标记不再需要（CacheManager已删除）
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    LoggerService.instance.i(
      'HomePage: 移除生命周期监听器并清理资源',
      category: LogCategory.ui,
      tags: ['lifecycle', 'dispose', 'cleanup'],
    );
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    LoggerService.instance.i(
      'HomePage: 应用生命周期状态变化: $state',
      category: LogCategory.ui,
      tags: ['lifecycle', 'state-change'],
    );

    switch (state) {
      case AppLifecycleState.paused:
        // 立即上报缓冲日志，避免丢失
        LogReporterService.instance.flush();
        break;
      case AppLifecycleState.resumed:
        // 应用恢复前台时，不自动恢复播放，让可见性检测器处理
        break;
      case AppLifecycleState.inactive:
        break;
      case AppLifecycleState.detached:
        break;
      case AppLifecycleState.hidden:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    // 监听外部 Tab 切换请求。
    // 用户点击底部导航时也会写回此 Provider，保持单一真相源。
    final selectedIndex = ref.watch(homeTabIndexNotifierProvider);

    // 响应外部/导航触发的 Tab 切换，执行副作用：
    // 切换 AI Agent 场景
    ref.listen<int>(homeTabIndexNotifierProvider, (previous, next) {
      if (previous == null || previous == next) return;
      ref.read(currentAgentScenarioProvider.notifier).state =
          next == _browserTabIndex
              ? ScenarioIds.webviewExtract
              : ScenarioIds.writing;
    });

    // 所有 Tab（含浏览器）统一使用 IndexedStack 保持状态：
    // 浏览器 Tab 此前每次切换都会销毁重建 WebView，导致浏览页面/历史丢失。
    // IndexedStack 会保留各 Tab 的 element 与 State，切换 Tab 不再销毁 WebView。
    return Scaffold(
      body: AgentFloatingShell(
        child: IndexedStack(
          index: selectedIndex,
          children: [
            const BookshelfScreen(),
            // active 标记当前浏览器是否可见：
            // 仅在可见时拦截系统返回手势，避免 offstage 状态下误拦截其他 Tab 的返回键。
            WebViewBrowserScreen(active: selectedIndex == _browserTabIndex),
            const SettingsScreen(),
          ],
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: selectedIndex,
        onDestinationSelected: (index) {
          _onItemTapped(index, ref);
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.book),
            label: '书架',
          ),
          NavigationDestination(
            icon: Icon(Icons.public),
            label: '浏览器',
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
