# 搜索站点架构改进实施记录

> 实施日期: 2026-03-12
> 实施内容: 增强站点元数据，添加搜索能力信息

## 概述

本次架构改进针对不支持搜索的站点进行了系统性的增强，通过添加 `search_reason` 和 `search_hint` 字段，为客户端提供了更详细的站点能力信息。

## 实施内容

### 1. 站点元数据增强

**文件**: `backend/app/services/crawler_factory.py`

为 `SOURCE_SITES_METADATA` 中的每个站点添加了两个新字段：

- `search_reason`: 不支持搜索的原因代码
- `search_hint`: 搜索提示或替代方案

**搜索原因类型**:

| 代码 | 说明 | 代表站点 |
|------|------|----------|
| `external_search` | 使用外部搜索引擎，无内部搜索 | ddxsmf |
| `rate_limit` | 搜索功能有频率限制 | biquge543 |
| `anti_crawler` | 反爬虫措施，无法正常获取 | smxku |
| `service_unavailable` | 服务异常或已下线 | xspsw |
| `None` | 搜索功能完全正常 | alice_sw, shukuge, etc. |

### 2. API Schema 更新

**文件**: `backend/app/schemas.py`

更新 `SourceSite` 模型以包含新字段：

```python
class SourceSite(BaseModel):
    id: str
    name: str
    base_url: str
    description: str
    enabled: bool
    search_enabled: bool
    search_reason: str | None = None  # 新增
    search_hint: str | None = None    # 新增
```

### 3. API 端点验证

**端点**: `GET /source-sites`

现在返回增强的站点信息：

```json
{
  "id": "ddxsmf",
  "name": "顶点小说",
  "base_url": "https://www.ddxsmf.com",
  "description": "中文免费小说阅读网...",
  "enabled": true,
  "search_enabled": false,
  "search_reason": "external_search",
  "search_hint": "请使用外部搜索引擎搜索 'site:ddxsmf.com 关键词' 来查找小说"
}
```

## 站点状态更新

### DDXSMF (顶点小说)
- **之前**: `search_enabled: True` (错误)
- **现在**: `search_enabled: False`
- **原因**: `external_search`
- **提示**: 请使用外部搜索引擎搜索 'site:ddxsmf.com 关键词' 来查找小说

### 其他站点状态确认

| 站点ID | 搜索支持 | 原因代码 |
|--------|----------|----------|
| alice_sw | ✅ | - |
| ddxsmf | ❌ | external_search |
| shukuge | ✅ | - |
| xspsw | ❌ | service_unavailable |
| wdscw | ✅ | - |
| wodeshucheng | ✅ | - |
| smxku | ❌ | anti_crawler |
| wfxs | ✅ | - |
| biquge543 | ❌ | rate_limit |

## 新增文档

### SITE_CAPABILITIES.md
详细的站点能力文档，包含：
- 站点能力概览表
- 搜索原因类型详细说明
- API 响应格式
- 客户端处理建议

### 更新的 SUPPORTED_SITES.md
- 添加了搜索原因列
- 更新了站点状态说明

## 测试验证

### 语法检查
```bash
cd backend
python -m py_compile app/services/crawler_factory.py  # ✅ 通过
python -m py_compile app/schemas.py                     # ✅ 通过
```

### API 测试
```bash
curl -H "X-API-TOKEN: test_token_123" http://localhost:3800/source-sites
```

**结果**: ✅ 返回正确格式的数据，包含所有新字段

## 客户端集成建议

### 1. 搜索前检查
在进行搜索前，客户端应检查 `search_enabled` 字段：

```dart
final sites = await api.getSourceSites();
final searchableSites = sites.where((s) => s.searchEnabled).toList();
```

### 2. 显示提示信息
对于不支持搜索的站点，显示 `search_hint` 内容：

```dart
if (!site.searchEnabled) {
  showHint(site.searchHint ?? '该站点不支持搜索功能');
}
```

### 3. 直接URL添加
为不支持搜索的站点提供直接URL添加功能。

## 后续工作

1. **Flutter 客户端适配**: 更新移动应用以使用新的 API 字段
2. **UI 优化**: 根据搜索状态显示不同的 UI 状态
3. **错误处理**: 优化搜索失败时的错误提示
4. **测试覆盖**: 添加单元测试验证新字段

## 兼容性说明

本次更新向后兼容：
- 现有客户端忽略新字段仍可正常工作
- API 响应格式保持一致，仅添加可选字段
- 不影响现有搜索功能的正常使用

## 文件变更清单

### 修改的文件
1. `backend/app/services/crawler_factory.py` - 站点元数据增强
2. `backend/app/schemas.py` - API Schema 更新
3. `backend/SUPPORTED_SITES.md` - 文档更新

### 新增的文件
1. `backend/SITE_CAPABILITIES.md` - 站点能力详细文档
2. `backend/SEARCH_SITE_ARCHITECTURE_UPDATE.md` - 本文档

## 变更历史

| 日期 | 变更内容 |
|------|----------|
| 2026-03-12 | 初始实施，添加 search_reason 和 search_hint 字段 |
| 2026-03-12 | 修复 DDXSMF 站点元数据（search_enabled: False） |
| 2026-03-12 | 创建站点能力文档 |
