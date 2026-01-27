# LoggerService 日志分类和标签功能使用指南

## 概述

LoggerService 现已支持日志分类和标签功能，可以更精细地管理和过滤日志。

## 功能特性

### 1. 日志分类 (LogCategory)

提供8个预定义的分类：

| 分类 | Key | Label | 使用场景 |
|------|-----|-------|----------|
| database | database | 数据库 | 数据库操作、查询、事务 |
| network | network | 网络 | HTTP请求、API调用 |
| ai | ai | AI | Dify工作流、AI生成 |
| ui | ui | 界面 | 用户交互、UI更新 |
| cache | cache | 缓存 | 缓存读写、失效策略 |
| tts | tts | 语音 | 语音合成、播放控制 |
| character | character | 角色 | 角色管理、关系图谱 |
| general | general | 通用 | 其他未分类日志 |

### 2. 日志标签 (Tags)

为日志添加自定义标签，便于多维度过滤和搜索。

## 使用方法

### 基础用法（不使用分类）

```dart
// 默认分类为 general
LoggerService.instance.i('应用启动完成');
LoggerService.instance.e('发生错误', stackTrace: stackTrace);
```

### 使用分类

```dart
// 数据库相关日志
LoggerService.instance.i(
  '数据库升级完成',
  category: LogCategory.database,
);

// 网络请求日志
LoggerService.instance.i(
  'API请求成功',
  category: LogCategory.network,
);

// AI功能日志
LoggerService.instance.d(
  'Dify响应数据',
  category: LogCategory.ai,
);
```

### 使用标签

```dart
// 添加单个或多个标签
LoggerService.instance.i(
  'HTTP GET请求',
  category: LogCategory.network,
  tags: ['http', 'get', 'api'],
);

// TTS播放日志
LoggerService.instance.i(
  '开始语音播放',
  category: LogCategory.tts,
  tags: ['playback', 'chapter-1'],
);
```

### 组合使用

```dart
// 数据库查询标签化
LoggerService.instance.d(
  '执行SQL查询',
  category: LogCategory.database,
  tags: ['query', 'novels-table'],
);

// AI生成日志
LoggerService.instance.i(
  '生成场景插图',
  category: LogCategory.ai,
  tags: ['comfyui', 'scene-illustration'],
);

// 缓存操作
LoggerService.instance.w(
  '缓存命中率低',
  category: LogCategory.cache,
  tags: ['performance', 'redis'],
);
```

## 实际应用示例

### 1. 数据库操作日志

```dart
class DatabaseService {
  Future<void> upgradeDatabase() async {
    LoggerService.instance.i(
      '开始数据库升级',
      category: LogCategory.database,
      tags: ['migration', 'v3-to-v4'],
    );

    try {
      // 执行升级逻辑
      await _runMigration();

      LoggerService.instance.i(
        '数据库升级成功',
        category: LogCategory.database,
        tags: ['migration', 'success'],
      );
    } catch (e) {
      LoggerService.instance.e(
        '数据库升级失败: $e',
        category: LogCategory.database,
        tags: ['migration', 'error'],
      );
    }
  }
}
```

### 2. 网络请求日志

```dart
class BackendApiService {
  Future<void> fetchNovelChapters(String novelUrl) async {
    LoggerService.instance.i(
      '请求章节列表',
      category: LogCategory.network,
      tags: ['chapters', novelUrl],
    );

    try {
      final response = await httpClient.get(novelUrl);

      LoggerService.instance.d(
        '响应数据: ${response.body}',
        category: LogCategory.network,
        tags: ['response', '200'],
      );
    } catch (e) {
      LoggerService.instance.e(
        '网络请求失败: $e',
        category: LogCategory.network,
        tags: ['error', 'network'],
      );
    }
  }
}
```

### 3. AI功能日志

```dart
class DifyService {
  Future<String> generateScene(String prompt) async {
    LoggerService.instance.i(
      '调用Dify工作流',
      category: LogCategory.ai,
      tags: ['dify', 'scene-generation'],
    );

    try {
      final result = await _callDifyWorkflow(prompt);

      LoggerService.instance.i(
        'AI生成完成',
        category: LogCategory.ai,
        tags: ['dify', 'success'],
      );

      return result;
    } catch (e) {
      LoggerService.instance.e(
        'AI生成失败: $e',
        category: LogCategory.ai,
        tags: ['dify', 'error'],
      );
      rethrow;
    }
  }
}
```

### 4. UI交互日志

