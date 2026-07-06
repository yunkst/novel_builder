/// Agent 图片本地缓存服务
///
/// 单例，存放在 `<application_documents>/agent_images/` 下。
/// 文件名 `<imageId>.png`，与 ToolExecutor._createImages 生成的 imageId
/// 一一对应。跨会话 hydrate：重启 app 后从 chat_messages.toolCallsJson
/// 恢复的 imageId 仍能命中本地文件直接显示。
///
/// 不做主动 LRU 清理（量小，靠用户重装/清缓存兜底；与 llm_logger 落盘策略一致）。
library;

import 'dart:io';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';

import 'logger_service.dart';

class AgentImageCacheService {
  static final AgentImageCacheService instance = AgentImageCacheService._();

  AgentImageCacheService._();

  /// 缓存根目录名（位于应用文档目录下）
  static const String _dirName = 'agent_images';

  /// 缓存根目录惰性解析
  Future<Directory> _rootDir() async {
    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory('${docs.path}${Platform.pathSeparator}$_dirName');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  /// 拼出 `imageId.png` 完整路径。
  /// 注意：imageId 由 ToolExecutor 生成（`img_{ts}_{idx}`），不含路径分隔符，
  /// 这里按文件名拼接，规避路径穿越风险。
  Future<File> _pathFor(String imageId) async {
    final root = await _rootDir();
    final safeName = imageId.endsWith('.png') ? imageId : '$imageId.png';
    return File('${root.path}${Platform.pathSeparator}$safeName');
  }

  /// 读取缓存文件。命中返回 File，未命中返回 null。
  Future<File?> getFile(String imageId) async {
    try {
      final file = await _pathFor(imageId);
      if (await file.exists() && (await file.length()) > 0) {
        return file;
      }
      return null;
    } catch (e) {
      LoggerService.instance.d(
        'AgentImageCache.getFile 失败: imageId=$imageId, $e',
        category: LogCategory.cache,
        tags: ['agent', 'image_cache', 'read_failed'],
      );
      return null;
    }
  }

  /// 写入字节到缓存，返回保存后的 File。
  /// 上层在拿到 200 图片字节后调用，幂等：重复写会覆盖。
  Future<File> saveBytes(String imageId, Uint8List bytes) async {
    final file = await _pathFor(imageId);
    await file.writeAsBytes(bytes, flush: true);
    LoggerService.instance.d(
      'AgentImageCache.saveBytes: $imageId (${bytes.length} bytes)',
      category: LogCategory.cache,
      tags: ['agent', 'image_cache', 'write'],
    );
    return file;
  }
}
