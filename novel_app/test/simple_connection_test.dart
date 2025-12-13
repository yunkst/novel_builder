import 'package:flutter_test/flutter_test.dart';
import '../lib/services/api_service_wrapper.dart';
import '../lib/services/cache_manager.dart';
import 'package:flutter/foundation.dart';

void main() {
  group('Dio 连接问题深度分析', () {
    test('分析根本原因', () async {
      print('\n🔍 === Dio 连接问题深度分析 ===\n');

      print('📋 发现的主要问题:');

      print('\n1. 🚨 多个Screen调用dispose()导致连接关闭:');
      print('   - backend_settings_screen.dart:73 调用 _api.dispose()');
      print('   - search_screen.dart:75 调用 _api.dispose()');
      print('   - chapter_list_screen.dart:76 调用 _api.dispose()');
      print('   - reader_screen.dart:128 调用 _apiService.dispose()');
      print('   ⚠️ 这些调用会关闭共享的Dio实例，导致后续请求失败');

      print('\n2. ⚙️ 连接池配置问题:');
      print('   - maxConnectionsPerHost = 100 (过大)');
      print('   - 缺少空闲超时设置');
      print('   - 缺少连接健康检查');

      print('\n3. 🔄 并发请求竞争:');
      print('   - 缓存管理器可能发起大量并发请求');
      print('   - 用户快速切换页面可能产生竞态条件');
      print('   - 缺少请求队列管理');

      print('\n4. 📱 应用生命周期管理:');
      print('   - 应用进入后台时未暂停网络请求');
      print('   - 应用恢复时未检查连接状态');
      print('   - 缺少连接状态恢复机制');

      print('\n💡 错误信息分析:');
      print('   "dio can not establish a new connection after is was closed"');
      print('   ↳ 这明确表示Dio实例被关闭后仍被使用');

      print('\n🎯 根本原因总结:');
      print('   1. ApiServiceWrapper使用单例模式，但多个地方调用dispose()');
      print('   2. dispose()关闭Dio实例后，其他地方仍在使用该实例');
      print('   3. 缺少连接状态检查和自动恢复机制');
      print('   4. 连接池配置不合理，可能导致资源耗尽');
    });

    test('验证ApiServiceWrapper单例问题', () async {
      print('\n🧪 === 验证ApiServiceWrapper单例问题 ===\n');

      final wrapper1 = ApiServiceWrapper();
      final wrapper2 = ApiServiceWrapper();
      final wrapper3 = ApiServiceWrapper();

      print('📋 单例测试:');
      print('   wrapper1 === wrapper2: ${identical(wrapper1, wrapper2)}');
      print('   wrapper2 === wrapper3: ${identical(wrapper2, wrapper3)}');

      if (identical(wrapper1, wrapper2) && identical(wrapper2, wrapper3)) {
        print('   ✅ 确认为单例模式');
      } else {
        print('   ❌ 不是单例模式');
      }

      print('\n⚠️ 单例模式的问题:');
      print('   - 所有Screen共享同一个Dio实例');
      print('   - 任何一个Screen调用dispose()都会影响其他Screen');
      print('   - 缺少引用计数机制来安全管理实例生命周期');

      // 测试dispose影响
      print('\n🔫 测试dispose的影响:');
      try {
        await wrapper1.init();
        print('   ✅ wrapper1 初始化成功');

        final dio1 = wrapper1.dio;
        print('   📡 wrapper1.dio 获取成功: ${dio1 != null}');

        // 调用dispose
        wrapper2.dispose(); // 使用wrapper2调用dispose
        print('   🗑️ wrapper2.dispose() 已调用');

        final dio2 = wrapper1.dio;
        print('   📡 wrapper1.dio 再次获取: ${dio2 != null}');

        if (dio1 != null && dio2 == null) {
          print('   🎯 确认: dispose()调用来关闭了共享的Dio实例！');
        }

      } catch (e) {
        print('   ⚠️ 测试过程中的错误 (预期的): $e');
      }
    });

    test('模拟并发请求场景', () async {
      print('\n🚀 === 模拟并发请求场景 ===\n');

      final apiWrapper = ApiServiceWrapper();
      final cacheManager = CacheManager();

      try {
        // 初始化
        await apiWrapper.init();
        print('✅ API服务初始化成功');

        // 设置应用为活跃状态
        cacheManager.setAppActive(true);
        print('✅ 缓存管理器设置为活跃状态');

        // 模拟用户快速操作
        print('\n📱 模拟用户快速操作场景:');

        // 1. 用户搜索小说
        final searchFuture = apiWrapper.searchNovels('test').catchError((e) {
          print('❌ 搜索请求失败: ${e.toString().substring(0, 50)}...');
          return <dynamic>[];
        });

        // 2. 用户同时浏览章节列表
        final chaptersFuture = apiWrapper.getChapters('test_url').catchError((e) {
          print('❌ 章节列表请求失败: ${e.toString().substring(0, 50)}...');
          return <dynamic>[];
        });

        // 3. 后台缓存管理器也在工作
        cacheManager.enqueueNovel('test_novel_url');

        // 等待请求完成
        final results = await Future.wait([searchFuture, chaptersFuture]);

        print('\n📊 并发请求结果:');
        print('   搜索请求: ${results[0] is List ? "成功" : "失败"}');
        print('   章节请求: ${results[1] is List ? "成功" : "失败"}');

      } catch (e) {
        print('❌ 并发测试失败: $e');

        if (e.toString().contains('closed') ||
            e.toString().contains('establish a new connection')) {
          print('🎯 确认发现了连接关闭问题！');
        }
      } finally {
        cacheManager.setAppActive(false);
        print('🔚 缓存管理器设置为非活跃状态');
      }
    });

    test('生成修复建议', () async {
      print('\n💡 === 修复建议 ===\n');

      print('🔥 高优先级修复 (立即执行):');
      print('   1. 🚫 移除所有Screen中的dispose()调用');
      print('      - 删除 backend_settings_screen.dart:73');
      print('      - 删除 search_screen.dart:75');
      print('      - 删除 chapter_list_screen.dart:76');
      print('      - 删除 reader_screen.dart:128');
      print('   2. 🏗️ 将ApiServiceWrapper.dispose()改为空操作');
      print('      - 保持单例模式，但防止实例被关闭');
      print('   3. 🔄 添加连接状态检查和自动恢复');

      print('\n⚡ 中优先级修复 (短期内完成):');
      print('   4. ⚙️ 优化连接池配置:');
      print('      - maxConnectionsPerHost: 100 → 20');
      print('      - 添加 idleTimeout: 60秒');
      print('   5. 🛡️ 添加请求重试机制:');
      print('      - 连接错误时自动重试2-3次');
      print('      - 指数退避算法');
      print('   6. 📊 实现连接健康检查:');
      print('      - 定期检查连接状态');
      print('      - 检测到问题时自动重新初始化');

      print('\n🔧 低优先级修复 (长期改进):');
      print('   7. 🎯 实现智能连接管理器:');
      print('      - 应用生命周期感知');
      print('      - 网络状态感知');
      print('      - 连接池动态调整');
      print('   8. 📈 添加连接监控和日志:');
      print('      - 连接状态实时监控');
      print('      - 性能指标收集');
      print('      - 错误统计分析');

      print('\n🧪 测试验证:');
      print('   9. ✅ 创建回归测试:');
      print('      - 验证dispose()调用不再影响连接');
      print('      - 验证并发请求稳定性');
      print('      - 验证应用生命周期切换');
      print('   10. 📊 性能基准测试:');
      print('       - 连接建立时间');
      print('       - 并发请求处理能力');
      print('       - 内存使用情况');

      print('\n🎯 预期效果:');
      print('   ✅ 彻底解决 "dio can not establish a new connection" 错误');
      print('   ✅ 提高应用网络请求稳定性');
      print('   ✅ 改善用户体验');
      print('   ✅ 降低崩溃率');
    });
  });
}