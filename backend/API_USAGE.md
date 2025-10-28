# Novel Builder Backend API 使用说明

## 新增功能

### 1. 源站列表获取

**接口**: `GET /source-sites`

**说明**: 获取所有支持的源站列表，包括站点状态和详细信息

**请求头**:
```
X-API-TOKEN: your_api_token
```

**响应示例**:
```json
[
  {
    "id": "alice_sw",
    "name": "轻小说文库",
    "base_url": "https://www.alicesw.com",
    "description": "专业的轻小说网站，包含大量日系轻小说",
    "enabled": true,
    "search_enabled": true
  },
  {
    "id": "shukuge",
    "name": "书库",
    "base_url": "http://www.shukuge.com",
    "description": "综合性小说书库，资源丰富",
    "enabled": true,
    "search_enabled": true
  },
  {
    "id": "xspsw",
    "name": "小说网",
    "base_url": "https://m.xspsw.com",
    "description": "移动端优化的小说网站",
    "enabled": true,
    "search_enabled": true
  }
]
```

### 2. 指定站点搜索

**接口**: `GET /search`

**说明**: 搜索小说，支持指定特定站点进行搜索

**请求参数**:
- `keyword` (必需): 搜索关键词
- `sites` (可选): 指定搜索站点，多个站点用逗号分隔，如 `alice_sw,shukuge`

**请求头**:
```
X-API-TOKEN: your_api_token
```

**使用示例**:

1. **搜索所有启用站点**（向后兼容）:
   ```
   GET /search?keyword=斗破苍穹
   ```

2. **指定单个站点搜索**:
   ```
   GET /search?keyword=斗破苍穹&sites=alice_sw
   ```

3. **指定多个站点搜索**:
   ```
   GET /search?keyword=斗破苍穹&sites=alice_sw,shukuge
   ```

## 支持的站点

| 站点ID | 站点名称 | 站点URL | 描述 |
|--------|----------|---------|------|
| alice_sw | 轻小说文库 | https://www.alicesw.com | 专业的轻小说网站，包含大量日系轻小说 |
| shukuge | 书库 | http://www.shukuge.com | 综合性小说书库，资源丰富 |
| xspsw | 小说网 | https://m.xspsw.com | 移动端优化的小说网站 |

## 错误处理

1. **无效站点**: 当指定的站点ID无效时，返回400错误
   ```json
   {
     "detail": "指定的站点无效或未启用"
   }
   ```

2. **认证失败**: Token无效时返回401错误
   ```json
   {
     "detail": "TOKEN 无效或缺失"
   }
   ```

## 客户端集成建议

### Flutter应用集成步骤：

1. **获取源站列表**:
   ```dart
   Future<List<SourceSite>> getSourceSites() async {
     final response = await http.get(
       Uri.parse('$baseUrl/source-sites'),
       headers: {'X-API-TOKEN': token},
     );
     return sourceSiteFromJson(jsonDecode(response.body));
   }
   ```

2. **实现站点选择UI**:
   - 显示所有可用站点
   - 允许用户选择一个或多个站点
   - 保存用户偏好设置

3. **搜索功能集成**:
   ```dart
   Future<List<Novel>> searchNovels(String keyword, {List<String> sites}) async {
     final uri = Uri.parse('$baseUrl/search').replace(queryParameters: {
       'keyword': keyword,
       if (sites != null && sites.isNotEmpty) 'sites': sites.join(','),
     });

     final response = await http.get(uri, headers: {'X-API-TOKEN': token});
     return novelFromJson(jsonDecode(response.body));
   }
   ```

## 性能优化建议

1. **减少搜索范围**: 用户指定站点可以显著提高搜索速度
2. **缓存源站列表**: 源站列表相对稳定，可以适当缓存
3. **并行搜索**: 多站点搜索时可以考虑并行请求提高响应速度

## 向后兼容性

- 现有的搜索API调用方式完全兼容
- 不传递 `sites` 参数时，将搜索所有启用的站点
- 客户端可以逐步升级以支持新功能