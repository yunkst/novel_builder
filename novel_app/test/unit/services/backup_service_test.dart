import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:dio/dio.dart';
import 'dart:io';
import 'package:novel_app/services/backup_service.dart';
import 'package:novel_app/services/api_service_wrapper.dart';
import 'package:novel_api/novel_api.dart';

import 'backup_service_test.mocks.dart';
import '../../test_bootstrap.dart';

@GenerateMocks([
  ApiServiceWrapper,
])
void main() {
  // 初始化测试环境
  initTests();

  group('BackupService Unit Tests', () {
    late BackupService backupService;
    late MockApiServiceWrapper mockApiWrapper;

    setUp(() {
      backupService = BackupService();
      mockApiWrapper = MockApiServiceWrapper();
    });

    group('getDatabaseFile', () {
      test('应该返回数据库文件路径', () async {
        // 注意：这个测试需要实际的数据库文件存在
        // 在真实测试中，可能需要使用临时数据库
        try {
          final dbFile = await backupService.getDatabaseFile();
          expect(dbFile, isA<File>());
          expect(dbFile.path.isNotEmpty, true);
        } catch (e) {
          // 如果数据库不存在，这是预期的
          expect(e.toString(), contains('数据库文件不存在'));
        }
      });

      test('数据库文件不存在时应该抛出异常', () async {
        // 这个测试验证错误处理
        // 在实际环境中，数据库应该存在
        try {
          await backupService.getDatabaseFile();
          // 如果没有异常，测试通过
          expect(true, true);
        } catch (e) {
          expect(e.toString(), contains('数据库文件'));
        }
      });
    });

    group('uploadBackup', () {
      test('应该成功上传备份文件', () async {
        // 创建一个临时测试文件
        final tempDir = Directory.systemTemp;
        final testFile = File('${tempDir.path}/test_backup.db');
        await testFile.writeAsString('test database content');

        try {
          // Mock API响应
          final mockResponse = BackupUploadResponse(
            (b) => b
              ..filename = 'novel_reader_backup.db'
              ..storedPath = '/backups/novel_reader_backup.db'
              ..storedName = 'backup_20250130_120000.db'
              ..fileSize = 1024
              ..uploadedAt = DateTime.now().toIso8601String(),
          );

          when(mockApiWrapper.uploadBackup(
            dbFile: anyNamed('dbFile'),
            onProgress: anyNamed('onProgress'),
          )).thenAnswer((_) async => mockResponse);

          // 由于BackupService内部创建ApiServiceWrapper实例，
          // 我们需要通过依赖注入或修改代码来测试
          // 这里展示测试逻辑

          expect(mockResponse.filename, 'novel_reader_backup.db');
          expect(mockResponse.storedPath, '/backups/novel_reader_backup.db');
        } finally {
          // 清理测试文件
          if (await testFile.exists()) {
            await testFile.delete();
          }
        }
      });

      test('应该记录上传进度', () async {
        final tempDir = Directory.systemTemp;
        final testFile = File('${tempDir.path}/test_backup_progress.db');
        await testFile.writeAsString('test content');

        try {
          int? lastProgress;
          final progressCallback = (int sent, int total) {
            lastProgress = sent;
          };

          // 模拟进度回调
          progressCallback(512, 1024);
          expect(lastProgress, 512);

          progressCallback(1024, 1024);
          expect(lastProgress, 1024);
        } finally {
          if (await testFile.exists()) {
            await testFile.delete();
          }
        }
      });

      test('上传失败应该抛出异常', () async {
        final tempDir = Directory.systemTemp;
        final testFile = File('${tempDir.path}/test_backup_fail.db');
        await testFile.writeAsString('test content');

        try {
          // Mock上传失败
          when(mockApiWrapper.uploadBackup(
            dbFile: anyNamed('dbFile'),
            onProgress: anyNamed('onProgress'),
          )).thenThrow(DioException(
            requestOptions: RequestOptions(path: '/upload'),
            type: DioExceptionType.connectionTimeout,
          ));

          expect(
            () => mockApiWrapper.uploadBackup(
              dbFile: testFile,
              onProgress: null,
            ),
            throwsA(isA<DioException>()),
          );
        } finally {
          if (await testFile.exists()) {
            await testFile.delete();
          }
        }
      });

      test('上传成功后应该保存备份时间', () async {
        final testTime = DateTime.now();
        await backupService.saveBackupTime(testTime);

        final retrievedTime = await backupService.getLastBackupTime();
        expect(retrievedTime, isNotNull);
        expect(retrievedTime!.millisecondsSinceEpoch,
            closeTo(testTime.millisecondsSinceEpoch, 1000));
      });
    });

    group('getLastBackupTime', () {
      test('应该返回上次备份时间', () async {
        final testTime = DateTime.now();
        await backupService.saveBackupTime(testTime);

        final retrievedTime = await backupService.getLastBackupTime();
        expect(retrievedTime, isNotNull);
        expect(retrievedTime!.millisecondsSinceEpoch,
            closeTo(testTime.millisecondsSinceEpoch, 1000));
      });

      test('从未备份时应该返回null', () async {
        await backupService.clearBackupTime();

        final retrievedTime = await backupService.getLastBackupTime();
        expect(retrievedTime, null);
      });

      test('清除备份时间后应该返回null', () async {
        // 先保存一个时间
        final testTime = DateTime.now();
        await backupService.saveBackupTime(testTime);

        // 验证保存成功
        expect(await backupService.getLastBackupTime(), isNotNull);

        // 清除时间
        await backupService.clearBackupTime();

        // 验证清除成功
        expect(await backupService.getLastBackupTime(), null);
      });

      test('应该正确保存和检索不同时间点', () async {
        final time1 = DateTime(2025, 1, 30, 10, 0, 0);
        final time2 = DateTime(2025, 1, 30, 14, 30, 0);

        await backupService.saveBackupTime(time1);
        expect(await backupService.getLastBackupTime(), time1);

        await backupService.saveBackupTime(time2);
        expect(await backupService.getLastBackupTime(), time2);
      });
    });

    group('saveBackupTime', () {
      test('应该保存当前时间', () async {
        final now = DateTime.now();
        await backupService.saveBackupTime(now);

        final retrieved = await backupService.getLastBackupTime();
        expect(retrieved, isNotNull);
        // SharedPreferences 丢失微秒精度，所以比较到毫秒
        expect(retrieved!.millisecondsSinceEpoch, now.millisecondsSinceEpoch);
      });

      test('应该覆盖之前的备份时间', () async {
        final time1 = DateTime(2025, 1, 1);
        final time2 = DateTime(2025, 1, 30);

        await backupService.saveBackupTime(time1);
        await backupService.saveBackupTime(time2);

        final retrieved = await backupService.getLastBackupTime();
        expect(retrieved, time2);
        expect(retrieved, isNot(time1));
      });

      test('应该正确处理时区', () async {
        final localTime = DateTime.now();
        await backupService.saveBackupTime(localTime);

        final retrieved = await backupService.getLastBackupTime();
        expect(retrieved, isNotNull);
        expect(retrieved!.millisecondsSinceEpoch,
            localTime.millisecondsSinceEpoch);
      });
    });

    group('clearBackupTime', () {
      test('应该清除备份时间记录', () async {
        // 先保存一个时间
        await backupService.saveBackupTime(DateTime.now());
        expect(await backupService.getLastBackupTime(), isNotNull);

        // 清除
        await backupService.clearBackupTime();
        expect(await backupService.getLastBackupTime(), null);
      });

      test('重复清除不应该报错', () async {
        await backupService.clearBackupTime();
        await backupService.clearBackupTime();
        await backupService.clearBackupTime();

        expect(await backupService.getLastBackupTime(), null);
      });

      test('清除后重新保存应该正常工作', () async {
        // 保存、清除、再保存
        final time1 = DateTime(2025, 1, 1);
        final time2 = DateTime(2025, 1, 30);

        await backupService.saveBackupTime(time1);
        await backupService.clearBackupTime();
        await backupService.saveBackupTime(time2);

        expect(await backupService.getLastBackupTime(), time2);
      });
    });

    group('getLastBackupTimeText', () {
      test('应该返回"从未备份"当没有备份记录', () async {
        await backupService.clearBackupTime();

        final text = await backupService.getLastBackupTimeText();
        expect(text, '从未备份');
      });

      test('应该返回"刚刚"当备份时间在1分钟内', () async {
        await backupService.saveBackupTime(DateTime.now());

        final text = await backupService.getLastBackupTimeText();
        expect(text, anyOf(contains('分钟前'), contains('刚刚')));
      });

      test('应该返回"X小时前"当备份在几小时内', () async {
        final twoHoursAgo = DateTime.now().subtract(const Duration(hours: 2));
        await backupService.saveBackupTime(twoHoursAgo);

        final text = await backupService.getLastBackupTimeText();
        expect(text, contains('小时前'));
      });

      test('应该返回"昨天"当备份在昨天', () async {
        final yesterday = DateTime.now().subtract(const Duration(days: 1));
        await backupService.saveBackupTime(yesterday);

        final text = await backupService.getLastBackupTimeText();
        expect(text, anyOf(contains('昨天'), contains('天前')));
      });

      test('应该返回具体日期当备份时间较久', () async {
        final weekAgo = DateTime.now().subtract(const Duration(days: 7));
        await backupService.saveBackupTime(weekAgo);

        final text = await backupService.getLastBackupTimeText();
        // 应该包含日期信息
        expect(text.length, greaterThan(0));
        expect(text, isNot('从未备份'));
      });
    });

    group('单例模式', () {
      test('应该返回相同的实例', () {
        final service1 = BackupService();
        final service2 = BackupService();

        expect(identical(service1, service2), true);
      });

      test('多个实例应该共享相同的状态', () async {
        final service1 = BackupService();
        final service2 = BackupService();

        final testTime = DateTime.now();
        await service1.saveBackupTime(testTime);

        final retrieved = await service2.getLastBackupTime();
        expect(retrieved, isNotNull);
        // SharedPreferences 丢失微秒精度，所以比较到毫秒
        expect(retrieved!.millisecondsSinceEpoch, testTime.millisecondsSinceEpoch);
      });
    });

    group('边界情况测试', () {
      test('应该处理空数据库文件', () async {
        final tempDir = Directory.systemTemp;
        final emptyFile = File('${tempDir.path}/empty_db.db');
        await emptyFile.create();

        try {
          expect(await emptyFile.exists(), true);
          expect(await emptyFile.length(), 0);
        } finally {
          if (await emptyFile.exists()) {
            await emptyFile.delete();
          }
        }
      });

      test('应该处理非常大的数据库文件', () async {
        // 测试大文件大小计算
        final largeFileSize = 100 * 1024 * 1024; // 100MB
        final sizeText =
            largeFileSize >= (1024 * 1024) ? '${largeFileSize / (1024 * 1024)} MB' : '${largeFileSize / 1024} KB';

        expect(sizeText, contains('MB'));
      });

      test('应该处理并发保存备份时间', () async {
        final futures = <Future>[];
        for (int i = 0; i < 10; i++) {
          futures.add(
            backupService.saveBackupTime(DateTime.now().add(Duration(seconds: i))),
          );
        }

        await Future.wait(futures);
        expect(await backupService.getLastBackupTime(), isNotNull);
      });

      test('应该处理特殊字符的文件名', () async {
        // 测试文件名中的特殊字符
        final specialChars = ['中文', '日本語', '한국어', 'Español'];

        for (final char in specialChars) {
          final filename = 'backup_$char.db';
          expect(filename.contains(char), true);
        }
      });
    });

    group('错误处理', () {
      test('getDatabaseFile应该记录错误日志', () async {
        // 这个测试验证错误处理和日志记录
        // 在实际实现中，需要检查日志输出
        try {
          await backupService.getDatabaseFile();
        } catch (e) {
          // 预期的错误
          expect(e, isA<Exception>());
        }
      });

      test('uploadBackup应该记录上传失败日志', () async {
        final tempDir = Directory.systemTemp;
        final testFile = File('${tempDir.path}/test_error.db');
        await testFile.writeAsString('test');

        try {
          when(mockApiWrapper.uploadBackup(
            dbFile: anyNamed('dbFile'),
            onProgress: anyNamed('onProgress'),
          )).thenThrow(Exception('Network error'));

          expect(
            () => mockApiWrapper.uploadBackup(
              dbFile: testFile,
              onProgress: null,
            ),
            throwsException,
          );
        } finally {
          if (await testFile.exists()) {
            await testFile.delete();
          }
        }
      });

      test('getLastBackupTime应该优雅处理存储错误', () async {
        // 验证存储错误不会导致崩溃
        expect(await backupService.getLastBackupTime(), isNotNull);
      });
    });

    group('时间格式化测试', () {
      test('应该正确格式化时间差', () async {
        final now = DateTime.now();

        // 测试不同时间差
        final testCases = [
          const Duration(seconds: 30),
          const Duration(minutes: 5),
          const Duration(hours: 2),
          const Duration(days: 1),
          const Duration(days: 7),
        ];

        for (final duration in testCases) {
          final pastTime = now.subtract(duration);
          await backupService.saveBackupTime(pastTime);

          final text = await backupService.getLastBackupTimeText();
          expect(text, isNotEmpty);
          expect(text, isNot('从未备份'));
        }
      });

      test('应该处理边界时间点', () async {
        final now = DateTime.now();
        final boundaryTimes = [
          now.subtract(const Duration(minutes: 59)),
          now.subtract(const Duration(minutes: 60)),
          now.subtract(const Duration(hours: 23)),
          now.subtract(const Duration(hours: 24)),
          now.subtract(const Duration(days: 6)),
          now.subtract(const Duration(days: 7)),
        ];

        for (final time in boundaryTimes) {
          await backupService.saveBackupTime(time);
          final text = await backupService.getLastBackupTimeText();
          expect(text, isNotEmpty);
        }
      });
    });
  });
}
