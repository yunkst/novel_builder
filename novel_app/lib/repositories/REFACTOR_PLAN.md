# database_service.dart 重构方案

## 问题分析

- **文件大小**: 3,543行
- **公共方法数**: 120个
- **文档注释数**: 231个
- **主要问题**: 单一类承担了太多职责，违反单一职责原则（SRP）

## 重构策略

采用渐进式重构，而非一次性重写，以确保：
1. 保持功能完整性
2. 不破坏现有调用方
3. 可以逐步测试和验证

## 架构设计

### 第一阶段：创建Repository层（当前）

```
lib/
  repositories/
    base_repository.dart          # 基础Repository类
    novel_repository.dart          # 小说相关操作
    chapter_repository.dart        # 章节相关操作
    character_repository.dart      # 角色相关操作
    character_relation_repository.dart  # 角色关系相关操作
    illustration_repository.dart   # 插图相关操作
    outline_repository.dart        # 大纲相关操作
    chat_scene_repository.dart     # 聊天场景相关操作
    bookshelf_repository.dart      # 书架分类相关操作
```

### 第二阶段：DatabaseService作为门面

保留DatabaseService作为统一入口，内部委托给各个Repository：

```dart
class DatabaseService {
  static final DatabaseService _instance = DatabaseService._internal();

  // Repository实例
  late final NovelRepository _novelRepo = NovelRepository();
  late final ChapterRepository _chapterRepo = ChapterRepository();
  late final CharacterRepository _characterRepo = CharacterRepository();
  // ... 其他repositories

  // ========== 书架操作（委托给NovelRepository） ==========
  Future<int> addToBookshelf(Novel novel) => _novelRepo.addToBookshelf(novel);
  Future<List<Novel>> getBookshelf() => _novelRepo.getNovels();

  // ========== 章节缓存操作（委托给ChapterRepository） ==========
  Future<bool> isChapterCached(String url) => _chapterRepo.isCached(url);
  Future<void> cacheChapter(...) => _chapterRepo.cache(...);

  // ... 其他委托方法
}
```

### 第三阶段：逐步迁移调用方

1. 优先级高的模块（如reader_screen.dart）直接使用Repository
2. 低优先级模块继续使用DatabaseService
3. 使用@Deprecated标记DatabaseService中的方法

## 功能领域划分

### 1. NovelRepository（小说管理）
- 添加/删除小说
- 获取小说列表
- 阅读进度管理
- AI伴读设置
- 背景设定管理

**对应原文件行数**: ~250行

### 2. ChapterRepository（章节管理）
- 章节内容缓存
- 章节列表缓存
- 用户插入章节
- 章节搜索
- AI伴读标记

**对应原文件行数**: ~900行

### 3. CharacterRepository（角色管理）
- 角色CRUD
- 角色头像管理
- 角色上下文提取
- 角色图集缓存

**对应原文件行数**: ~600行

### 4. CharacterRelationRepository（角色关系管理）
- 关系CRUD
- 关系图数据
- 关系同步

**对应原文件行数**: ~200行

### 5. IllustrationRepository（插图管理）
- 插图CRUD
- 插图任务管理
- 插图批量操作

**对应原文件行数**: ~200行

### 6. OutlineRepository（大纲管理）
- 大纲CRUD
- 大纲搜索

**对应原文件行数**: ~100行

### 7. ChatSceneRepository（聊天场景管理）
- 场景CRUD
- 场景搜索

**对应原文件行数**: ~100行

### 8. BookshelfRepository（书架分类管理）
- 书架CRUD
- 小说-书架关联
- 书架选择器

**对应原文件行数**: ~300行

### 9. 共享基础设施
- 数据库初始化
- 数据库迁移
- 事务处理
- 错误处理

**对应原文件行数**: ~800行

## 实施步骤

### Step 1: 创建Repository类（当前）
✅ 创建base_repository.dart
✅ 创建novel_repository.dart（示例）
⏳ 创建其他Repository类

### Step 2: 修改DatabaseService使用Repository
⏳ 添加Repository实例
⏳ 将方法实现改为委托
⏳ 保持向后兼容

### Step 3: 测试验证
⏳ 运行现有测试
⏳ 手动测试核心功能
⏳ 性能测试

### Step 4: 迁移调用方
⏳ 更新高优先级模块
⏳ 添加@Deprecated标记
⏳ 更新文档

## 预期成果

### 代码质量提升
- **单一职责**: 每个Repository只负责一个领域
- **可测试性**: Repository可以独立测试
- **可维护性**: 代码更易理解和修改
- **可扩展性**: 新增功能更容易

### 文件大小优化
- **database_service.dart**: 从3,543行降至~1,000行（门面模式）
- **novel_repository.dart**: ~250行
- **chapter_repository.dart**: ~900行
- **character_repository.dart**: ~600行
- **其他repositories**: 每个100-300行

## 风险控制

1. **向后兼容**: 保留DatabaseService的所有公共API
2. **渐进迁移**: 一次迁移一个模块
3. **充分测试**: 每次迁移后运行测试
4. **回滚方案**: Git分支保护，可随时回滚

## 下一步行动

1. 完成所有Repository类的创建
2. 修改DatabaseService使用Repository
3. 运行测试验证功能完整性
4. 创建迁移指南文档
