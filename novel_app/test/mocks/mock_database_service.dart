import 'package:sqflite/sqflite.dart';
import 'package:novel_app/services/database_service.dart';
import 'package:novel_app/models/novel.dart';
import 'package:novel_app/models/chapter.dart';
import 'package:novel_app/models/character.dart';
import 'package:novel_app/models/character_relationship.dart';
import 'package:novel_app/models/scene_illustration.dart';
import 'package:novel_app/models/outline.dart';
import 'package:novel_app/models/chat_scene.dart';
import 'package:novel_app/models/ai_companion_response.dart';
import 'package:novel_app/models/ai_accompaniment_settings.dart';
import 'package:novel_app/models/bookshelf.dart';
import 'package:novel_app/models/search_result.dart';

/// Mock DatabaseService
///
/// ## 用途
/// 用于测试环境的 Mock DatabaseService，避免真实数据库查询
///
/// ## 核心特性
/// - 不访问真实 SQLite 数据库
/// - 返回测试数据或空数据
/// - 解决 Pending Timer 测试问题
/// - 快速、可靠的测试执行
///
/// ## 使用示例
/// ```dart
/// testWidgets('测试书架屏幕', (tester) async {
///   final mockDb = MockDatabaseService();
///   mockDb.mockNovels = [testNovel1, testNovel2];
///
///   await tester.pumpWidget(
///     ProviderScope(
///       overrides: [
///         databaseServiceProvider.overrideWithValue(mockDb),
///       ],
///       child: MaterialApp(home: BookshelfScreen()),
///     ),
///   );
///
///   // 不需要 pumpAndSettle，因为没有真实数据库操作
///   await tester.pump();
///   expect(find.text('测试小说1'), findsOneWidget);
/// });
/// ```
class MockDatabaseService implements DatabaseService {
  // ==================== Mock 数据存储 ====================

  /// Mock 小说列表
  List<Novel> mockNovels = [];

  /// Mock 章节缓存 (key: chapterUrl, value: Chapter)
  Map<String, Chapter> mockChapters = {};

  /// Mock 章节内容缓存 (key: chapterUrl, value: content)
  Map<String, String> mockChapterContents = {};

  /// Mock 角色列表 (key: novelUrl, value: List<Character>)
  Map<String, List<Character>> mockCharacters = {};

  /// Mock 角色关系 (key: characterId, value: List<CharacterRelationship>)
  Map<int, List<CharacterRelationship>> mockRelationships = {};

  /// Mock 场景插图 (key: novelUrl, value: List<SceneIllustration>)
  Map<String, List<SceneIllustration>> mockIllustrations = {};

  /// Mock 大纲 (key: novelUrl, value: Outline)
  Map<String, Outline> mockOutlines = {};

  /// Mock 聊天场景列表
  List<ChatScene> mockChatScenes = [];

  /// Mock 书架分类列表
  List<Bookshelf> mockBookshelves = [];

  /// Mock 小说-书架关联 (key: novelUrl, value: List<bookshelfId>)
  Map<String, List<int>> mockNovelBookshelves = {};

  // ==================== DatabaseService 接口实现 ====================

  @override
  bool get isWebPlatform => false;

  @override
  Future<Database> get database async {
    throw UnimplementedError(
      'MockDatabaseService 不支持访问真实数据库。'
      '请使用 mock 数据属性设置测试数据。',
    );
  }

  // ========== 小说操作 ==========

  @override
  Future<int> addToBookshelf(Novel novel) async {
    mockNovels.add(novel.copyWith(isInBookshelf: true));
    return mockNovels.length;
  }

  @override
  Future<int> createCustomNovel(
    String title,
    String author, {
    String? description,
  }) async {
    final novel = Novel(
      title: title,
      author: author,
      url: 'local://custom_novel_${DateTime.now().millisecondsSinceEpoch}',
      coverUrl: null,
      description: description,
      backgroundSetting: null,
    );
    return await addToBookshelf(novel);
  }

