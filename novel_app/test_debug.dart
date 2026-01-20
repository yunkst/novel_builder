import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:novel_app/screens/log_viewer_screen.dart';
import 'package:novel_app/services/logger_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Debug - 诊断日志加载问题', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    
    LoggerService.resetForTesting();
    await LoggerService.instance.init();
    
    print('=== After init ===');
    print('LoggerService logCount: ${LoggerService.instance.logCount}');
    
    // 添加100条日志
    for (int i = 0; i < 100; i++) {
      LoggerService.instance.i('Test log message $i');
    }
    
    print('=== After adding 100 logs ===');
    print('LoggerService logCount: ${LoggerService.instance.logCount}');
    final logs = LoggerService.instance.getLogs();
    print('getLogs() returned: ${logs.length} logs');
    
    await tester.pumpWidget(
      MaterialApp(home: const LogViewerScreen()),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    
    final cards = find.byType(Card);
    print('=== After pumping widget ===');
    print('Cards found: ${cards.evaluate().length}');
    
    // 列出所有Card的文本内容
    for (var card in cards.evaluate()) {
      final widget = card.widget as Card;
      print('Card widget: $widget');
    }
  });
}
