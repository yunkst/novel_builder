import '../models/novel.dart';
import '../models/character.dart';
import '../models/character_update.dart';
import '../services/dify_service.dart';
import '../services/database_service.dart';
import '../utils/character_matcher.dart';
import 'logger_service.dart';

/// CharacterCardService
///
/// 职责：
/// - 角色卡片更新的完整流程管理
/// - 准备更新数据（章节内容、现有角色信息）
/// - 调用AI服务更新角色信息
/// - 保存更新后的角色到数据库
/// - 错误处理和日志记录
///
/// 使用方式：
/// ```dart
/// final service = CharacterCardService();
/// await service.updateCharacterCards(
///   novel: novel,
///   chapterContent: content,
///   onProgress: (message) => print(message),
///   onSuccess: (characters) => print('成功更新${characters.length}个角色'),
///   onError: (error) => print('错误: $error'),
/// );
/// ```
class CharacterCardService {
  final DifyService _difyService;
  final DatabaseService _databaseService;

  CharacterCardService({
    DifyService? difyService,
    DatabaseService? databaseService,
  })  : _difyService = difyService ?? DifyService(),
        _databaseService = databaseService ?? DatabaseService();

  /// 更新角色卡片
  ///
  /// [novel] 小说对象
  /// [chapterContent] 章节内容
  /// [onProgress] 进度回调（可选）
  /// [onSuccess] 成功回调（可选）
  /// [onError] 错误回调（可选）
  Future<List<Character>> updateCharacterCards({
    required Novel novel,
    required String chapterContent,
    void Function(String message)? onProgress,
    void Function(List<Character> characters)? onSuccess,
    void Function(dynamic error)? onError,
  }) async {
    try {
      onProgress?.call('开始更新角色卡...');
      LoggerService.instance.i(
        '开始更新角色卡',
        category: LogCategory.character,
        tags: ['card', 'update', 'start'],
      );
      LoggerService.instance.d(
        '小说: ${novel.title}, 章节内容长度: ${chapterContent.length}',
        category: LogCategory.character,
        tags: ['card', 'update', 'info'],
      );

      // 验证章节内容
      if (chapterContent.isEmpty) {
        final error = '章节内容为空，无法更新角色卡';
        onProgress?.call(error);
        onError?.call(error);
        throw Exception(error);
      }

      // 准备更新数据
      onProgress?.call('正在分析章节内容并准备数据...');
      final updateData = await CharacterMatcher.prepareUpdateData(
        novel.url,
        chapterContent,
      );

      LoggerService.instance.d(
        '章节内容长度: ${updateData['chapters_content']!.length}, 角色信息: ${updateData['roles']}',
        category: LogCategory.character,
        tags: ['card', 'update', 'prepare'],
      );

      // 调用AI服务更新角色信息
      onProgress?.call('正在调用AI服务更新角色信息...');
      final updatedCharacters = await _difyService.updateCharacterCards(
        chaptersContent: updateData['chapters_content']!,
        roles: updateData['roles']!,
        novelUrl: novel.url,
        backgroundSetting: novel.backgroundSetting ?? '',
      );

      LoggerService.instance.i(
        'Dify返回角色数量: ${updatedCharacters.length}',
        category: LogCategory.character,
        tags: ['card', 'update', 'ai_response'],
      );

      // 自动保存所有角色（不显示预览对话框，让UI层决定是否需要预览）
      onProgress?.call('正在保存角色信息...');
      final savedCharacters =
          await _databaseService.batchUpdateCharacters(updatedCharacters);

      onProgress?.call('成功更新 ${savedCharacters.length} 个角色卡');
      onSuccess?.call(savedCharacters);

      LoggerService.instance.i(
        '角色更新完成: ${savedCharacters.length} 个',
        category: LogCategory.character,
        tags: ['card', 'update', 'success'],
      );
      return savedCharacters;
    } catch (e, stackTrace) {
      LoggerService.instance.e(
        '更新角色卡失败: $e',
        stackTrace: stackTrace.toString(),
        category: LogCategory.character,
        tags: ['card', 'update', 'error'],
      );
      onProgress?.call('更新角色卡失败: $e');
      onError?.call(e);
      rethrow;
    }
  }

