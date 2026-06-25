# AI 配置多序列化改造

## 上下文
将分散写死的 AI LLM 配置改为 SQLite 表存储的多配置序列，支持在 Hermes Agent 和章节生成中切换。

## 数据模型
```
llm_configs {
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  name TEXT NOT NULL,          -- 配置名称（如"DeepSeek"、"OpenAI"）
  api_url TEXT NOT NULL,       -- LLM API URL
  api_key TEXT NOT NULL,       -- LLM API Key
  model TEXT NOT NULL DEFAULT '', -- 默认模型
  is_default INTEGER NOT NULL DEFAULT 0, -- 是否默认（0/1）
  sort_order INTEGER NOT NULL DEFAULT 0, -- 排序
  created_at INTEGER NOT NULL,
  updated_at INTEGER NOT NULL
}
```

## 执行步骤

### Step 1: 数据层 — Model + 迁移 + 接口 + Repository + Provider
1. `lib/models/llm_config.dart` — 新建 Model（toMap/fromMap/copyWith）
2. `lib/core/database/database_migrations.dart` — v29 建表+索引
3. `lib/core/interfaces/repositories/i_llm_config_repository.dart` — 接口
4. `lib/repositories/llm_config_repository.dart` — Repository 实现
5. `lib/core/providers/database_providers.dart` — 注册 Provider

### Step 2: 服务层 — 统一配置读取
1. `lib/services/llm_config_service.dart` — 新建配置服务
   - `getActiveConfig()` — 获取当前激活配置（is_default=1）
   - `getActiveConfigForScenario(scenarioId)` — 场景级配置（SharedPreferences key `active_llm_profile_{scenarioId}` 引用 profile id）
   - `setActiveConfig(id)` — 设置默认配置
   - `setActiveConfigForScenario(scenarioId, id?)` — 设置场景配置
   - `buildLlmConfig(LlmConfig profile)` — LlmConfig profile -> LlmProvider 的 LlmConfig
   - `ensureMigratedFromLegacy()` — 首次运行时从旧 DslEngineConfig 迁移数据
2. 修改 `lib/services/ai/ai_service_factory.dart` — 接受 configId 参数或从 LlmConfigService 获取
3. 修改 `lib/services/novel_agent/agent_engine_config.dart` — 委托给 LlmConfigService

### Step 3: UI 层 — 配置管理页 + 切换控件
1. `lib/screens/llm_config_management_screen.dart` — 新建配置管理页
   - 配置列表（名称、URL、默认标记、排序拖拽）
   - 新增/编辑/删除配置
   - 设置默认配置
2. 修改 `lib/screens/dify_settings_screen.dart` — 入口改为跳转配置管理页，保留 AI 设定 prompt
3. 修改 `lib/widgets/hermes/hermes_scenario_config_dialog.dart` — 改为选择已有配置（下拉/列表），而非手动输入 URL/Key
4. 修改 `lib/screens/insert_chapter_screen.dart` — 添加配置选择器（下拉/弹出）
5. 修改 `lib/widgets/hermes/hermes_chat_dialog.dart` — 添加配置切换入口

### Step 4: 数据迁移 + 清理
1. `LlmConfigService.ensureMigratedFromLegacy()` — 读取旧 DslEngineConfig + AgentEngineConfig，写入 llm_configs 表，标记 is_default
2. 旧代码标记 @Deprecated 但暂不删除（DslEngineConfig、AgentEngineConfig）

### Step 5: build_runner + 测试 + 验证
1. `dart run build_runner build --delete-conflicting-outputs`
2. `flutter analyze` 零错误
3. `flutter test` 全部通过
