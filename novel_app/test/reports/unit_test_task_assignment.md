# Novel App 单元测试任务分配总览

## 📅 创建日期
2025-01-30

## 🎯 总体目标

提高Novel App的整体单元测试覆盖率从当前约60%提升到**80%+**

---

## 📊 当前测试覆盖情况

### 已有测试统计
- **总测试文件数**: 69个
- **已有较好覆盖的模块**:
  - ✅ 角色管理 (character_management, relationships)
  - ✅ 章节管理 (chapter_loader, action_handler)
  - ✅ AI伴读 (115个测试)
  - ✅ 数据库服务 (database_service)
  - ✅ 角色提取 (character_extraction)
  - ✅ TTS功能 (tts_player)
  - ✅ 场景插图 (scene_illustration)

### 测试覆盖不足的模块
- ⚠️ 大纲管理 (outline_service)
- ⚠️ 聊天功能 (character_chat, multi_role_chat)
- ⚠️ 书架管理 (bookshelf_screen)
- ⚠️ 搜索功能 (search_screen, chapter_search)
- ⚠️ 预加载服务 (preload_service - 仅1个测试)
- ⚠️ 设置页面 (settings_screen)
- ⚠️ 备份恢复 (backup_service)
- ⚠️ 应用更新 (app_update_service)
- ⚠️ 章节生成 (chapter_generation_screen)
- ⚠️ 角色头像服务 (character_avatar_service)
- ⚠️ 章节历史 (chapter_history_service)

---

## 📋 任务分配清单

### 任务 #1: 大纲管理模块单元测试

**模块**: 大纲管理 (Outline Management)

**负责文件**:
- `lib/services/outline_service.dart`
- `lib/models/outline.dart`
- `lib/screens/outline/outline_management_screen.dart`
- `lib/screens/outline/create_outline_screen.dart`

**创建测试文件**:
1. `test/unit/services/outline_service_test.dart`
2. `test/unit/models/outline_test.dart` (如果不存在)

**测试重点**:
- 大纲CRUD操作
- 章节结构管理
- 序列化/反序列化
- 边界情况（空大纲、嵌套章节）

**目标覆盖率**: 80%+

**参考**: `test/unit/services/scene_illustration_service_test.dart`

---

### 任务 #2: 聊天功能模块单元测试

**模块**: 聊天功能 (Chat Functionality)

**负责文件**:
- `lib/screens/character_chat_screen.dart`
- `lib/screens/multi_role_chat_screen.dart`
- `lib/screens/chat_scene_management_screen.dart`
- `lib/models/chat_scene.dart`
- `lib/models/chat_message.dart`

**创建测试文件**:
1. `test/unit/screens/character_chat_screen_test.dart`
2. `test/unit/screens/multi_role_chat_screen_test.dart`
3. `test/unit/models/chat_scene_test.dart`

**测试重点**:
- 角色聊天UI交互
- 消息发送逻辑
- 历史记录加载
- 多角色群聊场景
- 场景配置验证

**目标覆盖率**: 70%

**参考**: `test/unit/screens/character_management_screen_test.dart`

---

### 任务 #3: 书架与搜索模块单元测试

**模块**: 书架与搜索 (Bookshelf & Search)

**负责文件**:
- `lib/screens/bookshelf_screen.dart`
- `lib/screens/search_screen.dart`
- `lib/screens/chapter_search_screen.dart`

**创建测试文件**:
1. `test/unit/screens/bookshelf_screen_test.dart`
2. `test/unit/screens/search_screen_test.dart`
3. `test/unit/services/chapter_search_service_test.dart` (如果不存在)

**测试重点**:
- 书架CRUD操作
- 多书架分类
- 预加载进度显示
- 拖拽排序
- 搜索功能与源站过滤
- 分页加载
- 关键词搜索算法

**目标覆盖率**: 75%

**参考**: `test/unit/screens/character_management_screen_test.dart`

---

### 任务 #4: 预加载服务模块单元测试

**模块**: 预加载服务 (Preload Service)

**负责文件**:
- `lib/services/preload_service.dart`
- `lib/services/preload_task.dart`
- `lib/services/preload_progress_update.dart`

**创建/完善测试文件**:
1. 完善 `test/unit/services/preload_service_race_condition_test.dart`
2. `test/unit/services/preload_queue_test.dart`
3. `test/unit/models/preload_task_test.dart`

**测试重点**:
- 并发场景
- 速率限制机制
- 任务优先级
- 队列管理
- 任务去重
- 状态流转
- 取消/重试逻辑

**目标覆盖率**: 85%

**参考**: `test/unit/services/tts_player_service_test.dart`

---

### 任务 #5: 设置与工具模块单元测试

**模块**: 设置与工具 (Settings & Utilities)

**负责文件**:
- `lib/screens/settings_screen.dart`
- `lib/screens/backend_settings_screen.dart`
- `lib/screens/dify_settings_screen.dart`
- `lib/services/backup_service.dart`
- `lib/services/app_update_service.dart`

