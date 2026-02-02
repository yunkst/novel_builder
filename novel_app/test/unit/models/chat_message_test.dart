import 'package:flutter_test/flutter_test.dart';
import 'package:novel_app/models/chat_message.dart';
import 'package:novel_app/models/character.dart';
import '../../test_bootstrap.dart';

/// ChatMessage模型单元测试
///
/// 测试重点:
/// 1. 构造函数和字段验证
/// 2. 工厂方法 (narration, dialogue, userAction, userSpeech)
/// 3. copyWith方法的正确性
/// 4. toString方法
/// 5. 时间戳处理
/// 6. 边界情况和特殊字符
void main() {
  // 初始化测试环境
  initTests();
  group('ChatMessage模型 - 基础功能测试', () {
    group('构造函数和字段', () {
      test('测试1: 应该正确创建ChatMessage实例', () {
        final now = DateTime.now();
        final character = Character(
          id: 1,
          novelUrl: 'https://example.com/novel',
          name: '测试角色',
        );

        final message = ChatMessage(
          type: 'dialogue',
          content: '你好',
          character: character,
          isUser: false,
          timestamp: now,
        );

        expect(message.type, 'dialogue');
        expect(message.content, '你好');
        expect(message.character, character);
        expect(message.isUser, false);
        expect(message.timestamp, now);
      });

      test('测试2: 应该支持空content', () {
        final message = ChatMessage(
          type: 'narration',
          content: '',
        );

        expect(message.content, '');
        expect(message.type, 'narration');
      });

      test('测试3: 默认timestamp应该是当前时间', () {
        final beforeCreate = DateTime.now();
        final message = ChatMessage(
          type: 'narration',
          content: '测试',
        );
        final afterCreate = DateTime.now();

        expect(
          message.timestamp.isAfter(beforeCreate) ||
          message.timestamp.isAtSameMomentAs(beforeCreate),
          true,
        );
        expect(
          message.timestamp.isBefore(afterCreate) ||
          message.timestamp.isAtSameMomentAs(afterCreate),
          true,
        );
      });

      test('测试4: 默认isUser应该是false', () {
        final message = ChatMessage(
          type: 'dialogue',
          content: '测试',
        );

        expect(message.isUser, false);
      });

      test('测试5: character可以为null', () {
        final message = ChatMessage(
          type: 'narration',
          content: '旁白内容',
          character: null,
        );

        expect(message.character, null);
      });
    });

    group('工厂方法 - narration', () {
      test('测试6: narration工厂方法应该创建旁白消息', () {
        final message = ChatMessage.narration('这是旁白内容');

        expect(message.type, 'narration');
        expect(message.content, '这是旁白内容');
        expect(message.isUser, false);
        expect(message.character, null);
      });

      test('测试7: narration应该支持空字符串', () {
        final message = ChatMessage.narration('');

        expect(message.type, 'narration');
        expect(message.content, '');
      });

      test('测试8: narration应该支持特殊字符', () {
        final specialContent = '包含\n换行符\t制表符和"引号"\'单引号\'';
        final message = ChatMessage.narration(specialContent);

        expect(message.content, specialContent);
        expect(message.content, contains('\n'));
        expect(message.content, contains('"'));
      });

      test('测试9: narration应该支持长文本', () {
        final longContent = '长文本' * 1000;
        final message = ChatMessage.narration(longContent);

        expect(message.content.length, greaterThanOrEqualTo(3000));
        expect(message.content, longContent);
      });

      test('测试10: narration应该自动生成timestamp', () {
        final beforeCreate = DateTime.now();
        final message = ChatMessage.narration('测试');
        final afterCreate = DateTime.now();

        expect(
          message.timestamp.isAfter(beforeCreate) ||
          message.timestamp.isAtSameMomentAs(beforeCreate),
          true,
        );
        expect(
          message.timestamp.isBefore(afterCreate) ||
          message.timestamp.isAtSameMomentAs(afterCreate),
          true,
        );
      });
    });

    group('工厂方法 - dialogue', () {
      test('测试11: dialogue工厂方法应该创建对话消息', () {
        final character = Character(
          id: 1,
          novelUrl: 'https://example.com/novel',
          name: '角色A',
        );

        final message = ChatMessage.dialogue('你好', character);

        expect(message.type, 'dialogue');
        expect(message.content, '你好');
        expect(message.character, character);
        expect(message.isUser, false);
      });

      test('测试12: dialogue应该包含正确的角色信息', () {
        final character = Character(
          id: 123,
          novelUrl: 'https://example.com/novel',
          name: '李明',
          gender: '男',
          age: 25,
        );

        final message = ChatMessage.dialogue('测试对话', character);

        expect(message.character?.name, '李明');
        expect(message.character?.id, 123);
        expect(message.character?.gender, '男');
      });

      test('测试13: dialogue应该支持空字符串', () {
        final character = Character(
          id: 1,
          novelUrl: 'https://example.com/novel',
          name: '角色',
        );

        final message = ChatMessage.dialogue('', character);

        expect(message.content, '');
        expect(message.type, 'dialogue');
      });

      test('测试14: dialogue应该支持特殊字符', () {
        final character = Character(
          id: 1,
          novelUrl: 'https://example.com/novel',
          name: '角色',
        );

        final specialContent = '表情符号: 🎉✨🎊';
        final message = ChatMessage.dialogue(specialContent, character);

        expect(message.content, specialContent);
        expect(message.content, contains('🎉'));
      });

      test('测试15: dialogue应该自动生成timestamp', () {
        final character = Character(
          id: 1,
          novelUrl: 'https://example.com/novel',
          name: '角色',
        );

        final beforeCreate = DateTime.now();
        final message = ChatMessage.dialogue('测试', character);
        final afterCreate = DateTime.now();

        expect(
          message.timestamp.isAfter(beforeCreate) ||
          message.timestamp.isAtSameMomentAs(beforeCreate),
          true,
        );
        expect(
          message.timestamp.isBefore(afterCreate) ||
          message.timestamp.isAtSameMomentAs(afterCreate),
          true,
        );
      });
    });

    group('工厂方法 - userAction', () {
      test('测试16: userAction工厂方法应该创建用户行为消息', () {
        final message = ChatMessage.userAction('举起酒杯');

        expect(message.type, 'user_action');
        expect(message.content, '举起酒杯');
        expect(message.isUser, true);
        expect(message.character, null);
      });

      test('测试17: userAction应该支持空字符串', () {
        final message = ChatMessage.userAction('');

        expect(message.type, 'user_action');
        expect(message.content, '');
        expect(message.isUser, true);
      });

      test('测试18: userAction应该支持特殊字符', () {
        final specialAction = '微笑着说："你好！"\n然后挥手';
        final message = ChatMessage.userAction(specialAction);

        expect(message.content, specialAction);
        expect(message.content, contains('"'));
        expect(message.content, contains('\n'));
      });

      test('测试19: userAction应该支持长文本', () {
        final longAction = '行为描述' * 200;
        final message = ChatMessage.userAction(longAction);

        expect(message.content.length, greaterThanOrEqualTo(800));
        expect(message.content, longAction);
      });
    });

    group('工厂方法 - userSpeech', () {
      test('测试20: userSpeech工厂方法应该创建用户对话消息', () {
        final message = ChatMessage.userSpeech('你好，我是用户');

        expect(message.type, 'user_speech');
        expect(message.content, '你好，我是用户');
        expect(message.isUser, true);
        expect(message.character, null);
      });

      test('测试21: userSpeech应该支持空字符串', () {
        final message = ChatMessage.userSpeech('');

        expect(message.type, 'user_speech');
        expect(message.content, '');
        expect(message.isUser, true);
      });

      test('测试22: userSpeech应该支持多行文本', () {
        final multiLineSpeech = '''第一行
第二行
第三行''';
        final message = ChatMessage.userSpeech(multiLineSpeech);

        expect(message.content, multiLineSpeech);
        expect(message.content, contains('\n'));
      });

      test('测试23: userSpeech应该支持表情符号', () {
        final speechWithEmoji = '你好！😊 今天天气真好 ☀️';
        final message = ChatMessage.userSpeech(speechWithEmoji);

        expect(message.content, speechWithEmoji);
        expect(message.content, contains('😊'));
      });
    });

    group('copyWith方法测试', () {
      test('测试24: copyWith不传参数应该创建相同副本', () {
        final character = Character(
          id: 1,
          novelUrl: 'https://example.com/novel',
          name: '角色',
        );
        final original = ChatMessage(
          type: 'dialogue',
          content: '原始内容',
          character: character,
          isUser: false,
          timestamp: DateTime(2025, 1, 1),
        );

        final copy = original.copyWith();

        expect(copy.type, original.type);
        expect(copy.content, original.content);
        expect(copy.character, original.character);
        expect(copy.isUser, original.isUser);
        expect(copy.timestamp, original.timestamp);
      });

      test('测试25: copyWith应该可以修改type', () {
        final original = ChatMessage.narration('原始');
        final updated = original.copyWith(type: 'dialogue');

        expect(updated.type, 'dialogue');
        expect(original.type, 'narration');
        expect(updated.content, original.content);
      });

      test('测试26: copyWith应该可以修改content', () {
        final original = ChatMessage.narration('原始内容');
        final updated = original.copyWith(content: '新内容');

        expect(updated.content, '新内容');
        expect(original.content, '原始内容');
        expect(updated.type, original.type);
      });

      test('测试27: copyWith应该可以修改character', () {
        final character1 = Character(
          id: 1,
          novelUrl: 'https://example.com/novel',
          name: '角色A',
        );
        final character2 = Character(
          id: 2,
          novelUrl: 'https://example.com/novel',
          name: '角色B',
        );

        final original = ChatMessage.dialogue('测试', character1);
        final updated = original.copyWith(character: character2);

        expect(updated.character?.name, '角色B');
        expect(original.character?.name, '角色A');
        expect(updated.content, original.content);
      });

      test('测试28: copyWith应该可以修改isUser', () {
        final original = ChatMessage.userSpeech('测试');
        final updated = original.copyWith(isUser: false);

        expect(updated.isUser, false);
        expect(original.isUser, true);
        expect(updated.type, original.type);
      });

      test('测试29: copyWith应该可以修改timestamp', () {
        final original = ChatMessage.narration('测试');
        final newTimestamp = DateTime(2025, 6, 15, 10, 30);
        final updated = original.copyWith(timestamp: newTimestamp);

        expect(updated.timestamp, newTimestamp);
        expect(original.timestamp, isNot(newTimestamp));
      });

      test('测试30: copyWith应该可以同时修改多个字段', () {
        final character1 = Character(
          id: 1,
          novelUrl: 'https://example.com/novel',
          name: '角色A',
        );
        final character2 = Character(
          id: 2,
          novelUrl: 'https://example.com/novel',
          name: '角色B',
        );

        final original = ChatMessage.dialogue('原始', character1);
        final newTimestamp = DateTime(2025, 6, 15);
        final updated = original.copyWith(
          content: '新内容',
          character: character2,
          timestamp: newTimestamp,
        );

        expect(updated.content, '新内容');
        expect(updated.character?.name, '角色B');
        expect(updated.timestamp, newTimestamp);
        expect(updated.type, original.type);
        expect(original.content, '原始');
      });

      test('测试31: copyWith应该正确处理null参数', () {
        final character = Character(
          id: 1,
          novelUrl: 'https://example.com/novel',
          name: '角色',
        );

        final original = ChatMessage.dialogue('测试', character);
        final updated = original.copyWith(
          character: null,
          content: null,
        );

        expect(updated.character, null);
        expect(updated.content, '测试'); // null参数保持原值
      });
    });

    group('toString方法测试', () {
      test('测试32: toString应该包含type和content', () {
        final message = ChatMessage.narration('这是测试内容');

        final str = message.toString();

        expect(str, contains('type: narration'));
        expect(str, contains('content: 这是测试内容'));
      });

      test('测试33: toString应该包含isUser信息', () {
        final userMessage = ChatMessage.userSpeech('用户消息');
        final aiMessage = ChatMessage.narration('AI消息');

        expect(userMessage.toString(), contains('isUser: true'));
        expect(aiMessage.toString(), contains('isUser: false'));
      });

      test('测试34: toString应该显示dialogue类型', () {
        final character = Character(
          id: 1,
          novelUrl: 'https://example.com/novel',
          name: '角色',
        );
        final message = ChatMessage.dialogue('对话内容', character);

        final str = message.toString();

        expect(str, contains('type: dialogue'));
        expect(str, contains('content: 对话内容'));
      });

      test('测试35: toString应该显示user_action类型', () {
        final message = ChatMessage.userAction('用户行为');

        final str = message.toString();

        expect(str, contains('type: user_action'));
        expect(str, contains('content: 用户行为'));
      });

      test('测试36: toString应该显示user_speech类型', () {
        final message = ChatMessage.userSpeech('用户对话');

        final str = message.toString();

        expect(str, contains('type: user_speech'));
        expect(str, contains('content: 用户对话'));
      });
    });

    group('消息类型常量测试', () {
      test('测试37: narration类型常量应该正确', () {
        final message = ChatMessage.narration('测试');
        expect(message.type, 'narration');
      });

      test('测试38: dialogue类型常量应该正确', () {
        final character = Character(
          id: 1,
          novelUrl: 'https://example.com/novel',
          name: '角色',
        );
        final message = ChatMessage.dialogue('测试', character);
        expect(message.type, 'dialogue');
      });

      test('测试39: user_action类型常量应该正确', () {
        final message = ChatMessage.userAction('测试');
        expect(message.type, 'user_action');
      });

      test('测试40: user_speech类型常量应该正确', () {
        final message = ChatMessage.userSpeech('测试');
        expect(message.type, 'user_speech');
      });
    });

    group('用户消息标识测试', () {
      test('测试41: 用户行为消息应该标识为用户消息', () {
        final message = ChatMessage.userAction('测试行为');
        expect(message.isUser, true);
      });

      test('测试42: 用户对话消息应该标识为用户消息', () {
        final message = ChatMessage.userSpeech('测试对话');
        expect(message.isUser, true);
      });

      test('测试43: AI对话消息应该标识为AI消息', () {
        final character = Character(
          id: 1,
          novelUrl: 'https://example.com/novel',
          name: '角色',
        );
        final message = ChatMessage.dialogue('测试', character);
        expect(message.isUser, false);
      });

      test('测试44: 旁白消息应该标识为AI消息', () {
        final message = ChatMessage.narration('测试旁白');
        expect(message.isUser, false);
      });
    });

    group('边界情况和特殊字符测试', () {
      test('测试45: 应该处理超长内容', () {
        final longContent = '内容' * 10000; // 约20KB
        final message = ChatMessage.narration(longContent);

        expect(message.content.length, greaterThanOrEqualTo(20000));
        expect(message.content, longContent);
      });

      test('测试46: 应该处理包含HTML标签的内容', () {
        final htmlContent = '<div>测试内容</div><p>段落</p>';
        final message = ChatMessage.narration(htmlContent);

        expect(message.content, htmlContent);
        expect(message.content, contains('<div>'));
      });

      test('测试47: 应该处理包含Markdown语法的内容', () {
        final markdownContent = '''# 标题
**粗体** 和 *斜体*
- 列表项1
- 列表项2''';
        final message = ChatMessage.narration(markdownContent);

        expect(message.content, markdownContent);
        expect(message.content, contains('# 标题'));
        expect(message.content, contains('**粗体**'));
      });

      test('测试48: 应该处理包含多语言的内容', () {
        final multiLangContent = '中文 🇨🇳 English 日本語 🇯🇵 한국어';
        final message = ChatMessage.narration(multiLangContent);

        expect(message.content, multiLangContent);
        expect(message.content, contains('中文'));
        expect(message.content, contains('English'));
      });

      test('测试49: 应该处理空字符串', () {
        final message = ChatMessage.narration('');
        expect(message.content, '');
      });

      test('测试50: 应该处理单字符内容', () {
        final message = ChatMessage.narration('测');
        expect(message.content.length, 1);
        expect(message.content, '测');
      });
    });

    group('时间戳处理测试', () {
      test('测试51: 应该正确处理过去的时间戳', () {
        final past = DateTime(2025, 1, 1, 12, 0, 0);
        final message = ChatMessage(
          type: 'narration',
          content: '测试',
          timestamp: past,
        );

        expect(message.timestamp, past);
        expect(message.timestamp.isBefore(DateTime.now()), true);
      });

      test('测试52: 应该正确处理未来的时间戳', () {
        final future = DateTime(2026, 12, 31, 23, 59, 59);
        final message = ChatMessage(
          type: 'narration',
          content: '测试',
          timestamp: future,
        );

        expect(message.timestamp, future);
        expect(message.timestamp.isAfter(DateTime.now()), true);
      });

      test('测试53: copyWith应该保持时间戳的一致性', () {
        final specificTimestamp = DateTime(2025, 1, 1, 12, 0, 0);
        final original = ChatMessage.narration('测试');
        final updated = original.copyWith(timestamp: specificTimestamp);

        expect(updated.timestamp, equals(specificTimestamp));
        expect(original.timestamp, isNot(equals(specificTimestamp)));
      });
    });

    group('角色关联测试', () {
      test('测试54: dialogue消息应该关联角色', () {
        final character = Character(
          id: 1,
          novelUrl: 'https://example.com/novel',
          name: '角色名',
        );
        final message = ChatMessage.dialogue('对话', character);

        expect(message.character, isNotNull);
        expect(message.character?.name, '角色名');
        expect(message.character?.id, 1);
      });

      test('测试55: 非dialogue消息不应该关联角色', () {
        final narration = ChatMessage.narration('旁白');
        final userAction = ChatMessage.userAction('行为');
        final userSpeech = ChatMessage.userSpeech('对话');

        expect(narration.character, null);
        expect(userAction.character, null);
        expect(userSpeech.character, null);
      });

      test('测试56: copyWith应该可以移除角色关联', () {
        final character = Character(
          id: 1,
          novelUrl: 'https://example.com/novel',
          name: '角色',
        );
        final original = ChatMessage.dialogue('对话', character);
        final updated = original.copyWith(character: null);

        expect(updated.character, null);
        expect(original.character, isNotNull);
      });

      test('测试57: copyWith应该可以添加角色关联', () {
        final character = Character(
          id: 1,
          novelUrl: 'https://example.com/novel',
          name: '角色',
        );
        final original = ChatMessage.narration('旁白');
        final updated = original.copyWith(character: character);

        expect(updated.character, character);
        expect(original.character, null);
      });
    });

    group('实际应用场景测试', () {
      test('测试58: 应该正确表示用户输入的行为和对话', () {
        final action = ChatMessage.userAction('举起酒杯');
        final speech = ChatMessage.userSpeech('你好！');

        expect(action.type, 'user_action');
        expect(action.isUser, true);
        expect(speech.type, 'user_speech');
        expect(speech.isUser, true);
      });

      test('测试59: 应该正确表示AI的旁白和角色对话', () {
        final character = Character(
          id: 1,
          novelUrl: 'https://example.com/novel',
          name: '李明',
        );
        final narration = ChatMessage.narration('阳光明媚的早晨');
        final dialogue = ChatMessage.dialogue('你好！', character);

        expect(narration.type, 'narration');
        expect(narration.isUser, false);
        expect(dialogue.type, 'dialogue');
        expect(dialogue.isUser, false);
        expect(dialogue.character?.name, '李明');
      });

      test('测试60: 应该支持消息内容的逐步构建', () {
        final character = Character(
          id: 1,
          novelUrl: 'https://example.com/novel',
          name: '角色',
        );

        // 初始空消息
        var message = ChatMessage.dialogue('', character);

        // 逐步添加内容
        for (int i = 1; i <= 5; i++) {
          message = message.copyWith(
            content: message.content + '第${i}句\n',
          );
        }

        expect(message.content, contains('第1句'));
        expect(message.content, contains('第5句'));
        expect(message.content.split('\n').length, 6); // 5句 + 1空行
      });
    });
  });
}
