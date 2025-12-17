#!/usr/bin/env python3
"""
网络请求抽象层

提供统一的HTTP客户端接口，支持多种请求策略和反爬虫技术
"""

import asyncio
import os
import time
from abc import ABC, abstractmethod
from dataclasses import dataclass
from enum import Enum

import requests
from bs4 import BeautifulSoup


class RequestStrategy(Enum):
    """请求策略枚举"""
    SIMPLE = "simple"          # 简单requests请求
    BROWSER = "browser"        # 浏览器模拟请求
    HYBRID = "hybrid"          # 混合模式，优先浏览器，失败降级
    STEALTH = "stealth"        # 隐蔽模式，高级反检测


@dataclass
class RequestConfig:
    """请求配置"""
    timeout: int = 10
    max_retries: int = 3
    retry_delay: float = 1.0
    strategy: RequestStrategy = RequestStrategy.SIMPLE
    headers: dict[str, str] | None = None
    proxy: str | None = None
    use_session: bool = True
    respect_robots_txt: bool = False
    # SSL配置
    verify_ssl: bool = True
    # 自定义浏览器参数（Playwright使用）
    browser_args: list[str] | None = None
    # 自定义请求头
    custom_headers: dict[str, str] | None = None


@dataclass
class Response:
    """统一响应格式"""
    url: str
    status_code: int
    headers: dict[str, str]
    content: str
    encoding: str
    cookies: dict[str, str]
    elapsed: float  # 请求耗时(秒)
    strategy_used: RequestStrategy
    from_cache: bool = False

    def soup(self, parser: str = "html.parser") -> BeautifulSoup:
        """获取BeautifulSoup对象"""
        return BeautifulSoup(self.content, parser)


class IHttpClient(ABC):
    """HTTP客户端抽象接口"""

    @abstractmethod
    async def get(self, url: str, config: RequestConfig | None = None) -> Response:
        """发送GET请求"""
        pass

    @abstractmethod
    async def post(self, url: str, data: dict | None = None,
                  config: RequestConfig | None = None) -> Response:
        """发送POST请求"""
        pass

    @abstractmethod
    def set_cookies(self, cookies: dict[str, str]) -> None:
        """设置Cookie"""
        pass

    @abstractmethod
    def clear_cache(self) -> None:
        """清除缓存"""
        pass


