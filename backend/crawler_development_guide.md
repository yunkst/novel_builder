# Novel Builder 爬虫开发规范

## 📋 目录
- [架构概述](#架构概述)
- [开发环境要求](#开发环境要求)
- [爬虫命名规范](#爬虫命名规范)
- [核心接口规范](#核心接口规范)
- [HTTP客户端使用规范](#http客户端使用规范)
- [数据处理规范](#数据处理规范)
- [错误处理规范](#错误处理规范)
- [测试规范](#测试规范)
- [部署和配置](#部署和配置)
- [最佳实践](#最佳实践)
- [开发模板](#开发模板)

## 🏗️ 架构概述

### 分层架构
```
┌─────────────────────────────────────┐
│           API层 (FastAPI)            │
├─────────────────────────────────────┤
│         服务层 (Services)           │
├─────────────────────────────────────┤
│  爬虫抽象层 (EnhancedBaseCrawler)   │
├─────────────────────────────────────┤
│    HTTP客户端抽象层 (HttpClient)     │
├─────────────────────────────────────┤
│    网络实现层 (Requests/Playwright)  │
└─────────────────────────────────────┘
```

### 核心设计原则
- **单一职责**: 爬虫只负责数据提取，不处理业务逻辑
- **依赖注入**: 通过工厂模式统一管理爬虫实例
- **策略模式**: HTTP客户端支持多种请求策略
- **统一接口**: 所有爬虫必须实现相同的抽象接口
- **错误隔离**: 单个爬虫故障不影响整体服务

## 🔧 开发环境要求

### Python版本
- Python 3.8+
- 推荐使用 Python 3.10+

### 依赖包
```python
# 核心依赖
fastapi>=0.100.0
beautifulsoup4>=4.12.0
requests>=2.31.0
playwright>=1.40.0

# 数据处理
pydantic>=2.0.0
sqlalchemy>=2.0.0

# 工具包
lxml>=4.9.0
urllib3>=2.0.0
```

### 开发工具
```bash
# 代码质量
ruff          # 代码检查和格式化
mypy          # 类型检查
pytest        # 测试框架

# Docker支持
docker        # 容器化
docker-compose # 编排工具
```

## 📝 爬虫命名规范

### 类名规范
```python
# 格式：{SiteName}CrawlerRefactored
class AliceSWCrawlerRefactored(EnhancedBaseCrawler):
    """AliceSW网站爬虫重构版"""

class ShukugeCrawlerRefactored(EnhancedBaseCrawler):
    """书库网站爬虫重构版"""
```

### 文件名规范
```bash
# 格式：{site_name}_crawler_refactored.py
alice_sw_crawler_refactored.py
shukuge_crawler_refactored.py
xspsw_crawler_refactored.py
```

### 常量和方法命名
```python
# 私有方法使用下划线前缀
def _extract_search_results(self, soup, keyword: str):
    """提取搜索结果"""

def _should_skip_link(self, title: str, href: str) -> bool:
    """判断是否跳过链接"""

# 站点特定方法使用站点前缀
def _extract_alice_sw_author(self, element):
    """提取AliceSW作者信息"""

def _parse_shukuge_chapter_list(self, soup):
    """解析Shukuge章节列表"""
```

## 🔌 核心接口规范

### 必须实现的抽象方法
```python
from abc import ABC, abstractmethod
from typing import Any, Dict, List

class EnhancedBaseCrawler(ABC):
    @abstractmethod
    async def search_novels(self, keyword: str) -> List[Dict[str, Any]]:
        """
        搜索小说

        Args:
            keyword: 搜索关键词

        Returns:
            List[Dict]: 搜索结果列表，格式见下方规范

        Raises:
            Exception: 搜索失败时抛出异常
        """
        pass

    @abstractmethod
    async def get_chapter_list(self, novel_url: str) -> List[Dict[str, Any]]:
        """
        获取章节列表

        Args:
            novel_url: 小说详情页URL

        Returns:
            List[Dict]: 章节列表，格式见下方规范

        Raises:
            Exception: 获取失败时抛出异常
        """
        pass

    @abstractmethod
    async def get_chapter_content(self, chapter_url: str) -> Dict[str, Any]:
        """
        获取章节内容

        Args:
            chapter_url: 章节URL

        Returns:
            Dict: 章节内容，格式见下方规范

        Raises:
            Exception: 获取失败时抛出异常
        """
        pass
```

### 标准数据格式

#### 搜索结果格式
```python
[
    {
        "title": "小说标题",           # 必需
        "author": "作者名称",         # 必需
        "url": "小说详情页URL",      # 必需
        "cover_url": "封面图片URL",   # 可选
        "description": "小说简介",    # 可选
        "status": "连载/完结",       # 可选
        "category": "小说分类",      # 可选
        "last_updated": "更新时间",   # 可选
        "source": "alice_sw"         # 自动添加，无需手动设置
    }
]
```

#### 章节列表格式
```python
[
    {
        "title": "章节标题",         # 必需
        "url": "章节URL"            # 必需
    }
]
```

#### 章节内容格式
```python
{
    "title": "章节标题",           # 必需
    "content": "章节正文内容"      # 必需
}
```

## 🌐 HTTP客户端使用规范

### 请求策略选择
```python
from .http_client import RequestStrategy

# 策略选择指南
strategies = {
    "简单HTTP网站": RequestStrategy.SIMPLE,      # 使用requests
    "复杂SPA网站": RequestStrategy.BROWSER,      # 使用playwright
    "需要反爬虫": RequestStrategy.HYBRID,        # 混合模式，优先requests
    "高级反检测": RequestStrategy.STEALTH         # 隐蔽模式
}
```

### 爬虫初始化
```python
class ExampleCrawler(EnhancedBaseCrawler):
    def __init__(self):
        super().__init__(
            base_url="https://www.example.com",
            strategy=RequestStrategy.HYBRID  # 根据网站特性选择策略
        )

        # 自定义请求头
        self.custom_headers = {
            "User-Agent": "Mozilla/5.0...",
            "Accept": "text/html...",
            "Accept-Language": "zh-CN,zh;q=0.9"
        }

        # 浏览器参数（仅在需要时）
        self.browser_args = [
            '--disable-web-security',
            '--no-sandbox'
        ]
```

### 请求配置规范
```python
async def search_novels(self, keyword: str):
    try:
        # 标准配置
        config = RequestConfig(
            timeout=15,              # 超时时间
            max_retries=3,           # 最大重试次数
            strategy=self.strategy,   # 请求策略
            custom_headers=self.custom_headers,  # 自定义请求头
            verify_ssl=False,        # SSL验证（针对问题证书）
            browser_args=self.browser_args  # 浏览器参数
        )

        # 发送请求
        response = await self.get_page(url, timeout=15)

        # 或者POST请求
        response = await self.post_form(url, data, timeout=15)

    except Exception as e:
        print(f"请求失败: {e}")
        return []
```

### 响应处理规范
```python
# 获取BeautifulSoup对象
soup = response.soup()

# 获取原始内容
content = response.content

# 获取编码信息
encoding = response.encoding

# 检查请求策略
strategy_used = response.strategy_used

# 检查是否来自缓存
from_cache = response.from_cache
```

## 📊 数据处理规范

### HTML解析规范
```python
# 使用CSS选择器优先于正则表达式
title_element = soup.select_one('h1.title, .book-title, #book-title')
if title_element:
    title = title_element.get_text().strip()

# 多选择器降级策略
content_selectors = [
    '#content',
    '.content',
    '.chapter-content',
    'div[class*="content"]'
]

content = None
for selector in content_selectors:
    content = soup.select_one(selector)
    if content:
        break
```

### 数据清理规范
```python
# 使用基类提供的清理方法
cleaned_text = self.clean_text(raw_text)

# 自定义清理（在基类方法基础上）
def clean_novel_content(self, text: str) -> str:
    # 先使用基类清理
    text = self.clean_text(text)

    # 站点特定清理
    text = re.sub(r'请记住本站域名.*$', '', text)
    text = re.sub(r'最新章节.*$', '', text)

    return text.strip()
```

### URL处理规范
```python
import urllib.parse

# URL拼接
full_url = urllib.parse.urljoin(self.base_url, relative_url)

# URL参数编码
params = {'key': keyword, 'type': 'all'}
full_url = f"{search_url}?{urllib.parse.urlencode(params)}"

# URL有效性检查
if not href or href.startswith(('javascript:', '#', 'mailto:')):
    continue
```

### 数据验证规范
```python
# 搜索结果验证
def _validate_novel_info(self, novel_info: Dict[str, Any]) -> bool:
    """验证小说信息完整性"""
    required_fields = ['title', 'author', 'url']

    for field in required_fields:
        if not novel_info.get(field) or len(novel_info[field].strip()) < 2:
            return False

    # URL格式检查
    if not novel_info['url'].startswith(('http://', 'https://')):
        return False

    return True

# 章节验证
def _validate_chapter(self, chapter: Dict[str, Any]) -> bool:
    """验证章节信息"""
    title = chapter.get('title', '').strip()
    url = chapter.get('url', '').strip()

    return len(title) > 1 and url.startswith('http')
```

## ⚠️ 错误处理规范

### 异常处理原则
```python
async def search_novels(self, keyword: str):
    try:
        # 主要逻辑
        results = await self._perform_search(keyword)
        return results

    except requests.exceptions.Timeout:
        print(f"搜索超时: {keyword}")
        return []

    except requests.exceptions.ConnectionError:
        print(f"网络连接失败: {keyword}")
        return []

    except Exception as e:
        print(f"搜索失败: {keyword}, 错误: {str(e)}")
        return []
```

### 重试机制
```python
async def _get_with_retry(self, url: str, max_retries: int = 3):
    """带重试的请求"""
    for attempt in range(max_retries):
        try:
            return await self.get_page(url)

        except Exception as e:
            if attempt == max_retries - 1:
                raise e

            # 指数退避
            delay = 2 ** attempt
            await asyncio.sleep(delay)
```

### 优雅降级
```python
async def get_chapter_list(self, novel_url: str):
    try:
        # 主要方法
        chapters = await self._extract_from_detail_page(novel_url)
        if chapters:
            return chapters

    except Exception:
        pass

    try:
        # 备用方法
        chapters = await self._extract_from_reading_page(novel_url)
        if chapters:
            return chapters

    except Exception:
        pass

    # 最后的备用方案
    return await self._extract_generic_chapters(novel_url)
```

## 🧪 测试规范

### 单元测试结构
```python
import pytest
import asyncio
from app.services.alice_sw_crawler_refactored import AliceSWCrawlerRefactored

class TestAliceSWCrawler:
    @pytest.fixture
    def crawler(self):
        return AliceSWCrawlerRefactored()

    @pytest.mark.asyncio
    async def test_search_novels(self, crawler):
        """测试搜索功能"""
        results = await crawler.search_novels("斗破苍穹")

        assert isinstance(results, list)
        if results:  # 如果有结果
            assert all(isinstance(r, dict) for r in results)
            assert all('title' in r and 'url' in r for r in results)

    @pytest.mark.asyncio
    async def test_get_chapter_list(self, crawler):
        """测试章节列表获取"""
        # 先获取一个小说URL
        search_results = await crawler.search_novels("test")
        if search_results:
            novel_url = search_results[0]['url']
            chapters = await crawler.get_chapter_list(novel_url)

            assert isinstance(chapters, list)
            assert all('title' in c and 'url' in c for c in chapters)
```

### 集成测试
```python
@pytest.mark.asyncio
async def test_complete_workflow():
    """测试完整工作流程"""
    crawler = AliceSWCrawlerRefactored()

    # 1. 搜索
    novels = await crawler.search_novels("测试小说")
    assert len(novels) > 0

    # 2. 获取章节列表
    novel_url = novels[0]['url']
    chapters = await crawler.get_chapter_list(novel_url)
    assert len(chapters) > 0

    # 3. 获取章节内容
    chapter_url = chapters[0]['url']
    content = await crawler.get_chapter_content(chapter_url)
    assert 'title' in content
    assert len(content['content']) > 100  # 内容长度检查
```

## 🚀 部署和配置

### 环境变量配置
```bash
# 启用爬虫站点
NOVEL_ENABLED_SITES=alice_sw,shukuge,xspsw

# API认证
NOVEL_API_TOKEN=your-secret-token

# 代理配置（可选）
HTTP_PROXY=http://proxy.example.com:7890
HTTPS_PROXY=http://proxy.example.com:7890

# 调试模式
DEBUG=true
```

### 爬虫工厂注册
```python
# 在 crawler_factory.py 中注册新爬虫
SOURCE_SITES_METADATA = {
    "new_site": {
        "name": "新小说网站",
        "base_url": "https://www.newsite.com",
        "description": "网站描述",
        "search_enabled": True,
        "crawler_class": NewSiteCrawlerRefactored
    }
}

def get_enabled_crawlers():
    enabled = os.getenv("NOVEL_ENABLED_SITES", "").lower()
    crawlers = {}

    if not enabled or "new_site" in enabled:
        crawlers["new_site"] = NewSiteCrawlerRefactored()

    return crawlers
```

### Docker部署
```dockerfile
# 确保安装所有依赖
RUN pip install playwright
RUN playwright install chromium

# 设置环境变量
ENV NOVEL_ENABLED_SITES=alice_sw,shukuge,xspsw,new_site
ENV PYTHONPATH=/app
```

## 💡 最佳实践

### 1. 性能优化
```python
# 使用连接池
self.custom_headers = {
    "Connection": "keep-alive"
}

# 合理设置超时
config = RequestConfig(timeout=15, max_retries=3)

# 缓存利用（HTTP客户端自动处理）
response = await self.get_page(url)  # 自动缓存响应
```

### 2. 反爬虫策略
```python
# 随机延迟
import random
await asyncio.sleep(random.uniform(1, 3))

# 轮换User-Agent
user_agents = [
    "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36",
    "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36"
]
self.custom_headers["User-Agent"] = random.choice(user_agents)

# 使用混合策略
strategy = RequestStrategy.HYBRID  # 自动降级
```

### 3. 数据质量
```python
# 内容长度检查
if len(content) < 300:
    raise Exception("内容过短，可能获取失败")

# 标题规范化
def normalize_title(self, title: str) -> str:
    title = title.strip()
    title = re.sub(r'^\d+\.\s*', '', title)  # 去除序号
    title = re.sub(r'[_\-]{2,}', '', title)   # 去除多余符号
    return title

# 去重处理
def deduplicate_results(self, results: List[Dict]) -> List[Dict]:
    seen = set()
    unique = []
    for item in results:
        key = (item['title'], item['url'])
        if key not in seen:
            unique.append(item)
            seen.add(key)
    return unique
```

### 4. 监控和日志
```python
import logging

logger = logging.getLogger(__name__)

async def search_novels(self, keyword: str):
    logger.info(f"开始搜索: {keyword}")
    start_time = time.time()

    try:
        results = await self._perform_search(keyword)
        elapsed = time.time() - start_time

        logger.info(f"搜索完成: {keyword}, 找到 {len(results)} 个结果, 耗时 {elapsed:.2f}s")
        return results

    except Exception as e:
        logger.error(f"搜索失败: {keyword}, 错误: {str(e)}")
        return []
```

## 📋 开发模板

### 新爬虫模板
```python
#!/usr/bin/env python3
"""
{SiteName}爬虫

网站描述、特性说明
"""

import re
import urllib.parse
from typing import Any, Dict, List

from .enhanced_base_crawler import EnhancedBaseCrawler
from .http_client import RequestConfig, RequestStrategy


class {SiteName}CrawlerRefactored(EnhancedBaseCrawler):
    """{SiteName}网站爬虫"""

    def __init__(self):
        super().__init__(
            base_url="https://www.{site_name}.com",
            strategy=RequestStrategy.{STRATEGY}
        )

        # 自定义请求头
        self.custom_headers = {
            "User-Agent": "Mozilla/5.0...",
            "Accept": "text/html...",
            "Accept-Language": "zh-CN,zh;q=0.9",
            "Accept-Encoding": "gzip, deflate, br",
            "Connection": "keep-alive"
        }

        # 浏览器参数（如果需要）
        self.browser_args = [
            '--no-sandbox',
            '--disable-web-security'
        ]

    async def search_novels(self, keyword: str) -> List[Dict[str, Any]]:
        """搜索小说"""
        try:
            # 搜索URL
            search_url = f"{self.base_url}/search"

            # 请求配置
            config = RequestConfig(
                timeout=15,
                max_retries=3,
                strategy=self.strategy,
                custom_headers=self.custom_headers
            )

            # 搜索参数（根据网站调整）
            search_data = {
                "keyword": keyword.strip()
            }

            # 发送请求
            response = await self.post_form(search_url, search_data, timeout=15)

            # 提取搜索结果
            novels = self._extract_search_results(response.soup(), keyword)

            # 数据验证和清理
            valid_novels = []
            for novel in novels:
                if self._validate_novel_info(novel):
                    valid_novels.append(novel)

            # 去重
            return self._deduplicate_results(valid_novels)[:20]

        except Exception as e:
            print(f"{self.__class__.__name__}搜索失败: {str(e)}")
            return []

    async def get_chapter_list(self, novel_url: str) -> List[Dict[str, Any]]:
        """获取章节列表"""
        try:
            # 获取小说详情页
            response = await self.get_page(novel_url, timeout=15)

            # 提取章节列表
            chapters = self._extract_chapter_list(response.soup(), novel_url)

            # 数据验证
            valid_chapters = []
            for chapter in chapters:
                if self._validate_chapter(chapter):
                    valid_chapters.append(chapter)

            return valid_chapters

        except Exception as e:
            print(f"{self.__class__.__name__}获取章节列表失败: {str(e)}")
            return []

    async def get_chapter_content(self, chapter_url: str) -> Dict[str, Any]:
        """获取章节内容"""
        try:
            # 获取章节页面
            response = await self.get_page(chapter_url, timeout=15)
            soup = response.soup()

            # 提取标题
            title = self._extract_chapter_title(soup)

            # 提取内容
            content = self._extract_chapter_content(soup)

            # 内容清理
            content = self.clean_novel_content(content)

            return {
                "title": title,
                "content": content
            }

        except Exception as e:
            print(f"{self.__class__.__name__}获取章节内容失败: {str(e)}")
            return {
                "title": "章节内容",
                "content": f"获取失败: {str(e)}"
            }

    # ==================== 站点特定方法 ====================

    def _extract_search_results(self, soup, keyword: str) -> List[Dict[str, Any]]:
        """提取搜索结果"""
        novels = []

        # 根据网站结构编写选择器
        result_items = soup.find_all("div", class_="result-item")

        for item in result_items:
            try:
                # 提取标题和链接
                title_link = item.find("a", href=True)
                if not title_link:
                    continue

                title = title_link.get_text().strip()
                href = title_link.get("href", "")
                full_url = urllib.parse.urljoin(self.base_url, href)

                # 提取作者
                author = self._extract_author(item)

                # 提取其他信息
                novel_info = {
                    "title": title,
                    "author": author,
                    "url": full_url,
                    "cover_url": self._extract_cover_url(item),
                    "description": self._extract_description(item),
                    "status": self._extract_status(item),
                    "category": self._extract_category(item),
                    "last_updated": self._extract_last_updated(item)
                }

                novels.append(novel_info)

            except Exception:
                continue

        return novels

    def _extract_chapter_list(self, soup, novel_url: str) -> List[Dict[str, Any]]:
        """提取章节列表"""
        chapters = []

        # 根据网站结构编写选择器
        chapter_links = soup.select("div.chapter-list a")

        for link in chapter_links:
            try:
                title = link.get_text().strip()
                href = link.get("href", "")
                full_url = urllib.parse.urljoin(novel_url, href)

                if self._is_valid_chapter(title, href):
                    chapters.append({
                        "title": title,
                        "url": full_url
                    })

            except Exception:
                continue

        return chapters

    def _extract_chapter_title(self, soup) -> str:
        """提取章节标题"""
        title_selectors = [
            "h1", "h2", ".chapter-title",
            ".title", "title"
        ]

        for selector in title_selectors:
            title_elem = soup.select_one(selector)
            if title_elem:
                title = title_elem.get_text().strip()
                if title and len(title) > 1:
                    return title

        return "章节内容"

    def _extract_chapter_content(self, soup) -> str:
        """提取章节内容"""
        # 根据网站结构调整选择器
        content_selectors = [
            "#content", ".content", ".chapter-content",
            ".read-content", "div[class*='content']"
        ]

        content_elem = None
        for selector in content_selectors:
            content_elem = soup.select_one(selector)
            if content_elem:
                break

        if not content_elem:
            return self.extract_content(soup)

        # 移除无关元素
        for elem in content_elem(["script", "style", "ins", "iframe"]):
            elem.decompose()

        # 获取内容
        content = content_elem.get_text()
        return content

    # ==================== 辅助方法 ====================

    def _extract_author(self, element) -> str:
        """提取作者信息"""
        # 根据网站结构实现
        return "未知作者"

    def _extract_cover_url(self, element) -> str:
        """提取封面URL"""
        img = element.find("img")
        if img:
            src = img.get("src") or img.get("data-src")
            if src:
                return urllib.parse.urljoin(self.base_url, src)
        return ""

    def _extract_description(self, element) -> str:
        """提取简介"""
        # 根据网站结构实现
        return ""

    def _extract_status(self, element) -> str:
        """提取连载状态"""
        text = element.get_text().lower()
        if "完结" in text or "完本" in text:
            return "完结"
        elif "连载" in text:
            return "连载"
        return "unknown"

    def _extract_category(self, element) -> str:
        """提取分类"""
        # 根据网站结构实现
        return "unknown"

    def _extract_last_updated(self, element) -> str:
        """提取更新时间"""
        # 根据网站结构实现
        return ""

    def _is_valid_chapter(self, title: str, href: str) -> bool:
        """验证章节链接有效性"""
        if len(title) <= 1 or not href:
            return False

        # 跳过无效链接
        skip_patterns = [
            r"javascript:", r"#", r"目录", r"书签",
            r"收藏", r"推荐", r"排行"
        ]

        for pattern in skip_patterns:
            if re.search(pattern, title, re.IGNORECASE):
                return False

        return True

    def _validate_novel_info(self, novel_info: Dict[str, Any]) -> bool:
        """验证小说信息"""
        required_fields = ["title", "author", "url"]

        for field in required_fields:
            if not novel_info.get(field) or len(novel_info[field].strip()) < 2:
                return False

        return True

    def _validate_chapter(self, chapter: Dict[str, Any]) -> bool:
        """验证章节信息"""
        title = chapter.get("title", "").strip()
        url = chapter.get("url", "").strip()

        return len(title) > 1 and url.startswith("http")

    def _deduplicate_results(self, results: List[Dict[str, Any]]) -> List[Dict[str, Any]]:
        """去重"""
        seen = set()
        unique = []

        for item in results:
            key = (item["title"], item["url"])
            if key not in seen:
                unique.append(item)
                seen.add(key)

        return unique

    def clean_novel_content(self, text: str) -> str:
        """清理小说内容"""
        if not text:
            return ""

        # 先使用基类清理
        text = self.clean_text(text)

        # 站点特定清理
        text = re.sub(r'请记住.*?[wW][wW][wW]\.[^s]+', '', text)
        text = re.sub(r'最新章节.*?$', '', text)
        text = re.sub(r'\s*\n\s*\n\s*', '\n\n', text)

        return text.strip()


# 为了向后兼容，创建别名
{SiteName}Crawler = {SiteName}CrawlerRefactored
```

### 使用模板步骤
1. 复制模板代码
2. 替换 `{SiteName}` 为实际站点名称
3. 调整 `base_url` 和 `RequestStrategy`
4. 根据目标网站结构修改选择器
5. 实现站点特定的辅助方法
6. 在 `crawler_factory.py` 中注册新爬虫
7. 编写单元测试
8. 集成测试验证

## 📝 总结

本规范定义了Novel Builder项目爬虫开发的标准流程和最佳实践。遵循这些规范可以：

- **保证代码质量**: 统一的代码风格和结构
- **提高开发效率**: 标准化的开发模板和工具
- **确保系统稳定**: 完善的错误处理和测试覆盖
- **便于维护扩展**: 清晰的架构和文档

开发新爬虫时，请严格遵循本规范，确保代码质量和系统稳定性。