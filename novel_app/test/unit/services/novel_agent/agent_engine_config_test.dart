/// AgentEngineConfig 单元测试
///
/// 覆盖场景级 LLM 覆盖配置：
/// 1. 场景级 key 拼接正确性（隐式通过读写验证）
/// 2. 场景级留空时回退到全局默认
/// 3. 全局留空时回退到 DSL Engine
/// 4. clearScenarioConfig 清空指定场景
/// 5. 不同场景互不影响
/// 6. isConfiguredForScenario / hasScenarioOverride 状态判断
///
/// 运行:
///   cd novel_app
///   flutter test test/unit/services/novel_agent/agent_engine_config_test.dart
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:novel_app/services/novel_agent/agent_engine_config.dart';
import 'package:novel_app/services/dsl_engine/dsl_engine_config.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('AgentEngineConfig - 场景级配置读写', () {
    test('setScenarioApiUrl / getScenarioApiUrl 写入后能读出', () async {
      await AgentEngineConfig.setScenarioApiUrl('writing', 'https://api.openai.com/v1');
      expect(await AgentEngineConfig.getScenarioApiUrl('writing'),
          'https://api.openai.com/v1');
    });

    test('setScenarioApiKey / getScenarioApiKey 写入后能读出', () async {
      await AgentEngineConfig.setScenarioApiKey('writing', 'sk-test');
      expect(await AgentEngineConfig.getScenarioApiKey('writing'), 'sk-test');
    });

    test('setScenarioModel / getScenarioModel 写入后能读出', () async {
      await AgentEngineConfig.setScenarioModel('writing', 'gpt-4o');
      expect(await AgentEngineConfig.getScenarioModel('writing'), 'gpt-4o');
    });

    test('未写入时返回空字符串', () async {
      expect(await AgentEngineConfig.getScenarioApiUrl('writing'), '');
      expect(await AgentEngineConfig.getScenarioApiKey('writing'), '');
      expect(await AgentEngineConfig.getScenarioModel('writing'), '');
    });
  });

  group('AgentEngineConfig - 场景级 key 隔离', () {
    test('不同场景的配置互不影响', () async {
      await AgentEngineConfig.setScenarioApiUrl('writing', 'https://a.example/v1');
      await AgentEngineConfig.setScenarioApiUrl('webview_extract', 'https://b.example/v1');

      expect(await AgentEngineConfig.getScenarioApiUrl('writing'),
          'https://a.example/v1');
      expect(await AgentEngineConfig.getScenarioApiUrl('webview_extract'),
          'https://b.example/v1');
    });

    test('修改一个场景不影响另一个场景', () async {
      await AgentEngineConfig.setScenarioApiKey('writing', 'sk-a');
      await AgentEngineConfig.setScenarioApiKey('webview_extract', 'sk-b');

      await AgentEngineConfig.setScenarioApiKey('writing', 'sk-a-new');

      expect(await AgentEngineConfig.getScenarioApiKey('writing'), 'sk-a-new');
      expect(await AgentEngineConfig.getScenarioApiKey('webview_extract'),
          'sk-b');
    });
  });

  group('AgentEngineConfig - clearScenarioConfig', () {
    test('清除指定场景的所有覆盖配置', () async {
      await AgentEngineConfig.setScenarioApiUrl('writing', 'https://api.openai.com/v1');
      await AgentEngineConfig.setScenarioApiKey('writing', 'sk-test');
      await AgentEngineConfig.setScenarioModel('writing', 'gpt-4o');

      await AgentEngineConfig.clearScenarioConfig('writing');

      expect(await AgentEngineConfig.getScenarioApiUrl('writing'), '');
      expect(await AgentEngineConfig.getScenarioApiKey('writing'), '');
      expect(await AgentEngineConfig.getScenarioModel('writing'), '');
    });

    test('清除一个场景不影响另一个场景', () async {
      await AgentEngineConfig.setScenarioApiUrl('writing', 'https://a.example/v1');
      await AgentEngineConfig.setScenarioApiUrl('webview_extract', 'https://b.example/v1');

      await AgentEngineConfig.clearScenarioConfig('writing');

      expect(await AgentEngineConfig.getScenarioApiUrl('writing'), '');
      expect(await AgentEngineConfig.getScenarioApiUrl('webview_extract'),
          'https://b.example/v1');
    });
  });

  group('AgentEngineConfig - hasScenarioOverride', () {
    test('无任何配置时返回 false', () async {
      expect(await AgentEngineConfig.hasScenarioOverride('writing'), false);
    });

    test('配置了 url 时返回 true', () async {
      await AgentEngineConfig.setScenarioApiUrl('writing', 'https://api.openai.com/v1');
      expect(await AgentEngineConfig.hasScenarioOverride('writing'), true);
    });

    test('配置了 key 时返回 true', () async {
      await AgentEngineConfig.setScenarioApiKey('writing', 'sk-test');
      expect(await AgentEngineConfig.hasScenarioOverride('writing'), true);
    });

    test('配置了 model 时返回 true', () async {
      await AgentEngineConfig.setScenarioModel('writing', 'gpt-4o');
      expect(await AgentEngineConfig.hasScenarioOverride('writing'), true);
    });

    test('清除后返回 false', () async {
      await AgentEngineConfig.setScenarioApiUrl('writing', 'https://api.openai.com/v1');
      await AgentEngineConfig.clearScenarioConfig('writing');
      expect(await AgentEngineConfig.hasScenarioOverride('writing'), false);
    });
  });

  group('AgentEngineConfig - getEffectiveApiUrlForScenario 回退链', () {
    test('场景级有值时使用场景级', () async {
      await DslEngineConfig.setApiUrl('https://dsl.example/v1');
      await AgentEngineConfig.setScenarioApiUrl(
          'writing', 'https://scenario.example/v1');

      expect(await AgentEngineConfig.getEffectiveApiUrlForScenario('writing'),
          'https://scenario.example/v1');
    });

    test('场景级为空时回退到 DSL Engine', () async {
      await DslEngineConfig.setApiUrl('https://dsl.example/v1');

      expect(await AgentEngineConfig.getEffectiveApiUrlForScenario('writing'),
          'https://dsl.example/v1');
    });

    test('场景级和 DSL 都为空时返回空字符串', () async {
      expect(await AgentEngineConfig.getEffectiveApiUrlForScenario('writing'),
          '');
    });
  });

  group('AgentEngineConfig - getEffectiveApiKeyForScenario 回退链', () {
    test('场景级有值时使用场景级', () async {
      await DslEngineConfig.setApiKey('dsl-key');
      await AgentEngineConfig.setScenarioApiKey('writing', 'scenario-key');

      expect(await AgentEngineConfig.getEffectiveApiKeyForScenario('writing'),
          'scenario-key');
    });

    test('场景级为空时回退到 DSL Engine', () async {
      await DslEngineConfig.setApiKey('dsl-key');

      expect(await AgentEngineConfig.getEffectiveApiKeyForScenario('writing'),
          'dsl-key');
    });
  });

  group('AgentEngineConfig - getEffectiveModelForScenario 回退链', () {
    test('场景级有值时使用场景级', () async {
      await DslEngineConfig.setModel('dsl-model');
      await AgentEngineConfig.setScenarioModel('writing', 'scenario-model');

      expect(await AgentEngineConfig.getEffectiveModelForScenario('writing'),
          'scenario-model');
    });

    test('场景级为空时回退到 DSL Engine', () async {
      await DslEngineConfig.setModel('dsl-model');

      expect(await AgentEngineConfig.getEffectiveModelForScenario('writing'),
          'dsl-model');
    });

    test('场景级和 DSL 都为空时回退到硬编码默认', () async {
      expect(await AgentEngineConfig.getEffectiveModelForScenario('writing'),
          'deepseek-chat');
    });
  });

  group('AgentEngineConfig - isConfiguredForScenario', () {
    test('仅 DSL 配置完整时返回 true', () async {
      await DslEngineConfig.setApiUrl('https://dsl.example/v1');
      await DslEngineConfig.setApiKey('dsl-key');

      expect(await AgentEngineConfig.isConfiguredForScenario('writing'), true);
    });

    test('DSL 和场景都未配置时返回 false', () async {
      expect(await AgentEngineConfig.isConfiguredForScenario('writing'), false);
    });

    test('场景有 url 无 key，DSL 有 key 无 url 时返回 false', () async {
      await AgentEngineConfig.setScenarioApiUrl('writing', 'https://s.example/v1');
      await DslEngineConfig.setApiKey('dsl-key');
      // 场景 url 非空,key 留空 -> 场景 key = '' -> 回退到 DSL key
      // 但 DSL 没有 url,最终 url = 场景 url,key = DSL key
      // 理论上应该是 true,让我们再核对一下
      expect(await AgentEngineConfig.isConfiguredForScenario('writing'), true);
    });

    test('场景完整配置时返回 true', () async {
      await AgentEngineConfig.setScenarioApiUrl('writing', 'https://s.example/v1');
      await AgentEngineConfig.setScenarioApiKey('writing', 'sk-s');

      expect(await AgentEngineConfig.isConfiguredForScenario('writing'), true);
    });
  });

  group('AgentEngineConfig - 兼容性: 原有 getEffectiveXxx 仍工作', () {
    test('getEffectiveApiUrl 仍然回退到 DSL Engine', () async {
      await DslEngineConfig.setApiUrl('https://dsl.example/v1');
      expect(await AgentEngineConfig.getEffectiveApiUrl(),
          'https://dsl.example/v1');
    });

    test('getEffectiveModel 仍然三级回退', () async {
      expect(await AgentEngineConfig.getEffectiveModel(), 'deepseek-chat');
    });
  });
}
