# Novel Builder 爬虫架构文档

> 更新时间: 2025-03-12
> 记录爬虫系统的架构、分层结构和代码使用方式

## 架构概览

```
┌─────────────────────────────────────────────────────────────────────────────────┐
│                        API 层 (FastAPI)                         │
│  ┌──────────────────────────────────────────────────────────────────────┐  │
│  │              服务层 (Services)                        │  │
│  │  ┌────────────────────────────────────────────────────────────┐  │  │
│  │  │          工厂层 (Crawler Factory)          │  │  │
│  │  │  ┌──────────────────────────────────────────────────┐  │  │  │
│  │  │  │        爬虫层 (Crawlers)           │  │  │  │
│  │  │  │  ┌────────────────────────────────────┐   │  │  │  │
│  │  │  │  │    网络层 (Network)        │   │  │  │  │
│  │  │  │  └────────────────────────────────────┘   │  │  │  │
│  │  │  └──────────────────────────────────────────────────┘  │  │  │
│  │  └────────────────────────────────────────────────────────────┐  │  │
│  └──────────────────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────────────────────┘
```

## 分层详细说明

### 1. API 层 (FastAPI)

**文件**: `app/main.py`, `app/routes/`

**职责**:
- 提供 RESTful API 端点
- 处理认证和授权
- 调用服务层完成业务逻辑

**主要端点**:
```python
# 搜索小说
GET /search?keyword={keyword}&sites={sites}

# 获取章节列表
GET /chapters?url={novel_url}

# 获取章节内容
GET /chapter-content?url={chapter_url}&force_refresh={bool}

# 获取源站列表
GET /source-sites
```

**使用示例**:
```python
from app.services.search_service import SearchService
from app.services.crawler_factory import get_enabled_crawlers

# 获取启用的爬虫
crawlers = get_enabled_crawlers()

# 创建搜索服务
search_service = SearchService(list(crawlers.values()))

# 执行搜索
results = await search_service.search(keyword)
```

### 2. 服务层 (Services)

**文件**: `app/services/search_service.py`

**职责**:
- 协调多个爬虫进行搜索
- 结果聚合和去重
- 错误处理和容错

**类结构**:
```python
class SearchService:
    def __init__(self, crawlers: list[BaseCrawler]):
        self.crawlers = crawlers

    async def search(
        self, keyword: str, crawlers: dict[str, Any] | None = None
    ) -> list[dict[str, Any]]:
        """并发的多个爬虫搜索"""
        # 1. 遍历每个爬虫
        # 2. 调用 search_novels 方法
        # 3. 收集所有结果
        # 4. 去重和规范化
        # 5. 返回聚合结果
```

**使用示例**:
```python
from app.services.search_service import SearchService

# 使用所有启用的爬虫
search_service = SearchService()

# 搜索
results = await search_service.search('仙侠')

# 只使用指定爬虫
results = await search_service.search('仙侠', crawlers={'alice_sw': alice_sw_crawler})
```

### 3. 工厂层 (Crawler Factory)

**文件**: `app/services/crawler_factory.py`

**职责**:
- 管理所有爬虫的注册
- 根据配置动态加载爬虫
- 提供 URL 到爬虫的映射

**关键函数**:
```python
# 获取所有启用的爬虫
def get_enabled_crawlers() -> dict[str, BaseCrawler]:
    """根据环境变量 NOVEL_ENABLED_SITES 返回启用的爬虫"""
    # 环境变量: NOVEL_ENABLED_SITES="alice_sw,shukuge,xspsw"
    # 返回: {'alice_sw': AliceSWCrawler(), ...}

# 根据 URL 获取对应的爬虫
def get_crawler_for_url(url: str) -> BaseCrawler | None:
    """根据 URL 匹配对应的爬虫"""
    # 示例: "alicesw.com" -> AliceSWCrawler

# 获取源站信息
def get_source_sites_info() -> list[dict]:
    """返回所有站点元数据"""
```

**使用示例**:
```python
from app.services.crawler_factory import get_enabled_crawlers, get_source_sites_info

# 获取所有启用的爬虫
crawlers = get_enabled_crawlers()
for site_id, crawler in crawlers.items():
    print(f"{site_id}: {crawler.__class__.__name__}")

# 获取源站信息（用于API返回）
sites = get_source_sites_info()
# 返回格式: [{"id": "alice_sw", "name": "轻小说文库", ...}]
```

