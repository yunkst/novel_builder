import 'package:flutter_test/flutter_test.dart';
import 'package:novel_app/core/providers/search_screen_providers.dart';

/// 动态站点验证单元测试
///
/// 测试策略：
/// 1. 测试支持的站点 URL 验证
/// 2. 测试不支持的站点 URL 拒绝
/// 3. 测试站点列表为空时的容错行为
/// 4. 测试 base_url 解析和匹配逻辑
/// 5. 测试边界条件（无效 URL、空字符串等）
void main() {
  group('动态站点验证 - URL 匹配测试', () {
    test('应该正确识别支持的站点 URL - AliceSW', () {
      // Arrange
      final url = 'https://www.alicesw.com/book/123/';
      final uri = Uri.tryParse(url);
      final site = {
        'id': 'alice_sw',
        'name': 'AliceSW',
        'base_url': 'https://www.alicesw.com',
        'description': '轻小说文库',
        'enabled': true,
        'search_enabled': true,
      };

      // Act
      final host = uri?.host ?? '';
      final baseUrlHost = Uri.parse(site['base_url'] as String).host;
      final isMatch = host.contains(baseUrlHost);

      // Assert
      expect(uri, isNotNull, reason: 'URL 应该能够解析');
      expect(host, equals('www.alicesw.com'));
      expect(baseUrlHost, equals('www.alicesw.com'));
      expect(isMatch, isTrue, reason: 'AliceSW URL 应该通过验证');
    });

    test('应该正确识别支持的站点 URL - Biquge543', () {
      // Arrange
      final url = 'https://m.biquge543.com/shu/163512/';
      final uri = Uri.tryParse(url);
      final site = {
        'id': 'biquge543',
        'name': '笔趣阁543',
        'base_url': 'https://m.biquge543.com',
        'description': '移动端笔趣阁',
        'enabled': true,
        'search_enabled': false,
      };

      // Act
      final host = uri?.host ?? '';
      final baseUrlHost = Uri.parse(site['base_url'] as String).host;
      final isMatch = host.contains(baseUrlHost);

      // Assert
      expect(uri, isNotNull, reason: 'URL 应该能够解析');
      expect(host, equals('m.biquge543.com'));
      expect(baseUrlHost, equals('m.biquge543.com'));
      expect(isMatch, isTrue, reason: 'Biquge543 URL 应该通过验证');
    });

    test('应该正确识别支持的站点 URL - Shukuge', () {
      // Arrange
      final url = 'https://shukuge.com/book/123/';
      final uri = Uri.tryParse(url);
      final site = {
        'id': 'shukuge',
        'name': '书库',
        'base_url': 'https://shukuge.com',
        'description': '书库',
        'enabled': true,
        'search_enabled': true,
      };

      // Act
      final host = uri?.host ?? '';
      final baseUrlHost = Uri.parse(site['base_url'] as String).host;
      final isMatch = host.contains(baseUrlHost);

      // Assert
      expect(uri, isNotNull);
      expect(host, equals('shukuge.com'));
      expect(isMatch, isTrue, reason: 'Shukuge URL 应该通过验证');
    });

    test('应该正确识别支持的站点 URL - 支持子域名', () {
      // Arrange
      final url = 'https://www.xspsw.com/book/123/';
      final uri = Uri.tryParse(url);
      final site = {
        'id': 'xspsw',
        'name': '小说网',
        'base_url': 'https://xspsw.com',
        'description': '小说网',
        'enabled': true,
        'search_enabled': true,
      };

      // Act
      final host = uri?.host ?? '';
      final baseUrlHost = Uri.parse(site['base_url'] as String).host;
      final isMatch = host.contains(baseUrlHost);

      // Assert
      expect(uri, isNotNull);
      expect(host, equals('www.xspsw.com'));
      expect(baseUrlHost, equals('xspsw.com'));
      expect(isMatch, isTrue, reason: '子域名应该能够匹配');
    });

    test('应该拒绝不支持的站点 URL', () {
      // Arrange
      final unsupportedUrl = 'https://unsupported-site.com/book/123/';
      final uri = Uri.tryParse(unsupportedUrl);

      final supportedSites = [
        {
          'id': 'alice_sw',
          'name': 'AliceSW',
          'base_url': 'https://www.alicesw.com',
        },
        {
          'id': 'biquge543',
          'name': '笔趣阁543',
          'base_url': 'https://m.biquge543.com',
        },
      ];

      // Act
      final host = uri?.host ?? '';
      bool isMatch = false;
      for (final site in supportedSites) {
        final baseUrlHost = Uri.parse(site['base_url'] as String).host;
        if (host.contains(baseUrlHost)) {
          isMatch = true;
          break;
        }
      }

      // Assert
      expect(uri, isNotNull);
      expect(host, equals('unsupported-site.com'));
      expect(isMatch, isFalse, reason: '不支持的站点应该被拒绝');
    });
  });

  group('动态站点验证 - 容错行为测试', () {
    test('站点列表为空时，应该只验证 URL 格式（http）', () {
      // Arrange
      final url = 'http://some-site.com/book/123/';
      const sites = <Map<String, dynamic>>[]; // 站点列表为空

      // Act: 模拟 search_screen.dart 中的逻辑
      final uri = Uri.tryParse(url);
      bool result;
      if (sites.isEmpty) {
        // 站点列表未加载，暂时接受（让后端判断）
        result = uri != null &&
               (uri.scheme == 'http' || uri.scheme == 'https');
      } else {
        result = false;
      }

      // Assert
      expect(result, isTrue,
          reason: '站点列表为空时，应该只验证 URL 格式');
    });

    test('站点列表为空时，应该只验证 URL 格式（https）', () {
      // Arrange
      final url = 'https://some-site.com/book/123/';
      const sites = <Map<String, dynamic>>[];

      // Act
      final uri = Uri.tryParse(url);
      bool result;
      if (sites.isEmpty) {
        result = uri != null &&
               (uri.scheme == 'http' || uri.scheme == 'https');
      } else {
        result = false;
      }

      // Assert
      expect(result, isTrue);
    });

    test('站点列表为空时，应该拒绝无效协议', () {
      // Arrange
      final url = 'ftp://some-site.com/book/123/';
      const sites = <Map<String, dynamic>>[];

      // Act
      final uri = Uri.tryParse(url);
      bool result;
      if (sites.isEmpty) {
        result = uri != null &&
               (uri.scheme == 'http' || uri.scheme == 'https');
      } else {
        result = false;
      }

      // Assert
      expect(result, isFalse,
          reason: '站点列表为空时，应该拒绝无效协议');
    });

    test('站点列表不为空时，应该进行站点匹配验证', () {
      // Arrange
      final url = 'https://m.biquge543.com/shu/163512/';
      const sites = [
        {
          'id': 'biquge543',
          'base_url': 'https://m.biquge543.com',
        },
      ];

      // Act
      final uri = Uri.tryParse(url);
      bool result;
      if (sites.isEmpty) {
        result = uri != null &&
               (uri.scheme == 'http' || uri.scheme == 'https');
      } else {
        final host = uri?.host ?? '';
        result = sites.any((site) {
          final baseUrl = site['base_url'] as String;
          return host.contains(Uri.parse(baseUrl).host);
        });
      }

      // Assert
      expect(result, isTrue);
    });
  });

  group('动态站点验证 - 边界条件测试', () {
    test('应该拒绝空字符串', () {
      // Arrange
      const url = '';

      // Act
      final uri = Uri.tryParse(url);

      // Assert
      expect(uri, isNull, reason: '空字符串应该返回 null');
    });

    test('应该拒绝无效的 URL', () {
      // Arrange
      const url = 'not-a-valid-url';

      // Act
      final uri = Uri.tryParse(url);

      // Assert
      expect(uri, isNull, reason: '无效的 URL 应该返回 null');
    });

    test('应该拒绝没有 host 的 URL', () {
      // Arrange
      const url = 'file:///path/to/file.html';

      // Act
      final uri = Uri.tryParse(url);
      final hasHost = uri?.host != null && uri!.host.isNotEmpty;

      // Assert
      expect(hasHost, isFalse, reason: '没有 host 的 URL 应该被拒绝');
    });

    test('应该正确处理带端口号的 URL', () {
      // Arrange
      final url = 'https://shukuge.com:8080/book/123/';
      final site = {
        'id': 'shukuge',
        'base_url': 'https://shukuge.com',
      };

      // Act
      final uri = Uri.tryParse(url);
      final host = uri?.host ?? '';
      final baseUrlHost = Uri.parse(site['base_url'] as String).host;
      final isMatch = host.contains(baseUrlHost);

      // Assert
      expect(uri, isNotNull);
      expect(host, equals('shukuge.com'));
      expect(isMatch, isTrue, reason: '带端口号的 URL 应该能够匹配');
    });

    test('应该正确处理带路径的 URL', () {
      // Arrange
      final url = 'https://m.biquge543.com/shu/163512/';
      final site = {
        'id': 'biquge543',
        'base_url': 'https://m.biquge543.com',
      };

      // Act
      final uri = Uri.tryParse(url);
      final host = uri?.host ?? '';
      final baseUrlHost = Uri.parse(site['base_url'] as String).host;
      final isMatch = host.contains(baseUrlHost);

      // Assert
      expect(uri, isNotNull);
      expect(isMatch, isTrue, reason: '带路径的 URL 应该能够匹配');
    });

    test('应该正确处理带查询参数的 URL', () {
      // Arrange
      final url = 'https://shukuge.com/book/123/?page=2';
      final site = {
        'id': 'shukuge',
        'base_url': 'https://shukuge.com',
      };

      // Act
      final uri = Uri.tryParse(url);
      final host = uri?.host ?? '';
      final baseUrlHost = Uri.parse(site['base_url'] as String).host;
      final isMatch = host.contains(baseUrlHost);

      // Assert
      expect(uri, isNotNull);
      expect(isMatch, isTrue, reason: '带查询参数的 URL 应该能够匹配');
    });
  });

  group('动态站点验证 - 多站点匹配测试', () {
    test('应该正确匹配站点列表中的任意一个站点', () {
      // Arrange
      final url = 'https://m.biquge543.com/shu/163512/';
      final sites = [
        {'id': 'alice_sw', 'base_url': 'https://www.alicesw.com'},
        {'id': 'shukuge', 'base_url': 'https://shukuge.com'},
        {'id': 'biquge543', 'base_url': 'https://m.biquge543.com'},
        {'id': 'xspsw', 'base_url': 'https://xspsw.com'},
      ];

      // Act
      final uri = Uri.tryParse(url);
      final host = uri?.host ?? '';
      final isMatch = sites.any((site) {
        final baseUrl = site['base_url'] as String;
        return host.contains(Uri.parse(baseUrl).host);
      });

      // Assert
      expect(isMatch, isTrue, reason: '应该匹配站点列表中的 Biquge543');
    });

    test('当 URL 不匹配任何站点时应该返回 false', () {
      // Arrange
      final url = 'https://unknown-site.com/book/123/';
      final sites = [
        {'id': 'alice_sw', 'base_url': 'https://www.alicesw.com'},
        {'id': 'shukuge', 'base_url': 'https://shukuge.com'},
      ];

      // Act
      final uri = Uri.tryParse(url);
      final host = uri?.host ?? '';
      final isMatch = sites.any((site) {
        final baseUrl = site['base_url'] as String;
        return host.contains(Uri.parse(baseUrl).host);
      });

      // Assert
      expect(isMatch, isFalse, reason: '不匹配任何站点时应该返回 false');
    });
  });

  group('动态站点验证 - base_url 解析测试', () {
    test('应该正确解析带有 https 协议的 base_url', () {
      // Arrange
      final baseUrl = 'https://shukuge.com';

      // Act
      final uri = Uri.parse(baseUrl);
      final host = uri.host;

      // Assert
      expect(uri.scheme, equals('https'));
      expect(host, equals('shukuge.com'));
      expect(uri.hasAuthority, isTrue);
    });

    test('应该正确解析带有 www 子域名的 base_url', () {
      // Arrange
      final baseUrl = 'https://www.alicesw.com';

      // Act
      final uri = Uri.parse(baseUrl);
      final host = uri.host;

      // Assert
      expect(host, equals('www.alicesw.com'));
    });

    test('应该正确解析移动端 base_url', () {
      // Arrange
      final baseUrl = 'https://m.biquge543.com';

      // Act
      final uri = Uri.parse(baseUrl);
      final host = uri.host;

      // Assert
      expect(host, equals('m.biquge543.com'));
    });
  });

  group('SourceSitesState 测试', () {
    test('应该正确创建空的 SourceSitesState', () {
      // Arrange & Act
      final state = const SourceSitesState();

      // Assert
      expect(state.sites, isEmpty);
      expect(state.selectedSiteIds, isEmpty);
      expect(state.showFilter, isFalse);
    });

    test('copyWith 应该正确更新 sites', () {
      // Arrange
      final state = const SourceSitesState();
      final newSites = [
        {
          'id': 'biquge543',
          'base_url': 'https://m.biquge543.com',
        },
      ];

      // Act
      final newState = state.copyWith(sites: newSites);

      // Assert
      expect(newState.sites, equals(newSites));
      expect(newState.selectedSiteIds, isEmpty);
      expect(newState.showFilter, isFalse);
    });

    test('copyWith 应该保持未更改的字段', () {
      // Arrange
      final state = SourceSitesState(
        sites: [
          {'id': 'biquge543', 'base_url': 'https://m.biquge543.com'},
        ],
        selectedSiteIds: {'biquge543'},
        showFilter: true,
      );

      // Act
      final newState = state.copyWith(showFilter: false);

      // Assert
      expect(newState.sites, equals(state.sites));
      expect(newState.selectedSiteIds, equals(state.selectedSiteIds));
      expect(newState.showFilter, isFalse);
    });

    test('getSelectedSiteNames 应该正确返回站点名称', () {
      // Arrange
      final state = SourceSitesState(
        sites: [
          {
            'id': 'biquge543',
            'name': '笔趣阁543',
            'base_url': 'https://m.biquge543.com',
          },
          {
            'id': 'shukuge',
            'name': '书库',
            'base_url': 'https://shukuge.com',
          },
        ],
        selectedSiteIds: {'biquge543'},
      );

      // Act
      final names = state.getSelectedSiteNames();

      // Assert
      expect(names, equals('笔趣阁543'));
    });

    test('getSelectedSiteNames 当全选时应该返回空字符串', () {
      // Arrange
      final state = SourceSitesState(
        sites: [
          {
            'id': 'biquge543',
            'name': '笔趣阁543',
            'base_url': 'https://m.biquge543.com',
          },
          {
            'id': 'shukuge',
            'name': '书库',
            'base_url': 'https://shukuge.com',
          },
        ],
        selectedSiteIds: {'biquge543', 'shukuge'},
      );

      // Act
      final names = state.getSelectedSiteNames();

      // Assert
      expect(names, isEmpty, reason: '全选时应该返回空字符串');
    });
  });

  group('动态站点验证 - 集成场景测试', () {
    test('应该模拟实际的 validator 函数行为', () {
      // Arrange
      const testUrl = 'https://m.biquge543.com/shu/163512/';

      // 模拟 sourceSitesState
      final sourceSitesState = SourceSitesState(
        sites: [
          {
            'id': 'alice_sw',
            'name': 'AliceSW',
            'base_url': 'https://www.alicesw.com',
            'description': '轻小说文库',
            'enabled': true,
            'search_enabled': true,
          },
          {
            'id': 'biquge543',
            'name': '笔趣阁543',
            'base_url': 'https://m.biquge543.com',
            'description': '移动端笔趣阁',
            'enabled': true,
            'search_enabled': false,
          },
          {
            'id': 'shukuge',
            'name': '书库',
            'base_url': 'https://shukuge.com',
            'description': '书库',
            'enabled': true,
            'search_enabled': true,
          },
        ],
      );

      // Act: 模拟 validator 函数逻辑
      final uri = Uri.tryParse(testUrl);
      if (uri == null) {
        fail('URL 解析失败');
      }

      // 使用动态站点列表
      bool isValid = false;
      if (sourceSitesState.sites.isEmpty) {
        // 如果站点列表未加载，暂时接受（让后端判断）
        isValid = uri.scheme == 'http' || uri.scheme == 'https';
      } else {
        final host = uri.host;
        isValid = sourceSitesState.sites.any((site) {
          final baseUrl = site['base_url'] as String;
          return host.contains(Uri.parse(baseUrl).host);
        });
      }

      // Assert
      expect(isValid, isTrue, reason: 'Biquge543 URL 应该通过验证');
    });

    test('应该模拟站点未加载时的降级行为', () {
      // Arrange
      const testUrl = 'https://unknown-site.com/book/123/';

      // 模拟站点未加载的情况
      final sourceSitesState = const SourceSitesState();

      // Act
      final uri = Uri.tryParse(testUrl);
      if (uri == null) {
        fail('URL 解析失败');
      }

      bool isValid = false;
      if (sourceSitesState.sites.isEmpty) {
        // 站点列表未加载，只验证 URL 格式
        isValid = uri.scheme == 'http' || uri.scheme == 'https';
      } else {
        final host = uri.host;
        isValid = sourceSitesState.sites.any((site) {
          final baseUrl = site['base_url'] as String;
          return host.contains(Uri.parse(baseUrl).host);
        });
      }

      // Assert
      expect(isValid, isTrue,
          reason: '站点未加载时，应该只验证 URL 格式');
    });
  });
}
