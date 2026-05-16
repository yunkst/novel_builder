import 'package:test/test.dart';
import 'package:novel_api/novel_api.dart';

// tests for NovelSyncData
void main() {
  final instance = NovelSyncDataBuilder();
  // TODO add properties to the builder and call build()

  group(NovelSyncData, () {
    // 小说标题
    // String title
    test('to test the property `title`', () async {
      // TODO
    });

    // String author
    test('to test the property `author`', () async {
      // TODO
    });

    // String description
    test('to test the property `description`', () async {
      // TODO
    });

    // String coverUrl
    test('to test the property `coverUrl`', () async {
      // TODO
    });

    // String backgroundSetting
    test('to test the property `backgroundSetting`', () async {
      // TODO
    });

    // 章节列表
    // BuiltList<ChapterSyncData> chapters (default value: ListBuilder())
    test('to test the property `chapters`', () async {
      // TODO
    });

    // 角色列表
    // BuiltList<CharacterSyncData> characters (default value: ListBuilder())
    test('to test the property `characters`', () async {
      // TODO
    });

    // 角色关系列表
    // BuiltList<CharacterRelationSyncData> characterRelations (default value: ListBuilder())
    test('to test the property `characterRelations`', () async {
      // TODO
    });

    // 大纲列表
    // BuiltList<OutlineSyncData> outlines (default value: ListBuilder())
    test('to test the property `outlines`', () async {
      // TODO
    });

  });
}
