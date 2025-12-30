# Novel Builder - Flutter应用架构问题清单

## 📋 问题总览

**分析日期**: 2025-12-25
**总体评分**: 4.4/10 - 急需架构重构
**总代码行数**: 约 25,000+ 行
**Dart文件数**: 94个

---

## 🔴 高优先级问题（必须修复）

### 1. CacheManager 命名冲突

**位置**:
- `lib/services/cache_manager.dart` (168行) - 小说章节缓存管理
- `lib/core/cache/cache_manager.dart` (337行) - 通用内存缓存
- `lib/core/di/service_locator.dart:24-25` - DI容器中的命名冲突

**问题**:
两个功能完全不同的类使用相同的名字，极易误用。

**影响**:
- 开发者可能误用错误的 CacheManager
- IDE 自动补全可能给出错误建议
- 代码可读性差

**建议重命名**:
- `services.CacheManager` → `NovelChapterCacheManager` 或 `BackgroundChapterDownloader`
- `core.cache.CacheManager` → `MemoryCacheManager` 或 `InMemoryCacheManager`

**预计工作量**: 2小时

---

### 2. 未使用的 Clean Architecture Repository 层 ⚠️ **可删除**

**位置**:
- `lib/core/repositories/novel_repository.dart` (29行)
- `lib/core/repositories/chapter_repository.dart` (未检查具体内容)
- `lib/core/repositories/ai_service_repository.dart` (未检查具体内容)
- `lib/data/repositories/novel_repository_impl.dart` (164行)
- `lib/data/repositories/chapter_repository_impl.dart` (未检查具体内容)

**问题**:
定义了完整的 Repository 接口和实现，但实际代码中没有任何使用。

**证据**:
```bash
# NovelRepository 只在以下文件中出现：
- lib/core/repositories/novel_repository.dart (接口定义)
- lib/data/repositories/novel_repository_impl.dart (实现)
- lib/core/di/service_locator.dart (DI注册)

# 在实际业务代码中的搜索结果：
grep -r "NovelRepository" lib/screens/  # 0 结果
grep -r "NovelRepository" lib/widgets/  # 0 结果
grep -r "NovelRepository" lib/services/ # 0 结果
```

**建议**: ✅ **完全删除** 这些文件

**预计工作量**: 1小时

---

### 3. UseCase 抽象类完全未使用 ⚠️ **可删除**

**位置**: `lib/core/use_cases/use_case.dart` (15行)

**问题**:
定义了 UseCase 抽象类，但没有任何实现。

**证据**:
```bash
grep -r "extends UseCase" lib/  # 0 结果
```

**内容**:
```dart
abstract class UseCase<T, P> {
  Future<Result<T>> call(P params);
}

class NoParams {
  const NoParams();
}
```

**建议**: ✅ **完全删除** 此文件和整个目录

**预计工作量**: 5分钟

---

### 4. Failure 类几乎未使用 ⚠️ **部分可删除**

**位置**:
- `lib/core/failures/database_failure.dart` (17行)
- `lib/core/failures/network_failure.dart` (20行)
- `lib/core/failures/cache_failure.dart` (未检查)
- `lib/core/failures/ai_service_failure.dart` (未检查)
- `lib/core/errors/failure.dart` (基类)

**问题**:
定义了多种 Failure 类型，但只在未使用的 Repository 层中使用。

**证据**:
```bash
# 在实际业务代码中的使用情况：
grep -r "DatabaseFailure" lib/screens/   # 0 结果
grep -r "DatabaseFailure" lib/services/  # 0 结果
grep -r "NetworkFailure" lib/screens/    # 0 结果
grep -r "NetworkFailure" lib/services/   # 0 结果
```

**使用情况**:
只在以下文件中使用：
- `lib/data/repositories/novel_repository_impl.dart`
- `lib/data/repositories/chapter_repository_impl.dart`
- `lib/core/cache/cache_manager.dart`
- `lib/core/network/api_client.dart`

**建议**: ✅ **完全删除** `lib/core/failures/` 目录

**预计工作量**: 10分钟

---

### 5. DatabaseService 巨石类

**位置**: `lib/services/database_service.dart` (1582行，50+个公共方法)

**问题**:
违反单一职责原则，一个类负责：
- 书架管理 (9个方法)
- 章节内容缓存 (14个方法)
- 章节元数据管理 (8个方法)
- 人物卡CRUD (13个方法)
- 场景插图CRUD (8个方法)
- 搜索功能 (3个方法)
- 阅读进度管理

**建议拆分**:
```dart
class BookshelfDao { ... }       // 书架相关
class ChapterCacheDao { ... }    // 章节缓存相关
class CharacterDao { ... }       // 人物卡相关
class IllustrationDao { ... }    // 插图相关
class SearchDao { ... }          // 搜索相关
```

**预计工作量**: 2-3天

---

### 6. ApiServiceWrapper 职责过重

**位置**: `lib/services/api_service_wrapper.dart` (944行)

**问题**:
包含过多功能：
- 基础API (6个方法)
- 角色卡API (6个方法)
- 场景插图API (5个方法)
- 视频生成API (4个方法)
- 连接管理 (3个方法)

**建议拆分**:
```dart
ApiServiceWrapper → 只保留基础API

新增：
- RoleCardApiService
- SceneIllustrationApiService
- VideoGenerationApiService
```

