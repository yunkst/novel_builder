import 'dart:async';
import 'dart:convert';
import '../services/logger_service.dart';

/// Hermes SSE 事件类型
enum HermesEventType {
  /// 内容增量事件
  contentDelta,
  /// 工具执行进度事件
  toolProgress,
  /// 会话结束事件
  done,
  /// 错误事件
  error,
  /// 未知事件
  unknown,
}

/// Hermes SSE 事件数据
class HermesEvent {
  final HermesEventType type;
  final String? content;
  final Map<String, dynamic>? data;
  final String rawData;

  HermesEvent({
    required this.type,
    this.content,
    this.data,
    required this.rawData,
  });

  factory HermesEvent.fromContentDelta(Map<String, dynamic> json, String raw) {
    String? text;
    if (json['choices'] != null && json['choices'] is List) {
      final choices = json['choices'] as List;
      if (choices.isNotEmpty) {
        final delta = choices[0]['delta'];
        if (delta != null && delta is Map && delta['content'] != null) {
          text = delta['content'].toString();
        }
      }
    }
    return HermesEvent(
      type: HermesEventType.contentDelta,
      content: text,
      data: json,
      rawData: raw,
    );
  }

  factory HermesEvent.fromToolProgress(Map<String, dynamic> json, String raw) {
    return HermesEvent(
      type: HermesEventType.toolProgress,
      data: json,
      rawData: raw,
    );
  }

  factory HermesEvent.done(String raw) {
    return HermesEvent(
      type: HermesEventType.done,
      rawData: raw,
    );
  }

  factory HermesEvent.error(String message, String raw) {
    return HermesEvent(
      type: HermesEventType.error,
      content: message,
      rawData: raw,
    );
  }

  @override
  String toString() {
    return 'HermesEvent(type: $type, content: $content, data: $data)';
  }
}

/// 工具执行进度数据
class ToolProgress {
  final String toolName;
  final String status;
  final String? message;
  final double? progress;
  final Map<String, dynamic>? result;

  ToolProgress({
    required this.toolName,
    required this.status,
    this.message,
    this.progress,
    this.result,
  });

  factory ToolProgress.fromJson(Map<String, dynamic> json) {
    return ToolProgress(
      toolName: json['tool']?.toString() ?? json['tool_name']?.toString() ?? 'unknown',
      status: json['status']?.toString() ?? 'running',
      message: json['message']?.toString(),
      progress: json['progress'] != null ? (json['progress'] as num).toDouble() : null,
      result: json['result'] as Map<String, dynamic>?,
    );
  }

  @override
  String toString() {
    return 'ToolProgress(tool: $toolName, status: $status, progress: $progress)';
  }
}

/// Hermes SSE 解析器
class HermesSSEParser {
  /// 解析 SSE 流数据，返回事件流
  static Stream<HermesEvent> parseStream(Stream<String> inputStream) {
    return inputStream
        .transform(_HermesSSEStreamTransformer())
        .asBroadcastStream();
  }

  /// 从 SSE 流中提取文本内容增量
  static Stream<String> extractTextStream(Stream<HermesEvent> eventStream) {
    return eventStream
        .where((event) => event.type == HermesEventType.contentDelta && event.content != null)
        .map((event) => event.content!);
  }

  /// 从 SSE 流中提取工具进度
  static Stream<ToolProgress> extractToolProgressStream(Stream<HermesEvent> eventStream) {
    return eventStream
        .where((event) => event.type == HermesEventType.toolProgress && event.data != null)
        .map((event) => ToolProgress.fromJson(event.data!));
  }

  /// 等待流结束
  static Future<bool> waitForCompletion(Stream<HermesEvent> eventStream) async {
    final completer = Completer<bool>();

    StreamSubscription<HermesEvent>? subscription;
    subscription = eventStream.listen(
      (event) {
        if (event.type == HermesEventType.done) {
          completer.complete(true);
          subscription?.cancel();
        } else if (event.type == HermesEventType.error) {
          completer.complete(false);
          subscription?.cancel();
        }
      },
      onError: (error) {
        completer.completeError(error);
      },
    );

    return completer.future;
  }
}

/// SSE 流转换器
class _HermesSSEStreamTransformer extends StreamTransformerBase<String, HermesEvent> {
  @override
  Stream<HermesEvent> bind(Stream<String> stream) {
    return stream
        .transform(_HermesEventSplitter())
        .transform(_HermesEventParser());
  }
}

/// SSE 事件分割器
class _HermesEventSplitter extends StreamTransformerBase<String, String> {
  @override
  Stream<String> bind(Stream<String> stream) {
    String buffer = '';

    return stream.transform(
      StreamTransformer<String, String>.fromHandlers(
        handleData: (chunk, sink) {
          buffer += chunk;

          // 按 \n\n 分割 SSE 事件
          final events = buffer.split('\n\n');
          buffer = events.last;

          for (int i = 0; i < events.length - 1; i++) {
            final event = events[i].trim();
            if (event.isNotEmpty) {
              sink.add(event);
            }
          }
        },
        handleDone: (sink) {
          if (buffer.trim().isNotEmpty) {
            sink.add(buffer.trim());
          }
          sink.close();
        },
      ),
    );
  }
}

/// SSE 事件解析器
class _HermesEventParser extends StreamTransformerBase<String, HermesEvent> {
  @override
  Stream<HermesEvent> bind(Stream<String> stream) {
    return stream.transform(
      StreamTransformer<String, HermesEvent>.fromHandlers(
        handleData: (eventStr, sink) {
          try {
            final event = _parseEvent(eventStr);
            if (event != null) {
              sink.add(event);
            }
          } catch (e) {
            LoggerService.instance.e(
              'Hermes SSE parse error: $e',
              category: LogCategory.ai,
              tags: ['hermes', 'sse', 'error'],
            );
          }
        },
        handleError: (error, stackTrace, sink) {
          sink.addError(error, stackTrace);
        },
        handleDone: (sink) {
          sink.close();
        },
      ),
    );
  }

  HermesEvent? _parseEvent(String eventStr) {
    String? eventType;
    String? eventData;

    final lines = eventStr.split('\n');
    for (final line in lines) {
      if (line.startsWith('event:')) {
        eventType = line.substring(6).trim();
      } else if (line.startsWith('data:')) {
        eventData = line.substring(5).trim();
      }
    }

    if (eventData == null) {
      return null;
    }

    // 处理 [DONE] 信号
    if (eventData == '[DONE]') {
      return HermesEvent.done(eventStr);
    }

    try {
      final json = jsonDecode(eventData) as Map<String, dynamic>;

      // 检查是否为错误响应
      if (json['error'] != null) {
        return HermesEvent.error(json['error'].toString(), eventData);
      }

      // 根据事件类型或内容判断
      if (eventType == 'hermes.tool.progress') {
        return HermesEvent.fromToolProgress(json, eventData);
      }

      // 默认为内容增量事件
      return HermesEvent.fromContentDelta(json, eventData);
    } catch (e) {
      return null;
    }
  }
}