### 4. 爬虫层 (Crawlers)

**文件**: `app/services/base_crawler.py`, `app/services/*_crawler.py`

#### 4.1 基础爬虫类 (BaseCrawler)

**文件**: `app/services/base_crawler.py`

**职责**:
- 定义爬虫的统一接口
- 提供网络请求方法（GET/POST）
- 提供通用的数据提取方法

**核心接口**（必须由子类实现）:
```python
@abstractmethod
async def search_novels(self, keyword: str) -> list[dict[str, Any]]:
    """搜索小说"""
    # 返回: [{"title": "书名", "url": "...", ...}]

@abstractmethod
async def get_chapter_list(self, novel_url: str) -> list[dict[str] str]]:
    """获取章节列表"""
    # 返回: [{"title": "第1章", "url": "..."}, ...]

@abstractmethod
async def get_chapter_content(self, chapter_url: str) -> dict[str, Any]]:
    """获取章节内容"""
    # 返回: {"title": "第1章", "content": "..."}

@abstractmethod
async def get_novel_info(self, novel_url: str) -> dict[str, Any]]:
    """获取小说完整信息（含章节列表）"""
    # 返回: {"title": "...", "chapters": [...]}
```

**提供的网络方法**（子类可直接使用）:
```python

# GET 请求
async def get_page(
    self, url: str, timeout: int = 10, max_retries: int = 3, **kwargs
) -> PageResponse:
    """获取页面内容"""
    # 示例:
    page = await self.get_page(url, timeout=15)
    title = page.css('h1::text').get()

# POST 表单提交
async def post_form(
    self, url: str, data: dict[str, str], timeout: int = 10, **kwargs
) -> PageResponse:
    """提交表单"""
    # 示例:
    page = await self.post_form(url, {"searchkey": keyword})

# 通用工具方法
def clean_text(self, text: str) -> str:
    """清理文本内容"""

def extract_novel_info(self, page: PageResponse, keyword: str = "") -> list[dict]:
    """通用的小说信息提取方法"""

def extract_chapters(self, page: PageResponse, base_url: str) -> list[dict]:
    """通用的章节列表提取方法"""

def extract_content(self, page: PageResponse) -> str:
    """通用的章节内容提取方法"""
```

#### 4.2 具体爬虫实现

**文件模式**: `app/services/{site_id}_crawler.py`

**实现模板**:
```python
from .base_crawler import BaseCrawler
from .scrapling_fetcher import RequestStrategy

class SiteCrawler(BaseCrawler):
    """站点爬虫实现"""

    def __init__(self):
        super().__init__(
            base_url="https://www.example.com",
            strategy=RequestStrategy.SIMPLE  # 或 STEALTH
        )
        # 可选：添加站点特定的配置
        self.name = "站点名称"
        self.site_id = "site_id"

    async def search_novels(self, keyword: str) -> list[dict[str, Any]]:
        """搜索小说"""
        # 1. 构建搜索URL
        # 2. 发送请求（使用 self.get_page 或 self.post_form）
        # 3. 解析响应（使用 Scrapling Selector）
        # 4. 返回结果列表
        pass

    async def get_chapter_list(self, novel_url: str) -> list[dict[str, Any)]]:
        """获取章节列表"""
        # 1. 获取小说详情页
        # 2. 查找章节容器
        # 3. 提取章节链接
        # 4. 返回章节列表
        pass

    async def get_chapter_content(self, chapter_url: str) -> dict[str, Any]:
        """获取章节内容"""
        # 1. 获取章节页面
        # 2. 提取标题
        # 3. 提取内容
        # 4. 清理和格式化
        # 5. 返回内容
        pass
```

### 5. 网络层 (Network)

**文件**: `app/services/scrapling_fetcher.py`, `app/services/page_response.py`

#### 5.1 Scrapling 网络层 (ScraplingFetcher)

**文件**: `app/services/scrapling_fetcher.py`

**职责**:
- 基于 Scrapling 库提供网络请求
- 支持 SIMPLE 和 STEALTH 两种策略
- 统一的错误处理和重试机制

**请求策略**:
```python
class RequestStrategy(Enum):
    SIMPLE = "simple"    # Fetcher - 简单高效的 HTTP 请求
    STEALTH = "stealth"  # StealthyFetcher - 最强的反爬能力
```

