import 'package:flutter_test/flutter_test.dart';
import 'package:novel_app/services/character_avatar_service.dart';
import 'package:novel_app/services/database_service.dart';
import 'package:novel_app/services/character_image_cache_service.dart';
import 'package:novel_app/models/character.dart';
import 'dart:io';
import '../../test_bootstrap.dart';

/// CharacterAvatarService 单元测试
///
/// 测试角色头像管理服务的核心功能
void main() {
  // 初始化测试环境
  initTests();

  group('CharacterAvatarService - 基本功能测试', () {
    late CharacterAvatarService avatarService;
    late DatabaseService dbService;
    late CharacterImageCacheService cacheService;

    setUp(() async {
      avatarService = CharacterAvatarService();
      // 使用全局DatabaseService单例，因为CharacterAvatarService内部使用单例
      dbService = DatabaseService();
      cacheService = CharacterImageCacheService.instance;

      await dbService.database;
      await cacheService.init();
    });

    tearDown(() async {
      await cacheService.clearAllCachedImages();
      // 清理测试数据
      final db = await dbService.database;
      await db.delete('characters');
    });

    test('服务应该成功初始化', () {
      expect(avatarService, isNotNull);
      expect(cacheService, isNotNull);
    });

    test('setCharacterAvatar 应该成功设置头像', () async {
      // 先创建测试角色
      const characterId = 1;
      final character = Character(
        id: characterId,
        novelUrl: 'https://test.com/novel/1',
        name: '测试角色',
      );
      await dbService.createCharacter(character);

      // 创建测试图片数据
      final imageBytes = List<int>.filled(1024, 0xFF);
      const originalFilename = 'test_avatar.jpg';

      // 设置头像
      final result = await avatarService.setCharacterAvatar(
        characterId,
        imageBytes,
        originalFilename,
      );

      // 验证结果
      expect(result, isNotNull);
      expect(result, contains('avatar'));
      expect(result, contains('.jpg'));

      // 验证可以获取头像路径
      final avatarPath = await avatarService.getCharacterAvatarPath(characterId);
      expect(avatarPath, equals(result));

      // 验证头像文件存在
      final avatarFile = File(result!);
      expect(await avatarFile.exists(), isTrue);
    });

    test('getCharacterAvatarPath 没有头像应该返回null', () async {
      const characterId = 999;

      final result = await avatarService.getCharacterAvatarPath(characterId);

      expect(result, isNull);
    });

    test('hasCharacterAvatar 应该正确判断', () async {
      const characterId = 2;
      // 先创建测试角色
      final character = Character(
        id: characterId,
        novelUrl: 'https://test.com/novel/1',
        name: '测试角色2',
      );
      await dbService.createCharacter(character);

      final imageBytes = List<int>.filled(1024, 0xFF);

      // 初始状态：没有头像
      final hasBefore = await avatarService.hasCharacterAvatar(characterId);
      expect(hasBefore, isFalse);

      // 设置头像
      await avatarService.setCharacterAvatar(
        characterId,
        imageBytes,
        'avatar.jpg',
      );

      // 验证有头像
      final hasAfter = await avatarService.hasCharacterAvatar(characterId);
      expect(hasAfter, isTrue);
    });

    test('deleteCharacterAvatar 应该删除文件和数据库记录', () async {
      const characterId = 3;
      // 先创建测试角色
      final character = Character(
        id: characterId,
        novelUrl: 'https://test.com/novel/1',
        name: '测试角色3',
      );
      await dbService.createCharacter(character);

      final imageBytes = List<int>.filled(1024, 0xFF);

      // 设置头像
      final cachedPath = await avatarService.setCharacterAvatar(
        characterId,
        imageBytes,
        'to_delete.jpg',
      );

      expect(cachedPath, isNotNull);
      final fileExists = await File(cachedPath!).exists();
      expect(fileExists, isTrue);

      // 删除头像
      final result = await avatarService.deleteCharacterAvatar(characterId);
      expect(result, isTrue);

      // 验证文件被删除
      final fileExistsAfter = await File(cachedPath).exists();
      expect(fileExistsAfter, isFalse); // 文件已被删除

      // 验证数据库记录被清空
      final avatarPath = await avatarService.getCharacterAvatarPath(characterId);
      expect(avatarPath, isNull);
    });

    test('syncGalleryImageToAvatar 文件不存在应该返回null', () async {
      const characterId = 4;

      final result = await avatarService.syncGalleryImageToAvatar(
        characterId,
        '/nonexistent/path/image.jpg',
        'image.jpg',
      );

      expect(result, isNull);
    });
  });

  group('CharacterAvatarService - 边界情况测试', () {
    late CharacterAvatarService avatarService;
    late DatabaseService dbService;
    late CharacterImageCacheService cacheService;

    setUp(() async {
      avatarService = CharacterAvatarService();
      // 使用全局DatabaseService单例，因为CharacterAvatarService内部使用单例
      dbService = DatabaseService();
      cacheService = CharacterImageCacheService.instance;

      await dbService.database;
      await cacheService.init();
    });

    tearDown(() async {
      await cacheService.clearAllCachedImages();
      // 清理测试数据
      final db = await dbService.database;
      await db.delete('characters');
    });

    test('空图片数据应该正常处理', () async {
      const characterId = 10;
      // 先创建测试角色
      final character = Character(
        id: characterId,
        novelUrl: 'https://test.com/novel/1',
        name: '测试角色10',
      );
      await dbService.createCharacter(character);

      final emptyBytes = <int>[];

      final result = await avatarService.setCharacterAvatar(
        characterId,
        emptyBytes,
        'empty.jpg',
      );

      expect(result, isA<String?>());
    });

    test('特殊字符文件名应该正常处理', () async {
      const characterId = 11;
      // 先创建测试角色
      final character = Character(
        id: characterId,
        novelUrl: 'https://test.com/novel/1',
        name: '测试角色11',
      );
      await dbService.createCharacter(character);

      final imageBytes = List<int>.filled(1024, 0xFF);
      const specialFilename = '图片@#\$%测试.jpg';

      final result = await avatarService.setCharacterAvatar(
        characterId,
        imageBytes,
        specialFilename,
      );

      expect(result, isNotNull);
    });

    test('批量操作多个角色头像应该正确处理', () async {
      final imageBytes = List<int>.filled(1024, 0xFF);

      // 创建多个角色头像
      for (int i = 1; i <= 5; i++) {
        final characterId = i + 20;
        // 先创建测试角色
        final character = Character(
          id: characterId,
          novelUrl: 'https://test.com/novel/1',
          name: '测试角色$characterId',
        );
        await dbService.createCharacter(character);

        final result = await avatarService.setCharacterAvatar(
          characterId,
          imageBytes,
          'avatar_$i.jpg',
        );

        expect(result, isNotNull);
      }

      // 验证所有角色都有头像
      for (int i = 1; i <= 5; i++) {
        final hasAvatar = await avatarService.hasCharacterAvatar(i + 20);
        expect(hasAvatar, isTrue);
      }
    });

    test('cleanupAllInvalidAvatarCaches 应该完成不抛异常', () async {
      await expectLater(
        () => avatarService.cleanupAllInvalidAvatarCaches(),
        returnsNormally,
      );
    });
  });

  group('CharacterAvatarService - 文件系统测试', () {
    late CharacterAvatarService avatarService;
    late DatabaseService dbService;
    late CharacterImageCacheService cacheService;

    setUp(() async {
      avatarService = CharacterAvatarService();
      // 使用全局DatabaseService单例，因为CharacterAvatarService内部使用单例
      dbService = DatabaseService();
      cacheService = CharacterImageCacheService.instance;

      await dbService.database;
      await cacheService.init();
    });

    tearDown(() async {
      await cacheService.clearAllCachedImages();
      // 清理测试数据
      final db = await dbService.database;
      await db.delete('characters');
    });

    test('缓存图片应该实际写入文件系统', () async {
      const characterId = 30;
      // 先创建测试角色
      final character = Character(
        id: characterId,
        novelUrl: 'https://test.com/novel/1',
        name: '测试角色30',
      );
      await dbService.createCharacter(character);

      // 创建特定模式的图片数据
      final imageBytes = List<int>.generate(1024, (i) => i % 256);
      const filename = 'filesystem_test.jpg';

      final cachedPath = await avatarService.setCharacterAvatar(
        characterId,
        imageBytes,
        filename,
      );

      expect(cachedPath, isNotNull);

      // 验证文件存在
      final file = File(cachedPath!);
      expect(await file.exists(), isTrue);

      // 验证文件内容
      final readBytes = await file.readAsBytes();
      expect(readBytes.length, equals(imageBytes.length));
      expect(readBytes, equals(imageBytes));
    });
  });
}
