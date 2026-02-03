import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:riverpod/riverpod.dart';
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
import '../database/database_connection.dart';
import '../interfaces/i_database_connection.dart';
import '../interfaces/repositories/i_novel_repository.dart';
import '../interfaces/repositories/i_chapter_repository.dart';
import '../interfaces/repositories/i_character_repository.dart';
import '../interfaces/repositories/i_character_relation_repository.dart';
import '../interfaces/repositories/i_bookshelf_repository.dart';
import '../interfaces/repositories/i_illustration_repository.dart';
import '../interfaces/repositories/i_outline_repository.dart';
import '../interfaces/repositories/i_chat_scene_repository.dart';

part 'database_providers.g.dart';

/// 数据库连接Provider
///
/// 提供全局单例 DatabaseConnection 实例
/// 使用 keepAlive: true 确保数据库连接不会因为没有监听者而被销毁
@Riverpod(keepAlive: true)
DatabaseConnection databaseConnection(Ref ref) {
  final connection = DatabaseConnection();
  ref.onDispose(() => connection.close());
  return connection;
}

/// IDatabaseConnection接口Provider
///
/// 提供接口类型的数据库连接，便于依赖注入和测试
@riverpod
IDatabaseConnection iDatabaseConnection(Ref ref) {
  return ref.watch(databaseConnectionProvider);
}

/// DatabaseService Provider
///
/// 提供全局单例 DatabaseService 实例（向后兼容）
/// 注意：新代码建议使用 databaseConnectionProvider
final databaseServiceProvider = Provider<DatabaseService>((ref) {
  return DatabaseService();
});

/// NovelRepository Provider
///
/// 使用IDatabaseConnection接口注入，支持测试和依赖替换
@riverpod
INovelRepository novelRepository(Ref ref) {
  final dbConnection = ref.watch(databaseConnectionProvider);
  return NovelRepository(dbConnection: dbConnection);
}

/// ChapterRepository Provider
///
/// 使用IDatabaseConnection接口注入，支持测试和依赖替换
@riverpod
IChapterRepository chapterRepository(Ref ref) {
  final dbConnection = ref.watch(databaseConnectionProvider);
  return ChapterRepository(dbConnection: dbConnection);
}

/// CharacterRepository Provider
///
/// 使用IDatabaseConnection接口注入，支持测试和依赖替换
@riverpod
ICharacterRepository characterRepository(Ref ref) {
  final dbConnection = ref.watch(databaseConnectionProvider);
  return CharacterRepository(dbConnection: dbConnection);
}

/// CharacterRelationRepository Provider
///
/// 使用IDatabaseConnection接口注入，支持测试和依赖替换
@riverpod
ICharacterRelationRepository characterRelationRepository(Ref ref) {
  final dbConnection = ref.watch(databaseConnectionProvider);
  return CharacterRelationRepository(dbConnection: dbConnection);
}

/// IllustrationRepository Provider
///
/// 使用IDatabaseConnection接口注入，支持测试和依赖替换
@riverpod
IIllustrationRepository illustrationRepository(Ref ref) {
  final dbConnection = ref.watch(databaseConnectionProvider);
  return IllustrationRepository(dbConnection: dbConnection);
}

/// OutlineRepository Provider
///
/// 使用IDatabaseConnection接口注入，支持测试和依赖替换
@riverpod
IOutlineRepository outlineRepository(Ref ref) {
  final dbConnection = ref.watch(databaseConnectionProvider);
  return OutlineRepository(dbConnection: dbConnection);
}

/// ChatSceneRepository Provider
///
/// 使用IDatabaseConnection接口注入，支持测试和依赖替换
@riverpod
IChatSceneRepository chatSceneRepository(Ref ref) {
  final dbConnection = ref.watch(databaseConnectionProvider);
  return ChatSceneRepository(dbConnection: dbConnection);
}

/// BookshelfRepository Provider
///
/// 使用IDatabaseConnection接口注入，支持测试和依赖替换
@riverpod
IBookshelfRepository bookshelfRepository(Ref ref) {
  final dbConnection = ref.watch(databaseConnectionProvider);
  return BookshelfRepository(dbConnection: dbConnection);
}