**配置类**:
```python
@dataclass
class RequestConfig:
    timeout: int = 10
    max_retries: int = 3
    retry_delay: float = 1.0
    strategy: RequestStrategy | None = None
    headers: dict[str, str] | None = None
    proxy: str | None = None
    custom_headers: dict[str, str] | None = None
    post_data: dict[str, str] | None = None  # POST 表单数据
```

**使用示例**:
```python
from app.services.scrapling_fetcher import ScraplingFetcher, RequestStrategy

# 创建 Fetcher
fetcher = ScraplingFetcher(strategy=RequestStrategy.SIMPLE)

# 发送请求（BaseCrawler 内部调用，爬虫代码不需要直接使用）
# response = await fetcher.fetch(url, config)
```

#### 5.2 响应包装层 (PageResponse)

**文件**: `app/services/page_response.py`

**职责**:
- 包装 Scrapling 响应，提供兼容接口
- 支持 Scrapling Selector 和 BeautifulSoup 两种解析方式

**属性**:
```python
class PageResponse:
    url: str                      #              # 响应的 URL
    status_code: int                #           # HTTP 状态码
    headers: dict[str, str]          #  # 响应头字典
    content: str                    #            # HTML 内容
    elapsed: float                   #           # 请求耗时（秒）

    # 获取解析器（两种方式）

    def soup(self) -> Selector:
        """获取 Scrapling Selector（性能比 BeautifulSoup 快 784 倍）"""
        # Scrapling Selector 使用示例:
        soup = response.soup()
        title = soup.css('h1::text').get()
        links = soup.css('a[href]')
        text = soup.find_by_text('关键词')

    def bs4(self) -> BeautifulSoup:
        """获取 BeautifulSoup 对象（兼容旧代码）"""
        # BeautifulSoup 使用示例:
        soup = response.bs4()
        title = soup.find('h1').get_text()
        links = soup.find_all('a', href=True)

    # 直接支持 Selector 方法（链式调用）
    def css(self, selector: str) -> SelectorElement:
        """直接使用 CSS 选择器"""
        title = response.css('h1::text').get()

    def xpath(self, selector: str) -> SelectorElement:
        """直接使用 XPath 选择器"""
        links = response.xpath('//a[@href]')
```

## 数据流示例

### 搜索流程

```
用户请求 -> API 端点
    -> SearchService.search()
        -> 遍历所有启用的爬虫
            -> crawler.search_novels()
                -> base_crawler.get_page()
                    -> scrapling_fetcher.fetch()
                        -> Scrapling Fetcher/StealthyFetcher
                -> page_response.soup()
                    -> Scrapling Selector
                -> 提取小说信息
        -> 聚合和去重结果
    -> 返回给 API 端点
    -> 返回给用户
```

### 章节内容获取流程

```
用户请求 -> API 端点
    -> crawler.get_chapter_content()
        -> base_crawler.get_page()
            -> scrapling_fetcher.fetch()
                -> Scrapling Fetcher
        -> page_response.soup()
            -> Scrapling Selector
        -> 提取标题和内容
        -> 清理和格式化
    -> 返回给 API 端点
    -> 返回给用户
```

## 当前实现状态

### 已完成迁移到 Scrapling

| 组件 | 文件 | 状态 | 说明 |
|------|------|------|------|
| **网络层** | `scrapling_fetcher.py` | ✅ | 支持 SIMPLE/STEALTH 策略 |
| **响应包装** | `page_response.py` | ✅ | 支持 Selector 和 BeautifulSoup |
| **基类** | `base_crawler.py` | ✅ | 提供统一的网络方法 |
| **工厂** | `crawler_factory.py` | ✅ | 管理爬虫注册和加载 |

### 爬虫实现状态