  /// 仅更新角色信息，不保存到数据库
  ///
  /// 用于需要预览的场景
  /// 返回 CharacterUpdate 列表,包含新旧角色对比信息
  Future<List<CharacterUpdate>> previewCharacterUpdates({
    required Novel novel,
    required String chapterContent,
    void Function(String message)? onProgress,
  }) async {
    try {
      onProgress?.call('正在分析章节内容...');

      // 获取现有角色用于对比
      final existingCharacters =
          await _databaseService.getCharacters(novel.url);

      final updateData = await CharacterMatcher.prepareUpdateData(
        novel.url,
        chapterContent,
      );

      onProgress?.call('正在调用AI服务...');
      final updatedCharacters = await _difyService.updateCharacterCards(
        chaptersContent: updateData['chapters_content']!,
        roles: updateData['roles']!,
        novelUrl: novel.url,
        backgroundSetting: novel.backgroundSetting ?? '',
      );

      LoggerService.instance.i(
        '预览完成，角色数量: ${updatedCharacters.length}',
        category: LogCategory.character,
        tags: ['card', 'preview', 'complete'],
      );

      // 包装为 CharacterUpdate 列表
      final characterUpdates = updatedCharacters.map((newChar) {
        final oldChar = _findBestMatch(newChar, existingCharacters);
        return CharacterUpdate(
          newCharacter: newChar,
          oldCharacter: oldChar,
        );
      }).toList();

      final newCount = characterUpdates.where((u) => u.isNew).length;
      final updateCount = characterUpdates.where((u) => u.isUpdate).length;
      LoggerService.instance.i(
        '新增: $newCount, 更新: $updateCount',
        category: LogCategory.character,
        tags: ['card', 'preview', 'stats'],
      );

      return characterUpdates;
    } catch (e, stackTrace) {
      LoggerService.instance.e(
        '预览失败: $e',
        stackTrace: stackTrace.toString(),
        category: LogCategory.character,
        tags: ['card', 'preview', 'error'],
      );
      rethrow;
    }
  }

  /// 查找最佳匹配的角色
  ///
  /// 支持精确匹配和包含匹配,提升AI返回名称的容错性
  Character? _findBestMatch(Character newChar, List<Character> existingChars) {
    if (existingChars.isEmpty) return null;

    // 1. 精确匹配
    for (final char in existingChars) {
      if (char.name == newChar.name) {
        LoggerService.instance.d(
          '角色匹配: 精确匹配 "${newChar.name}"',
          category: LogCategory.character,
          tags: ['card', 'match', 'exact'],
        );
        return char;
      }
    }

    // 2. 包含匹配(如"张三"匹配"张三丰")
    for (final char in existingChars) {
      if (char.name.contains(newChar.name) ||
          newChar.name.contains(char.name)) {
        LoggerService.instance.d(
          '角色匹配: 包含匹配 "${newChar.name}" -> "${char.name}"',
          category: LogCategory.character,
          tags: ['card', 'match', 'partial'],
        );
        return char;
      }
    }

    LoggerService.instance.d(
      '角色匹配: 未找到匹配 "${newChar.name}"视为新增',
      category: LogCategory.character,
      tags: ['card', 'match', 'new'],
    );
    return null; // 无法匹配,视为新增
  }

  /// 保存角色到数据库
  ///
  /// 用于用户确认预览后保存
  Future<List<Character>> saveCharacters(List<Character> characters) async {
    try {
      LoggerService.instance.i(
        '开始保存 ${characters.length} 个角色',
        category: LogCategory.character,
        tags: ['card', 'save', 'start'],
      );
      final savedCharacters =
          await _databaseService.batchUpdateCharacters(characters);
      LoggerService.instance.i(
        '保存完成',
        category: LogCategory.character,
        tags: ['card', 'save', 'success'],
      );
      return savedCharacters;
    } catch (e, stackTrace) {
      LoggerService.instance.e(
        '保存失败: $e',
        stackTrace: stackTrace.toString(),
        category: LogCategory.character,
        tags: ['card', 'save', 'error'],
      );
      rethrow;
    }
  }
}
