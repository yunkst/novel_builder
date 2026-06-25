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
import '../../repositories/novel_export_repository.dart';
import '../../repositories/prompt_history_repository.dart';
import '../../repositories/prompt_tag_category_repository.dart';
import '../../repositories/prompt_tag_repository.dart';
import '../../repositories/prompt_tag_history_repository.dart';
import '../../repositories/site_script_repository.dart';
import '../../repositories/agent_memory_repository.dart';
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
import '../interfaces/repositories/i_prompt_history_repository.dart';
import '../interfaces/repositories/i_prompt_tag_category_repository.dart';
import '../interfaces/repositories/i_prompt_tag_repository.dart';

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
// ignore: deprecated_member_use_from_same_package
final databaseServiceProvider = Provider<DatabaseService>((ref) {
  // ignore: deprecated_member_use_from_same_package
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

/// PromptHistoryRepository Provider
@riverpod
IPromptHistoryRepository promptHistoryRepository(Ref ref) {
  final dbConnection = ref.watch(databaseConnectionProvider);
  return PromptHistoryRepository(dbConnection: dbConnection);
}

/// PromptTagCategoryRepository Provider
@riverpod
IPromptTagCategoryRepository promptTagCategoryRepository(Ref ref) {
  final dbConnection = ref.watch(databaseConnectionProvider);
  return PromptTagCategoryRepository(dbConnection: dbConnection);
}

/// PromptTagRepository Provider
@riverpod
IPromptTagRepository promptTagRepository(Ref ref) {
  final dbConnection = ref.watch(databaseConnectionProvider);
  return PromptTagRepository(dbConnection: dbConnection);
}

/// PromptTagHistoryRepository Provider
///
/// 使用普通 Provider 定义（无需 build_runner 重新生成），
/// 记录 AI 自省对 tag 的修改历史，支持回滚。
final promptTagHistoryRepositoryProvider =
    Provider<PromptTagHistoryRepository>((ref) {
  final dbConnection = ref.watch(databaseConnectionProvider);
  return PromptTagHistoryRepository(dbConnection: dbConnection);
});

/// BookshelfRepository Provider
///
/// 使用IDatabaseConnection接口注入，支持测试和依赖替换
@riverpod
IBookshelfRepository bookshelfRepository(Ref ref) {
  final dbConnection = ref.watch(databaseConnectionProvider);
  return BookshelfRepository(dbConnection: dbConnection);
}

/// NovelExportRepository Provider
///
/// 用于小说数据的导出和导入操作
/// 依赖其他Repository，不直接依赖数据库连接
@riverpod
NovelExportRepository novelExportRepository(Ref ref) {
  final chapterRepository = ref.watch(chapterRepositoryProvider);
  final characterRepository = ref.watch(characterRepositoryProvider);
  final characterRelationRepository = ref.watch(characterRelationRepositoryProvider);
  final outlineRepository = ref.watch(outlineRepositoryProvider);

  return NovelExportRepository(
    chapterRepository: chapterRepository,
    characterRepository: characterRepository,
    characterRelationRepository: characterRelationRepository,
    outlineRepository: outlineRepository,
  );
}

/// SiteScriptRepository Provider
///
/// 站点提取脚本的持久化操作
final siteScriptRepositoryProvider = Provider<SiteScriptRepository>((ref) {
  final dbConnection = ref.watch(databaseConnectionProvider);
  return SiteScriptRepository(dbConnection: dbConnection);
});

/// AgentMemoryRepository Provider
///
/// Agent 场景经验记忆的持久化操作
final agentMemoryRepositoryProvider = Provider<AgentMemoryRepository>((ref) {
  final dbConnection = ref.watch(databaseConnectionProvider);
  return AgentMemoryRepository(dbConnection: dbConnection);
});
