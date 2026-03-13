# 小说站点支持状态

> 更新时间: 2026-03-12
> 记录所有支持的小说站点及其爬虫状态

## 当前支持的站点列表

| 站点ID | 站点名称 | 基础URL | 状态 | 搜索功能 | 搜索原因 | 爬虫类 |
|--------|----------|---------|------|----------|----------|--------|
| **alice_sw** | 轻小说文库 | https://www.alicesw.com | ✅ 启用 | ✅ 支持 | - | AliceSWCrawlerRefactored |
| **ddxsmf** | 顶点小说 | https://www.ddxsmf.com | ✅ 启用 | ❌ 不支持 | external_search | DdxsmfCrawler |
| **shukuge** | 书库 | http://www.shukuge.com | ✅ 启用 | ✅ 支持 | - | ShukugeCrawlerRefactored |
| **xspsw** | 小说网 | https://m.xspsw.com | ❌ 已禁用 | ❌ 不支持 | service_unavailable | XspswCrawlerRefactored |
| **wdscw** | 我的书城 | https://www.5dscw.com | ✅ 启用 | ✅ 支持 | - | WdscwCrawlerRefactored |
| **wodeshucheng** | 我的书城(备用) | https://www.wodeshucheng.net | ✅ 启用 | ✅ 支持 | - | WodeshuchengCrawler |
| **smxku** | 蜘蛛小说网 | https://www.smxku.com | ❌ 已禁用 | ❌ 不支持 | anti_crawler | SmxkuCrawler |
| **wfxs** | 微风小说网 | https://m.wfxs.tw | ✅ 启用 | ✅ 支持 | - | WfxsCrawler |
| **biquge543** | 笔趣阁543 | https://m.biquge543.com | ✅ 启用 | ❌ 不支持 | rate_limit | Biquge543Crawler |

## 搜索原因说明

### external_search (外部搜索)
站点使用外部搜索引擎（如 Bing），无内部搜索功能。
- **代表站点**: ddxsmf (顶点小说)
- **替代方案**: 请使用外部搜索引擎搜索 `site:ddxsmf.com 关键词` 来查找小说

### rate_limit (频率限制)
站点搜索功能存在频率限制，频繁请求会被封锁。
- **代表站点**: biquge543 (笔趣阁543)
- **替代方案**: 该站点搜索功能有频率限制，请使用直接URL添加

### anti_crawler (反爬虫措施)
站点已实施严格的反爬虫措施，无法正常获取内容。
- **代表站点**: smxku (蜘蛛小说网)
- **替代方案**: 该网站已实施反爬虫措施，章节列表无法获取

### service_unavailable (服务不可用)
站点服务异常或已下线。
- **代表站点**: xspsw (小说网)
- **替代方案**: 该网站服务异常，暂时不可用

## 站点详细信息

### 1. alice_sw (轻小说文库)
- **描述**: 专业的轻小说网站，包含大量日系轻小说
- **搜索方式**: POST表单提交
- **搜索URL**: `/search.html`
- **表单参数**:
  ```python
  {"q": keyword, "f": "_all", "sort": "relevance"}
  ```
- **特殊处理**:
  - 需要禁用SSL验证
  - 使用自定义headers模拟浏览器
  - 支持POST和GET两种搜索方式

### 2. ddxsmf (顶点小说)
- **描述**: 中文免费小说阅读网，提供玄幻、修真、都市、穿越等多种类型小说
- **搜索方式**: 已禁用
- **特殊处理**:
  - 搜索功能被禁用，只能通过直接URL获取章节
  - 内容使用`<generic>`标签包裹
  - 需要特殊解析逻辑提取文本节点

### 3. shukuge (书库)
- **描述**: 综合性小说书库，资源丰富
- **搜索方式**: 多入口尝试
  1. GET: `/Search?wd={keyword}`
  2. POST: `/modules/article/search.php`
  3. POST: `/search.php`
- **表单参数**:
  ```python
  {"searchkey": keyword, "searchtype": "all"}
  ```
- **已知问题**: POST请求存在 "Only string values are accepted for arguments" 错误

### 4. xspsw (小说网)
- **描述**: 移动端优化的小说网站
- **状态**: ❌ 已禁用
- **搜索方式**: POST表单提交（历史）
- **搜索URL**: `/search.html`（历史）
- **已知问题**:
  - ⚠️ **所有请求返回 HTTP 520** (2026-03-12测试)
  - Cloudflare 错误页面表明源服务器不可用
  - 尝试过 `https://m.xspsw.com`、`https://www.xspsw.com`、HTTP/HTTPS 均失败
  - 响应头显示 `Server: cloudflare`，说明源服务器与 Cloudflare 之间连接断开
  - 结论: 该网站已下线或服务器故障，无法使用

