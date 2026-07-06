/// parseImageGallery 解析器单元测试
///
/// 验证 create_images 工具结果 JSON 的解析逻辑（纯函数，无依赖）。
/// 覆盖：null、非法 JSON、success=false、images 缺失/空、元素缺关键字段、
/// 完整有效数据、modelName 可选字段。
///
/// 运行：
///   cd novel_app
///   flutter test test/unit/services/novel_agent/image_gallery_parser_test.dart
library;

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:novel_app/widgets/agent_chat/image_gallery_card.dart';

void main() {
  group('parseImageGallery - 边界返回 null', () {
    test('null 输入返回 null', () {
      expect(parseImageGallery(null), isNull);
    });

    test('空字符串返回 null', () {
      expect(parseImageGallery(''), isNull);
    });

    test('非 JSON 字符串返回 null', () {
      expect(parseImageGallery('not a json'), isNull);
    });

    test('JSON 非 Map 返回 null', () {
      expect(parseImageGallery('[1,2,3]'), isNull);
      expect(parseImageGallery('"string"'), isNull);
      expect(parseImageGallery('42'), isNull);
    });
  });

  group('parseImageGallery - success 标志', () {
    test('success 缺失返回 null', () {
      expect(parseImageGallery('{"images":[]}'), isNull);
    });

    test('success=false 返回 null（即使有 images）', () {
      final json = jsonEncode({
        'success': false,
        'error': 'backend_unavailable',
        'images': [
          {'imageId': 'a', 'taskId': 'b'}
        ],
      });
      expect(parseImageGallery(json), isNull);
    });

    test('success=true 但 images 缺失返回 null', () {
      expect(parseImageGallery('{"success":true}'), isNull);
    });

    test('success=true 但 images 为空数组返回 null', () {
      expect(parseImageGallery('{"success":true,"images":[]}'), isNull);
    });

    test('success=true 但 images 非 List 返回 null', () {
      expect(
        parseImageGallery('{"success":true,"images":{"a":1}}'),
        isNull,
      );
    });
  });

  group('parseImageGallery - 元素字段校验', () {
    test('元素缺 imageId 时被跳过', () {
      final json = jsonEncode({
        'success': true,
        'images': [
          {'taskId': 't1'}, // 缺 imageId
        ],
      });
      expect(parseImageGallery(json), isNull, reason: '全部元素无效时应返回 null');
    });

    test('元素缺 taskId 时被跳过', () {
      final json = jsonEncode({
        'success': true,
        'images': [
          {'imageId': 'i1'}, // 缺 taskId
        ],
      });
      expect(parseImageGallery(json), isNull);
    });

    test('部分元素无效时仅保留有效元素', () {
      final json = jsonEncode({
        'success': true,
        'images': [
          {'imageId': 'valid', 'taskId': 't1'},
          {'taskId': 'no_id'}, // 缺 imageId
          {'imageId': 'also_valid', 'taskId': 't2', 'modelName': '写实1'},
        ],
      });
      final data = parseImageGallery(json);
      expect(data, isNotNull);
      expect(data!.images.length, 2);
      expect(data.images[0].imageId, 'valid');
      expect(data.images[1].imageId, 'also_valid');
      expect(data.images[1].modelName, '写实1');
    });
  });

  group('parseImageGallery - 完整有效数据', () {
    test('单图正常解析', () {
      final json = jsonEncode({
        'success': true,
        'message': '已提交 1 张图片生成任务',
        'images': [
          {
            'imageId': 'img_1700000000000_0',
            'taskId': 'e7dd42b0-ee1a-48c9-ac30-d7001480ad97',
            'prompt': '1girl, anime style',
            'modelName': '动漫风17.5',
          }
        ],
        'count': 1,
      });
      final data = parseImageGallery(json);
      expect(data, isNotNull);
      expect(data!.images.length, 1);
      final item = data.images.first;
      expect(item.imageId, 'img_1700000000000_0');
      expect(item.taskId, 'e7dd42b0-ee1a-48c9-ac30-d7001480ad97');
      expect(item.prompt, '1girl, anime style');
      expect(item.modelName, '动漫风17.5');
    });

    test('多图正常解析（顺序保留）', () {
      final json = jsonEncode({
        'success': true,
        'images': [
          {'imageId': 'img_1', 'taskId': 't1', 'prompt': 'p1'},
          {'imageId': 'img_2', 'taskId': 't2', 'prompt': 'p2'},
          {'imageId': 'img_3', 'taskId': 't3', 'prompt': 'p3'},
        ],
      });
      final data = parseImageGallery(json);
      expect(data, isNotNull);
      expect(data!.images.map((i) => i.imageId).toList(),
          ['img_1', 'img_2', 'img_3']);
    });

    test('prompt 缺失时回退为空字符串', () {
      final json = jsonEncode({
        'success': true,
        'images': [
          {'imageId': 'i1', 'taskId': 't1'},
        ],
      });
      final data = parseImageGallery(json);
      expect(data, isNotNull);
      expect(data!.images.first.prompt, '');
    });

    test('modelName 缺失时为 null', () {
      final json = jsonEncode({
        'success': true,
        'images': [
          {'imageId': 'i1', 'taskId': 't1', 'prompt': 'x'},
        ],
      });
      final data = parseImageGallery(json);
      expect(data, isNotNull);
      expect(data!.images.first.modelName, isNull);
    });
  });
}
