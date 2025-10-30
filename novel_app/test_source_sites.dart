#!/usr/bin/env dart

import 'package:dio/dio.dart';

// ignore_for_file: avoid_print
void main() async {
  final dio = Dio();
  const backendUrl = 'http://localhost:3800';
  const token = 'test_token_123'; // 使用配置文件中的默认token

  print('🔍 测试后端源站点功能...\n');

  try {
    // 1. 测试获取源站点列表
    print('1. 测试获取源站点列表...');
    final response = await dio.get(
      '$backendUrl/source-sites',
      options: Options(headers: {'X-API-TOKEN': token}),
    );

    if (response.statusCode == 200) {
      final sites = response.data as List;
      print('✅ 成功获取 ${sites.length} 个源站点:');
      for (var site in sites) {
        print('   - ID: ${site['id']}, 名称: ${site['name']}, 启用: ${site['enabled']}');
      }
      print('');
    } else {
      print('❌ 获取源站点列表失败: ${response.statusCode}');
      print('响应: ${response.data}');
      return;
    }

    // 2. 测试搜索功能（使用站点ID）
    print('2. 测试搜索功能（使用alice_sw站点ID）...');
    try {
      final searchResponse = await dio.get(
        '$backendUrl/search',
        queryParameters: {
          'keyword': '斗罗大陆',
          'sites': 'alice_sw', // 使用站点ID而不是站点名称
        },
        options: Options(headers: {'X-API-TOKEN': token}),
      );

      if (searchResponse.statusCode == 200) {
        final results = searchResponse.data as List;
        print('✅ 搜索成功，找到 ${results.length} 个结果:');
        for (var i = 0; i < results.length && i < 3; i++) {
          final novel = results[i];
          print('   ${i + 1}. ${novel['title']} - ${novel['author']}');
        }
        if (results.length > 3) {
          print('   ... 还有 ${results.length - 3} 个结果');
        }
      } else {
        print('❌ 搜索失败: ${searchResponse.statusCode}');
        print('响应: ${searchResponse.data}');
      }
    } catch (e) {
      print('❌ 搜索请求异常: $e');
    }

    // 3. 测试搜索功能（使用错误的中文名称）
    print('\n3. 测试搜索功能（使用错误的中文名称"轻小说文库"）...');
    try {
      final errorResponse = await dio.get(
        '$backendUrl/search',
        queryParameters: {
          'keyword': '斗罗大陆',
          'sites': '轻小说文库', // 错误：使用中文名称
        },
        options: Options(headers: {'X-API-TOKEN': token}),
      );

      print('❌ 意外成功: ${errorResponse.statusCode}');
    } on DioException catch (e) {
      if (e.response?.statusCode == 400) {
        print('✅ 预期的错误: ${e.response?.data['detail']}');
        print('这证明了修复是必要的！');
      } else {
        print('❌ 意外错误: $e');
      }
    }

    print('\n🎉 测试完成！');
    print('修复总结:');
    print('- 使用正确的源站点ID (alice_sw, shukuge, xspsw)');
    print('- UI显示友好的中文名称');
    print('- API调用使用技术ID标识符');

  } catch (e) {
    print('❌ 无法连接到后端服务: $e');
    print('请确保后端服务运行在 $backendUrl');
  }
}