**预计工作量**: 2天

---

## 🟡 中优先级问题（建议修复）

### 7. 状态管理模式混乱

**位置**:
- `lib/providers/reader_edit_mode_provider.dart`
- `lib/controllers/paragraph_rewrite_controller.dart`
- `lib/controllers/summarize_controller.dart`
- `lib/services/` (直接使用Service状态)

**问题**:
三种状态管理模式并存：
1. Provider 模式
2. Controller 模式（本质相同但命名不同）
3. 直接使用 Service

**建议**:
统一使用一种模式，制定规范文档

**预计工作量**: 3天

---

### 8. 模型序列化方式不一致

**位置**:
- `lib/models/character.dart` - 手动 toMap()/fromMap()
- `lib/models/scene_illustration.dart` - 同时使用 json_annotation 和手动方法
- `lib/models/novel.dart` - 手动方法

**问题**:
```dart
// SceneIllustration 混乱示例：
@JsonSerializable()  // 使用代码生成
factory SceneIllustration.fromJson(...) => _$SceneIllustrationFromJson(json);
factory SceneIllustration.fromMap(...) { ... }  // 又有手动实现
Map<String, dynamic> toMap() { ... }  // 手动实现
Map<String, dynamic> toJson() => _$SceneIllustrationToJson(this);  // 自动生成
```

**建议**:
统一使用 json_serializable 或 freezed

**预计工作量**: 1-2天

---

### 9. Service 层职责划分不清

**问题**:
- 角色相关4个服务（职责重叠）
- 场景插图2个服务
- 搜索2个服务

**建议**: 合并相关服务

**预计工作量**: 1天

---

## 🟢 低优先级问题（可选优化）

### 10. 依赖注入使用不完整

**位置**: `lib/core/di/service_locator.dart`

**问题**:
引入了 GetIt，但大部分代码仍直接使用单例

**建议**:
要么全部使用 DI，要么移除 DI 配置

**预计工作量**: 1天

---

### 11. ChapterManager 职责命名模糊

**位置**: `lib/services/chapter_manager.dart` (343行)

**问题**:
名字不够明确，实际负责请求去重和预加载

**建议**: 重命名为 ChapterRequestManager 或 ChapterPreloadManager

**预计工作量**: 1小时

---

### 12. DifyService 职责过重

**位置**: `lib/services/dify_service.dart` (872行)

**问题**:
包含过多功能：特写生成、角色生成、场景描写、提示词生成等

**建议**: 拆分为多个专门服务

**预计工作量**: 1-2天

---

## 🗑️ 垃圾代码清单

### 13. TODO 标记的未实现功能

**位置**:
- `lib/services/chapter_search_service.dart:79` - TODO: 搜索建议功能
- `lib/services/chapter_search_service.dart:93` - TODO: 搜索历史记录功能
- `lib/services/chapter_search_service.dart:104` - TODO: 清除搜索历史功能
- `lib/services/dify_service.dart:23` - TODO: _getStructToken() 未使用
- `lib/widgets/gallery_action_panel.dart:50` - TODO: 更新回调

**建议**: 实现或删除

**预计工作量**: 4小时

---

### 14. 重复的模型转换逻辑

**位置**:
- `lib/api_service_wrapper.dart:732-761` - _mapToCharacter 方法

**建议**: 创建统一映射工具

**预计工作量**: 4小时

---

## 📊 删除清单总结

### ✅ 可以立即删除的文件/目录：

1. **lib/core/use_cases/** - 整个目录
2. **lib/core/failures/** - 整个目录
3. **lib/core/repositories/novel_repository.dart**
4. **lib/core/repositories/chapter_repository.dart** (需确认)
5. **lib/core/repositories/ai_service_repository.dart** (需确认)
6. **lib/data/repositories/novel_repository_impl.dart**
7. **lib/data/repositories/chapter_repository_impl.dart** (需确认)

### ⚠️ 需要重构的文件：

8. **lib/services/cache_manager.dart** - 重命名为 NovelChapterCacheManager
9. **lib/core/cache/cache_manager.dart** - 重命名为 MemoryCacheManager
10. **lib/core/di/service_locator.dart** - 更新引用

### 🔧 需要拆分的文件：

11. **lib/services/database_service.dart** - 拆分为多个 DAO
12. **lib/services/api_service_wrapper.dart** - 拆分为多个 API Service

---

## 🎯 重构路线图

### 第一阶段：清理无用代码（1-2天）
- ✅ 删除未使用的 Repository 层
- ✅ 删除未使用的 UseCase
- ✅ 删除未使用的 Failure 类
- ✅ 解决 TODO 或删除相关代码

### 第二阶段：解决命名冲突（2-3小时）
- ✅ 重命名 CacheManager 类
- ✅ 更新所有引用

### 第三阶段：重构巨石类（1-2周）
- 拆分 DatabaseService
- 拆分 ApiServiceWrapper
- 优化 DifyService

### 第四阶段：统一规范（1-2周）
- 统一状态管理模式
- 统一模型序列化方式
- 优化 Service 层职责划分

---

## 📝 注意事项

1. **删除前务必备份**
2. **每次删除前 grep 搜索确认无引用**
3. **逐步重构，不要一次性大改**
4. **每阶段完成后运行测试**
5. **保持 Git 提交粒度细小**

---

**最后更新**: 2025-12-25