**创建测试文件**:
1. `test/unit/screens/settings_screen_test.dart`
2. `test/unit/screens/backend_settings_screen_test.dart`
3. `test/unit/services/backup_service_test.dart`
4. `test/unit/services/app_update_service_test.dart`

**测试重点**:
- 设置页面交互
- 配置保存/读取
- API地址与Token配置
- 连接验证
- 数据备份/恢复
- 版本检查与更新

**目标覆盖率**: 70%

**参考**: `test/unit/screens/background_setting_load_test.dart`

---

### 任务 #6: 章节生成与改写模块单元测试

**模块**: 章节生成与改写 (Chapter Generation & Rewrite)

**负责文件**:
- `lib/screens/chapter_generation_screen.dart`
- `lib/screens/insert_chapter_screen.dart`
- `lib/services/rewrite_service.dart`
- `lib/services/stream_state_manager.dart`

**创建测试文件**:
1. `test/unit/screens/chapter_generation_screen_test.dart`
2. `test/unit/services/rewrite_service_test.dart`
3. `test/unit/services/stream_state_manager_test.dart`
4. `test/integration/paragraph_rewrite_full_test.dart`

**测试重点**:
- 流式内容显示
- 取消/重试/插入操作
- 改写逻辑
- 历史上下文构建
- Dify API调用 (Mock)
- 流状态管理
- 完整改写流程

**目标覆盖率**: 80%

**参考**: `test/integration/paragraph_rewrite_integration_test.dart`

---

### 任务 #7: 角色头像与卡片模块单元测试

**模块**: 角色头像与卡片 (Character Avatar & Card)

**负责文件**:
- `lib/services/character_avatar_service.dart`
- `lib/services/character_avatar_sync_service.dart`
- `lib/services/character_image_cache_service.dart`
- `lib/services/character_card_service.dart`

**创建测试文件**:
1. `test/unit/services/character_avatar_service_test.dart`
2. `test/unit/services/character_avatar_sync_service_test.dart`
3. `test/unit/services/character_image_cache_service_test.dart`
4. `test/unit/services/character_card_service_test.dart`

**测试重点**:
- 头像生成逻辑
- 缓存机制
- 同步触发
- 批量同步逻辑
- 同步队列管理
- 失败重试
- 图片缓存存储与清理
- 卡片生成逻辑

**目标覆盖率**: 80%

**参考**: `test/unit/services/character_extraction_service_test.dart`

---

### 任务 #8: 章节历史与阅读进度模块单元测试

**模块**: 章节历史与阅读进度 (Chapter History & Reading Progress)

**负责文件**:
- `lib/services/chapter_history_service.dart`
- `lib/models/reading_progress.dart`
- `lib/services/cache_search_service.dart`

**创建/完善测试文件**:
1. `test/unit/services/chapter_history_service_test.dart`
2. 完善 `test/unit/models/reading_progress_test.dart`
3. `test/unit/services/cache_search_service_test.dart`

**测试重点**:
- 历史记录添加/查询
- 历史清理逻辑
- 历史去重
- 进度计算逻辑
- 跨章节进度
- 缓存搜索逻辑
- 搜索结果排序
- 全文检索

**目标覆盖率**: 85%

**参考**: `test/unit/models/character_update_test.dart`

---

## 🎯 测试标准与规范

### 测试框架
- **单元测试**: flutter_test
- **Widget测试**: testWidget
- **数据库测试**: sqflite_common_ffi
- **Mock**: Mockito或手动Mock

### 测试组织
```
test/
├── unit/
│   ├── models/          # 模型测试
│   ├── services/        # 服务测试
│   ├── screens/         # 页面Widget测试
│   ├── controllers/     # 控制器测试
│   ├── utils/           # 工具类测试
│   └── widgets/         # 自定义Widget测试
├── integration/         # 集成测试
└── reports/            # 测试报告
```

### 测试命名规范
- 文件命名: `[filename]_test.dart`
- 测试分组: `group('[模块名]', () { ... })`
- 测试命名: `test('[方法名] 应该 [预期行为]', () { ... })`

### 测试编写原则

1. **独立性**: 每个测试独立运行，不依赖其他测试
2. **清晰性**: 测试意图明确，断言清晰
3. **完整性**: 覆盖正常流程和边界情况
4. **真实性**: 尽量使用真实数据库测试
5. **Mock合理**: 外部依赖使用Mock（API、原生平台）

### 数据库测试标准

```dart
void main() {
  // 初始化FFI SQLite
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  group('[模块名]', () {
    late DatabaseService db;

    setUp(() async {
      db = DatabaseService();
      // 创建测试数据
    });

    tearDown(() async {
      // 清理测试数据
      final database = await db.database;
      await database.delete('[table_name]');
    });

    test('[测试场景]', () async {
      // 准备
      // 执行
      // 断言
    });
  });
}
```

### Widget测试标准