  @override
  Future<int> removeFromBookshelf(String novelUrl) async {
    mockNovels.removeWhere((n) => n.url == novelUrl);
    return mockNovels.length;
  }

  @override
  Future<List<Novel>> getBookshelf() async => mockNovels;

  @override
  Future<List<Novel>> getNovels() async => mockNovels;

  @override
  Future<bool> isInBookshelf(String novelUrl) async {
    return mockNovels.any((n) => n.url == novelUrl);
  }

  @override
  Future<int> updateLastReadChapter(String novelUrl, int chapterIndex) async {
    final index = mockNovels.indexWhere((n) => n.url == novelUrl);
    if (index >= 0) {
      // Mock 不需要实际更新，直接返回成功
      return 1;
    }
    return 0;
  }

  @override
  Future<int> updateBackgroundSetting(String novelUrl, String? backgroundSetting) async {
    final index = mockNovels.indexWhere((n) => n.url == novelUrl);
    if (index >= 0) {
      mockNovels[index] = mockNovels[index].copyWith(backgroundSetting: backgroundSetting);
      return 1;
    }
    return 0;
  }

  @override
  Future<int> appendBackgroundSetting(String novelUrl, String newBackground) async {
    if (newBackground.trim().isEmpty) {
      return 0;
    }

    final index = mockNovels.indexWhere((n) => n.url == novelUrl);
    if (index < 0) {
      return 0;
    }

    final current = mockNovels[index].backgroundSetting ?? '';
    final updated = current.isEmpty ? newBackground : '$current\n\n$newBackground';
    mockNovels[index] = mockNovels[index].copyWith(backgroundSetting: updated);
    return 1;
  }

  @override
  Future<String?> getBackgroundSetting(String novelUrl) async {
    final novel = mockNovels.firstWhere(
      (n) => n.url == novelUrl,
      orElse: () => Novel(
        title: '',
        author: '',
        url: '',
      ),
    );
    return novel.backgroundSetting;
  }

  @override
  Future<int> getLastReadChapter(String novelUrl) async {
    return 0; // Mock 返回默认值
  }

  @override
  Future<AiAccompanimentSettings> getAiAccompanimentSettings(String novelUrl) async {
    return const AiAccompanimentSettings(
      autoEnabled: false,
      infoNotificationEnabled: false,
    );
  }

  @override
  Future<int> updateAiAccompanimentSettings(
    String novelUrl,
    AiAccompanimentSettings settings,
  ) async {
    return 1; // Mock 返回成功
  }

  // ========== 章节操作 ==========

  @override
  Future<bool> isChapterCached(String chapterUrl) async {
    return mockChapterContents.containsKey(chapterUrl);
  }

  @override
  Future<List<String>> filterUncachedChapters(List<String> chapterUrls) async {
    return chapterUrls.where((url) => !mockChapterContents.containsKey(url)).toList();
  }

  @override
  Future<Map<String, bool>> getChaptersCacheStatus(List<String> chapterUrls) async {
    final result = <String, bool>{};
    for (final url in chapterUrls) {
      result[url] = mockChapterContents.containsKey(url);
    }
    return result;
  }

  @override
  void markAsPreloading(String chapterUrl) {
    // Mock 不需要实现预加载状态
  }

  @override
  bool isPreloading(String chapterUrl) => false;

  @override
  void clearMemoryState() {
    // Mock 不需要清理内存状态
  }

  @override
  Future<int> cacheChapter(String novelUrl, Chapter chapter, String content) async {
    mockChapters[chapter.url] = chapter;
    mockChapterContents[chapter.url] = content;
    return 1;
  }

  @override
  Future<int> updateChapterContent(String chapterUrl, String content) async {
    mockChapterContents[chapterUrl] = content;
    return 1;
  }

  @override
  Future<int> deleteChapterCache(String chapterUrl) async {
    mockChapters.remove(chapterUrl);
    mockChapterContents.remove(chapterUrl);
    return 1;
  }

