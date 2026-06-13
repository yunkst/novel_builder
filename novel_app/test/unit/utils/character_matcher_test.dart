/// CharacterMatcher 角色名称匹配工具单元测试
///
/// 验证角色匹配逻辑：
/// - 大小写不敏感匹配
/// - 别名匹配
/// - 角色提取
/// - 启发式名称提取
/// - 角色合并
/// - 别名冲突检测
///
/// 运行:
///   cd novel_app
///   flutter test test/unit/utils/character_matcher_test.dart
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:novel_app/core/interfaces/repositories/i_character_repository.dart';
import 'package:novel_app/models/character.dart';
import 'package:novel_app/models/ai_companion_response.dart';
import 'package:novel_app/utils/character_matcher.dart';

/// 测试用 mock repository
class _MockCharacterRepository implements ICharacterRepository {
  List<Character> characters;

  _MockCharacterRepository(this.characters);

  @override
  Future<List<Character>> getCharacters(String novelUrl) async {
    return characters;
  }

  // 其他方法未使用，抛出未实现错误
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('未在测试中实现');
}

void main() {
  late _MockCharacterRepository mockRepo;

  setUp(() {
    mockRepo = _MockCharacterRepository([]);
    CharacterMatcher.setCharacterRepository(mockRepo);
  });

  group('CharacterMatcher', () {
    group('findAppearingCharacterIds', () {
      test('应找到通过正式名称出现的角色', () {
        final content = '张三和李四在街上碰面';
        final characters = [
          Character(
            id: 1,
            novelUrl: 'test',
            name: '张三',
            createdAt: DateTime.now(),
          ),
          Character(
            id: 2,
            novelUrl: 'test',
            name: '李四',
            createdAt: DateTime.now(),
          ),
        ];

        final result = CharacterMatcher.findAppearingCharacterIds(
            content, characters);

        expect(result.toSet(), {1, 2});
      });

      test('应不区分大小写匹配', () {
        final content = 'ZHANGSAN meets someone';
        final characters = [
          Character(
            id: 1,
            novelUrl: 'test',
            name: 'zhangsan',
            createdAt: DateTime.now(),
          ),
        ];

        final result = CharacterMatcher.findAppearingCharacterIds(
            content, characters);

        expect(result, [1]);
      });

      test('应通过别名匹配', () {
        final content = '小林今天出去了';
        final characters = [
          Character(
            id: 1,
            novelUrl: 'test',
            name: '林天',
            aliases: ['小林'],
            createdAt: DateTime.now(),
          ),
        ];

        final result = CharacterMatcher.findAppearingCharacterIds(
            content, characters);

        expect(result, [1]);
      });

      test('空内容应返回空列表', () {
        final characters = [
          Character(
            id: 1,
            novelUrl: 'test',
            name: '张三',
            createdAt: DateTime.now(),
          ),
        ];
        expect(
            CharacterMatcher.findAppearingCharacterIds('', characters),
            isEmpty);
      });

      test('空角色列表应返回空列表', () {
        expect(
            CharacterMatcher.findAppearingCharacterIds('内容', []),
            isEmpty);
      });

      test('角色名为空应跳过', () {
        final content = '任意内容';
        final characters = [
          Character(
            id: 1,
            novelUrl: 'test',
            name: '',
            createdAt: DateTime.now(),
          ),
        ];
        expect(
            CharacterMatcher.findAppearingCharacterIds(content, characters),
            isEmpty);
      });

      test('角色 ID 为空应跳过', () {
        final content = '张三在街上';
        final characters = [
          Character(
            id: null,
            novelUrl: 'test',
            name: '张三',
            createdAt: DateTime.now(),
          ),
        ];
        expect(
            CharacterMatcher.findAppearingCharacterIds(content, characters),
            isEmpty);
      });
    });

    group('extractCharactersFromChapter', () {
      test('应提取所有在章节中出现的角色', () {
        final content = '张三和李四相遇，王五也在场';
        final characters = [
          Character(
            id: 1,
            novelUrl: 'test',
            name: '张三',
            createdAt: DateTime.now(),
          ),
          Character(
            id: 2,
            novelUrl: 'test',
            name: '李四',
            createdAt: DateTime.now(),
          ),
          Character(
            id: 3,
            novelUrl: 'test',
            name: '王五',
            createdAt: DateTime.now(),
          ),
          Character(
            id: 4,
            novelUrl: 'test',
            name: '赵六',
            createdAt: DateTime.now(),
          ),
        ];

        final result =
            CharacterMatcher.extractCharactersFromChapter(content, characters);

        expect(result.length, 3);
        expect(result.map((c) => c.id), containsAll([1, 2, 3]));
      });
    });

    group('isCharacterInChapter', () {
      test('通过正式名称匹配应返回 true', () {
        final character = Character(
          novelUrl: 'test',
          name: '张三',
          createdAt: DateTime.now(),
        );
        expect(
            CharacterMatcher.isCharacterInChapter(character, '张三出现了'),
            isTrue);
      });

      test('通过别名匹配应返回 true', () {
        final character = Character(
          novelUrl: 'test',
          name: '林天',
          aliases: ['小林'],
          createdAt: DateTime.now(),
        );
        expect(
            CharacterMatcher.isCharacterInChapter(character, '小林来了'),
            isTrue);
      });

      test('未出现应返回 false', () {
        final character = Character(
          novelUrl: 'test',
          name: '张三',
          createdAt: DateTime.now(),
        );
        expect(
            CharacterMatcher.isCharacterInChapter(character, '李四出现了'),
            isFalse);
      });
    });

    group('countCharacterOccurrences', () {
      test('应统计正式名称出现次数', () {
        final character = Character(
          novelUrl: 'test',
          name: '张三',
          createdAt: DateTime.now(),
        );
        final content = '张三张三张三出现了';
        expect(
            CharacterMatcher.countCharacterOccurrences(character, content),
            3);
      });

      test('应统计别名出现次数', () {
        final character = Character(
          novelUrl: 'test',
          name: '林天',
          aliases: ['小林'],
          createdAt: DateTime.now(),
        );
        final content = '小林和林天都在';
        expect(
            CharacterMatcher.countCharacterOccurrences(character, content),
            2);
      });

      test('未出现应返回 0', () {
        final character = Character(
          novelUrl: 'test',
          name: '张三',
          createdAt: DateTime.now(),
        );
        expect(
            CharacterMatcher.countCharacterOccurrences(character, '李四在'),
            0);
      });
    });

    group('checkAliasConflict', () {
      test('与他人正式名称冲突应返回错误消息', () {
        final current = Character(
          id: 1,
          novelUrl: 'test',
          name: '甲',
          createdAt: DateTime.now(),
        );
        final other = Character(
          id: 2,
          novelUrl: 'test',
          name: '乙',
          createdAt: DateTime.now(),
        );
        final result =
            CharacterMatcher.checkAliasConflict('乙', current, [other]);

        expect(result, isNotNull);
        expect(result, contains('正式名称'));
      });

      test('与他人别名冲突应返回错误消息', () {
        final current = Character(
          id: 1,
          novelUrl: 'test',
          name: '甲',
          createdAt: DateTime.now(),
        );
        final other = Character(
          id: 2,
          novelUrl: 'test',
          name: '乙',
          aliases: ['别名'],
          createdAt: DateTime.now(),
        );
        final result =
            CharacterMatcher.checkAliasConflict('别名', current, [other]);

        expect(result, isNotNull);
        expect(result, contains('别名'));
      });

      test('无冲突应返回 null', () {
        final current = Character(
          id: 1,
          novelUrl: 'test',
          name: '甲',
          createdAt: DateTime.now(),
        );
        final other = Character(
          id: 2,
          novelUrl: 'test',
          name: '乙',
          createdAt: DateTime.now(),
        );
        final result =
            CharacterMatcher.checkAliasConflict('新别名', current, [other]);

        expect(result, isNull);
      });

      test('与自己不冲突', () {
        final current = Character(
          id: 1,
          novelUrl: 'test',
          name: '甲',
          aliases: ['小甲'],
          createdAt: DateTime.now(),
        );
        final result = CharacterMatcher.checkAliasConflict(
            '小甲', current, [current]);

        expect(result, isNull);
      });
    });

    group('extractPotentialCharacterNames', () {
      test('应返回通过过滤的名称', () {
        // 使用 2 字名称 + 常见姓氏，确保名称出现在不同句子中
        // 需确保名称单独被 regex 匹配到 2 次以上
        final content = '王明。王明。';
        final names =
            CharacterMatcher.extractPotentialCharacterNames(content);

        // "王" 是常见姓氏，而且 "王明" 出现 2 次（用句号分隔保证独立匹配）
        expect(names, contains('王明'));
      });

      test('应排除常见词', () {
        final content = '这个这个也这个。什么什么的。但是但是。';
        final names =
            CharacterMatcher.extractPotentialCharacterNames(content);

        expect(names, isNot(contains('这个')));
        expect(names, isNot(contains('什么')));
        expect(names, isNot(contains('但是')));
      });

      test('非排除词但非人名的词不应被误判', () {
        // "东西" 在排除词列表中
        final content = '东西东西。';
        final names =
            CharacterMatcher.extractPotentialCharacterNames(content);

        expect(names, isNot(contains('东西')));
      });
    });

    group('mergeCharacterInfo', () {
      test('新角色字段应覆盖旧角色', () {
        final oldCharacter = Character(
          id: 1,
          novelUrl: 'test',
          name: '张三',
          age: 20,
          gender: '男',
          createdAt: DateTime.now(),
        );
        final newCharacter = Character(
          id: 1,
          novelUrl: 'test',
          name: '张三',
          age: 25,
          occupation: '剑客',
          createdAt: DateTime.now(),
        );

        final merged =
            CharacterMatcher.mergeCharacterInfo(oldCharacter, newCharacter);

        expect(merged.age, 25); // 来自新角色
        expect(merged.gender, '男'); // 来自旧角色
        expect(merged.occupation, '剑客'); // 来自新角色
        expect(merged.updatedAt, isA<DateTime>());
      });

      test('新角色为空字段时应保留旧角色值', () {
        final oldCharacter = Character(
          id: 1,
          novelUrl: 'test',
          name: '张三',
          age: 20,
          gender: '男',
          createdAt: DateTime.now(),
        );
        final newCharacter = Character(
          id: 1,
          novelUrl: 'test',
          name: '张三',
          createdAt: DateTime.now(),
        );

        final merged =
            CharacterMatcher.mergeCharacterInfo(oldCharacter, newCharacter);

        expect(merged.age, 20);
        expect(merged.gender, '男');
      });
    });
  });
}
