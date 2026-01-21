# TTS朗读功能设计文档

## 概述

为Novel Builder应用添加文本转语音(TTS)朗读功能，使用系统原生TTS引擎实现小说内容的语音播放。

## 设计日期

2025-01-21

## 核心需求

- 使用系统TTS引擎（Android TextToSpeech / iOS AVSpeechSynthesizer）
- 支持播放/暂停/停止/语速调节
- 朗读时高亮当前段落，自动滚动跟随
- 支持后台播放
- 跨章节连续朗读（本章读完自动读下一章）
- 独立全屏播放页面
- 断点续读功能

## 架构设计

### 服务层

```
TtsService (Platform Channel)
    ↓
TtsPlayerService (状态管理)
    ↓
TtsPlayerScreen (UI)
```

### 核心组件

1. **TtsService** - TTS引擎封装
   - Platform Channel调用原生代码
   - 管理原生引擎生命周期
   - 提供统一播放控制接口

2. **TtsPlayerService** - 播放器服务
   - 管理播放状态和队列
   - 协调章节切换
   - 保存/恢复朗读进度

3. **TtsPlayerScreen** - 全屏播放页面
   - 大字显示当前朗读内容
   - 播放控制按钮
   - 进度指示器

## 数据流

```
启动朗读 → 分割段落 → 逐段播放 → 段落完成 → 下一段
                                              ↓
                                        章节完成检测
                                              ↓
                                    加载下一章 → 继续播放
                                              ↓
                                    全部完成 → 显示完成
```

## 状态管理

```dart
enum TtsPlayerState {
  idle,       // 空闲
  loading,    // 加载中
  playing,    // 播放中
  paused,     // 已暂停
  error,      // 错误
  completed,  // 完成
}
```

## 跨章节朗读逻辑

1. 当前章节最后一段完成
2. 检查是否有下一章
3. 加载下一章内容（数据库或API）
4. 更新当前章节信息
5. 开始朗读新章节

## 进度保存

```json
{
  "novel_url": "...",
  "chapter_url": "...",
  "paragraph_index": 5,
  "speech_rate": 1.2,
  "timestamp": 1234567890
}
```

## 错误处理

- TTS初始化失败：禁用功能，显示提示
- 内容加载失败：重试/跳过/停止选项
- 网络错误：优先使用缓存
- 播放中断：自动暂停，恢复后继续

## 原生实现

### Android
- `TextToSpeech` API
- 前台服务支持后台播放
- 音频焦点管理

### iOS
- `AVSpeechSynthesizer` API
- `AVAudioSession` 配置
- 后台音频模式

## 文件结构

```
lib/
├── services/
│   ├── tts_service.dart           # TTS核心服务
│   └── tts_player_service.dart    # 播放器服务
├── screens/
│   └── tts_player_screen.dart     # 全屏播放页面
├── models/
│   └── reading_progress.dart      # 进度模型
└── widgets/
    └── tts_control_panel.dart     # 控制面板组件

android/app/src/main/kotlin/.../TtsPlugin.kt
ios/Runner/TtsPlugin.swift
```

## 开发计划

1. 实现TtsService基础框架
2. 实现原生Android TTS
3. 实现原生iOS TTS
4. 实现TtsPlayerService状态管理
5. 创建TtsPlayerScreen UI
6. 集成到ReaderScreen
7. 添加进度保存功能
8. 测试和调试