  @override
  Future<String?> getCachedChapter(String chapterUrl) async {
    return mockChapterContents[chapterUrl];
  }

  @override
  Future<String?> getChapterContent(String chapterUrl) async {
    return mockChapterContents[chapterUrl];
  }

  @override
  Future<List<Chapter>> getCachedChapters(String novelUrl) async {
    // Mock 简化实现：返回所有章节
    return mockChapters.values.toList();
  }

  @override
  Future<int> deleteCachedChapters(String novelUrl) async {
    // Mock 简化实现：清空所有章节
    final count = mockChapters.length;
    mockChapters.clear();
    mockChapterContents.clear();
    return count;
  }

  @override
  Future<void> clearNovelCache(String novelUrl) async {
    await deleteCachedChapters(novelUrl);
  }

  @override
  Future<void> markChapterAsRead(String novelUrl, String chapterUrl) async {
    // Mock 不需要实现
  }

  @override
  Future<int> getCachedChaptersCount(String novelUrl) async {
    return mockChapters.length; // Mock 简化实现
  }

  @override
  Future<bool> isChapterAccompanied(String novelUrl, String chapterUrl) async {
    return false; // Mock 返回默认值
  }

  @override
  Future<void> markChapterAsAccompanied(String novelUrl, String chapterUrl) async {
    // Mock 不需要实现
  }

  @override
  Future<void> resetChapterAccompaniedFlag(String novelUrl, String chapterUrl) async {
    // Mock 不需要实现
  }

  @override
  Future<void> cacheNovelChapters(String novelUrl, List<Chapter> chapters) async {
    for (final chapter in chapters) {
      mockChapters[chapter.url] = chapter;
    }
  }

  @override
  Future<List<Chapter>> getCachedNovelChapters(String novelUrl) async {
    // Mock 简化实现：返回所有章节
    return mockChapters.values.toList();
  }

  @override
  Future<List<Chapter>> getChapters(String novelUrl) async {
    return getCachedNovelChapters(novelUrl);
  }

  @override
  Future<void> updateChaptersOrder(String novelUrl, List<Chapter> chapters) async {
    // Mock 不需要实现
  }

  @override
  static bool isLocalChapter(String chapterUrl) => chapterUrl.startsWith('local://');

  @override
  Future<int> createCustomChapter(String novelUrl, String title, String content, [int? index]) async {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final chapterUrl = 'local://user_chapter_$timestamp';
    final chapter = Chapter(
      title: title,
      url: chapterUrl,
      chapterIndex: index ?? 0,
      isUserInserted: true,
    );
    mockChapters[chapterUrl] = chapter;
    mockChapterContents[chapterUrl] = content;
    return 1;
  }

  @override
  Future<int> insertUserChapter(String novelUrl, String title, String content, [int? index]) async {
    return await createCustomChapter(novelUrl, title, content, index);
  }

  @override
  Future<void> updateCustomChapter(String chapterUrl, String title, String content) async {
    final chapter = mockChapters[chapterUrl];
    if (chapter != null) {
      mockChapters[chapterUrl] = chapter.copyWith(title: title);
      mockChapterContents[chapterUrl] = content;
    }
  }

  @override
  Future<void> deleteCustomChapter(String chapterUrl) async {
    mockChapters.remove(chapterUrl);
    mockChapterContents.remove(chapterUrl);
  }

  @override
  Future<void> deleteUserChapter(String chapterUrl) async {
    await deleteCustomChapter(chapterUrl);
  }

  @override
  Future<void> clearAllCache() async {
    mockChapters.clear();
    mockChapterContents.clear();
  }

  // ========== 角色操作 ==========

  @override
  Future<int> createCharacter(Character character) async {
    final novelUrl = character.novelUrl;
    if (!mockCharacters.containsKey(novelUrl)) {
      mockCharacters[novelUrl] = [];
    }
    final newCharacter = character.copyWith(id: mockCharacters[novelUrl]!.length + 1);
    mockCharacters[novelUrl]!.add(newCharacter);
    return newCharacter.id!;
  }

