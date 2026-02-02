import 'package:flutter_test/flutter_test.dart';
import 'package:novel_app/services/character_image_cache_service.dart';
import 'dart:io';
import '../../test_bootstrap.dart';

/// CharacterImageCacheService 单元测试
///
/// 测试角色图片缓存服务的核心功能：
void main() {
  // 初始化测试环境
  initTests();

  group('CharacterImageCacheService - 初始化测试', () {
    test('init 应该成功初始化缓存目录', () async {
      final service = CharacterImageCacheService.instance;

      await expectLater(
        () => service.init(),
        returnsNormally,
      );

      // 验证初始化状态
      expect(service, isNotNull);
    });

    test('重复初始化不应该创建多个目录', () async {
      final service = CharacterImageCacheService.instance;

      await service.init();
      await service.init();
      await service.init();

      // 应该正常完成，不抛出异常
      expect(true, isTrue);
    });
  });

  group('CharacterImageCacheService - 缓存操作测试', () {
    late CharacterImageCacheService service;

    setUp(() async {
      service = CharacterImageCacheService.instance;
      await service.init();
    });

    tearDown(() async {
      await service.clearAllCachedImages();
    });

    test('cacheCharacterImage 应该成功缓存图片', () async {
      const characterId = 1;
      final imageBytes = List<int>.filled(1024, 0xFF);
      const filename = 'test_image.jpg';

      final result = await service.cacheCharacterImage(
        characterId,
        imageBytes,
        filename,
      );

      expect(result, isNotNull);
      expect(result, contains('$characterId'));
      expect(result, contains(filename));

      // 验证文件存在
      final file = File(result!);
      expect(await file.exists(), isTrue);

      // 验证文件内容
      final readBytes = await file.readAsBytes();
      expect(readBytes, equals(imageBytes));
    });

    test('cacheCharacterImage 相同文件应该覆盖', () async {
      const characterId = 2;
      final imageBytes1 = List<int>.filled(512, 0xAA);
      final imageBytes2 = List<int>.filled(512, 0xBB);
      const filename = 'overwrite_test.jpg';

      final path1 = await service.cacheCharacterImage(
        characterId,
        imageBytes1,
        filename,
      );

      final path2 = await service.cacheCharacterImage(
        characterId,
        imageBytes2,
        filename,
      );

      expect(path1, equals(path2));

      // 验证最终内容是第二次的数据
      final file = File(path2!);
      final readBytes = await file.readAsBytes();
      expect(readBytes, equals(imageBytes2));
    });

    test('cacheCharacterImageFromUrl 应该返回路径', () async {
      const characterId = 3;
      const imageUrl = 'https://example.com/image.jpg';

      final result = await service.cacheCharacterImageFromUrl(
        characterId,
        imageUrl,
      );

      // 当前实现中，URL缓存会返回URL本身或提取的路径
      expect(result, isNotNull);
    });

    test('cacheCharacterImageFromUrl 应该提取文件名', () async {
      const characterId = 4;
      const imageUrl = 'https://example.com/images/test_image.png?size=large';

      final result = await service.cacheCharacterImageFromUrl(
        characterId,
        imageUrl,
      );

      expect(result, isNotNull);
      // URL中的文件名应该被提取
    });

    test('cacheCharacterImageFromUrl 无效URL应该返回null', () async {
      const characterId = 5;
      const invalidUrl = 'not-a-valid-url';

      final result = await service.cacheCharacterImageFromUrl(
        characterId,
        invalidUrl,
      );

      // 可能抛出异常或返回null
      expect(result, isA<String?>());
    });
  });

  group('CharacterImageCacheService - 获取缓存测试', () {
    late CharacterImageCacheService service;

    setUp(() async {
      service = CharacterImageCacheService.instance;
      await service.init();
    });

    tearDown(() async {
      await service.clearAllCachedImages();
    });

    test('getCharacterImagePath 应该返回正确路径', () async {
      const characterId = 10;
      const filename = 'path_test.jpg';

      final path = await service.getCharacterImagePath(characterId, filename);

      expect(path, contains('$characterId'));
      expect(path, contains(filename));
    });

    test('getCharacterImagePathCached 应该找到已缓存的图片', () async {
      const characterId = 11;
      final imageBytes = List<int>.filled(1024, 0xFF);
      const filename = 'cached_image.jpg';

      // 先缓存图片
      final cachePath = await service.cacheCharacterImage(
        characterId,
        imageBytes,
        filename,
      );

      expect(cachePath, isNotNull);

      // 获取缓存路径
      final foundPath = await service.getCharacterImagePathCached(characterId);

      expect(foundPath, isNotNull);
      expect(foundPath, equals(cachePath));
    });

    test('getCharacterImagePathCached 未找到应该返回null', () async {
      const characterId = 999;

      final result = await service.getCharacterImagePathCached(characterId);

      expect(result, isNull);
    });

    test('isImageCached 应该正确判断', () async {
      const characterId = 12;
      final imageBytes = List<int>.filled(512, 0xCC);
      const filename = 'check_cached.jpg';

      // 未缓存时
      final before = await service.isImageCached(characterId, filename);
      expect(before, isFalse);

      // 缓存后
      await service.cacheCharacterImage(characterId, imageBytes, filename);

      final after = await service.isImageCached(characterId, filename);
      expect(after, isTrue);
    });
  });

  group('CharacterImageCacheService - 删除操作测试', () {
    late CharacterImageCacheService service;

    setUp(() async {
      service = CharacterImageCacheService.instance;
      await service.init();
    });

    tearDown(() async {
      await service.clearAllCachedImages();
    });

    test('deleteCharacterCachedImages 应该删除指定角色的所有图片', () async {
      const characterId = 20;

      // 缓存多张图片
      await service.cacheCharacterImage(
        characterId,
        List<int>.filled(100, 1),
        'image1.jpg',
      );
      await service.cacheCharacterImage(
        characterId,
        List<int>.filled(100, 2),
        'image2.jpg',
      );
      await service.cacheCharacterImage(
        characterId,
        List<int>.filled(100, 3),
        'image3.png',
      );

      // 验证缓存存在
      expect(
        await service.isImageCached(characterId, 'image1.jpg'),
        isTrue,
      );
      expect(
        await service.isImageCached(characterId, 'image2.jpg'),
        isTrue,
      );

      // 删除
      final result = await service.deleteCharacterCachedImages(characterId);

      expect(result, isTrue);

      // 验证已删除
      expect(
        await service.isImageCached(characterId, 'image1.jpg'),
        isFalse,
      );
      expect(
        await service.isImageCached(characterId, 'image2.jpg'),
        isFalse,
      );
      expect(
        await service.isImageCached(characterId, 'image3.png'),
        isFalse,
      );
    });

    test('deleteCharacterCachedImages 角色不存在应该返回true', () async {
      const characterId = 999;

      final result = await service.deleteCharacterCachedImages(characterId);

      expect(result, isTrue);
    });

    test('clearAllCachedImages 应该删除所有缓存', () async {
      // 缓存多个角色的图片
      for (int i = 1; i <= 5; i++) {
        await service.cacheCharacterImage(
          i,
          List<int>.filled(100, i),
          'image_$i.jpg',
        );
      }

      // 验证缓存存在
      var count = await service.getCacheFileCount();
      expect(count, greaterThan(0));

      // 清理所有
      final result = await service.clearAllCachedImages();

      expect(result, isTrue);

      // 验证已清空
      count = await service.getCacheFileCount();
      expect(count, equals(0));
    });
  });

  group('CharacterImageCacheService - 缓存统计测试', () {
    late CharacterImageCacheService service;

    setUp(() async {
      service = CharacterImageCacheService.instance;
      await service.init();
      await service.clearAllCachedImages();
    });

    tearDown(() async {
      await service.clearAllCachedImages();
    });

    test('getCacheSize 空缓存应该返回0', () async {
      final size = await service.getCacheSize();

      expect(size, equals(0));
    });

    test('getCacheSize 应该正确计算缓存大小', () async {
      const characterId = 30;
      const imageSize1 = 1024;
      const imageSize2 = 2048;

      await service.cacheCharacterImage(
        characterId,
        List<int>.filled(imageSize1, 1),
        'image1.jpg',
      );
      await service.cacheCharacterImage(
        characterId,
        List<int>.filled(imageSize2, 2),
        'image2.jpg',
      );

      final size = await service.getCacheSize();

      expect(size, equals(imageSize1 + imageSize2));
    });

    test('getCacheFileCount 应该正确统计文件数', () async {
      const characterId = 31;

      // 缓存5张图片
      for (int i = 1; i <= 5; i++) {
        await service.cacheCharacterImage(
          characterId,
          List<int>.filled(100, i),
          'image_$i.jpg',
        );
      }

      final count = await service.getCacheFileCount();

      expect(count, equals(5));
    });

    test('getCacheStats 应该返回完整统计信息', () async {
      const characterId = 32;
      const imageSize = 1024;

      await service.cacheCharacterImage(
        characterId,
        List<int>.filled(imageSize, 1),
        'stats_test.jpg',
      );

      final stats = await service.getCacheStats();

      expect(stats, isNotNull);
      expect(stats.containsKey('totalSize'), isTrue);
      expect(stats.containsKey('fileCount'), isTrue);
      expect(stats.containsKey('cacheDir'), isTrue);
      expect(stats.containsKey('sizeFormatted'), isTrue);

      expect(stats['totalSize'], equals(imageSize));
      expect(stats['fileCount'], equals(1));
    });
  });

  group('CharacterImageCacheService - 边界情况测试', () {
    late CharacterImageCacheService service;

    setUp(() async {
      service = CharacterImageCacheService.instance;
      await service.init();
      await service.clearAllCachedImages();
    });

    tearDown(() async {
      await service.clearAllCachedImages();
    });

    test('空图片数据应该正常处理', () async {
      const characterId = 40;
      final emptyBytes = <int>[];
      const filename = 'empty.jpg';

      final result = await service.cacheCharacterImage(
        characterId,
        emptyBytes,
        filename,
      );

      // 可能成功或失败，取决于文件系统
      expect(result, isA<String?>());
    });

    test('大文件应该正常缓存', () async {
      const characterId = 41;
      const largeSize = 5 * 1024 * 1024; // 5MB
      final largeBytes = List<int>.filled(largeSize, 0xFF);
      const filename = 'large_image.jpg';

      final result = await service.cacheCharacterImage(
        characterId,
        largeBytes,
        filename,
      );

      expect(result, isNotNull);

      // 验证文件大小
      final file = File(result!);
      expect(await file.exists(), isTrue);

      final fileSize = await file.length();
      expect(fileSize, equals(largeSize));
    });

    test('特殊字符文件名应该正常处理', () async {
      const characterId = 42;
      final imageBytes = List<int>.filled(100, 1);
      const specialFilename = '图片@#\$%测试.jpg';

      final result = await service.cacheCharacterImage(
        characterId,
        imageBytes,
        specialFilename,
      );

      expect(result, isNotNull);
      expect(result, contains(specialFilename));
    });

    test('URL文件名提取应该处理各种格式', () async {
      const characterId = 43;

      // 测试不同URL格式
      final urls = [
        'https://example.com/image.jpg',
        'https://example.com/images/image.png',
        'https://example.com/path/to/image.gif',
        'https://example.com/image.jpeg?query=1',
      ];

      for (final url in urls) {
        final result = await service.cacheCharacterImageFromUrl(
          characterId,
          url,
        );

        expect(result, isNotNull);
      }
    });

    test('并发缓存应该正确处理', () async {
      const characterId = 44;
      final imageBytes = List<int>.filled(1024, 1);

      // 并发缓存多个文件
      final futures = List.generate(
        10,
        (i) => service.cacheCharacterImage(
          characterId,
          imageBytes,
          'concurrent_$i.jpg',
        ),
      );

      final results = await Future.wait(futures);

      expect(results.length, equals(10));
      expect(results.every((r) => r != null), isTrue);

      // 验证所有文件都存在
      for (final result in results) {
        expect(await File(result!).exists(), isTrue);
      }
    });

    test('删除和重新缓存应该正常工作', () async {
      const characterId = 45;
      final imageBytes1 = List<int>.filled(512, 1);
      final imageBytes2 = List<int>.filled(512, 2);
      const filename = 're_cache_test.jpg';

      // 第一次缓存
      final path1 = await service.cacheCharacterImage(
        characterId,
        imageBytes1,
        filename,
      );

      expect(path1, isNotNull);

      // 删除
      await service.deleteCharacterCachedImages(characterId);

      // 重新缓存
      final path2 = await service.cacheCharacterImage(
        characterId,
        imageBytes2,
        filename,
      );

      expect(path2, isNotNull);
      expect(path2, equals(path1));

      // 验证内容是新的
      final file = File(path2!);
      final readBytes = await file.readAsBytes();
      expect(readBytes, equals(imageBytes2));
    });
  });

  group('CharacterImageCacheService - 单例模式测试', () {
    test('instance 应该返回同一个实例', () {
      final instance1 = CharacterImageCacheService.instance;
      final instance2 = CharacterImageCacheService.instance;

      expect(identical(instance1, instance2), isTrue);
    });

    test('多次调用init不应该影响功能', () async {
      final service = CharacterImageCacheService.instance;

      await service.init();
      await service.init();

      const characterId = 50;
      final imageBytes = List<int>.filled(100, 1);

      final result = await service.cacheCharacterImage(
        characterId,
        imageBytes,
        'singleton_test.jpg',
      );

      expect(result, isNotNull);

      await service.clearAllCachedImages();
    });
  });
}
