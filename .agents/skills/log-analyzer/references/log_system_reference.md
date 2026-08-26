# 日志系统参考文档

## 数据库表结构：client_logs

| 字段 | 类型 | 约束 | 说明 |
|------|------|------|------|
| id | Integer | PK, 自增 | 主键 |
| level | String(10) | NOT NULL, 索引 | 日志级别 |
| message | Text | NOT NULL | 日志消息 |
| stack_trace | Text | NULLABLE | 异常堆栈 |
| category | String(20) | 默认 "general", 索引 | 日志分类 |
| tags | Text | NULLABLE | JSON 数组字符串 |
| timestamp | DateTime | NOT NULL, 索引 | 客户端时间戳(UTC) |
| received_at | DateTime | 默认 UTC now | 服务端接收时间 |

复合索引: `idx_level_timestamp(level, timestamp)`, `idx_received_at(received_at)`, `idx_category_timestamp(category, timestamp)`

## 日志级别

前端 `LogLevel` 枚举与上报值对应关系：

| 枚举名 | label | 上报值 (label.toLowerCase()) | 优先级(index) |
|--------|-------|-----|------|
| debug | DEBUG | debug | 0 |
| info | INFO | info | 1 |
| warning | WARN | warn | 2 |
| error | ERROR | error | 3 |

> ⚠️ 已知问题：枚举名是 `warning`，但上报值是 `warn`。数据库中可能同时存在 `warn` 和 `warning` 两个值，查询时需注意统一处理。

## 日志分类

前端 `LogCategory` 枚举：

| key | label | 说明 |
|-----|-------|------|
| database | 数据库 | SQLite 本地操作 |
| network | 网络 | HTTP 请求、API 调用 |
| ai | AI | LLM 调用、DSL 引擎、Hermes Agent |
| ui | 界面 | 页面生命周期、用户交互 |
| cache | 缓存 | 章节内容缓存 |
| tts | 语音 | 语音合成 |
| character | 角色 | 角色管理 |
| backup | 备份 | 数据导入导出 |
| general | 通用 | 默认分类 |

## 后端 API

### POST /api/logs/upload

- 认证: `X-API-TOKEN` header
- 请求体: `{ "logs": [LogEntrySchema, ...] }`，logs 长度限制 1-50
- 响应体: `{ "received": int, "message": str }`

### LogEntrySchema 字段

| 字段 | 类型 | 必填 | 默认值 |
|------|------|------|--------|
| timestamp | datetime | 是 | - |
| level | str | 是 | - |
| message | str | 是 | - |
| stack_trace | str | 否 | None |
| category | str | 否 | "general" |
| tags | list[str] | 否 | [] |

## 数据库连接信息

- Host: localhost (Docker 映射)
- Port: 5432 (容器内部)
- User: novel_user
- Password: novel_pass
- Database: novel_db
- Docker 容器名: novel_builder-postgres-1

## 常用 SQL 查询模板

```sql
-- 基础统计
SELECT COUNT(*) as total, MIN(received_at) as earliest, MAX(received_at) as latest FROM client_logs;

-- 按级别统计
SELECT level, COUNT(*) as count FROM client_logs GROUP BY level ORDER BY count DESC;

-- 按分类统计
SELECT category, COUNT(*) as count FROM client_logs GROUP BY category ORDER BY count DESC;

-- 最近N条错误日志
SELECT level, category, message, stack_trace, timestamp, received_at FROM client_logs WHERE level = 'error' ORDER BY received_at DESC LIMIT 20;

-- 时间范围查询
SELECT * FROM client_logs WHERE received_at >= NOW() - INTERVAL '1 hour' ORDER BY received_at DESC;

-- 按分类和级别交叉统计
SELECT category, level, COUNT(*) as count FROM client_logs GROUP BY category, level ORDER BY category, level;

-- 查找有堆栈信息的日志
SELECT level, category, message, stack_trace, timestamp FROM client_logs WHERE stack_trace IS NOT NULL AND stack_trace != '' ORDER BY received_at DESC;

-- 查找高频重复日志（可能的日志洪泛）
SELECT message, COUNT(*) as count FROM client_logs GROUP BY message HAVING COUNT(*) > 3 ORDER BY count DESC;

-- 按小时统计日志量趋势
SELECT DATE_TRUNC('hour', received_at) as hour, COUNT(*) as count FROM client_logs GROUP BY hour ORDER BY hour;
```

## Docker psql 命令

```bash
# 基础查询
docker exec novel_builder-postgres-1 psql -U novel_user -d novel_db -c "<SQL>"

# 交互模式
docker exec -it novel_builder-postgres-1 psql -U novel_user -d novel_db
```

## 已知 Bug 模式（分析时重点关注）

### 1. warn/warning 级别不一致
- 数据库中可能同时存在 `warn` 和 `warning` 两个值
- 根因：前端 `LogLevel.warning.label` 是 `'WARN'`，上报后为 `'warn'`
- 查询时用 `WHERE level IN ('warn', 'warning')` 兼容两种值

### 2. LLM contentLength=0 无告警
- `RealLlmExecutor.executeStreaming` 完成时 contentLength=0 只记 info 级别
- GraphEngine 仍报告"全部成功"，无错误反馈
- 搜索模式：`contentLength=0` 在 ai 分类日志中

### 3. DSL Engine 配置缺失
- 错误链：`DSL Engine 配置不完整` → `Agent 拒绝请求` → `Hermes Agent 错误`
- 分类为 ai/general，级别为 warn→warn→error

### 4. 条件短路求值全部为 false
- DSL 图中条件节点全部短路，大量节点被 skip
- 搜索模式：`条件短路求值触发` + `节点被 skip`
