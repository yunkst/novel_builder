import 'package:flutter/foundation.dart';
import '../models/novel.dart';
import '../models/character.dart';
import '../services/dify_service.dart';
import '../services/database_service.dart';
import '../utils/character_matcher.dart';

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
  final DifyService _difyService = DifyService();
  final DatabaseService _databaseService = DatabaseService();

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
      debugPrint('=== CharacterCardService: 开始更新角色卡 ===');
      debugPrint('小说: ${novel.title}');
      debugPrint('章节内容长度: ${chapterContent.length}');

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

      debugPrint('章节内容长度: ${updateData['chapters_content']!.length}');
      debugPrint('角色信息: ${updateData['roles']}');

      // 调用AI服务更新角色信息
      onProgress?.call('正在调用AI服务更新角色信息...');
      final updatedCharacters = await _difyService.updateCharacterCards(
        chaptersContent: updateData['chapters_content']!,
        roles: updateData['roles']!,
        novelUrl: novel.url,
        backgroundSetting: novel.backgroundSetting ?? '',
      );

      debugPrint('=== Dify返回角色数量: ${updatedCharacters.length} ===');

      // 自动保存所有角色（不显示预览对话框，让UI层决定是否需要预览）
      onProgress?.call('正在保存角色信息...');
      final savedCharacters =
          await _databaseService.batchUpdateCharacters(updatedCharacters);

      onProgress?.call('成功更新 ${savedCharacters.length} 个角色卡');
      onSuccess?.call(savedCharacters);

      debugPrint(
          '=== CharacterCardService: 角色更新完成: ${savedCharacters.length} 个 ===');
      return savedCharacters;
    } catch (e) {
      debugPrint('=== CharacterCardService: 更新角色卡失败: $e ===');
      onProgress?.call('更新角色卡失败: $e');
      onError?.call(e);
      rethrow;
    }
  }

  /// 仅更新角色信息，不保存到数据库
  ///
  /// 用于需要预览的场景
  Future<List<Character>> previewCharacterUpdates({
    required Novel novel,
    required String chapterContent,
    void Function(String message)? onProgress,
  }) async {
    try {
      onProgress?.call('正在分析章节内容...');
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

      debugPrint(
          '=== CharacterCardService: 预览完成，角色数量: ${updatedCharacters.length} ===');
      return updatedCharacters;
    } catch (e) {
      debugPrint('=== CharacterCardService: 预览失败: $e ===');
      rethrow;
    }
  }

  /// 保存角色到数据库
  ///
  /// 用于用户确认预览后保存
  Future<List<Character>> saveCharacters(List<Character> characters) async {
    try {
      debugPrint('=== CharacterCardService: 开始保存 ${characters.length} 个角色 ===');
      final savedCharacters =
          await _databaseService.batchUpdateCharacters(characters);
      debugPrint('=== CharacterCardService: 保存完成 ===');
      return savedCharacters;
    } catch (e) {
      debugPrint('=== CharacterCardService: 保存失败: $e ===');
      rethrow;
    }
  }
}
