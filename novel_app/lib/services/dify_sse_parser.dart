import 'dart:async';
import 'dart:convert';
import 'logger_service.dart';

/// Dify SSE事件类型
enum DifyEventType {
  textChunk, // 文本块事件
  workflowFinished, // 工作流完成
  workflowError, // 工作流错误
  unknown // 未知事件
}

/// Dify SSE事件数据
class DifyEvent {
  final DifyEventType type;
  final String? text;
  final Map<String, dynamic>? data;
  final String rawJson;

  DifyEvent({
    required this.type,
    this.text,
    this.data,
    required this.rawJson,
  });

  factory DifyEvent.fromJson(Map<String, dynamic> json, String rawJson) {
    final eventTypeStr = json['event']?.toString();
    DifyEventType type;

    switch (eventTypeStr) {
      case 'text_chunk':
        type = DifyEventType.textChunk;
        break;
      case 'workflow_finished':
        type = DifyEventType.workflowFinished;
        break;
      case 'workflow_error':
        type = DifyEventType.workflowError;
        break;
      default:
        type = DifyEventType.unknown;
        break;
    }

    String? text;
    if (type == DifyEventType.textChunk && json['data'] != null) {
      final dataField = json['data'];
      if (dataField is Map) {
        text = dataField['text']?.toString();
      } else if (dataField is String) {
        text = dataField;
      }
    }

    return DifyEvent(
      type: type,
      text: text,
      data: json['data'],
      rawJson: rawJson,
    );
  }

  @override
  String toString() {
    return 'DifyEvent(type: $type, text: $text, data: $data)';
  }
}

/// Dify SSE解析器 - 专门负责解析Dify的SSE格式
class DifySSEParser {
  /// 解析SSE流数据，返回事件流（修复流监听冲突）
  static Stream<DifyEvent> parseStream(Stream<String> inputStream) {
    // 使用广播流避免重复监听问题
    return inputStream.transform(_SSEStreamTransformer()).asBroadcastStream();
  }

  /// 从SSE流中提取文本内容（使用广播流）
  static Stream<String> extractTextStream(Stream<DifyEvent> eventStream) {
    return eventStream
        .where((event) =>
            event.type == DifyEventType.textChunk && event.text != null)
        .map((event) => event.text!);
  }

  /// 监听工作流完成状态（使用广播流，不终止文本流）
  static Future<bool> waitForCompletion(Stream<DifyEvent> eventStream) {
    final completer = Completer<bool>();

    // 订阅事件流但不终止它
    StreamSubscription<DifyEvent>? subscription;
    subscription = eventStream.listen((event) {
      if (event.type == DifyEventType.workflowFinished ||
          event.type == DifyEventType.workflowError) {
        // 完成或错误时设置结果并取消订阅
        completer.complete(event.type == DifyEventType.workflowFinished);
        subscription?.cancel();
      }
    });

    // 错误处理
    subscription.onError((error) {
      completer.completeError(error);
    });

    return completer.future;
  }
}

/// SSE流转换器 - 将原始流转换为事件流
class _SSEStreamTransformer extends StreamTransformerBase<String, DifyEvent> {
  @override
  Stream<DifyEvent> bind(Stream<String> stream) {
    return stream.transform(_SSEEventSplitter()).transform(_SSEEventParser());
  }
}

/// SSE事件分割器 - 按\n\n分割SSE事件，优化处理避免内容丢失
class _SSEEventSplitter extends StreamTransformerBase<String, String> {
  @override
  Stream<String> bind(Stream<String> stream) {
    String buffer = '';

    return stream.transform(
      StreamTransformer<String, String>.fromHandlers(
        handleData: (chunk, sink) {
          LoggerService.instance.d(
            '收到数据块，长度: ${chunk.length}',
            category: LogCategory.ai,
            tags: ['sse', 'chunk', 'receive'],
          );
          LoggerService.instance.d(
            '数据块内容: "${chunk.substring(0, chunk.length > 100 ? 100 : chunk.length)}..."',
            category: LogCategory.ai,
            tags: ['sse', 'chunk', 'content'],
          );

          buffer += chunk;
          LoggerService.instance.d(
            '当前缓冲区长度: ${buffer.length}',
            category: LogCategory.ai,
            tags: ['sse', 'buffer'],
          );

          // 按照SSE格式，事件以 \n\n 分隔
          final events = buffer.split('\n\n');
          buffer = events.last; // 保留最后一个可能不完整的事件

          LoggerService.instance.d(
            '分割出 ${events.length - 1} 个完整事件',
            category: LogCategory.ai,
            tags: ['sse', 'parse'],
          );
          LoggerService.instance.d(
            '剩余缓冲区长度: ${buffer.length}',
            category: LogCategory.ai,
            tags: ['sse', 'buffer'],
          );

          // 输出完整的事件
          for (int i = 0; i < events.length - 1; i++) {
            final event = events[i].trim();
            if (event.isNotEmpty) {
              LoggerService.instance.d(
                '输出事件 ${i + 1}: "${event.substring(0, event.length > 50 ? 50 : event.length)}..."',
                category: LogCategory.ai,
                tags: ['sse', 'event', 'output'],
              );
              sink.add(event);
            }
          }
        },
        handleDone: (sink) {
          LoggerService.instance.i(
            '流结束，处理剩余缓冲区',
            category: LogCategory.ai,
            tags: ['sse', 'stream', 'done'],
          );
          LoggerService.instance.d(
            '剩余缓冲区长度: ${buffer.length}',
            category: LogCategory.ai,
            tags: ['sse', 'buffer'],
          );

          // 处理剩余的缓冲区内容，包括可能的不完整事件
          if (buffer.trim().isNotEmpty) {
            // 尝试修复不完整的事件
            final processedBuffer = _fixIncompleteEvent(buffer.trim());
            if (processedBuffer.isNotEmpty) {
              LoggerService.instance.d(
                '输出最后的事件: "${processedBuffer.substring(0, processedBuffer.length > 50 ? 50 : processedBuffer.length)}..."',
                category: LogCategory.ai,
                tags: ['sse', 'event', 'final'],
              );
              sink.add(processedBuffer);
            }
          }
          LoggerService.instance.d(
            '缓冲区处理完成',
            category: LogCategory.ai,
            tags: ['sse', 'buffer'],
          );
          sink.close();
        },
      ),
    );
  }

