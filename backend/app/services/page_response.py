#!/usr/bin/env python3
"""
PageResponse - Scrapling 响应包装类

提供与原 Response 兼容的接口，同时提供 Scrapling Selector
的所有强大功能。

这个类作为连接 Scrapling 和现有爬虫代码的桥梁，确保
所有爬虫无需修改即可使用 Scrapling 的高性能解析功能。
"""

from scrapling.parser import Selector


class PageResponse:
    """
    页面响应包装类

    提供与原 Response 兼容的接口，同时提供 Scrapling Selector
    的强大功能。Selector 比 BeautifulSoup4 快 784 倍，并提供了
    更丰富的选择器功能。

    属性:
        url: 响应的 URL
        status_code: HTTP 状态码
        headers: 响应头字典
        content: HTML 内容
        elapsed: 请求耗时（秒）
        _selector: Scrapling Selector 实例（延迟初始化）

    使用示例:
        >>> # 原有接口保持不变
        >>> print(response.url)
        >>> print(response.status_code)
        >>>
        >>> # 获取 Selector（比 BeautifulSoup4 快 784 倍）
        >>> soup = response.soup()
        >>> title = soup.css('h1::text').get()
        >>> links = soup.css('a')
    """

    def __init__(self, response: "Response", fetcher):
        """
        初始化

        Args:
            response: 原始响应对象（包含 url, status_code, headers, content, elapsed）
            fetcher: ScraplingFetcher 实例（用于创建 Selector）
        """
        self._response = response
        self._fetcher = fetcher
        self._selector: Selector | None = None  # 延迟初始化

    @property
    def url(self) -> str:
        """响应 URL"""
        return self._response.url

    @property
    def status_code(self) -> int:
        """HTTP 状态码"""
        return self._response.status_code

    @property
    def headers(self) -> dict[str, str]:
        """响应头字典"""
        return self._response.headers

    @property
    def content(self) -> str:
        """HTML 内容"""
        return self._response.content

    @property
    def elapsed(self) -> float:
        """请求耗时（秒）"""
        return self._response.elapsed

    def soup(self) -> Selector:
        """
        获取 Selector 对象（兼容原有接口）

        这个方法是保持接口兼容的关键。原代码使用 response.soup()
        获取 BeautifulSoup 对象，现在返回的是 Scrapling Selector。

        Returns:
            Selector: Scrapling Selector 对象

        Selector 功能：
            - CSS 选择器：selector.css('div.class::text')
            - XPath 选择器：selector.xpath('//a[@href]')
            - 文本搜索：selector.find_by_text('关键词')
            - 属性提取：selector.css('a::attr(href)')
            - 相似元素：selector.find_similar()

        使用示例:
            >>> soup = response.soup()
            >>> # 获取文本内容
            >>> title = soup.css('h1::text').get()
            >>> # 获取属性
            >>> href = soup.css('a::attr(href)').get()
            >>> # 获取所有元素
            >>> links = soup.css('a')
            >>> # 链式操作
            >>> content = soup.css('#content').css('p::text').getall()
        """
        if self._selector is None:
            self._selector = self._fetcher.create_selector(self.content)
        return self._selector
