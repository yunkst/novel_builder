import 'package:flutter_test/flutter_test.dart';
import 'package:novel_app/models/role_gallery.dart';
import '../../test_bootstrap.dart';

/// CharacterAvatarSyncService 单元测试
///
/// 测试角色头像同步服务的核心功能
void main() {
  // 初始化测试环境
  initTests();
  group('CharacterAvatarSyncService - RoleImage模型测试', () {
    test('RoleImage 应该正确创建', () {
      final image = RoleImage(
        filename: 'test.jpg',
        createdAt: DateTime.now(),
        thumbnailUrl: 'https://example.com/thumb.jpg',
      );

      expect(image.filename, equals('test.jpg'));
      expect(image.thumbnailUrl, equals('https://example.com/thumb.jpg'));
    });

    test('RoleImage fromJson 应该解析URL字段', () {
      final json = {
        'url': 'image.jpg',
        'created_at': '2024-01-01T00:00:00.000Z',
      };

      final image = RoleImage.fromJson(json);

      expect(image.filename, equals('image.jpg'));
      expect(image.createdAt, isA<DateTime>());
    });

    test('RoleImage fromJson 应该解析filename字段', () {
      final json = {
        'filename': 'filename.jpg',
        'created_at': '2024-01-01T00:00:00.000Z',
      };

      final image = RoleImage.fromJson(json);

      expect(image.filename, equals('filename.jpg'));
    });

    test('RoleImage copyWith 应该正确复制', () {
      final image = RoleImage(
        filename: 'test.jpg',
        createdAt: DateTime(2024, 1, 1),
      );

      final copied = image.copyWith(
        filename: 'new.jpg',
        thumbnailUrl: 'thumb.jpg',
      );

      expect(copied.filename, equals('new.jpg'));
      expect(copied.thumbnailUrl, equals('thumb.jpg'));
      expect(copied.createdAt, equals(image.createdAt));
    });

    test('RoleImage 相等性比较应该工作', () {
      final image1 = RoleImage(
        filename: 'test.jpg',
        createdAt: DateTime(2024, 1, 1),
      );

      final image2 = RoleImage(
        filename: 'test.jpg',
        createdAt: DateTime(2024, 1, 2),
      );

      final image3 = RoleImage(
        filename: 'other.jpg',
        createdAt: DateTime(2024, 1, 1),
      );

      expect(image1, equals(image2)); // 文件名相同
      expect(image1, isNot(equals(image3))); // 文件名不同
    });
  });

  group('CharacterAvatarSyncService - RoleGallery模型测试', () {
    test('RoleGallery 应该正确创建', () {
      final gallery = RoleGallery(
        roleId: '1',
        images: [
          RoleImage(
            filename: 'image1.jpg',
            createdAt: DateTime(2024, 1, 1),
          ),
          RoleImage(
            filename: 'image2.jpg',
            createdAt: DateTime(2024, 1, 2),
          ),
        ],
      );

      expect(gallery.roleId, equals('1'));
      expect(gallery.images.length, equals(2));
    });

    test('RoleGallery fromJson 应该解析字符串数组', () {
      final json = {
        'role_id': '1',
        'images': ['image1.jpg', 'image2.jpg', 'image3.jpg'],
      };

      final gallery = RoleGallery.fromJson(json);

      expect(gallery.roleId, equals('1'));
      expect(gallery.images.length, equals(3));
      expect(gallery.images[0].filename, equals('image1.jpg'));
    });

    test('RoleGallery fromJson 应该解析对象数组', () {
      final json = {
        'role_id': '1',
        'images': [
          {
            'url': 'image1.jpg',
            'created_at': '2024-01-01T00:00:00.000Z',
          },
          {
            'filename': 'image2.jpg',
            'created_at': '2024-01-02T00:00:00.000Z',
          },
        ],
      };

      final gallery = RoleGallery.fromJson(json);

      expect(gallery.images.length, equals(2));
    });

    test('RoleGallery sortedImages 应该按文件名逆序排列', () {
      final gallery = RoleGallery(
        roleId: '1',
        images: [
          RoleImage(
            filename: 'a.jpg',
            createdAt: DateTime(2024, 1, 1),
          ),
          RoleImage(
            filename: 'c.jpg',
            createdAt: DateTime(2024, 1, 3),
          ),
          RoleImage(
            filename: 'b.jpg',
            createdAt: DateTime(2024, 1, 2),
          ),
        ],
      );

      final sorted = gallery.sortedImages;

      expect(sorted[0].filename, equals('c.jpg'));
      expect(sorted[1].filename, equals('b.jpg'));
      expect(sorted[2].filename, equals('a.jpg'));
    });

    test('RoleGallery firstImage 应该返回第一张图片', () {
      final gallery = RoleGallery(
        roleId: '1',
        images: [
          RoleImage(
            filename: 'a.jpg',
            createdAt: DateTime(2024, 1, 1),
          ),
          RoleImage(
            filename: 'z.jpg',
            createdAt: DateTime(2024, 1, 2),
          ),
        ],
      );

      final first = gallery.firstImage;

      expect(first, isNotNull);
      expect(first!.filename, equals('z.jpg')); // 文件名逆序的第一张
    });

    test('RoleGallery firstImage 空图集应该返回null', () {
      final gallery = RoleGallery(
        roleId: '1',
        images: [],
      );

      final first = gallery.firstImage;

      expect(first, isNull);
    });

    test('RoleGallery addImage 应该添加图片', () {
      final gallery = RoleGallery(
        roleId: '1',
        images: [
          RoleImage(
            filename: 'image1.jpg',
            createdAt: DateTime(2024, 1, 1),
          ),
        ],
      );

      final newImage = RoleImage(
        filename: 'image2.jpg',
        createdAt: DateTime(2024, 1, 2),
      );

      final updated = gallery.addImage(newImage);

      expect(updated.images.length, equals(2));
      expect(updated.images.contains(newImage), isTrue);
    });

    test('RoleGallery removeImage 应该删除图片', () {
      final gallery = RoleGallery(
        roleId: '1',
        images: [
          RoleImage(
            filename: 'image1.jpg',
            createdAt: DateTime(2024, 1, 1),
          ),
          RoleImage(
            filename: 'image2.jpg',
            createdAt: DateTime(2024, 1, 2),
          ),
        ],
      );

      final updated = gallery.removeImage('image1.jpg');

      expect(updated.images.length, equals(1));
      expect(updated.images[0].filename, equals('image2.jpg'));
    });

    test('RoleGallery imageCount 应该返回图片数量', () {
      final gallery = RoleGallery(
        roleId: '1',
        images: [
          RoleImage(
            filename: 'image1.jpg',
            createdAt: DateTime(2024, 1, 1),
          ),
          RoleImage(
            filename: 'image2.jpg',
            createdAt: DateTime(2024, 1, 2),
          ),
          RoleImage(
            filename: 'image3.jpg',
            createdAt: DateTime(2024, 1, 3),
          ),
        ],
      );

      expect(gallery.imageCount, equals(3));
    });

    test('RoleGallery toJson 应该正确序列化', () {
      final gallery = RoleGallery(
        roleId: '1',
        images: [
          RoleImage(
            filename: 'image.jpg',
            createdAt: DateTime(2024, 1, 1, 12, 30),
          ),
        ],
      );

      final json = gallery.toJson();

      expect(json['role_id'], equals('1'));
      expect(json['images'], isA<List>());
      expect(json['images'].length, equals(1));
    });
  });

  group('CharacterAvatarSyncService - 边界情况测试', () {
    test('空图集应该正确处理', () {
      final gallery = RoleGallery(
        roleId: '1',
        images: [],
      );

      expect(gallery.imageCount, equals(0));
      expect(gallery.firstImage, isNull);
      expect(gallery.sortedImages, isEmpty);
    });

    test('单张图片图集应该正确处理', () {
      final gallery = RoleGallery(
        roleId: '1',
        images: [
          RoleImage(
            filename: 'single.jpg',
            createdAt: DateTime(2024, 1, 1),
          ),
        ],
      );

      expect(gallery.imageCount, equals(1));
      expect(gallery.firstImage!.filename, equals('single.jpg'));
    });

    test('特殊字符文件名应该正常处理', () {
      final gallery = RoleGallery(
        roleId: '1',
        images: [
          RoleImage(
            filename: '图片@#\$%测试.jpg',
            createdAt: DateTime(2024, 1, 1),
          ),
        ],
      );

      expect(gallery.images[0].filename, equals('图片@#\$%测试.jpg'));
    });

    test('RoleImage without created_at应该使用默认时间', () {
      final json = {
        'url': 'image.jpg',
        // 没有 created_at 字段
      };

      final image = RoleImage.fromJson(json);

      expect(image.filename, equals('image.jpg'));
      expect(image.createdAt, isA<DateTime>());
    });
  });
}