```dart
class ReaderScreen extends StatelessWidget {
  void _handleChapterTap(Chapter chapter) {
    LoggerService.instance.d(
      '用户点击章节',
      category: LogCategory.ui,
      tags: ['tap', 'chapter', chapter.title],
    );
  }

  void _handleSettingsOpen() {
    LoggerService.instance.i(
      '打开设置页面',
      category: LogCategory.ui,
      tags: ['navigation', 'settings'],
    );
  }
}
```

### 5. TTS功能日志

```dart
class TTSPlayerService {
  Future<void> playChapter(String content) async {
    LoggerService.instance.i(
      '开始TTS播放',
      category: LogCategory.tts,
      tags: ['play', 'chapter'],
    );

    try {
      await _speak(content);

      LoggerService.instance.i(
        'TTS播放完成',
        category: LogCategory.tts,
        tags: ['complete', 'chapter'],
      );
    } catch (e) {
      LoggerService.instance.e(
        'TTS播放失败: $e',
        category: LogCategory.tts,
        tags: ['error', 'playback'],
      );
    }
  }
}
```

## 日志过滤建议

虽然当前版本还未实现分类过滤API，但您可以通过遍历日志手动过滤：

```dart
// 按分类过滤
final aiLogs = LoggerService.instance.getLogs()
    .where((log) => log.category == LogCategory.ai)
    .toList();

// 按标签过滤
final difyLogs = LoggerService.instance.getLogs()
    .where((log) => log.tags.contains('dify'))
    .toList();

// 组合过滤
final errorDifyLogs = LoggerService.instance.getLogs()
    .where((log) =>
        log.category == LogCategory.ai &&
        log.tags.contains('dify') &&
        log.level == LogLevel.error)
    .toList();
```

## 最佳实践

### 1. 选择合适的分类

- **database**: 所有数据库相关操作
- **network**: HTTP/HTTPS请求、WebSocket连接
- **ai**: Dify、ComfyUI等AI功能
- **ui**: 用户交互、页面导航、状态更新
- **cache**: 本地缓存、远程缓存
- **tts**: 文本转语音功能
- **character**: 角色卡片、关系图谱
- **general**: 无法归类的通用日志

### 2. 使用有意义的标签

```dart
// 好的标签示例
tags: ['migration', 'v3-to-v4', 'users-table']
tags: ['http', 'get', '/api/novels']
tags: ['dify', 'workflow-v1', 'scene-generation']

// 避免使用过于泛泛的标签
tags: ['log', 'info']  // ❌ 太泛泛
tags: ['error']        // ❌ 应该使用LogLevel.error
```

### 3. 保持一致性

```dart
// 统一使用小写和连字符
tags: ['scene-illustration', 'comfyui']
tags: ['chapter-cache', 'hit']

// 避免混用格式
tags: ['scene_illustration', 'ComfyUI']  // ❌ 不一致
```

### 4. 标签粒度适中

```dart
// 好的粒度
tags: ['query', 'novels-table']
tags: ['http', 'post', '/api/chapters']

// 过细的粒度
tags: ['mysql', 'query', 'select', 'novels', 'table']  // ❌ 太多标签

// 过粗的粒度
tags: ['database']  // ❌ 应该用category
```

## 向后兼容性

旧代码无需修改即可继续使用：

```dart
// 旧代码仍然有效
LoggerService.instance.i('信息日志');

// 自动使用默认值：
// - category: LogCategory.general
// - tags: []
```

## 迁移指南

如果您想将现有日志迁移到使用分类和标签：

```dart
// 迁移前
LoggerService.instance.i('数据库查询完成');

// 迁移后
LoggerService.instance.i(
  '数据库查询完成',
  category: LogCategory.database,
  tags: ['query', 'select'],
);
```

## 性能考虑

1. **标签存储**: 标签存储在内存中，避免添加过多标签（建议不超过5个）
2. **序列化**: 每个标签都会被序列化到SharedPreferences，考虑性能影响
3. **过滤**: 当前版本不支持索引过滤，大量日志时手动过滤可能较慢

## 未来计划

- [ ] 添加按分类过滤的API方法
- [ ] 添加按标签过滤的API方法
- [ ] 在LogViewer中显示分类和标签
- [ ] 支持标签搜索和高亮
- [ ] 添加分类图标显示

## 总结

日志分类和标签功能提供了更精细的日志管理能力，建议：

1. 为所有日志添加合适的分类
2. 为重要操作添加有意义的标签
3. 保持命名和格式的一致性
4. 定期审查和优化标签使用

这样可以更好地追踪应用行为，快速定位问题。
