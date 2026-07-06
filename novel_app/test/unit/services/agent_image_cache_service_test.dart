/// AgentImageCacheService 单元测试
///
/// 验证文生图本地缓存：
/// - getFile 命中/未命中
/// - saveBytes 写入 + 幂等覆盖
/// - imageId 自动补 .png 后缀 / 已带后缀不重复
///
/// 使用 test_bootstrap 的 initTests() 注入 _FakePathProviderPlatform
/// （指向 /tmp/test_app_documents），每个测试前清理缓存目录避免污染。
///
/// 运行：
///   cd novel_app
///   flutter test test/unit/services/agent_image_cache_service_test.dart
library;

import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import '../../test_bootstrap.dart';
import 'package:novel_app/services/agent_image_cache_service.dart';

void main() {
  // _FakePathProviderPlatform 把文档目录指向 /tmp/test_app_documents
  final cacheDir = Directory('/tmp/test_app_documents/agent_images');

  setUpAll(() {
    initTests();
  });

  setUp(() {
    // 每个测试前清空缓存目录，保证隔离
    if (cacheDir.existsSync()) {
      cacheDir.deleteSync(recursive: true);
    }
  });

  tearDown(() {
    if (cacheDir.existsSync()) {
      cacheDir.deleteSync(recursive: true);
    }
  });

  group('AgentImageCacheService - getFile', () {
    test('未写入时返回 null', () async {
      final file = await AgentImageCacheService.instance.getFile('img_none');
      expect(file, isNull);
    });

    test('写入后命中返回 File', () async {
      const imageId = 'img_123_0';
      await AgentImageCacheService.instance
          .saveBytes(imageId, Uint8List.fromList([1, 2, 3, 4]));

      final file = await AgentImageCacheService.instance.getFile(imageId);
      expect(file, isNotNull);
      expect(await file!.exists(), true);
      expect(await file.length(), 4);
    });

    test('空文件（长度 0）视为未命中返回 null', () async {
      const imageId = 'img_empty';
      // 手动创建空文件，绕过 saveBytes 的正常写入
      await cacheDir.create(recursive: true);
      File('${cacheDir.path}${Platform.pathSeparator}$imageId.png')
          .writeAsBytesSync(const []);

      final file = await AgentImageCacheService.instance.getFile(imageId);
      expect(file, isNull, reason: '0 字节文件应视为未命中');
    });
  });

  group('AgentImageCacheService - saveBytes', () {
    test('写入内容可被读回', () async {
      const imageId = 'img_save_1';
      final bytes =
          Uint8List.fromList(List.generate(256, (i) => i % 256));
      await AgentImageCacheService.instance.saveBytes(imageId, bytes);

      final file = await AgentImageCacheService.instance.getFile(imageId);
      expect(file, isNotNull);
      final readBack = await file!.readAsBytes();
      expect(readBack.length, 256);
      expect(readBack[0], 0);
      expect(readBack[255], 255);
    });

    test('同名重复写入幂等覆盖', () async {
      const imageId = 'img_overwrite';
      await AgentImageCacheService.instance
          .saveBytes(imageId, Uint8List.fromList([1, 2, 3]));
      await AgentImageCacheService.instance
          .saveBytes(imageId, Uint8List.fromList([9, 8, 7, 6, 5]));

      final file = await AgentImageCacheService.instance.getFile(imageId);
      expect(file, isNotNull);
      expect(await file!.length(), 5, reason: '应以最后一次写入为准');
      final readBack = await file.readAsBytes();
      expect(readBack, [9, 8, 7, 6, 5]);
    });
  });

  group('AgentImageCacheService - 文件名规范', () {
    test('imageId 不带 .png 后缀时自动补全', () async {
      const imageId = 'img_nosuffix';
      await AgentImageCacheService.instance
          .saveBytes(imageId, Uint8List.fromList([0]));

      final expected =
          File('${cacheDir.path}${Platform.pathSeparator}img_nosuffix.png');
      expect(await expected.exists(), true,
          reason: '文件名应为 <imageId>.png');
    });

    test('imageId 已带 .png 后缀时不重复追加', () async {
      const imageId = 'img_withsuffix.png';
      await AgentImageCacheService.instance
          .saveBytes(imageId, Uint8List.fromList([0]));

      final correct =
          File('${cacheDir.path}${Platform.pathSeparator}img_withsuffix.png');
      final doubled = File(
          '${cacheDir.path}${Platform.pathSeparator}img_withsuffix.png.png');
      expect(await correct.exists(), true);
      expect(await doubled.exists(), false, reason: '不应出现 .png.png 双后缀');
    });
  });

  group('AgentImageCacheService - 目录惰性创建', () {
    test('缓存目录不存在时自动创建', () async {
      // setUp 已删除目录，这里验证写入会自动 mkdir
      expect(cacheDir.existsSync(), false);
      await AgentImageCacheService.instance
          .saveBytes('img_autodir', Uint8List.fromList([1]));
      expect(cacheDir.existsSync(), true,
          reason: '首次写入应自动创建 agent_images 目录');
    });
  });
}