  /// 修复不完整的事件
  String _fixIncompleteEvent(String event) {
    LoggerService.instance.d(
      '修复不完整事件',
      category: LogCategory.ai,
      tags: ['sse', 'fix', 'event'],
    );
    LoggerService.instance.d(
      '原始事件: "$event"',
      category: LogCategory.ai,
      tags: ['sse', 'fix', 'raw'],
    );

    // 如果事件缺少 data: 前缀，尝试添加
    if (!event.startsWith('data:') && event.trim().isNotEmpty) {
      // 可能是纯JSON数据，尝试添加data:前缀
      try {
        // 验证是否是有效的JSON
        final trimmed = event.trim();
        if (trimmed.startsWith('{') && trimmed.endsWith('}')) {
          final fixed = 'data: $trimmed';
          LoggerService.instance.d(
            '修复后事件: "$fixed"',
            category: LogCategory.ai,
            tags: ['sse', 'fix', 'success'],
          );
          return fixed;
        }
      } catch (e) {
        LoggerService.instance.e(
          '修复失败',
          category: LogCategory.ai,
          tags: ['sse', 'fix', 'error'],
        );
      }
    }

    LoggerService.instance.d(
      '返回原始事件',
      category: LogCategory.ai,
      tags: ['sse', 'fix', 'original'],
    );
    return event;
  }
}

/// SSE事件解析器 - 将事件字符串解析为DifyEvent对象
class _SSEEventParser extends StreamTransformerBase<String, DifyEvent> {
  @override
  Stream<DifyEvent> bind(Stream<String> stream) {
    return stream.transform(
      StreamTransformer<String, DifyEvent>.fromHandlers(
        handleData: (eventStr, sink) {
          LoggerService.instance.d(
            '解析SSE事件',
            category: LogCategory.ai,
            tags: ['sse', 'parse', 'event'],
          );
          LoggerService.instance.d(
            '事件字符串: "$eventStr"',
            category: LogCategory.ai,
            tags: ['sse', 'parse', 'raw'],
          );

          try {
            final event = _parseEvent(eventStr);
            if (event != null) {
              LoggerService.instance.d(
                '解析成功: $event',
                category: LogCategory.ai,
                tags: ['sse', 'parse', 'success'],
              );
              sink.add(event);
            } else {
              LoggerService.instance.w(
                '跳过空事件',
                category: LogCategory.ai,
                tags: ['sse', 'parse', 'skip'],
              );
            }
          } catch (e) {
            LoggerService.instance.e(
              '解析失败',
              category: LogCategory.ai,
              tags: ['sse', 'parse', 'error'],
            );
            LoggerService.instance.d(
              '原始事件: "$eventStr"',
              category: LogCategory.ai,
              tags: ['sse', 'parse', 'raw'],
            );
            // 不抛出异常，继续处理下一个事件
          }
        },
        handleError: (error, stackTrace, sink) {
          LoggerService.instance.e(
            'SSE流错误',
            category: LogCategory.ai,
            tags: ['sse', 'stream', 'error'],
          );
          sink.addError(error, stackTrace);
        },
        handleDone: (sink) {
          LoggerService.instance.i(
            'SSE流结束',
            category: LogCategory.ai,
            tags: ['sse', 'stream', 'done'],
          );
          sink.close();
        },
      ),
    );
  }

  /// 解析单个SSE事件
  DifyEvent? _parseEvent(String eventStr) {
    String? eventData;

    // 解析SSE格式的行
    final lines = eventStr.split('\n');
    for (final line in lines) {
      if (line.startsWith('data: ')) {
        eventData = line.substring(6);
        if (eventData.trim().isEmpty) {
          eventData = null;
        }
      }
    }

    if (eventData == null) {
      LoggerService.instance.w(
        '没有找到有效的data字段',
        category: LogCategory.ai,
        tags: ['sse', 'parse', 'nodata'],
      );
      return null;
    }

    try {
      final json = jsonDecode(eventData) as Map<String, dynamic>;
      return DifyEvent.fromJson(json, eventData);
    } catch (e) {
      LoggerService.instance.e(
        'JSON解析失败',
        category: LogCategory.ai,
        tags: ['sse', 'parse', 'json'],
      );
      LoggerService.instance.d(
        '原始数据: "$eventData"',
        category: LogCategory.ai,
        tags: ['sse', 'parse', 'raw'],
      );
      return null;
    }
  }
}