class RequestsClient(IHttpClient):
    """基于requests的HTTP客户端"""

    def __init__(self):
        self.session = requests.Session()
        self._cache: dict[str, Response] = {}
        self._setup_default_headers()
        self._setup_ssl_context()
        self._setup_proxy_from_env()

    def _setup_default_headers(self):
        """设置默认请求头"""
        self.session.headers.update({
            "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36",
            "Accept": "text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,image/apng,*/*;q=0.8,application/signed-exchange;v=b3;q=0.7",
            "Accept-Language": "zh-CN,zh;q=0.9,en;q=0.8",
            "Accept-Encoding": "gzip, deflate, br",
            "DNT": "1",
            "Connection": "keep-alive",
            "Upgrade-Insecure-Requests": "1",
            "Sec-Fetch-Dest": "document",
            "Sec-Fetch-Mode": "navigate",
            "Sec-Fetch-Site": "none",
            "Sec-Fetch-User": "?1",
            "Cache-Control": "max-age=0"
        })

    def _setup_ssl_context(self):
        """设置SSL上下文"""
        import ssl

        from requests.adapters import HTTPAdapter
        from urllib3.util.retry import Retry

        # 创建SSL上下文
        ssl_context = ssl.create_default_context()
        ssl_context.check_hostname = False
        ssl_context.verify_mode = ssl.CERT_NONE

        # 设置适配器
        adapter = HTTPAdapter(
            max_retries=Retry(
                total=5,
                backoff_factor=0.5,
                status_forcelist=[500, 502, 503, 504],
                allowed_methods=["GET", "POST"]
            )
        )
        self.session.mount('https://', adapter)
        self.session.mount('http://', adapter)

    async def get(self, url: str, config: RequestConfig | None = None) -> Response:
        """发送GET请求"""
        config = config or RequestConfig()

        # 检查缓存
        if url in self._cache:
            cached_response = self._cache[url]
            cached_response.from_cache = True
            return cached_response

        # 执行请求
        response = await self._execute_request("GET", url, None, config)

        # 缓存响应
        self._cache[url] = response
        return response

    async def post(self, url: str, data: dict | None = None,
                  config: RequestConfig | None = None) -> Response:
        """发送POST请求"""
        config = config or RequestConfig()
        return await self._execute_request("POST", url, data, config)

    async def _execute_request(self, method: str, url: str, data: dict | None,
                              config: RequestConfig) -> Response:
        """执行HTTP请求"""
        loop = asyncio.get_event_loop()

        # 准备请求头
        headers = {}
        if config.custom_headers:
            headers.update(config.custom_headers)
        if config.headers:
            headers.update(config.headers)

        # 准备请求参数
        request_kwargs = {
            "timeout": config.timeout,
            "headers": headers,
            "proxies": self._get_proxies(config.proxy),
            "verify": config.verify_ssl
        }

        for attempt in range(config.max_retries):
            try:
                if attempt > 0:
                    delay = config.retry_delay * (2 ** (attempt - 1))  # 指数退避
                    await asyncio.sleep(delay)

                start_time = time.time()

                if method == "GET":
                    r = await loop.run_in_executor(
                        None, lambda: self.session.get(url, **request_kwargs)
                    )
                else:  # POST
                    request_kwargs["data"] = data
                    r = await loop.run_in_executor(
                        None, lambda: self.session.post(url, **request_kwargs)
                    )

                elapsed = time.time() - start_time

                if r.status_code == 200:
                    # 智能编码检测
                    encoding = self._detect_encoding(r)
                    return Response(
                        url=r.url,
                        status_code=r.status_code,
                        headers=dict(r.headers),
                        content=r.content.decode(encoding, errors='ignore'),
                        encoding=encoding,
                        cookies=dict(r.cookies),
                        elapsed=elapsed,
                        strategy_used=RequestStrategy.SIMPLE
                    )
                else:
                    raise Exception(f"HTTP {r.status_code}")

            except Exception as e:
                if attempt == config.max_retries - 1:
                    raise Exception(f"请求失败，已重试{config.max_retries}次: {e!s}")
                continue

        raise Exception("未知错误")

    def _detect_encoding(self, response: requests.Response) -> str:
        """智能检测页面编码"""
        # 1. 优先使用HTTP头指定的编码
        if response.encoding:
            encoding = response.encoding.lower()
            if encoding in ['gb2312', 'gbk']:
                return 'gbk'
            elif encoding != 'utf-8':
                return encoding

        # 2. 使用apparent_encoding
        if hasattr(response, 'apparent_encoding') and response.apparent_encoding:
            encoding = response.apparent_encoding.lower()
            if encoding in ['gb2312', 'gbk']:
                return 'gbk'
            return encoding

        # 3. 默认utf-8
        return 'utf-8'

    def _get_proxies(self, proxy: str | None) -> dict[str, str] | None:
        """获取代理配置"""
        if proxy:
            return {
                'http': proxy,
                'https': proxy
            }
        return None

    def _setup_proxy_from_env(self):
        """从环境变量设置代理"""
        # 获取环境变量中的代理配置
        http_proxy = os.environ.get('HTTP_PROXY') or os.environ.get('http_proxy')
        https_proxy = os.environ.get('HTTPS_PROXY') or os.environ.get('https_proxy')
        os.environ.get('NO_PROXY') or os.environ.get('no_proxy')

        if http_proxy or https_proxy:
            proxies = {}
            if http_proxy:
                proxies['http'] = http_proxy
            if https_proxy:
                proxies['https'] = https_proxy

            # 设置session的代理
            self.session.proxies.update(proxies)
            print(f"✅ 已配置代理: {proxies}")
        else:
            print("ℹ️  未检测到代理环境变量，使用直连")

    def set_cookies(self, cookies: dict[str, str]) -> None:
        """设置Cookie"""
        self.session.cookies.update(cookies)

    def clear_cache(self) -> None:
        """清除缓存"""
        self._cache.clear()