  @override
  Future<List<Character>> getCharacters(String novelUrl) async {
    return mockCharacters[novelUrl] ?? [];
  }

  @override
  Future<Character?> getCharacter(int id) async {
    for (final characters in mockCharacters.values) {
      final character = characters.firstWhere(
        (c) => c.id == id,
        orElse: () => Character(
          novelUrl: '',
          name: '',
        ),
      );
      if (character.id != null) return character;
    }
    return null;
  }

  @override
  Future<int> updateCharacter(Character character) async {
    final novelUrl = character.novelUrl;
    if (mockCharacters.containsKey(novelUrl)) {
      final index = mockCharacters[novelUrl]!.indexWhere((c) => c.id == character.id);
      if (index >= 0) {
        mockCharacters[novelUrl]![index] = character;
        return 1;
      }
    }
    return 0;
  }

  @override
  Future<int> deleteCharacter(int id) async {
    for (final novelUrl in mockCharacters.keys) {
      final index = mockCharacters[novelUrl]!.indexWhere((c) => c.id == id);
      if (index >= 0) {
        mockCharacters[novelUrl]!.removeAt(index);
        return 1;
      }
    }
    return 0;
  }

  @override
  Future<Character?> findCharacterByName(String novelUrl, String name) async {
    final characters = mockCharacters[novelUrl] ?? [];
    try {
      return characters.firstWhere((c) => c.name == name);
    } catch (e) {
      return null;
    }
  }

  @override
  Future<Character> updateOrInsertCharacter(Character newCharacter) async {
    final existing = await findCharacterByName(newCharacter.novelUrl, newCharacter.name);
    if (existing != null) {
      final updated = newCharacter.copyWith(id: existing.id);
      await updateCharacter(updated);
      return updated;
    } else {
      final id = await createCharacter(newCharacter);
      return newCharacter.copyWith(id: id);
    }
  }

  @override
  Future<List<Character>> batchUpdateCharacters(List<Character> newCharacters) async {
    final result = <Character>[];
    for (final character in newCharacters) {
      final updated = await updateOrInsertCharacter(character);
      result.add(updated);
    }
    return result;
  }

  @override
  Future<List<String>> getCharacterNames(String novelUrl) async {
    final characters = mockCharacters[novelUrl] ?? [];
    return characters.map((c) => c.name).toList();
  }

  @override
  Future<bool> characterExists(int id) async {
    return await getCharacter(id) != null;
  }

  @override
  Future<List<Character>> getCharactersByIds(List<int> ids) async {
    final result = <Character>[];
    for (final id in ids) {
      final character = await getCharacter(id);
      if (character != null) {
        result.add(character);
      }
    }
    return result;
  }

  @override
  Future<int> deleteAllCharacters(String novelUrl) async {
    final count = mockCharacters[novelUrl]?.length ?? 0;
    mockCharacters.remove(novelUrl);
    return count;
  }

  @override
  Future<int> updateCharacterCachedImage(int characterId, String? imageUrl) async {
    return 1; // Mock 返回成功
  }

  @override
  Future<int> clearCharacterCachedImage(int characterId) async {
    return 1; // Mock 返回成功
  }

  @override
  Future<int> clearAllCharacterCachedImages(String novelUrl) async {
    return 1; // Mock 返回成功
  }

  @override
  Future<String?> getCharacterCachedImage(int characterId) async {
    return null; // Mock 返回默认值
  }

  @override
  Future<int> updateCharacterAvatar(
    int characterId, {
    String? imageUrl,
    String? originalFilename,
    String? originalImageUrl,
  }) async {
    return 1; // Mock 返回成功
  }

  @override
  Future<bool> hasCharacterAvatar(int characterId) async {
    return false; // Mock 返回默认值
  }

  @override
  Future<int> batchUpdateOrInsertCharacters(String novelUrl, List<AICompanionRole> aiRoles) async {
    return aiRoles.length; // Mock 返回成功数量
  }

  // ========== 角色关系操作 ==========

