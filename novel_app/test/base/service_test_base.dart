import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:novel_app/services/database_service.dart';
import '../test_bootstrap.dart';

/// ⚠️ DEPRECATED - 服务测试基类 ⚠️
///
/// **重要提示: 此基类已被废弃**
///
/// @deprecated 请使用 [DatabaseTestBase] 代替
/// 此基类使用Mock数据库，无法验证实际数据操作
///
/// ## 为什么废弃？
///
/// 1. **Mock只验证"调用"，不验证"结果"**
///    - Mock可以验证方法被调用，但无法验证实际数据是否正确
///    - 例如：`readAt` 字段bug在Mock测试中无法被发现
///
/// 2. **测试可信度低**
///    - Mock测试可能通过，但实际代码有严重bug
///    - 无法捕获数据库操作的真实问题
///
/// 3. **维护成本高**
///    - 需要编写大量的 `when/verify` 语句
///    - 每次数据库接口变更都需要更新Mock设置
///
/// ## 如何迁移到 DatabaseTestBase？
///
/// ### 步骤 1: 修改基类继承
/// ```dart
/// // 迁移前
/// class MyServiceTest extends ServiceTestBase { ... }
///
/// // 迁移后
/// class MyServiceTest extends DatabaseTestBase { ... }
/// ```
///
/// ### 步骤 2: 替换数据库引用
/// ```dart
/// // 迁移前
/// when(mockDb.insertUserChapter(...)).thenAnswer((_) async => 1);
/// await handler.insertChapter(...);
/// verify(mockDb.insertUserChapter(...)).called(1);
///
/// // 迁移后
/// final novel = await base.createAndAddNovel();
/// await handler.insertChapter(...);
/// await base.expectChapterExists(
///   novelUrl: novel.url,
///   chapterUrl: contains('/chapter/'),
///   title: '测试章节',
/// );
/// ```
///
/// ### 步骤 3: 删除Mock调用
/// - 删除所有 `when(...)` Mock设置
/// - 删除所有 `verify(...)` 验证调用
/// - 使用真实数据库断言替代
///
/// ### 步骤 4: 使用辅助方法
/// [DatabaseTestBase] 提供了丰富的辅助方法：
/// - `createAndAddNovel()` - 创建测试小说
/// - `expectChapterExists()` - 验证章节存在
/// - `expectNovelExists()` - 验证小说存在
/// - `getChapterByTitle()` - 获取章节数据
///
/// ## 迁移示例
///
/// ### 场景 1: 测试章节插入
/// ```dart
/// // 迁移前 (Mock)
/// test('应该插入章节', () async {
///   when(mockDb.insertUserChapter(any)).thenAnswer((_) async => 1);
///   await service.insertChapter(novelUrl, chapter);
///   verify(mockDb.insertUserChapter(any)).called(1);
/// });
///
/// // 迁移后 (真实数据库)
/// test('应该插入章节', () async {
///   final novel = await base.createAndAddNovel();
///   await service.insertChapter(novel.url, chapter);
///   await base.expectChapterExists(
///     novelUrl: novel.url,
///     chapterUrl: chapter.url,
///   );
/// });
/// ```
///
/// ### 场景 2: 测试查询功能
/// ```dart
/// // 迁移前 (Mock)
/// test('应该返回章节列表', () async {
///   final chapters = [Chapter(...)];
///   when(mockDb.getChapters(any)).thenReturn(chapters);
///   final result = await service.getChapters(novelUrl);
///   expect(result, chapters);
/// });
///
/// // 迁移后 (真实数据库)
/// test('应该返回章节列表', () async {
///   final novel = await base.createAndAddNovel();
///   await base.insertTestChapter(novel.url, '第1章');
///   await base.insertTestChapter(novel.url, '第2章');
///
///   final result = await service.getChapters(novel.url);
///   expect(result.length, 2);
///   expect(result[0].title, '第1章');
/// });
/// ```
///
/// ## 参考资源
///
/// - [DatabaseTestBase](./database_test_base.dart) - 新的测试基类
/// - [Mock数据库的局限性分析](../../../../.zcf/plan/current/Mock数据库的局限性分析与测试策略.md)
/// - [迁移实施报告](../../../../.zcf/plan/current/使用真实数据库进行单测测试的实施方案.md)
///
@Deprecated(
  '请使用 DatabaseTestBase 代替。ServiceTestBase 使用Mock数据库，无法验证实际数据操作。'
)
/// 服务测试基类
///
/// 提供服务测试的通用Mock和初始化逻辑
/// 所有服务层测试都应该继承此类
///
/// 使用示例：
/// ```dart
/// class MyServiceTest extends ServiceTestBase {
///   @override
///   Future<void> setUp() async {
///     await super.setUp();
///     // 自定义初始化
///   }
/// }
/// ```
abstract class ServiceTestBase {
  /// Mock数据库服务
  late MockDatabaseService mockDb;

  /// 设置测试环境
  ///
  /// ⚠️ **DEPRECATED**: 此基类已废弃，请迁移到 [DatabaseTestBase]
  ///
  /// 子类可以覆盖此方法添加自定义初始化逻辑
  Future<void> setUp() async {
    // 初始化测试环境
    initTests();

    // 创建Mock数据库
    mockDb = MockDatabaseService();
  }

  /// 清理测试环境
  ///
  /// 在测试完成后调用
  Future<void> tearDown() async {
    // 重置所有Mock调用
    reset(mockDb);
  }

  /// 验证Mock方法被调用
  ///
  /// 辅助方法：验证Mock对象的特定方法被调用了指定次数
  void verifyMockCalled<T extends Mock>(
    T mock,
    String methodName, {
    int times = 1,
    String? reason,
  }) {
    try {
      verify(() => (mock as dynamic).noSuchMethod(
        Invocation.method(
          Symbol(methodName),
          [],
        ),
      )).called(times);
    } catch (e) {
      final msg = reason ?? 'Mock方法 $methodName 应该被调用 $times 次';
      fail('$msg\n实际错误: $e');
    }
  }

  /// 验证Mock方法未被调用
  ///
  /// 辅助方法：验证Mock对象的特定方法从未被调用
  void verifyMockNeverCalled<T extends Mock>(
    T mock,
    String methodName, {
    String? reason,
  }) {
    try {
      verifyNever(() => (mock as dynamic).noSuchMethod(
        Invocation.method(
          Symbol(methodName),
          [],
        ),
      ));
    } catch (e) {
      final msg = reason ?? 'Mock方法 $methodName 不应该被调用';
      fail('$msg\n实际错误: $e');
    }
  }
}

/// Mock数据库服务
///
/// 使用Mockito生成的Mock类
class MockDatabaseService extends Mock implements DatabaseService {}