### 5. wdscw (我的书城)
- **描述**: 精品小说免费阅读网站，包含玄幻、奇幻、武侠等多种类型小说
- **搜索方式**: 待确认

### 6. wodeshucheng (我的书城备用)
- **描述**: 综合性小说阅读网站，提供多种类型小说的在线阅读
- **搜索方式**: 分类页面替代搜索
- **特殊处理**:
  - 原搜索功能跳转到外部
  - 使用分类页面(如`/xuanhuanxiaoshuo/`)作为替代方案
  - 过滤包含关键词的小说

### 7. smxku (蜘蛛小说网)
- **描述**: 海量小说免费在线阅读，包含玄幻、都市、言情等多种类型
- **状态**: ❌ 已禁用（反爬虫限制）
- **搜索方式**: GET参数
- **搜索URL**: `/search.php?searchkey={keyword}`
- **URL格式**:
  - 搜索结果: `https://www.smxku.com/12739/` (小说ID)
  - 章节列表: `https://www.smxku.com/novel_id/`
- **已知问题**:
  - ⚠️ **章节列表返回403** (2025-03-12测试)
  - ⚠️ **章节内容页返回403** (2025-03-12测试)
  - 搜索功能正常，但详情页和章节页全部被反爬虫机制封锁
  - 尝试过STEALTH模式、自定义headers、移动版等多种方法均无效
  - 结论: 该网站已实施严格的反爬虫措施，无法正常使用

### 8. wfxs (微风小说网)
- **描述**: 繁体中文小说网站，支持玄幻、都市、言情等多种类型，自动转换为简体
- **基础URL**: `https://m.wfxs.tw`
- **搜索方式**: GET参数
- **搜索URL**: `/s/?search={keyword}`
- **特殊处理**:
  - **繁简转换**: 使用 `opencc.OpenCC('t2s')` 进行繁体转简体
  - **独立架构**: 不继承BaseCrawler，使用独立的Playwright实现
  - **分页章节**: 章节内容可能分页，需要处理"下一页"链接
  - **移动端**: 使用移动端域名

### 9. biquge543 (笔趣阁543)
- **描述**: 移动端笔趣阁站点，提供多种类型小说的在线阅读
- **搜索方式**: 因频率限制被禁用
- **特点**:
  - 使用移动端域名 `m.biquge543.com`
  - 搜索功能有频率限制，暂不启用

## 爬虫接口规范

所有爬虫必须实现以下接口：

```python
class BaseCrawler:
    async def search_novels(self, keyword: str) -> list[dict[str, Any]]:
        """搜索小说
        Args:
            keyword: 搜索关键词
        Returns:
            小说列表，每本小说包含:
            {
                "title": str,      # 标题
                "author": str,     # 作者
                "url": str,        # 详情页URL
                "source": str,     # 站点ID
                # 可选字段
                "description": str, # 简介
                "cover_url": str,   # 封面
                "category": str,    # 分类
                "status": str       # 状态(连载/完结)
            }
        """

    async def get_chapter_list(self, novel_url: str) -> list[dict[str, Any]]:
        """获取章节列表
        Args:
            novel_url: 小说详情页URL
        Returns:
            章节列表，每章包含:
            {
                "title": str,  # 章节标题
                "url": str     # 章节URL
            }
        """

    async def get_chapter_content(self, chapter_url: str) -> dict[str, Any]:
        """获取章节内容
        Args:
            chapter_url: 章节URL
        Returns:
            {
                "title": str,      # 章节标题
                "content": str,    # 章节内容
                "success": bool    # 是否成功
            }
        """

    async def get_novel_info(self, novel_url: str) -> dict[str, Any]:
        """获取小说完整信息（含章节列表）
        Args:
            novel_url: 小说详情页URL
        Returns:
            {
                "title": str,
                "author": str,
                "url": str,
                "cover_url": str,
                "description": str,
                "chapters": list[dict]  # 章节列表
            }
        """
```

## 网络层架构

### 当前状态

| 组件 | 文件 | 状态 | 说明 |
|------|------|------|------|
| **旧HTTP客户端** | `http_client.py` | ⚠️ 部分废弃 | 旧接口，部分爬虫仍在使用 |
| **新网络层** | `scrapling_fetcher.py` | ⚠️ 迁移中 | 基于Scrapling库，存在兼容性问题 |
| **爬虫基类** | `base_crawler.py` | ✅ 完成 | 已更新，支持Scrapling |
| **响应对象** | `page_response.py` | ✅ 完成 | 支持soup()和bs4()两种解析方式 |