  @override
  Future<int> createRelationship(CharacterRelationship relationship) async {
    final sourceId = relationship.sourceCharacterId;
    if (!mockRelationships.containsKey(sourceId)) {
      mockRelationships[sourceId] = [];
    }
    final newRelationship = relationship.copyWith(
      id: mockRelationships[sourceId]!.length + 1,
    );
    mockRelationships[sourceId]!.add(newRelationship);
    return newRelationship.id!;
  }

  @override
  Future<List<CharacterRelationship>> getRelationships(int characterId) async {
    return mockRelationships[characterId] ?? [];
  }

  @override
  Future<List<CharacterRelationship>> getOutgoingRelationships(int characterId) async {
    return mockRelationships[characterId] ?? [];
  }

  @override
  Future<List<CharacterRelationship>> getIncomingRelationships(int characterId) async {
    final result = <CharacterRelationship>[];
    for (final relationships in mockRelationships.values) {
      result.addAll(
        relationships.where((r) => r.targetCharacterId == characterId),
      );
    }
    return result;
  }

  @override
  Future<int> updateRelationship(CharacterRelationship relationship) async {
    final sourceId = relationship.sourceCharacterId;
    if (mockRelationships.containsKey(sourceId)) {
      final index = mockRelationships[sourceId]!.indexWhere((r) => r.id == relationship.id);
      if (index >= 0) {
        mockRelationships[sourceId]![index] = relationship;
        return 1;
      }
    }
    return 0;
  }

  @override
  Future<int> deleteRelationship(int relationshipId) async {
    for (final sourceId in mockRelationships.keys) {
      final index = mockRelationships[sourceId]!.indexWhere((r) => r.id == relationshipId);
      if (index >= 0) {
        mockRelationships[sourceId]!.removeAt(index);
        return 1;
      }
    }
    return 0;
  }

  @override
  Future<bool> relationshipExists(int sourceId, int targetId, String type) async {
    final relationships = mockRelationships[sourceId] ?? [];
    return relationships.any((r) =>
      r.targetCharacterId == targetId &&
      r.relationshipType == type
    );
  }

  @override
  Future<int> getRelationshipCount(int characterId) async {
    return (mockRelationships[characterId] ?? []).length;
  }

  @override
  Future<List<int>> getRelatedCharacterIds(int characterId) async {
    final ids = <int>[];
    final relationships = mockRelationships[characterId] ?? [];
    for (final r in relationships) {
      ids.add(r.targetCharacterId);
    }
    return ids;
  }

  @override
  Future<List<CharacterRelationship>> getAllRelationships(String novelUrl) async {
    final result = <CharacterRelationship>[];
    for (final relationships in mockRelationships.values) {
      result.addAll(relationships);
    }
    return result;
  }

  @override
  Future<List<CharacterRelationship>> getRelationshipsByCharacterIds(
    int sourceId,
    int targetId,
  ) async {
    final relationships = mockRelationships[sourceId] ?? [];
    return relationships.where((r) => r.targetCharacterId == targetId).toList();
  }

  @override
  Future<int> batchUpdateOrInsertRelationships(
    String novelUrl,
    List<AICompanionRelation> aiRelations,
  ) async {
    return aiRelations.length; // Mock 返回成功数量
  }

  // ========== 场景插图操作 ==========

  @override
  Future<int> insertSceneIllustration(SceneIllustration illustration) async {
    final novelUrl = illustration.novelUrl;
    if (!mockIllustrations.containsKey(novelUrl)) {
      mockIllustrations[novelUrl] = [];
    }
    mockIllustrations[novelUrl]!.add(illustration);
    return 1;
  }

  @override
  Future<int> updateSceneIllustrationStatus(
    int id,
    String status, {
    List<String>? images,
    String? prompts,
  }) async {
    return 1; // Mock 返回成功
  }

