# 系统提示词进化功能 — 执行计划

## 任务概述

实现 Agent 场景的系统提示词进化功能：通过 `patch_memory` 工具让 AI 在对话中积累经验记忆，并在后续对话的 system prompt 中注入这些记忆，让 AI 越用越聪明。

## 核心设计

```
用户对话 → AgentLoop 调用 LLM
              ↓
         LLM 调用 patch_memory(oldText, newText)
              ↓
         AgentScenario.patchMemory() → SQLite agent_memory 表
              ↓
         下次对话时 buildSystemPrompt() → 从 DB 加载记忆 → 拼接到 system prompt
```

### 记忆存储：SQLite 表 `agent_memory`

```sql
CREATE TABLE agent_memory (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  scenario_id TEXT NOT NULL,    -- 'writing' | 'webview_extract'
  content TEXT NOT NULL,        -- 记忆内容（单条）
  created_at INTEGER NOT NULL,
  updated_at INTEGER NOT NULL
);
CREATE INDEX idx_agent_memory_scenario ON agent_memory(scenario_id);
```

### patch_memory 工具行为

| 场景 | oldText | newText | 行为 |
|------|---------|---------|------|
| 新增 | "" (空) | "xxx" | 直接插入 |
| 修改 | "aaa" | "bbb" | 查找并替换，找不到则报错 + 返回所有记忆 |
| 删除 | "aaa" | "" (空) | 查找并删除 |
| 记忆为空时 | "" | "xxx" | 直接插入（不报错） |

## 执行步骤

### 步骤 1: 数据库迁移 v27 — 创建 agent_memory 表

**文件**: `lib/core/database/database_migrations.dart`
**操作**:
- 将 `currentVersion` 从 26 改为 27
- 在 `_upgradeStep` 的 switch 中添加 `case 27`：创建 `agent_memory` 表 + 索引（IF NOT EXISTS 保证幂等）

**预期结果**: 数据库升级后 `agent_memory` 表存在

### 步骤 2: 新增 AgentMemoryRepository

**文件**: `lib/repositories/agent_memory_repository.dart` (新建)
**类**: `AgentMemoryRepository extends BaseRepository`
**方法**:
- `getAllByScenario(String scenarioId) → Future<List<String>>` — 按 scenario_id 查所有记忆
- `addMemory(String scenarioId, String content) → Future<void>` — 插入单条
- `updateMemory(int id, String newContent) → Future<int>` — 替换内容 + 更新时间戳
- `deleteMemory(int id) → Future<int>` — 删除单条
- `findByContent(String scenarioId, String oldText) → Future<Map<String, dynamic>?>` — 精确匹配查找

**预期结果**: Repository 可被 Provider 注入使用

### 步骤 3: 注册 AgentMemoryRepository Provider

**文件**: `lib/core/providers/repository_providers.dart`
**操作**: 添加 `agentMemoryRepositoryProvider`

**预期结果**: 其他模块可通过 `ref.read(agentMemoryRepositoryProvider)` 获取实例

### 步骤 4: AgentScenario 基类增加记忆能力

**文件**: `lib/services/novel_agent/agent_scenario.dart`
**操作**:
- 在 `AgentScenario` 抽象类中添加方法签名:
  - `Future<List<String>> getMemories()` — 获取当前场景所有记忆
  - `Future<void> patchMemory(String? oldText, String newText)` — patch 记忆（由基类提供默认实现，通过 Ref 访问 Repository）

**预期结果**: 所有场景自动继承记忆能力

### 步骤 5: 给 AgentScenario 抽象类添加 patch_memory 工具定义

**文件**: `lib/services/novel_agent/agent_scenario.dart`
**操作**:
- 添加静态方法 `patchMemoryToolDefinition()` 返回 OpenAI function schema
- 各场景的 `tools` getter 在返回的工具列表末尾追加此工具

**预期结果**: LLM 可见 `patch_memory` 工具

### 步骤 6: 在各场景 executeTool 中添加 patch_memory case

**文件**: 
- `lib/services/novel_agent/tool_executor.dart`（writing 场景）
- `lib/services/novel_agent/scenarios/webview_extract_scenario.dart`（webview_extract 场景）

**操作**: 在两个 executor 的 switch 中添加 `case 'patch_memory'` 分支
**逻辑**:
```
if (记忆为空) → oldText 忽略，直接插入 newText → 返回成功
else if (oldText 为空 && newText 非空) → 直接插入 → 返回成功
else if (oldText 非空 && newText 为空) → 查找并删除 → 成功/失败
else (oldText 非空 && newText 非空) → 查找并替换 → 成功/失败并返回所有记忆
```

**预期结果**: patch_memory 工具可正常执行

### 步骤 7: 修改 buildSystemPrompt 拼接记忆

**文件**: 
- `lib/services/novel_agent/agent_system_prompt.dart`（writing）
- `lib/services/novel_agent/scenarios/webview_extract_scenario.dart`（webview_extract）

**操作**: 在 `buildSystemPrompt()` 方法末尾拼接：
```
## 经验记忆
以下是你在以往对话中记录的重要经验，请遵循环保：
- 记忆1
- 记忆2
```
若当前场景无记忆则跳过此段。

**预期结果**: LLM 在每次对话中看到过往积累的记忆

### 步骤 8: 简化各场景的系统提示词

**文件**: 同上步骤 7 的两个文件
**操作**: 只保留绝对必要的信息：
- writing: 核心角色定位 + 当前上下文 + 操作原则（精简为 3-4 条）
- webview_extract: 核心目标 + run_id 机制 + JS 规范（精简）

**预期结果**: 提示词更短，减少 token 消耗，细节将由进化的记忆补充

### 步骤 9: 编写单元测试

**文件**: `test/unit/services/novel_agent/agent_memory_test.dart` (新建)
**用例**:
1. patch_memory 新增（记忆为空）→ 成功
2. patch_memory 新增（记忆非空）→ 成功
3. patch_memory 修改（oldText 匹配）→ 成功
4. patch_memory 修改（oldText 不匹配）→ 报错 + 返回所有记忆
5. patch_memory 删除（newText 为空）→ 成功
6. getMemories 按场景隔离 → 不同场景记忆不混淆
7. buildSystemPrompt 包含记忆段 → prompt 末尾有记忆内容

**预期结果**: 10+ 条测试全部通过

## 涉及文件清单

| 文件 | 操作 | 
|------|------|
| `lib/core/database/database_migrations.dart` | 修改：currentVersion 27 + case 27 |
| `lib/repositories/agent_memory_repository.dart` | 新建 |
| `lib/core/providers/repository_providers.dart` | 修改：注册 Provider |
| `lib/services/novel_agent/agent_scenario.dart` | 修改：加抽象方法 + 工具定义 |
| `lib/services/novel_agent/tool_executor.dart` | 修改：加 patch_memory case |
| `lib/services/novel_agent/scenarios/webview_extract_scenario.dart` | 修改：加 patch_memory case + 记忆拼接 + 简化 prompt |
| `lib/services/novel_agent/agent_system_prompt.dart` | 修改：加记忆拼接 + 简化 prompt |
| `test/unit/services/novel_agent/agent_memory_test.dart` | 新建 |