### 请求策略

```python
class RequestStrategy(Enum):
    SIMPLE = "simple"      # 简单HTTP请求 (Fetcher)
    STEALTH = "stealth"    # 隐蔽反爬请求 (StealthyFetcher)
    # 已废弃
    # HYBRID = "hybrid"    # 混合模式
    # BROWSER = "browser"  # 浏览器模式
```

### 待解决问题

1. **shukuge**: "Only string values are accepted for arguments" 错误
   - 原因: Scrapling的parser对kwargs有严格的字符串类型检查
   - 位置: `scrapling_fetcher.py` fetch方法

2. **smxku**: 章节列表返回403 ❌ 无法修复
   - 原因: 该网站已实施严格的反爬虫措施
   - 详情页: `https://www.smxku.com/12739/` → 403 Forbidden
   - 章节页: `https://www.smxku.com/12739/12047.html` → 403 Forbidden
   - 解决方案: 已禁用该爬虫的搜索功能
   - 测试日期: 2025-03-12

3. **大部分爬虫**: 搜索返回0结果
   - 可能原因:
     - 站点反爬虫机制
     - 解析逻辑需要更新
     - 站点结构变化

4. **Scrapling迁移**: 类型检查严格导致的兼容性问题
   - headers字典值必须是字符串
   - post_data字典值必须是字符串
   - timeout等参数需要特殊处理

## 配置管理

### 环境变量

```bash
# 启用的站点(逗号分隔，留空则全部启用)
NOVEL_ENABLED_SITES="alice_sw,shukuge,xspsw,wdscw"

# API访问令牌
NOVEL_API_TOKEN=your_token_here

# 数据库连接
DATABASE_URL=postgresql://user:pass@localhost/novel_builder

# 代理设置(可选)
HTTP_PROXY=http://127.0.0.1:7890
```

### 站点启用/禁用

通过 `NOVEL_ENABLED_SITES` 环境变量控制：

```bash
# 只启用部分站点
NOVEL_ENABLED_SITES="alice_sw,smxku"

# 启用所有站点(留空或未设置)
NOVEL_ENABLED_SITES=""
```

## 依赖库

### 核心依赖
```toml
dependencies = [
    "fastapi>=0.104.0",
    "scrapling[all]>=0.4.0",  # Web爬取框架
    "urllib3>=2.0.0",
    "pydantic>=2.4.0",
    "sqlalchemy>=2.0.0",
    "psycopg2-binary>=2.9.0",
    "opencc>=1.1.2",  # 繁简转换
]
```

### Scrapling特性
- ✅ 比BeautifulSoup4快784倍的解析速度
- ✅ 内置反爬虫检测和绕过
- ✅ 自动重试和容错机制
- ⚠️ 严格的类型检查(字符串值要求)

## 添加新站点流程

1. **分析目标站点**
   - 搜索方式(GET/POST)
   - 页面结构
   - 反爬虫机制

2. **创建爬虫类**
   ```python
   from .base_crawler import BaseCrawler
   from .scrapling_fetcher import RequestStrategy

   class NewSiteCrawler(BaseCrawler):
       def __init__(self):
           super().__init__(
               base_url="https://example.com",
               strategy=RequestStrategy.SIMPLE
           )
   ```

3. **实现核心方法**
   - `search_novels()`
   - `get_chapter_list()`
   - `get_chapter_content()`

4. **注册到工厂**
   - 在 `crawler_factory.py` 中导入
   - 添加到 `SOURCE_SITES_METADATA`
   - 在 `get_enabled_crawlers()` 中添加实例化逻辑

5. **测试验证**
   ```bash
   docker-compose exec backend python -c "
   import asyncio
   from app.services.new_site_crawler import NewSiteCrawler

   async def test():
       crawler = NewSiteCrawler()
       results = await crawler.search_novels('测试')
       print(f'搜索结果: {len(results)}个')

   asyncio.run(test())
   "
   ```

## 变更记录

| 日期 | 变更内容 |
|------|----------|
| 2026-03-12 | xspsw因HTTP 520服务器错误已禁用 |
| 2025-03-12 | 初始文档，记录9个站点状态 |
| 2025-03-12 | Scrapling迁移进行中，发现兼容性问题 |
| 2025-03-12 | smxku搜索功能正常，章节列表待修复 |
| 2025-03-12 | smxku因反爬虫限制已禁用（详情页和章节页返回403） |
