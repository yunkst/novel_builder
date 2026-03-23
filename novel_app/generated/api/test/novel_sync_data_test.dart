import 'package:test/test.dart';
import 'package:novel_api/novel_api.dart';

// tests for NovelSyncData
void main() {
  final instance = NovelSyncDataBuilder();
  // TODO add properties to the builder and call build()

  group(NovelSyncData, () {
    // 小说ID
    // int novelId
    test('to test the property `novelId`', () async {
      // TODO
    });

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

    // String sourceUrl
    test('to test the property `sourceUrl`', () async {
      // TODO
    });

    // 总章节数
    // int totalChapters (default value: 0)
    test('to test the property `totalChapters`', () async {
      // TODO
    });

    // 总字数
    // int totalWords (default value: 0)
    test('to test the property `totalWords`', () async {
      // TODO
    });

    // int lastReadChapterId
    test('to test the property `lastReadChapterId`', () async {
      // TODO
    });

    // 最后阅读位置
    // int lastReadPosition (default value: 0)
    test('to test the property `lastReadPosition`', () async {
      // TODO
    });

    // 是否收藏
    // bool isFavorite (default value: false)
    test('to test the property `isFavorite`', () async {
      // TODO
    });

    // String createdAt
    test('to test the property `createdAt`', () async {
      // TODO
    });

    // String updatedAt
    test('to test the property `updatedAt`', () async {
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