| 爬虫 | 文件 | 继承 BaseCrawler | 使用 Scrapling | 状态 |
|------|------|----------------|---------------|------|
| **alice_sw** | `alice_sw_crawler_refactored.py` | ✅ | ✅ | 搜索功能存在 POST 参数问题 |
| **shukuge** | `shukuge_crawler_refactored.py` | ✅ | ✅ | POST 请求类型错误 |
| **xspsw** | `xspsw_crawler_refactored.py` | ✅ | ✅ | 搜索返回 0 结果 |
| **wdscw** | `wdscw_crawler_refactored.py` | ✅ | ✅ | 搜索返回 0 结果 |
| **wodeshucheng** | `wodeshucheng_crawler.py` | ✅ | ✅ | 搜索返回 0 结果 |
| **smxku** | `smxku_crawler.py` | ❌ | ❌ | 章节列表返回403，已禁用 |
| **ddxsmf** | `ddxsmf_crawler.py` | ✅ | ✅ | 搜索被禁用 |
| **biquge543** | `biquge543_crawler.py` | ✅ | ✅ | 搜索被禁用 |
| **wfxs** | `wfxs_crawler.py` | ❌ | ❌ | 独立 Playwright 实现 |

### 遗留/废弃组件

| 组件 | 状态 | 说明 |
|------|------|------|
| **http_client.py** | ⚠️ 部分废弃 | 旧 HTTP 客户端，部分功能已由 Scrapling 替代 |
| **RequestStrategy.HYBRID** | ❌ 已废弃 | 混合模式策略已移除 |
| **RequestStrategy.BROWSER** | ❌ 已废弃 | 浏览器模式策略已移除 |

## Scrapling Selector 使用指南

### 基础选择器

```python
# 获取 PageResponse 后使用 Selector
page = await self.get_page(url)
soup = page.soup()

# CSS 选择器
title = soup.css('h1::text').get()
links = soup.css('a[href]')
first_link = soup.css('a:first')
all_links = soup.css('a::all')

# XPath 选择器
links = soup.xpath('//a[@href]')
first_link = soup.xpath('//a[1]')

# 文本搜索
element = soup.find_by_text('搜索文本')
elements = soup.find_all_by_text('关键词')

# 组合选择
content = soup.css('#content').css('p::text').getall()
```

### 属性提取

```python
# 提取属性
href = soup.css('a::attr(href)').get()
src = soup.css('img::attr(src)').get('')
class_name = soup.css('div::attr(class)').get()

# 提取文本
text = soup.css('div::text').get()
all_text = soup.css('div::text').getall()

# 相似元素查找
similar = soup.find_similar('div')
```

### 元素操作

```python
# 移除元素
soup.css('script').remove()
soup.css('style, ins').remove()

# 链式操作
parent = soup.css('a').parent
children = soup.css('div').children
next_sibling = soup.css('div').next

# 检查存在性
if soup.css('h1').first:
    print("标题存在")
```

## 常见问题解决

### 问题 1: "Only string values are accepted for arguments"

**原因**: Scrapling 的 parser 对 kwargs 有严格的类型检查，所有值必须是字符串。

**解决方案**:
```python
# 确保所有字典值都是字符串类型
headers = {k: str(v) if v is not None else "" for k, v in original_headers.items()}
post_data = {k: str(v) if v is not None else "" for k, v in original_data.items()}
```

### 问题 2: 403 Forbidden 错误

**原因**: 缺少必要的请求头或被反爬虫检测。

**解决方案**:
```python
# 添加自定义请求头
response = await self.get_page(
    url,
    custom_headers={
        "User-Agent": "Mozilla/5.0 ...",
        "Referer": self.base_url,
    }
)
```

### 问题 3: 页面结构变化

**原因**: 站点更新了页面结构，选择器失效。

**解决方案**:
```python
# 使用多个备选选择器
container = (
    soup.css('#content').first or
    soup.css('.content').first or
    soup.css('div[role="main"]').first
)

# 或者查找最长的 div（通常是内容容器）
divs = soup.css('div')
longest_div = max(divs, key=lambda d: len(d.css('::text').get()))
```

## 添加新爬虫流程

### 步骤 1: 创建爬虫文件

```bash
# 创建新文件
touch app/services/new_site_crawler.py
```

### 步骤 2: 实现爬虫类

