# 小说站点能力文档

> 更新时间: 2026-03-12
> 详细记录每个站点的搜索能力和限制

## 站点能力概览

### 搜索能力分类

| 站点ID | 站点名称 | 搜索支持 | 搜索原因 | 搜索提示 |
|--------|----------|----------|----------|----------|
| **alice_sw** | 轻小说文库 | ✅ 支持 | - | - |
| **ddxsmf** | 顶点小说 | ❌ 不支持 | external_search | 请使用外部搜索引擎搜索 'site:ddxsmf.com 关键词' 来查找小说 |
| **shukuge** | 书库 | ✅ 支持 | - | - |
| **xspsw** | 小说网 | ❌ 不支持 | service_unavailable | 该网站服务异常，暂时不可用 |
| **wdscw** | 我的书城 | ✅ 支持 | - | - |
| **wodeshucheng** | 我的书城(备用) | ✅ 支持 | - | - |
| **smxku** | 蜘蛛小说网 | ❌ 不支持 | anti_crawler | 该网站已实施反爬虫措施，章节列表无法获取 |
| **wfxs** | 微风小说网 | ✅ 支持 | - | - |
| **biquge543** | 笔趣阁543 | ❌ 不支持 | rate_limit | 该站点搜索功能有频率限制，请使用直接URL添加 |

## 搜索原因类型说明

### external_search (外部搜索)
站点使用外部搜索引擎（如 Bing）进行搜索，无内部搜索功能。

**代表站点**: ddxsmf (顶点小说)

**特点**:
- 站点搜索框跳转到外部搜索结果
- 无法通过API直接调用搜索功能
- 需要用户手动在外部搜索引擎中搜索

**替代方案**:
```bash
# 在搜索引擎中使用以下格式
site:ddxsmf.com 小说关键词
```

### rate_limit (频率限制)
站点搜索功能存在频率限制，频繁请求会被封锁。

**代表站点**: biquge543 (笔趣阁543)

**特点**:
- 搜索接口有请求频率限制
- 超过限制会被临时或永久封锁
- 单次搜索可能成功，但批量搜索不可行

**替代方案**:
- 使用直接URL添加小说
- 通过其他站点搜索后切换到该站点阅读

### anti_crawler (反爬虫措施)
站点已实施严格的反爬虫措施，无法正常获取内容。

**代表站点**: smxku (蜘蛛小说网)

**特点**:
- 搜索功能可能正常
- 但章节列表和详情页返回403
- 反爬虫机制封锁爬虫请求

**技术细节**:
- HTTP 403 Forbidden
- 可能需要Cloudflare验证
- IP地址可能被拉黑

**替代方案**:
- 该站点暂时不可用
- 建议使用其他站点替代

### service_unavailable (服务不可用)
站点服务异常或已下线。

**代表站点**: xspsw (小说网)

**特点**:
- 所有请求返回 HTTP 520
- Cloudflare 错误页面
- 源服务器不可用

**技术细节**:
- HTTP 520 Web Server Returned an Unknown Error
- Server: cloudflare
- 源服务器与 Cloudflare 连接断开

**替代方案**:
- 该站点暂时不可用
- 等待站点恢复或使用其他站点

## 完全支持的站点

以下站点搜索功能完全正常，支持批量搜索：

### alice_sw (轻小说文库)
- **搜索方式**: POST表单提交
- **搜索URL**: `/search.html`
- **状态**: ✅ 正常
- **特点**: 专业轻小说站点，资源丰富

### shukuge (书库)
- **搜索方式**: 多入口尝试
- **搜索URL**: `/Search?wd={keyword}`
- **状态**: ✅ 正常
- **特点**: 综合性书库，小说种类多

### wdscw (我的书城)
- **搜索方式**: 待确认
- **状态**: ✅ 正常
- **特点**: 精品小说免费阅读

### wodeshucheng (我的书城备用)
- **搜索方式**: 分类页面替代搜索
- **状态**: ✅ 正常
- **特点**: 使用分类页面作为搜索替代

### wfxs (微风小说网)
- **搜索方式**: GET参数
- **搜索URL**: `/s/?search={keyword}`
- **状态**: ✅ 正常
- **特点**: 繁体转简体自动转换

## API 响应格式

### 获取站点列表
**请求**: `GET /source-sites`

**响应**:
```json
{
  "sites": [
    {
      "id": "ddxsmf",
      "name": "顶点小说",
      "base_url": "https://www.ddxsmf.com",
      "description": "中文免费小说阅读网",
      "enabled": true,
      "search_enabled": false,
      "search_reason": "external_search",
      "search_hint": "请使用外部搜索引擎搜索 'site:ddxsmf.com 关键词' 来查找小说"
    }
  ]
}
```

## 客户端处理建议

### 1. 搜索前检查
在进行搜索前，客户端应检查站点的 `search_enabled` 字段：

```dart
// Dart/Flutter 示例
final sites = await api.getSourceSites();
final searchableSites = sites.where((s) => s.searchEnabled).toList();

if (searchableSites.isEmpty) {
  showError("没有可用的搜索站点");
  return;
}
```

### 2. 显示搜索提示
对于不支持搜索的站点，显示相应的提示信息：

```dart
if (!site.searchEnabled) {
  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: Text('搜索不可用'),
      content: Text(site.searchHint ?? '该站点不支持搜索功能'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('确定'),
        ),
      ],
    ),
  );
}
```

### 3. 使用直接URL
对于不支持搜索的站点，提供直接URL添加功能：

```dart
// 允许用户直接输入小说URL
final url = await showDialog<String>(
  context: context,
  builder: (context) => UrlInputDialog(
    hint: '请输入小说详情页URL',
    supportedSites: unsupportedSearchSites,
  ),
);

if (url != null) {
  await addNovelByUrl(url);
}
```

## 变更记录

| 日期 | 变更内容 |
|------|----------|
| 2026-03-12 | 初始文档，记录站点搜索能力和限制 |
| 2026-03-12 | 添加 search_reason 和 search_hint 字段 |
