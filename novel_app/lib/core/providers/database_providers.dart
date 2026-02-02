import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../services/database_service.dart';
import '../../repositories/character_repository.dart';
import '../../repositories/character_relation_repository.dart';
import '../../repositories/novel_repository.dart';
import '../../repositories/chapter_repository.dart';
import '../../repositories/illustration_repository.dart';
import '../../repositories/outline_repository.dart';
import '../../repositories/chat_scene_repository.dart';
import '../../repositories/bookshelf_repository.dart';

/// DatabaseService Provider
///
/// 提供全局单例 DatabaseService 实例
final databaseServiceProvider = Provider<DatabaseService>((ref) {
  return DatabaseService();
});

/// NovelRepository Provider
final novelRepositoryProvider = Provider<NovelRepository>((ref) {
  return NovelRepository();
});

/// ChapterRepository Provider
final chapterRepositoryProvider = Provider<ChapterRepository>((ref) {
  return ChapterRepository();
});

/// CharacterRepository Provider
///
/// 依赖 DatabaseService,自动共享数据库实例
final characterRepositoryProvider = Provider<CharacterRepository>((ref) {
  final dbService = ref.watch(databaseServiceProvider);
  final repository = CharacterRepository();

  // 使用Future来异步设置共享数据库
  ref.onDispose(() {
    // DatabaseService 管理数据库生命周期,这里不需要关闭
  });

  // 设置共享数据库实例
  dbService.database.then((db) {
    repository.setSharedDatabase(db);
  });

  return repository;
});

/// CharacterRelationRepository Provider
///
/// 依赖 DatabaseService,自动共享数据库实例
final characterRelationRepositoryProvider =
    Provider<CharacterRelationRepository>((ref) {
  final dbService = ref.watch(databaseServiceProvider);
  final repository = CharacterRelationRepository();

  // 设置共享的数据库实例
  ref.onDispose(() {
    // DatabaseService 管理数据库生命周期,这里不需要关闭
  });

  dbService.database.then((db) {
    repository.setSharedDatabase(db);
  });

  return repository;
});

/// IllustrationRepository Provider
final illustrationRepositoryProvider = Provider<IllustrationRepository>((ref) {
  return IllustrationRepository();
});

/// OutlineRepository Provider
final outlineRepositoryProvider = Provider<OutlineRepository>((ref) {
  return OutlineRepository();
});

/// ChatSceneRepository Provider
final chatSceneRepositoryProvider = Provider<ChatSceneRepository>((ref) {
  return ChatSceneRepository();
});

/// BookshelfRepository Provider
final bookshelfRepositoryProvider = Provider<BookshelfRepository>((ref) {
  return BookshelfRepository();
});
