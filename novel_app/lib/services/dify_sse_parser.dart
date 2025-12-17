import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';

/// Dify SSE事件类型
enum DifyEventType {
  textChunk,      // 文本块事件
  workflowFinished, // 工作流完成
  workflowError,   // 工作流错误
  unknown          // 未知事件
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
        .where((event) => event.type == DifyEventType.textChunk && event.text != null)
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
          debugPrint('📦 === 收到数据块 ===');
          debugPrint('数据块长度: ${chunk.length}');
          debugPrint('数据块内容: "${chunk.substring(0, chunk.length > 100 ? 100 : chunk.length)}..."');

          buffer += chunk;
          debugPrint('当前缓冲区长度: ${buffer.length}');

          // 按照SSE格式，事件以 \n\n 分隔
          final events = buffer.split('\n\n');
          buffer = events.last; // 保留最后一个可能不完整的事件

          debugPrint('分割出 ${events.length - 1} 个完整事件');
          debugPrint('剩余缓冲区长度: ${buffer.length}');

          // 输出完整的事件
          for (int i = 0; i < events.length - 1; i++) {
            final event = events[i].trim();
            if (event.isNotEmpty) {
              debugPrint('📤 输出事件 ${i + 1}: "${event.substring(0, event.length > 50 ? 50 : event.length)}..."');
              sink.add(event);
            }
          }
          debugPrint('========================');
        },
        handleDone: (sink) {
          debugPrint('🏁 === 流结束，处理剩余缓冲区 ===');
          debugPrint('剩余缓冲区长度: ${buffer.length}');

          // 处理剩余的缓冲区内容，包括可能的不完整事件
          if (buffer.trim().isNotEmpty) {
            // 尝试修复不完整的事件
            final processedBuffer = _fixIncompleteEvent(buffer.trim());
            if (processedBuffer.isNotEmpty) {
              debugPrint('📤 输出最后的事件: "${processedBuffer.substring(0, processedBuffer.length > 50 ? 50 : processedBuffer.length)}..."');
              sink.add(processedBuffer);
            }
          }
          debugPrint('缓冲区处理完成');
          sink.close();
        },
      ),
    );
  }

  /// 修复不完整的事件
  String _fixIncompleteEvent(String event) {
    debugPrint('🔧 === 修复不完整事件 ===');
    debugPrint('原始事件: "$event"');

    // 如果事件缺少 data: 前缀，尝试添加
    if (!event.startsWith('data:') && event.trim().isNotEmpty) {
      // 可能是纯JSON数据，尝试添加data:前缀
      try {
        // 验证是否是有效的JSON
        final trimmed = event.trim();
        if (trimmed.startsWith('{') && trimmed.endsWith('}')) {
          final fixed = 'data: $trimmed';
          debugPrint('✅ 修复后事件: "$fixed"');
          return fixed;
        }
      } catch (e) {
        debugPrint('❌ 修复失败: $e');
      }
    }

    debugPrint('📝 返回原始事件');
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
          debugPrint('🔥 === 解析SSE事件 ===');
          debugPrint('事件字符串: "$eventStr"');
          debugPrint('====================');

          try {
            final event = _parseEvent(eventStr);
            if (event != null) {
              debugPrint('✅ 解析成功: $event');
              sink.add(event);
            } else {
              debugPrint('⚠️ 跳过空事件');
            }
          } catch (e) {
            debugPrint('❌ 解析失败: $e');
            debugPrint('原始事件: "$eventStr"');
            // 不抛出异常，继续处理下一个事件
          }
        },
        handleError: (error, stackTrace, sink) {
          debugPrint('❌ SSE流错误: $error');
          sink.addError(error, stackTrace);
        },
        handleDone: (sink) {
          debugPrint('🏁 SSE流结束');
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
      debugPrint('⚠️ 没有找到有效的data字段');
      return null;
    }

    try {
      final json = jsonDecode(eventData) as Map<String, dynamic>;
      return DifyEvent.fromJson(json, eventData);
    } catch (e) {
      debugPrint('❌ JSON解析失败: $e');
      debugPrint('原始数据: "$eventData"');
      return null;
    }
  }
}