# AI伴读自动触发功能实施计划

## 任务上下文

**任务描述**: 如果自动伴读功能打开，当用户阅读章节的时候，自动触发伴读功能，但是不会出现弹窗打扰用户，静默更新信息，会弹出一个toast信息告诉用户内容已更新（如果用户关闭了显示，那么也不展示信息）

**额外需求**: 添加【已伴读】标记，避免用户回顾章节时AI重新读取

**创建时间**: 2026-01-25 17:20:23

---

## 技术方案

### 核心设计
- **数据库**: SQLite本地存储，添加 `ai_accompanied` 字段到 `chapter_cache` 表
- **防抖机制**: 使用两个布尔变量防止重复触发
- **静默模式**: 复用现有AI伴读逻辑，跳过确认对话框
- **动态Toast**: 根据实际更新内容生成提示消息
- **错误处理**: 静默失败，仅记录日志

### 用户选择
- 触发时机: A (立即触发)
- 静默模式: A (完全静默)
- Toast提示: B (详细提示 - 根据更新内容动态生成)
- 错误处理: A (静默失败)
- 防抖机制: A (添加标志位)

---

## 实施步骤

### 阶段1: 数据库升级 (v14 → v15)

#### 步骤1.1: 升级SQLite数据库版本
- **文件**: `novel_app/lib/services/database_service.dart`
- **修改点**:
  - 第55行: `version: 14` → `version: 15`
  - 在 `_onUpgrade()` 添加 v14→v15 迁移逻辑
  - SQL: `ALTER TABLE chapter_cache ADD COLUMN ai_accompanied INTEGER DEFAULT 0`

#### 步骤1.2: 添加伴读状态管理方法
- **文件**: `novel_app/lib/services/database_service.dart`
- **新增方法**:
  - `Future<bool> isChapterAccompanied(String novelUrl, String chapterUrl)`
  - `Future<void> markChapterAsAccompanied(String novelUrl, String chapterUrl)`
  - `Future<void> resetChapterAccompaniedFlag(String novelUrl, String chapterUrl)`

---

### 阶段2: 数据模型扩展

#### 步骤2.1: 扩展Chapter模型
- **文件**: `novel_app/lib/models/chapter.dart`
- **修改点**:
  - 添加 `final bool isAccompanied` 字段
  - 在 `copyWith()` 添加 `isAccompanied` 参数

---

### 阶段3: 阅读界面核心逻辑

#### 步骤3.1: 添加防抖标志变量
- **文件**: `novel_app/lib/screens/reader_screen.dart`
- **位置**: `_ReaderScreenState` 类
- **新增**:
  - `bool _hasAutoTriggered = false;`
  - `bool _isAutoCompanionRunning = false;`

#### 步骤3.2: 修改章节加载方法
- **文件**: `novel_app/lib/screens/reader_screen.dart`
- **方法**: `_loadChapterContent()`
- **修改点**:
  - 在 `forceRefresh=true` 时重置伴读标记
  - 在方法末尾添加 `await _checkAndAutoTriggerAICompanion()`
  - 重置 `_hasAutoTriggered = false`

#### 步骤3.3: 实现自动触发检查方法
- **文件**: `novel_app/lib/screens/reader_screen.dart`
- **方法**: `Future<void> _checkAndAutoTriggerAICompanion()`
- **逻辑**:
  1. 防抖检查
  2. 检查章节是否已伴读
  3. 获取AI伴读设置
  4. 检查autoEnabled和章节内容
  5. 调用静默伴读方法

#### 步骤3.4: 实现静默伴读方法
- **文件**: `novel_app/lib/screens/reader_screen.dart`
- **方法**: `Future<void> _handleAICompanionSilent(AiAccompanimentSettings settings)`
- **逻辑**:
  - 复用角色筛选、关系获取、Dify调用逻辑
  - 不显示loading SnackBar
  - 不显示确认对话框
  - 直接执行数据更新
  - 标记章节为已伴读
  - 根据infoNotificationEnabled显示动态Toast

---

### 阶段4: 兼容性修改

#### 步骤4.1: 修改数据更新方法
- **文件**: `novel_app/lib/screens/reader_screen.dart`
- **方法**: `_performAICompanionUpdates()`
- **修改点**: 添加 `bool isSilent = false` 参数，控制SnackBar显示

#### 步骤4.2: 修改手动触发方法
- **文件**: `novel_app/lib/screens/reader_screen.dart`
- **方法**: `_handleAICompanion()`
- **修改点**: 在用户确认后调用 `markChapterAsAccompanied()`

---

### 阶段5: 测试验证

#### 测试项:
1. 数据库v14→v15升级成功
2. 自动伴读触发正常
3. 已伴读章节不重复触发
4. 强制刷新重置标记
5. 手动触发更新标记
6. Toast提示开关控制
7. 错误静默失败
8. 快速切换章节防抖有效

---

## 涉及文件

```
novel_app/
├── lib/
│   ├── models/
│   │   └── chapter.dart                    [修改]
│   ├── screens/
│   │   └── reader_screen.dart              [修改]
│   └── services/
│       └── database_service.dart           [修改]
```

**Backend**: 不需要修改

---

## 预期成果

- ✅ 用户阅读章节时自动触发AI伴读（如果启用）
- ✅ 静默模式不打扰用户（无确认对话框）
- ✅ 动态Toast提示更新内容（可控开关）
- ✅ 已伴读章节不重复处理
- ✅ 手动触发和自动触发都更新标记
- ✅ 强制刷新可重置标记重新伴读
