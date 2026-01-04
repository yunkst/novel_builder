# 拆分 reader_screen 执行计划

## 任务目标
将 `reader_screen.dart` (2,273行) 拆分为多个Controller，提高代码可维护性和可测试性。

## 执行进度

### ✅ 阶段1：ReaderContentController (已完成)

**完成时间**: 2025-01-04

#### 新增文件
- `lib/controllers/reader_content_controller.dart` (211行)
  - 职责：章节加载、缓存管理、预加载调度、阅读进度更新
  - 主要方法：
    - `initialize()`: 初始化API服务
    - `loadChapter()`: 加载章节内容
    - `updateReadingProgress()`: 更新阅读进度
    - `content` getter/setter: 访问和更新内容

#### 修改文件
- `lib/screens/reader_screen.dart`
  - 导入 `ReaderContentController`
  - 初始化Controller并传入回调
  - 使用便捷访问器：`get _content`, `set _content`, `get _isLoading`, `get _errorMessage`
  - 删除已迁移的方法：
    - `_initApi()` (~30行)
    - `_loadChapterContent()` 简化为调用Controller (~50行 → 13行)
    - `_getErrorMessage()` (~18行)
    - `_updateReadingProgress()` (~6行)

#### 代码变化
- **新增**: 211行 (ReaderContentController)
- **删除**: ~104行 (reader_screen中的旧方法)
- **净减少**: reader_screen从2,273行 → 约2,169行 (**减少104行**)

#### 编译状态
✅ **编译通过，无错误无警告**

---

## 待完成任务

### 🔄 阶段2：ReaderInteractionController (待开始)

**预计时间**: 1-2天

#### 计划创建文件
- `lib/controllers/reader_interaction_controller.dart` (~250行)
  - 职责：段落选择、点击、长按、特写模式切换
  - 主要方法：
    - `handleParagraphTap()`: 处理段落点击
    - `handleParagraphLongPress()`: 处理段落长按
    - `toggleCloseupMode()`: 切换特写模式
    - `getSelectedText()`: 获取选中文本
    - `isConsecutive()`: 检查是否连续

#### 计划迁移代码
- `_handleParagraphTap()` (~40行)
- `_handleLongPress()` (~30行)
- `_toggleCloseupMode()` (~15行)
- `_isConsecutive()` (~10行)
- `_getSelectedText()` (~25行)

#### 预期收益
- 主文件再减少 **~120行**
- 从2,169行 → ~2,049行

---

### 🔄 阶段3：ReaderSearchController (待开始)

**预计时间**: 0.5天

#### 计划创建文件
- `lib/controllers/reader_search_controller.dart` (~150行)
  - 职责：搜索匹配跳转、搜索对话框显示
  - 主要方法：
    - `scrollToSearchMatch()`: 滚动到搜索匹配
    - `showSearchMatchDialog()`: 显示搜索对话框

#### 计划迁移代码
- `_scrollToSearchMatch()` (~20行)
- `_showSearchMatchDialog()` (~15行)

#### 预期收益
- 主文件再减少 **~35行**
- 从2,049行 → ~2,014行

---

### 🔄 阶段4：ReaderNavigationController (待开始)

**预计时间**: 0.5天

#### 计划创建文件
- `lib/controllers/reader_navigation_controller.dart` (~100行)
  - 职责：章节导航
  - 主要方法：
    - `goToPreviousChapter()`: 上一章
    - `goToNextChapter()`: 下一章
    - `navigateToChapter()`: 跳转到指定章节

#### 计划迁移代码
- `_goToPreviousChapter()` (~20行)
- `_goToNextChapter()` (~20行)

#### 预期收益
- 主文件再减少 **~40行**
- 从2,014行 → ~1,974行

---

## 总体目标

### 最终代码行数预测
| 阶段 | 新增Controller行数 | reader_screen减少 | 累计reader_screen行数 |
|-----|-------------------|------------------|---------------------|
| **初始** | 0 | 0 | 2,273 |
| **阶段1完成** ✅ | +211 | -104 | 2,169 |
| **阶段2完成** | +250 | -120 | 2,049 |
| **阶段3完成** | +150 | -35 | 2,014 |
| **阶段4完成** | +100 | -40 | 1,974 |
| **总计** | **+711** | **-299** | **-299** |

### 最终效果
- ✅ 主文件减少：**299行** (2,273 → 1,974, **减少13%**)
- ✅ 新增4个Controller：**711行** (可独立测试的代码)
- ✅ 职责分离：内容加载、交互、搜索、导航各司其职
- ✅ 可测试性：Controller层可进行单元测试

---

## 技术细节

### 设计模式
- **回调模式**: Controller通过 `_onStateChanged` 回调通知UI更新
- **便捷访问器**: 使用getter/setter保持向后兼容
- **单一职责**: 每个Controller只负责一个功能域

### 兼容性
- ✅ 用户UI完全不变
- ✅ 功能逻辑完全不变
- ✅ 性能不降低
- ✅ 不引入新框架

### Git提交
每个阶段完成后提交：
```bash
git add .
git commit -m "refactor(reader): extract ReaderContentController

- Extract chapter loading logic to ReaderContentController
- Reduce reader_screen.dart from 2,273 to 2,169 lines
- Improve testability and maintainability
- No functional changes"
```

---

## 下一步行动

1. ✅ **已完成**: ReaderContentController
2. ⏭️ **进行中**: 测试ReaderContentController功能
3. 📋 **待开始**: ReaderInteractionController

---

**创建时间**: 2025-01-04
**最后更新**: 2025-01-04 (阶段1完成)
**状态**: 阶段1完成，进入测试阶段