```dart
void main() {
  testWidgets('[Widget名称] 应该 [预期行为]', (tester) async {
    // 准备
    await tester.pumpWidget(
      MaterialApp(
        home: TestWidget(),
      ),
    );

    // 执行交互
    await tester.tap(find.byType(ElevatedButton));
    await tester.pumpAndSettle();

    // 断言
    expect(find.text('Expected Text'), findsOneWidget);
  });
}
```

---

## 📈 测试覆盖率目标

### 各模块目标

| 模块 | 当前覆盖率 | 目标覆盖率 | 优先级 |
|-----|----------|-----------|-------|
| 大纲管理 | 0% | 80% | P1 |
| 聊天功能 | 0% | 70% | P1 |
| 书架与搜索 | 20% | 75% | P1 |
| 预加载服务 | 30% | 85% | P1 |
| 设置与工具 | 10% | 70% | P2 |
| 章节生成与改写 | 40% | 80% | P1 |
| 角色头像与卡片 | 0% | 80% | P1 |
| 章节历史与进度 | 50% | 85% | P2 |
| **总体** | **60%** | **80%** | - |

### 覆盖率计算方式

使用flutter的覆盖率工具:
```bash
# 生成覆盖率报告
flutter test --coverage

# 查看覆盖率
genhtml coverage/lcov.info -o coverage/html
```

---

## 🔄 工作流程

### 步骤1: 认领任务
从上述8个任务中选择一个任务开始工作。

### 步骤2: 分析代码
阅读目标模块的源代码，理解功能逻辑。

### 步骤3: 编写测试
按照测试规范编写单元测试，确保:
- 测试文件命名正确
- 测试分组合理
- 测试命名清晰
- 断言完整准确

### 步骤4: 运行测试
```bash
flutter test test/unit/[your_test_file].dart
```

### 步骤5: 检查覆盖率
确保达到目标覆盖率。

### 步骤6: 生成报告
创建测试报告到 `test/reports/` 目录。

### 步骤7: 提交代码
使用conventional commit格式提交:
```
test: 添加[模块名]单元测试

- 添加XXX测试文件
- 覆盖XXX功能
- 测试覆盖率达到XX%
```

---

## 📝 测试报告模板

每个任务完成后，生成测试报告:

```markdown
# [模块名]单元测试报告

## 📅 测试日期
YYYY-MM-DD

## ✅ 测试结果总览
- 测试文件数量: X个
- 测试用例总数: X个
- 通过率: 100%
- 覆盖率: XX%

## 📊 测试详情

### 1. [测试文件1]
- 测试数量: X个
- 测试重点: ...

### 2. [测试文件2]
- 测试数量: X个
- 测试重点: ...

## 🔧 实现细节
...

## 🐛 发现的问题
...

## 📈 覆盖率分析
...

## 💡 建议
...
```

---

## 🎓 参考资料

### 优秀测试示例
- `test/unit/services/scene_illustration_service_test.dart` (20个测试，服务层测试)
- `test/unit/models/chapter_ai_accompaniment_test.dart` (23个测试，模型测试)
- `test/unit/screens/character_management_screen_test.dart` (Widget测试)
- `test/unit/services/character_extraction_service_test.dart` (复杂逻辑测试)

### 测试工具文档
- [Flutter Testing](https://docs.flutter.dev/testing)
- [flutter_unit-test Skill](../skills/flutter_unit_test/README.md)
- [sqflite_common_ffi](https://pub.dev/packages/sqflite_common_ffi)

### 相关报告
- `test/reports/ai_accompaniment_test_overview.md` (AI伴读测试总览)
- `test/reports/scene_illustration_unit_test_report.md` (场景插图测试报告)
- `test/reports/scene_illustration_bugfix_report.md` (Bug修复报告)

---

## ✅ 任务检查清单

每个任务完成后，确认:
- [ ] 所有测试文件创建完成
- [ ] 所有测试通过 (100% pass rate)
- [ ] 达到目标覆盖率
- [ ] 生成了测试报告
- [ ] 代码已提交
- [ ] 报告已添加到本文档

---

## 📊 进度追踪

| 任务 | 模块 | 状态 | 进度 | 负责人 |
|-----|------|------|------|-------|
| #1 | 大纲管理 | ⚪ 未开始 | 0% | - |
| #2 | 聊天功能 | ⚪ 未开始 | 0% | - |
| #3 | 书架与搜索 | ⚪ 未开始 | 0% | - |
| #4 | 预加载服务 | ⚪ 未开始 | 0% | - |
| #5 | 设置与工具 | ⚪ 未开始 | 0% | - |
| #6 | 章节生成与改写 | ⚪ 未开始 | 0% | - |
| #7 | 角色头像与卡片 | ⚪ 未开始 | 0% | - |
| #8 | 章节历史与进度 | ⚪ 未开始 | 0% | - |

**总体进度**: 0/8 任务完成 (0%)

---

## 🎯 最终目标

通过这8个任务的单元测试补充，将Novel App的整体测试覆盖率从**60%提升到80%+**，提升代码质量和可维护性。

---

**文档创建时间**: 2025-01-30
**预计完成时间**: TBD
**维护者**: Novel Builder Team
