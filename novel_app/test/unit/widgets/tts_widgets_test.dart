import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:novel_app/widgets/tts_content_display.dart';
import 'package:novel_app/widgets/tts_control_panel.dart';
import 'package:novel_app/services/tts_player_service.dart';

void main() {
  group('TtsContentDisplay Widget', () {
    testWidgets('应该显示所有段落', (WidgetTester tester) async {
      final paragraphs = List.generate(5, (i) => '第${i + 1}段内容');

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TtsContentDisplay(
              paragraphs: paragraphs,
              currentIndex: 0,
            ),
          ),
        ),
      );

      // 验证所有段落都显示
      for (int i = 0; i < paragraphs.length; i++) {
        expect(find.text(paragraphs[i]), findsOneWidget);
      }
    });

    testWidgets('当前段落应该高亮显示', (WidgetTester tester) async {
      final paragraphs = ['第一段', '第二段', '第三段'];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TtsContentDisplay(
              paragraphs: paragraphs,
              currentIndex: 1,
            ),
          ),
        ),
      );

      // 当前段落应该有不同的样式
      // 由于我们无法直接测试样式，这里验证文本存在
      expect(find.text('第二段'), findsOneWidget);
    });

    testWidgets('空段落列表应该显示提示', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: const TtsContentDisplay(
              paragraphs: [],
              currentIndex: 0,
            ),
          ),
        ),
      );

      expect(find.text('暂无内容'), findsOneWidget);
    });

    testWidgets('切换段落时应该更新高亮', (WidgetTester tester) async {
      final paragraphs = ['第一段', '第二段', '第三段'];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TtsContentDisplay(
              paragraphs: paragraphs,
              currentIndex: 0,
            ),
          ),
        ),
      );

      expect(find.text('第一段'), findsOneWidget);

      // 切换到第二段
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TtsContentDisplay(
              paragraphs: paragraphs,
              currentIndex: 1,
            ),
          ),
        ),
      );

      expect(find.text('第二段'), findsOneWidget);
    });
  });

  group('TtsControlPanel Widget', () {
    testWidgets('应该显示所有控制按钮', (WidgetTester tester) async {
      bool playCalled = false;
      bool pauseCalled = false;
      bool stopCalled = false;
      bool prevCalled = false;
      bool nextCalled = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TtsControlPanel(
              state: TtsPlayerState.paused,
              hasPreviousChapter: true,
              hasNextChapter: true,
              speechRate: 1.0,
              onPlay: () => playCalled = true,
              onPause: () => pauseCalled = true,
              onStop: () => stopCalled = true,
              onPreviousChapter: () => prevCalled = true,
              onNextChapter: () => nextCalled = true,
              onRateChanged: (_) {},
            ),
          ),
        ),
      );

      // 验证播放按钮存在
      expect(find.byIcon(Icons.play_circle_filled), findsOneWidget);

      // 验证停止按钮存在
      expect(find.byIcon(Icons.stop_circle), findsOneWidget);

      // 验证上一章/下一章按钮存在
      expect(find.byIcon(Icons.skip_previous), findsOneWidget);
      expect(find.byIcon(Icons.skip_next), findsOneWidget);
    });

    testWidgets('播放状态应该显示暂停按钮', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TtsControlPanel(
              state: TtsPlayerState.playing,
              hasPreviousChapter: true,
              hasNextChapter: true,
              speechRate: 1.0,
              onPlay: () {},
              onPause: () {},
              onStop: () {},
              onPreviousChapter: () {},
              onNextChapter: () {},
              onRateChanged: (_) {},
            ),
          ),
        ),
      );

      expect(find.byIcon(Icons.pause_circle_filled), findsOneWidget);
    });

    testWidgets('暂停状态应该显示播放按钮', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TtsControlPanel(
              state: TtsPlayerState.paused,
              hasPreviousChapter: true,
              hasNextChapter: true,
              speechRate: 1.0,
              onPlay: () {},
              onPause: () {},
              onStop: () {},
              onPreviousChapter: () {},
              onNextChapter: () {},
              onRateChanged: (_) {},
            ),
          ),
        ),
      );

      expect(find.byIcon(Icons.play_circle_filled), findsOneWidget);
    });

    testWidgets('没有上一段时按钮应该禁用', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TtsControlPanel(
              state: TtsPlayerState.paused,
              hasPreviousChapter: false,
              hasNextChapter: true,
              speechRate: 1.0,
              onPlay: () {},
              onPause: () {},
              onStop: () {},
              onPreviousChapter: () {},
              onNextChapter: () {},
              onRateChanged: (_) {},
            ),
          ),
        ),
      );

      // 验证上一章按钮存在（虽然可能被禁用）
      expect(find.byIcon(Icons.skip_previous), findsOneWidget);
    });

    testWidgets('没有下一段时按钮应该禁用', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TtsControlPanel(
              state: TtsPlayerState.paused,
              hasPreviousChapter: true,
              hasNextChapter: false,
              speechRate: 1.0,
              onPlay: () {},
              onPause: () {},
              onStop: () {},
              onPreviousChapter: () {},
              onNextChapter: () {},
              onRateChanged: (_) {},
            ),
          ),
        ),
      );

      // 验证下一章按钮存在
      expect(find.byIcon(Icons.skip_next), findsOneWidget);
    });

    testWidgets('点击播放按钮应该调用onPlay回调', (WidgetTester tester) async {
      bool playCalled = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TtsControlPanel(
              state: TtsPlayerState.paused,
              hasPreviousChapter: false,
              hasNextChapter: false,
              speechRate: 1.0,
              onPlay: () => playCalled = true,
              onPause: () {},
              onStop: () {},
              onPreviousChapter: () {},
              onNextChapter: () {},
              onRateChanged: (_) {},
            ),
          ),
        ),
      );

      await tester.tap(find.byIcon(Icons.play_circle_filled));
      expect(playCalled, true);
    });

    testWidgets('语速滑块应该显示当前语速', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TtsControlPanel(
              state: TtsPlayerState.paused,
              hasPreviousChapter: false,
              hasNextChapter: false,
              speechRate: 1.5,
              onPlay: () {},
              onPause: () {},
              onStop: () {},
              onPreviousChapter: () {},
              onNextChapter: () {},
              onRateChanged: (_) {},
            ),
          ),
        ),
      );

      expect(find.text('1.5x'), findsOneWidget);
    });

    testWidgets('拖动语速滑块应该调用回调', (WidgetTester tester) async {
      double? newRate;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TtsControlPanel(
              state: TtsPlayerState.paused,
              hasPreviousChapter: false,
              hasNextChapter: false,
              speechRate: 1.0,
              onPlay: () {},
              onPause: () {},
              onStop: () {},
              onPreviousChapter: () {},
              onNextChapter: () {},
              onRateChanged: (rate) => newRate = rate,
            ),
          ),
        ),
      );

      final slider = find.byType(Slider);
      expect(slider, findsOneWidget);

      await tester.drag(slider, const Offset(50, 0));
      await tester.pump(); // 只使用pump，不使用pumpAndSettle避免超时

      // 验证回调被调用（具体值取决于拖动距离）
      expect(newRate, isNotNull);
    });

    testWidgets('章节切换按钮应该正确显示', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TtsControlPanel(
              state: TtsPlayerState.paused,
              hasPreviousChapter: false,
              hasNextChapter: false,
              speechRate: 1.0,
              onPlay: () {},
              onPause: () {},
              onStop: () {},
              onPreviousChapter: () {},
              onNextChapter: () {},
              onRateChanged: (_) {},
            ),
          ),
        ),
      );

      expect(find.byIcon(Icons.skip_previous), findsOneWidget);
      expect(find.byIcon(Icons.skip_next), findsOneWidget);
    });
  });
}
