import 'dart:convert';

/// ComfyUI 模型下载/上传任务状态
enum ModelDownloadStatus {
  /// 下载中
  downloading,

  /// 下载已暂停
  downloadPaused,

  /// 下载完成（待上传或待用户操作）
  downloaded,

  /// 上传中
  uploading,

  /// 上传已暂停
  uploadPaused,

  /// 已完成（上传成功，本地文件已删除）
  completed,

  /// 已取消
  cancelled,

  /// 失败
  failed;

  /// 从字符串解析状态，未知值回退到 [failed]
  static ModelDownloadStatus fromString(String value) {
    return ModelDownloadStatus.values.firstWhere(
      (s) => s.name == value,
      orElse: () => ModelDownloadStatus.failed,
    );
  }
}

/// ComfyUI 模型下载/上传任务
///
/// 描述一次「WebView 触发下载 → 本地缓存 → 分块上传到 backend /app/models」
/// 的完整生命周期。任务状态持久化到 SQLite，支持跨 app 重启续传。
class ModelDownloadTask {
  /// 任务唯一标识（UUID）
  final String id;

  /// 下载源 URL
  final String url;

  /// 目标文件名
  final String filename;

  /// 保存到的 backend 子目录名（/app/models 下的一级子目录）
  final String targetSubdir;

  /// 文件总大小（字节），下载开始前可能为 0
  final int totalSize;

  /// 已下载字节数
  final int downloadedBytes;

  /// 已上传完成的分块序号集合
  final List<int> uploadedChunkIndices;

  /// 分块大小（字节）
  final int chunkSize;

  /// 分块总数
  final int totalChunks;

  /// 当前状态
  final ModelDownloadStatus status;

  /// 本地文件路径（下载中的 .part 或下载完成的文件）
  final String localPath;

  /// backend 返回的上传任务 ID
  final String? backendUploadId;

  /// 触发下载的来源页面 URL（用于审计/展示）
  final String? sourcePage;

  /// 错误信息（status == failed 时）
  final String? errorMessage;

  /// 创建时间（毫秒）
  final int createdAt;

  /// 更新时间（毫秒）
  final int updatedAt;

  ModelDownloadTask({
    required this.id,
    required this.url,
    required this.filename,
    required this.targetSubdir,
    this.totalSize = 0,
    this.downloadedBytes = 0,
    List<int>? uploadedChunkIndices,
    this.chunkSize = 0,
    this.totalChunks = 0,
    required this.status,
    required this.localPath,
    this.backendUploadId,
    this.sourcePage,
    this.errorMessage,
    required this.createdAt,
    required this.updatedAt,
  }) : uploadedChunkIndices = uploadedChunkIndices ?? const [];

  /// 是否处于下载阶段（含暂停）
  bool get isDownloadPhase =>
      status == ModelDownloadStatus.downloading ||
      status == ModelDownloadStatus.downloadPaused;

  /// 是否处于上传阶段（含暂停）
  bool get isUploadPhase =>
      status == ModelDownloadStatus.uploading ||
      status == ModelDownloadStatus.uploadPaused;

  /// 下载进度（0.0 - 1.0），未知总大小时为 0
  double get downloadProgress =>
      totalSize > 0 ? (downloadedBytes / totalSize).clamp(0.0, 1.0) : 0.0;

  /// 上传进度（0.0 - 1.0）
  double get uploadProgress =>
      totalChunks > 0 ? (uploadedChunkIndices.length / totalChunks).clamp(0.0, 1.0) : 0.0;

  ModelDownloadTask copyWith({
    String? id,
    String? url,
    String? filename,
    String? targetSubdir,
    int? totalSize,
    int? downloadedBytes,
    List<int>? uploadedChunkIndices,
    int? chunkSize,
    int? totalChunks,
    ModelDownloadStatus? status,
    String? localPath,
    String? backendUploadId,
    String? sourcePage,
    String? errorMessage,
    int? createdAt,
    int? updatedAt,
  }) {
    return ModelDownloadTask(
      id: id ?? this.id,
      url: url ?? this.url,
      filename: filename ?? this.filename,
      targetSubdir: targetSubdir ?? this.targetSubdir,
      totalSize: totalSize ?? this.totalSize,
      downloadedBytes: downloadedBytes ?? this.downloadedBytes,
      uploadedChunkIndices: uploadedChunkIndices ?? this.uploadedChunkIndices,
      chunkSize: chunkSize ?? this.chunkSize,
      totalChunks: totalChunks ?? this.totalChunks,
      status: status ?? this.status,
      localPath: localPath ?? this.localPath,
      backendUploadId: backendUploadId ?? this.backendUploadId,
      sourcePage: sourcePage ?? this.sourcePage,
      errorMessage: errorMessage ?? this.errorMessage,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'url': url,
      'filename': filename,
      'targetSubdir': targetSubdir,
      'totalSize': totalSize,
      'downloadedBytes': downloadedBytes,
      'uploadedChunkIndicesJson': jsonEncode(uploadedChunkIndices),
      'chunkSize': chunkSize,
      'totalChunks': totalChunks,
      'status': status.name,
      'localPath': localPath,
      'backendUploadId': backendUploadId,
      'sourcePage': sourcePage,
      'errorMessage': errorMessage,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
    };
  }

  factory ModelDownloadTask.fromMap(Map<String, dynamic> map) {
    List<int> parseIndices(dynamic raw) {
      if (raw is String && raw.isNotEmpty) {
        try {
          final decoded = jsonDecode(raw);
          if (decoded is List) {
            return decoded.map((e) => (e as num).toInt()).toList();
          }
        } catch (_) {}
      }
      return const [];
    }

    return ModelDownloadTask(
      id: map['id'] as String,
      url: map['url'] as String,
      filename: map['filename'] as String,
      targetSubdir: map['targetSubdir'] as String,
      totalSize: (map['totalSize'] as num?)?.toInt() ?? 0,
      downloadedBytes: (map['downloadedBytes'] as num?)?.toInt() ?? 0,
      uploadedChunkIndices: parseIndices(map['uploadedChunkIndicesJson']),
      chunkSize: (map['chunkSize'] as num?)?.toInt() ?? 0,
      totalChunks: (map['totalChunks'] as num?)?.toInt() ?? 0,
      status: ModelDownloadStatus.fromString(map['status'] as String? ?? ''),
      localPath: map['localPath'] as String,
      backendUploadId: map['backendUploadId'] as String?,
      sourcePage: map['sourcePage'] as String?,
      errorMessage: map['errorMessage'] as String?,
      createdAt: (map['createdAt'] as num?)?.toInt() ?? 0,
      updatedAt: (map['updatedAt'] as num?)?.toInt() ?? 0,
    );
  }
}