```python
#!/usr/bin/env python3
"""新站点爬虫"""

from .base_crawler import BaseCrawler
from .scrapling_fetcher import RequestStrategy
from typing import Any


class NewSiteCrawler(BaseCrawler):
    """新站点爬虫"""

    def __init__(self):
        super().__init__(
            base_url="https://www.example.com",
            strategy=RequestStrategy.SIMPLE  # 或 RequestStrategy.STEALTH
        )
        self.name = "新站点"
        self.site_id = "new_site"

    async def search_novels(self, keyword: str) -> list[dict[str, Any]]:
        """搜索小说"""
        try:
            # 构建搜索URL
            search_url = f"{self.base_url}/search?q={keyword}"

            # 发送请求
            page = await self.get_page(search_url, timeout=15)

            # 解析响应 - 使用 Scrapling Selector
            novels = []
            links = page.css('.novel-item a[href]')

            for link in links:
                title = link.css('::text').get('').strip()
                href = link.css('::attr(href)').get('')

                if title and href:
                    novels.append({
                        "title": title,
                        "url": href,
                        "source": self.site_id,
                    })

            return novels[:20]  # 限制返回数量

        except Exception as e:
            print(f"搜索失败: {e}")
            return []

    async def get_chapter_list(self, novel_url: str) -> list[dict[str, Any]]:
        """获取章节列表"""
        # 实现章节列表提取逻辑
        pass

    async def get_chapter_content(self, chapter_url: str) -> dict[str, Any]:
        """获取章节内容"""
        # 实现章节内容提取逻辑
        pass

    async def get_novel_info(self, novel_url: str) -> dict[str, Any]:
        """获取小说完整信息"""
        # 实现小说信息提取逻辑
        pass
```

### 步骤 3: 注册到工厂

编辑 `app/services/crawler_factory.py`:

```python
# 添加导入
from .new_site_crawler import NewSiteCrawler

# 添加到元数据
SOURCE_SITES_METADATA = {
    # ... 其他站点 ...
    "new_site": {
        "name": "新站点",
        "base_url": "https://www.example.com",
        "description": "站点描述",
        "search_enabled": True,
        "crawler_class": NewSiteCrawler,
    },
}

# 在 get_enabled_crawlers() 中添加实例化
def get_enabled_crawlers() -> dict[str, BaseCrawler]:
    # ... 现有代码 ...
    if not enabled or "new_site" in enabled:
        crawlers["new_site"] = NewSiteCrawler()
    return crawlers
```

### 步骤 4: 测试验证

```python
# 测试新爬虫
import asyncio
from app.services.new_site_crawler import NewSiteCrawler

async def test():
    crawler = NewSiteCrawler()

    # 测试搜索
    results = await crawler.search_novels('测试')
    print(f"搜索结果: {len(results)} 个")
    for result in results[:3]:
        print(f"  - {result['title']}")

    # 测试章节列表（如果有结果）
    if results:
        chapters = await crawler.get_chapter_list(results[0]['url'])
        print(f"章节列表: {len(chapters)} 章")

asyncio.run(test())
```

### 步骤 5: 更新文档

更新 `backend/SUPPORTED_SITES.md` 添加新站点信息。

## 性能优化建议

### 1. 使用 Scrapling Selector

```python
# 好的做法（慢）
soup = BeautifulSoup(html, 'lxml')
title = soup.find('h1').get_text()

# 推荐做法（快 784 倍）
page = await self.get_page(url)
title = page.css('h1::text').get()
```

### 2. 链式选择

```python
# 好的做法
soup = page.soup()
content = soup.css('#content')
paragraphs = content.css('p::text').getall()

# 推荐做法（一次选择）
paragraphs = page.css('#content p::text').getall()
```

### 3. 使用 STEALTH 策略（仅当必要时）

```python
# 对于反爬虫强的站点
class ProtectedSiteCrawler(BaseCrawler):
    def __init__(self):
        super().__init__(
            base_url="https://www.protected-site.com",
            strategy=RequestStrategy.STEALTH  # 使用隐蔽模式
        )
```

### 4. 避免不必要的解析

```python
# 好的做法
soup = BeautifulSoup(page.content, 'lxml')
text = soup.get_text()

# 推荐做法（直接使用）
text = page.css('::text').get()
```

## 总结

当前爬虫系统具有以下特点：

1. **清晰的分层结构** - API -> 服务 -> 工厂 -> 爬虫 -> 网络
2. **统一的接口规范** - 所有爬虫继承 BaseCrawler，实现相同方法
3. **灵活的配置管理** - 通过环境变量控制启用的站点
4. **强大的网络层** - 基于 Scrapling，支持多种策略
5. **良好的兼容性** - 支持 Selector 和 BeautifulSoup 两种解析方式
6. **可扩展性** - 添加新站点只需实现基类接口并注册

后续维护和扩展应遵循本文档的架构规范。
