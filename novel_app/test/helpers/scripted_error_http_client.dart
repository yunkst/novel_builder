/// 测试 helper:可枚举每次 response 的 LlmHttpClient
///
/// 用法:
///   final c = ScriptedErrorHttpClient()
///     ..queueBody('ok {\\"choices":[]}')
///     ..queueError(const RetryableHttpException(503, '', ''))
///     ..queueBody('ok2 {\\"choices":[]}');
///   await c.postJson(url, headers, body); // 返回 ok
///   await c.postJson(url, headers, body); // 抛 RetryableHttpException
///   await c.postJson(url, headers, body); // 返回 ok2
///
/// 通过 queueBody/queueError 装载脚本,按调用顺序消费。
library;

import 'package:novel_app/services/dsl_engine/llm_provider.dart';

/// 公开类(无下划线),供跨文件测试 import 使用。
class ScriptedErrorHttpClient implements LlmHttpClient {
  final List<dynamic> _script = [];
  int _pos = 0;
  final List<int> postJsonCalls = [];

  void queueBody(String body) => _script.add(body);
  void queueError(Object error) => _script.add(error);

  Future<T> _consume<T>(T Function(String) parser) async {
    if (_pos >= _script.length) {
      throw StateError('ScriptedErrorHttpClient 脚本已耗尽 ($_pos)');
    }
    final item = _script[_pos++];
    if (item is! String) {
      // 异常立刻抛,不延迟(简化)
      throw item;
    }
    return parser(item);
  }

  @override
  Future<String> postJson(
      String url, Map<String, String> headers, String body) async {
    postJsonCalls.add(1);
    return _consume<String>((s) => s);
  }

  @override
  Stream<String> postJsonStream(
      String url, Map<String, String> headers, String body) async* {
    final item = _script[_pos++];
    if (item is! String) throw item;
    yield item;
  }
}