  @override
  Future<int> deleteSceneIllustration(int id) async {
    for (final novelUrl in mockIllustrations.keys) {
      final index = mockIllustrations[novelUrl]!.indexWhere((i) => i.id == id);
      if (index >= 0) {
        mockIllustrations[novelUrl]!.removeAt(index);
        return 1;
      }
    }
    return 0;
  }

  @override
  Future<int> deleteSceneIllustrationsByChapter(String novelUrl, String chapterId) async {
    if (!mockIllustrations.containsKey(novelUrl)) {
      return 0;
    }
    final initialLength = mockIllustrations[novelUrl]!.length;
    mockIllustrations[novelUrl]!.removeWhere((i) => i.chapterId == chapterId);
    return initialLength - mockIllustrations[novelUrl]!.length;
  }

  @override
  Future<List<SceneIllustration>> getSceneIllustrationsByChapter(
    String novelUrl,
    String chapterId,
  ) async {
    final illustrations = mockIllustrations[novelUrl] ?? [];
    return illustrations.where((i) => i.chapterId == chapterId).toList();
  }

  @override
  Future<SceneIllustration?> getSceneIllustrationByTaskId(String taskId) async {
    for (final illustrations in mockIllustrations.values) {
      try {
        return illustrations.firstWhere((i) => i.taskId == taskId);
      } catch (e) {
        continue;
      }
    }
    return null;
  }

  @override
  Future<Map<String, dynamic>> getSceneIllustrationsPaginated({
    required int page,
    required int limit,
  }) async {
    final allIllustrations = <SceneIllustration>[];
    for (final illustrations in mockIllustrations.values) {
      allIllustrations.addAll(illustrations);
    }
    final start = (page - 1) * limit;
    final end = start + limit;
    final paginated = allIllustrations.skip(start).take(limit).toList();
    return {
      'data': paginated,
      'total': allIllustrations.length,
      'page': page,
      'limit': limit,
    };
  }

  @override
  Future<List<SceneIllustration>> getPendingSceneIllustrations() async {
    final result = <SceneIllustration>[];
    for (final illustrations in mockIllustrations.values) {
      result.addAll(illustrations.where((i) => i.status == 'pending'));
    }
    return result;
  }

  @override
  Future<int> batchUpdateSceneIllustrations(List<int> ids, String status) async {
    return ids.length; // Mock 返回成功数量
  }

  @override
  Future<int> getIllustrationCount(String novelUrl) async {
    return (mockIllustrations[novelUrl] ?? []).length;
  }

  @override
  Future<int> getCompletedIllustrationCount(String novelUrl, String chapterId) async {
    final illustrations = mockIllustrations[novelUrl] ?? [];
    return illustrations.where((i) =>
      i.chapterId == chapterId &&
      i.status == 'completed'
    ).length;
  }

  @override
  Future<bool> taskExists(String taskId) async {
    return await getSceneIllustrationByTaskId(taskId) != null;
  }

  // ========== 大纲操作 ==========

  @override
  Future<int> saveOutline(Outline outline) async {
    mockOutlines[outline.novelUrl] = outline;
    return 1;
  }

  @override
  Future<Outline?> getOutlineByNovelUrl(String novelUrl) async {
    return mockOutlines[novelUrl];
  }

  @override
  Future<List<Outline>> getAllOutlines() async {
    return mockOutlines.values.toList();
  }

  @override
  Future<int> deleteOutline(String novelUrl) async {
    mockOutlines.remove(novelUrl);
    return 1;
  }

  @override
  Future<int> updateOutlineContent(String novelUrl, String title, String content) async {
    if (mockOutlines.containsKey(novelUrl)) {
      final outline = mockOutlines[novelUrl]!;
      mockOutlines[novelUrl] = Outline(
        novelUrl: novelUrl,
        title: title,
        content: content,
        createdAt: outline.createdAt,
        updatedAt: DateTime.now(),
      );
      return 1;
    }
    return 0;
  }

  // ========== 聊天场景操作 ==========