class PlaywrightClient(IHttpClient):
    """基于Playwright的HTTP客户端"""

    def __init__(self):
        self.browser = None
        self.context = None
        self.page = None
        self._cache: dict[str, Response] = {}

    async def _ensure_browser(self, config: RequestConfig | None = None):
        """确保浏览器已初始化"""
        if self.browser is None:
            try:
                from playwright.async_api import async_playwright
                playwright = await async_playwright().start()

                # 默认浏览器参数
                default_args = [
                    '--no-sandbox',
                    '--disable-dev-shm-usage',
                    '--disable-gpu',
                    '--disable-web-security',
                    '--disable-features=VizDisplayCompositor'
                ]

                # 合并自定义参数
                browser_args = default_args
                if config and config.browser_args:
                    browser_args = default_args + config.browser_args

                self.browser = await playwright.chromium.launch(
                    headless=True,
                    args=browser_args
                )

                # 设置上下文
                context_options = {
                    "user_agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"
                }

                # 添加自定义请求头
                if config and config.custom_headers:
                    context_options["extra_http_headers"] = config.custom_headers

                self.context = await self.browser.new_context(**context_options)
                self.page = await self.context.new_page()

            except ImportError:
                raise Exception("Playwright未安装，请安装: pip install playwright")
            except Exception as e:
                raise Exception(f"Playwright初始化失败: {e!s}")

    async def get(self, url: str, config: RequestConfig | None = None) -> Response:
        """发送GET请求"""
        config = config or RequestConfig()

        # 检查缓存
        if url in self._cache:
            cached_response = self._cache[url]
            cached_response.from_cache = True
            return cached_response

        await self._ensure_browser(config)

        try:
            start_time = time.time()

            # 设置超时
            await self.page.set_default_timeout(config.timeout * 1000)

            # 发起请求
            response = await self.page.goto(url)
            elapsed = time.time() - start_time

            if response and response.ok:
                # 获取页面内容
                content = await self.page.content()

                # 获取响应头
                headers = {}
                if hasattr(response, 'headers'):
                    headers = dict(response.headers)

                result = Response(
                    url=url,
                    status_code=response.status,
                    headers=headers,
                    content=content,
                    encoding='utf-8',  # Playwright通常返回UTF-8
                    cookies={},
                    elapsed=elapsed,
                    strategy_used=RequestStrategy.BROWSER
                )

                # 缓存响应
                self._cache[url] = result
                return result
            else:
                raise Exception(f"Playwright请求失败: {response.status if response else 'Unknown'}")

        except Exception as e:
            raise Exception(f"Playwright请求异常: {e!s}")

    async def post(self, url: str, data: dict | None = None,
                  config: RequestConfig | None = None) -> Response:
        """发送POST请求"""
        await self._ensure_browser()

        try:
            start_time = time.time()

            # 设置表单数据
            if data:
                await self.page.evaluate("""
                    (data) => {
                        const form = document.createElement('form');
                        form.method = 'POST';
                        form.action = window.location.href;

                        for (const [key, value] of Object.entries(data)) {
                            const input = document.createElement('input');
                            input.type = 'hidden';
                            input.name = key;
                            input.value = value;
                            form.appendChild(input);
                        }

                        document.body.appendChild(form);
                        form.submit();
                    }
                """, data)
            else:
                await self.page.goto(url)

            elapsed = time.time() - start_time

            # 等待页面加载
            await self.page.wait_for_load_state('networkidle')

            content = await self.page.content()

            return Response(
                url=url,
                status_code=200,  # Playwright中很难准确获取状态码
                headers={},
                content=content,
                encoding='utf-8',
                cookies={},
                elapsed=elapsed,
                strategy_used=RequestStrategy.BROWSER
            )

        except Exception as e:
            raise Exception(f"Playwright POST请求异常: {e!s}")

    def set_cookies(self, cookies: dict[str, str]) -> None:
        """设置Cookie"""
        # 需要在context初始化后设置
        pass

    def clear_cache(self) -> None:
        """清除缓存"""
        self._cache.clear()

    async def close(self):
        """关闭浏览器"""
        if self.browser:
            await self.browser.close()


class HybridHttpClient(IHttpClient):
    """混合HTTP客户端，结合requests和playwright"""

    def __init__(self):
        self.requests_client = RequestsClient()
        self.playwright_client = PlaywrightClient()

    async def get(self, url: str, config: RequestConfig | None = None) -> Response:
        """发送GET请求，优先使用requests，失败时尝试playwright"""
        config = config or RequestConfig()

        if config.strategy == RequestStrategy.SIMPLE:
            return await self.requests_client.get(url, config)
        elif config.strategy == RequestStrategy.BROWSER:
            return await self.playwright_client.get(url, config)
        elif config.strategy == RequestStrategy.HYBRID:
            try:
                return await self.requests_client.get(url, config)
            except Exception as e:
                print(f"Requests请求失败，尝试Playwright: {e!s}")
                return await self.playwright_client.get(url, config)
        else:  # STEALTH
            # 总是使用Playwright，添加更多反检测策略
            return await self.playwright_client.get(url, config)

    async def post(self, url: str, data: dict | None = None,
                  config: RequestConfig | None = None) -> Response:
        """发送POST请求"""
        config = config or RequestConfig()

        if config.strategy == RequestStrategy.SIMPLE:
            return await self.requests_client.post(url, data, config)
        elif config.strategy == RequestStrategy.BROWSER:
            return await self.playwright_client.post(url, data, config)
        elif config.strategy == RequestStrategy.HYBRID:
            try:
                return await self.requests_client.post(url, data, config)
            except Exception as e:
                print(f"Requests请求失败，尝试Playwright: {e!s}")
                return await self.playwright_client.post(url, data, config)
        else:  # STEALTH
            return await self.playwright_client.post(url, data, config)

    def set_cookies(self, cookies: dict[str, str]) -> None:
        """设置Cookie"""
        self.requests_client.set_cookies(cookies)
        self.playwright_client.set_cookies(cookies)

    def clear_cache(self) -> None:
        """清除缓存"""
        self.requests_client.clear_cache()
        self.playwright_client.clear_cache()

    async def close(self):
        """关闭资源"""
        await self.playwright_client.close()




# 全局客户端实例
_default_client: IHttpClient | None = None


def get_http_client(strategy: RequestStrategy = RequestStrategy.HYBRID) -> IHttpClient:
    """获取HTTP客户端实例"""
    global _default_client

    if _default_client is None:
        if strategy in [RequestStrategy.BROWSER, RequestStrategy.STEALTH]:
            _default_client = PlaywrightClient()
        elif strategy == RequestStrategy.HYBRID:
            _default_client = HybridHttpClient()
        else:
            _default_client = RequestsClient()

    return _default_client


async def http_get(url: str, config: RequestConfig | None = None) -> Response:
    """便捷的GET请求函数"""
    client = get_http_client()
    return await client.get(url, config)


async def http_post(url: str, data: dict | None = None,
                   config: RequestConfig | None = None) -> Response:
    """便捷的POST请求函数"""
    client = get_http_client()
    return await client.post(url, data, config)
