# PreloadService 并发安全修复方案

## 🐛 问题分析

当前代码存在竞态条件 (Race Condition):

```dart
Future<void> _processQueue() async {
  if (_isProcessing) {        // ❌ 检查和设置不是原子操作
    return;
  }
  _isProcessing = true;
  // ...
}
```

**风险场景**:
- 用户快速翻页时,多个 `_loadChapterData()` 异步调用几乎同时执行
- 多个线程通过 `_isProcessing` 检查,都设置为 `true`
- 导致多个并发循环同时运行,30秒内缓存多章

---

## ✅ 解决方案

### 方案1: 使用 `Completer` 跟踪执行 (推荐)

```dart
class PreloadService {
  // 使用 Completer 而不是 bool 标志
  Completer<void>? _processingCompleter;

  Future<void> _processQueue() async {
    // 🔒 原子检查: 如果已有Completer,说明正在处理
    if (_processingCompleter != null) {
      debugPrint('⚠️ 队列处理中,跳过重复启动');
      return _processingCompleter!.future; // 可选:等待现有任务完成
    }

    // 🔒 创建新的Completer
    final completer = Completer<void>();
    _processingCompleter = completer;

    debugPrint('🚀 开始处理预加载队列');

    try {
      while (_queue.isNotEmpty) {
        await _rateLimiter.acquire();
        final task = _queue.removeFirst();
        // ... 处理任务
      }

      debugPrint('✅ 队列处理完成');
      completer.complete(); // ✅ 标记完成
    } catch (e) {
      debugPrint('❌ 队列处理失败: $e');
      completer.completeError(e); // ✅ 标记失败
    } finally {
      _processingCompleter = null; // ✅ 释放锁
    }
  }
}
```

**优点**:
- ✅ 真正的原子检查: `_processingCompleter != null` 是单个操作
- ✅ 可以等待现有任务完成 (可选)
- ✅ 更好的错误处理

---

### 方案2: 使用 `Mutex` 互斥锁 (最安全)

```dart
import 'package:mutex/mutex.dart';

class PreloadService {
  final Mutex _mutex = Mutex();

  Future<void> _processQueue() async {
    // 🔒 使用互斥锁确保同一时间只有一个执行
    if (_mutex.isLocked) {
      debugPrint('⚠️ 队列处理中,跳过重复启动');
      return;
    }

    await _mutex.protect(() async {
      debugPrint('🚀 开始处理预加载队列');

      try {
        while (_queue.isNotEmpty) {
          await _rateLimiter.acquire();
          final task = _queue.removeFirst();
          // ... 处理任务
        }
      } finally {
        // 锁自动释放
      }
    });
  }
}
```

**优点**:
- ✅ 最安全:互斥锁保证绝对不会并发
- ✅ 跨平台支持
- ✅ 业界标准做法

**缺点**:
- ❌ 需要添加依赖: `mutex: ^0.3.0`

---

### 方案3: 使用 `Atomic` 标志 (轻量级)

```dart
class PreloadService {
  // 使用 Atomic 操作
  bool _isProcessing = false;
  bool _isSettingLock = false; // 防止检查-设置竞态

  Future<void> _processQueue() async {
    // 🔒 防止竞态的检查-设置
    if (_isProcessing) {
      return;
    }

    // 尝试获取锁
    if (_isSettingLock) {
      return;
    }
    _isSettingLock = true;

    // 再次检查(双重检查锁定模式)
    if (_isProcessing) {
      _isSettingLock = false;
      return;
    }

    _isProcessing = true;
    _isSettingLock = false;

    debugPrint('🚀 开始处理预加载队列');

    try {
      while (_queue.isNotEmpty) {
        await _rateLimiter.acquire();
        // ... 处理任务
      }
    } finally {
      _isProcessing = false;
    }
  }
}
```

**优点**:
- ✅ 无需额外依赖
- ✅ 性能开销最小

**缺点**:
- ❌ 仍然不是100%线程安全(Dart单线程模型下通常够用)
- ❌ 代码复杂度增加

---

## 📊 方案对比

| 方案 | 安全性 | 性能 | 复杂度 | 依赖 | 推荐度 |
|-----|-------|-----|-------|------|--------|
| 方案1: Completer | ⭐⭐⭐⭐ | ⭐⭐⭐⭐ | ⭐⭐⭐ | 无 | ⭐⭐⭐⭐⭐ |
| 方案2: Mutex | ⭐⭐⭐⭐⭐ | ⭐⭐⭐⭐ | ⭐⭐⭐⭐⭐ | mutex包 | ⭐⭐⭐⭐ |
| 方案3: 双重检查 | ⭐⭐⭐ | ⭐⭐⭐⭐⭐ | ⭐⭐ | 无 | ⭐⭐⭐ |

---

## 🎯 最终推荐

**推荐方案1 (Completer)**,理由:
1. ✅ 零依赖,改动最小
2. ✅ 安全性足够(Dart单线程模型)
3. ✅ 代码更清晰,易于维护
4. ✅ 可以等待现有任务完成(更好的用户体验)

---

## 🧪 测试验证

修复后运行以下测试验证:

```bash
cd novel_app
flutter test test/unit/preload_service_race_condition_test.dart
```

预期结果:
- 2秒内只处理1章 (而不是2章或更多)
- 不会出现多个并发循环

---

## 📝 修复后的完整代码

见下方的 `preload_service_fixed.dart`