  @override
  Future<int> insertChatScene(ChatScene scene) async {
    final newScene = ChatScene(
      title: scene.title,
      content: scene.content,
      createdAt: scene.createdAt,
      updatedAt: scene.updatedAt,
    );
    mockChatScenes.add(newScene);
    return 1;
  }

  @override
  Future<void> updateChatScene(ChatScene scene) async {
    // Mock 不需要实现
  }

  @override
  Future<void> deleteChatScene(int id) async {
    // Mock 不需要实现
  }

  @override
  Future<List<ChatScene>> getAllChatScenes() async {
    return mockChatScenes;
  }

  @override
  Future<ChatScene?> getChatSceneById(int id) async {
    return mockChatScenes.isNotEmpty ? mockChatScenes.first : null;
  }

  @override
  Future<List<ChatScene>> searchChatScenes(String query) async {
    return mockChatScenes.where((s) => s.title.contains(query)).toList();
  }

  // ========== 书架分类操作 ==========

  @override
  Future<List<Bookshelf>> getBookshelves() async {
    return mockBookshelves;
  }

  @override
  Future<int> createBookshelf(String name) async {
    final newBookshelf = Bookshelf(
      id: mockBookshelves.length + 1,
      name: name,
      createdAt: DateTime.now().millisecondsSinceEpoch,
    );
    mockBookshelves.add(newBookshelf);
    return newBookshelf.id;
  }

  @override
  Future<bool> deleteBookshelf(int bookshelfId) async {
    mockBookshelves.removeWhere((b) => b.id == bookshelfId);
    return true;
  }

  @override
  Future<List<Novel>> getNovelsByBookshelf(int bookshelfId) async {
    // 返回所有小说（Mock 简化实现）
    return mockNovels;
  }

  @override
  Future<void> addNovelToBookshelf(String novelUrl, int bookshelfId) async {
    if (!mockNovelBookshelves.containsKey(novelUrl)) {
      mockNovelBookshelves[novelUrl] = [];
    }
    if (!mockNovelBookshelves[novelUrl]!.contains(bookshelfId)) {
      mockNovelBookshelves[novelUrl]!.add(bookshelfId);
    }
  }

  @override
  Future<bool> removeNovelFromBookshelf(String novelUrl, int bookshelfId) async {
    if (mockNovelBookshelves.containsKey(novelUrl)) {
      return mockNovelBookshelves[novelUrl]!.remove(bookshelfId);
    }
    return false;
  }

  @override
  Future<void> moveNovelToBookshelf(
    String novelUrl,
    int fromBookshelfId,
    int toBookshelfId,
  ) async {
    await removeNovelFromBookshelf(novelUrl, fromBookshelfId);
    await addNovelToBookshelf(novelUrl, toBookshelfId);
  }

  @override
  Future<List<int>> getBookshelvesByNovel(String novelUrl) async {
    return mockNovelBookshelves[novelUrl] ?? [];
  }

  @override
  Future<int> getNovelCountByBookshelf(int bookshelfId) async {
    return mockNovels.length; // Mock 简化实现
  }

  @override
  Future<bool> isNovelInBookshelf(String novelUrl, int bookshelfId) async {
    final bookshelves = mockNovelBookshelves[novelUrl] ?? [];
    return bookshelves.contains(bookshelfId);
  }

  @override
  Future<void> reorderBookshelves(List<int> bookshelfIds) async {
    // Mock 不需要实现
  }

  @override
  Future<int> updateBookshelf(Bookshelf bookshelf) async {
    return 1; // Mock 返回成功
  }

  // ========== 缓存搜索操作 ==========

  @override
  Future<List<ChapterSearchResult>> searchInCachedContent(
    String keyword, {
    String? novelUrl,
  }) async {
    return []; // Mock 返回空结果
  }

  @override
  Future<List<CachedNovelInfo>> getCachedNovels() async {
    return []; // Mock 返回空结果
  }

  @override
  Future<Character> saveCharacter(Character character) async {
    return await updateOrInsertCharacter(character);
  }

  @override
  Future<void> close() async {
    // Mock 不需要关闭连接
  }
}
