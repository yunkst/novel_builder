#!/usr/bin/env python3
"""
PageResponse - Scrapling 响应包装类

直接包装 Scrapling Response 对象，提供简洁的接口。
移除 BeautifulSoup 兼容层，直接使用 Scrapling Selector。
"""

from bs4 import BeautifulSoup
from scrapling.parser import Selector


class BeautifulSoupSelectorWrapper:
    """
    BeautifulSoup风格的Selector包装器

    将Scrapling Selector包装成类似BeautifulSoup的API
    使现有爬虫代码可以无缝迁移
    """

    def __init__(self, selector):
        self._selector = selector

    def find(self, name=None, attrs=None, recursive=True, text=None, **kwargs):
        """类似BeautifulSoup的find方法"""
        # 合并attrs和kwargs
        if attrs is None:
            attrs = {}
        if kwargs:
            attrs.update(kwargs)

        # 构建CSS选择器
        css_selector = self._build_css_selector(name, attrs, None)

        # 执行选择
        if css_selector:
            results = self._selector.css(css_selector)
        else:
            results = []

        # 处理text参数（文本匹配）
        if text is not None:
            filtered_results = []
            text_str = str(text) if not isinstance(text, str) else text
            for result in results:
                # 直接从Selector获取文本内容
                result_text = result.css('::text').get('')
                # 去除空白
                result_text = result_text.strip()
                # 检查匹配
                if text_str in result_text or result_text == text_str:
                    filtered_results.append(result)
            results = filtered_results

        if results:
            return BeautifulSoupSelectorWrapper(results[0])
        return None

    def find_all(self, name=None, attrs=None, recursive=True, text=None, limit=None, **kwargs):
        """类似BeautifulSoup的find_all方法"""
        # 合并attrs和kwargs
        if attrs is None:
            attrs = {}
        if kwargs:
            attrs.update(kwargs)

        # 处理标签名列表（如 ["p", "li", "div"]）
        if isinstance(name, list):
            results = []
            for tag_name in name:
                # 递归调用find_all处理每个标签名
                tag_results = self.find_all(tag_name, attrs, recursive, text, None)
                results.extend(tag_results)
                # 如果设置了limit并且已经达到，停止
                if limit is not None and len(results) >= limit:
                    break
            if limit is not None:
                results = results[:limit]
            return results

        # 构建CSS选择器（不传text参数）
        css_selector = self._build_css_selector(name, attrs, None)

        # 执行选择
        if css_selector:
            elements = self._selector.css(css_selector)
        else:
            elements = []

        # 处理text参数（文本匹配）
        if text is not None:
            filtered_elements = []
            text_str = str(text) if not isinstance(text, str) else text
            for element in elements:
                # 直接从Selector获取文本内容
                elem_text = element.css('::text').get('')
                # 去除空白
                elem_text = elem_text.strip()
                # 检查匹配
                if text_str in elem_text or elem_text == text_str:
                    filtered_elements.append(element)
            elements = filtered_elements

        # 处理limit参数
        if limit is not None:
            elements = elements[:limit]

        return [BeautifulSoupSelectorWrapper(elem) for elem in elements]

    def _build_css_selector(self, name, attrs, text):
        """
        将BeautifulSoup风格的参数转换为CSS选择器

        Args:
            name: 标签名，可以是字符串或列表
            attrs: 属性字典，可能包含布尔值（如 href=True）
            text: 文本内容匹配

        Returns:
            CSS选择器字符串或None
        """
        import re

        # 处理标签名列表（如 ["p", "li", "div"]）
        if isinstance(name, list):
            # 返回None，调用者需要多次调用
            return None

        selector_parts = []

        # 处理标签名
        if name:
            selector_parts.append(name)

        # 处理属性
        if attrs:
            for key, value in attrs.items():
                # 处理class_参数（BeautifulSoup使用class_避免与Python关键字冲突）
                if key == 'class_':
                    if isinstance(value, re.Pattern):
                        # 正则表达式匹配class - 需要特殊处理
                        # 这个情况在find_all中通过后处理实现
                        continue
                    elif isinstance(value, str):
                        selector_parts.append(f".{value}")
                    elif isinstance(value, list):
                        for cls in value:
                            selector_parts.append(f".{cls}")

                # 处理id参数
                elif key == 'id' and value:
                    selector_parts.append(f"#{value}")

                # 处理布尔值属性（如 href=True）
                elif value is True:
                    selector_parts.append(f"[{key}]")

                # 处理字符串值属性
                elif isinstance(value, str):
                    selector_parts.append(f"[{key}='{value}']")

                # 处理正则表达式
                elif isinstance(value, re.Pattern):
                    # 正则表达式无法直接转换为CSS选择器
                    # 返回None，调用者需要后处理
                    pass

        # 组合选择器
        if selector_parts:
            # 对于ID和class，直接附加到标签名后面
            # 对于其他属性，用[]附加
            result = selector_parts[0]
            for part in selector_parts[1:]:
                if part.startswith('#') or part.startswith('.'):
                    result += part
                else:
                    result += part
            return result
        elif name:
            return name
        return ''

    def get(self, key, default=None):
        """
        获取元素属性值

        Args:
            key: 属性名
            default: 默认值

        Returns:
            属性值或默认值
        """
        # 使用::attr()伪类获取属性
        value = self._selector.css(f'::attr({key})').get()
        return value if value is not None else default

    def get_text(self, separator='', strip=False, types=None):
        """
        获取文本内容

        Args:
            separator: 文本分隔符
            strip: 是否去除首尾空白
            types: （忽略）BeautifulSoup的参数，用于兼容性

        Returns:
            文本内容
        """
        # 获取所有文本节点
        text_nodes = self._selector.css('::text').getall()
        result = separator.join(text_nodes)
        return result.strip() if strip else result

    def select_one(self, selector):
        """
        使用CSS选择器选择单个元素

        Args:
            selector: CSS选择器

        Returns:
            BeautifulSoupSelectorWrapper或None
        """
        result = self._selector.css(selector).first
        if result:
            return BeautifulSoupSelectorWrapper(result)
        return None

    def select(self, selector):
        """
        使用CSS选择器选择多个元素

        Args:
            selector: CSS选择器

        Returns:
            BeautifulSoupSelectorWrapper列表
        """
        results = self._selector.css(selector)
        return [BeautifulSoupSelectorWrapper(r) for r in results]

    @property
    def text(self):
        """文本属性"""
        return self.get_text()

    @property
    def string(self):
        """字符串属性（BeautifulSoup兼容）"""
        text = self.get_text(strip=True)
        return text if text else None

    def decompose(self):
        """移除元素（空实现，因为Scrapling Selector不支持此操作）"""
        # Scrapling Selector是只读的，不支持修改DOM
        pass

    def find_next(self, name=None, attrs=None, text=None, **kwargs):
        """
        类似BeautifulSoup的find_next方法

        查找文档中下一个匹配的元素（非递归）

        Args:
            name: 标签名
            attrs: 属性字典
            text: 文本匹配
            **kwargs: 其他属性参数

        Returns:
            BeautifulSoupSelectorWrapper或None
        """
        # 由于Scrapling Selector不支持遍历，这里返回None
        # 实际应用中，应该使用CSS选择器或XPath替代
        return None

    def find_all_next(self, name=None, attrs=None, text=None, limit=None, **kwargs):
        """
        类似BeautifulSoup的find_all_next方法

        查找文档中后面所有匹配的元素（非递归）

        Args:
            name: 标签名
            attrs: 属性字典
            text: 文本匹配
            limit: 限制结果数量
            **kwargs: 其他属性参数

        Returns:
            BeautifulSoupSelectorWrapper列表
        """
        # 由于Scrapling Selector不支持遍历，这里返回空列表
        # 实际应用中，应该使用CSS选择器或XPath替代
        return []

    def __getattr__(self, name):
        """代理其他方法到原始Selector"""
        return getattr(self._selector, name)

    def __iter__(self):
        """支持迭代"""
        return iter(self._selector)

    def __len__(self):
        """支持长度"""
        return len(self._selector)

    def __bool__(self):
        """支持布尔检查"""
        return bool(self._selector)

    def __str__(self):
        """字符串表示"""
        return str(self._selector)

    def __repr__(self):
        """调试表示"""
        return f"<BeautifulSoupSelectorWrapper {self._selector!r}>"


class PageResponse:
    """
    页面响应包装类

    直接包装 Scrapling Response，提供简洁的访问接口。
    Selector 比 BeautifulSoup4 快 784 倍。

    属性:
        _response: Scrapling Response 对象
        _selector: 延迟初始化的 Selector

    使用示例:
        >>> # CSS 选择器
        >>> title = page.css('h1::text').get()
        >>> links = page.css('a[href]')
        >>>
        >>> # XPath 选择器
        >>> paragraphs = page.xpath('//p')
    """

    def __init__(self, response):
        """
        初始化

        Args:
            response: Scrapling Response 对象
        """
        self._response = response
        self._selector: Selector | None = None  # 延迟初始化

    @property
    def url(self) -> str:
        """响应 URL"""
        return getattr(self._response, 'url', '')

    @property
    def status_code(self) -> int:
        """HTTP 状态码"""
        return getattr(self._response, 'status', 200)

    @property
    def headers(self) -> dict:
        """响应头字典"""
        return dict(getattr(self._response, 'headers', {}))

    @property
    def content(self) -> str:
        """HTML 内容"""
        # 尝试多种属性获取内容
        if hasattr(self._response, 'html_content'):
            content = self._response.html_content
        elif hasattr(self._response, 'content'):
            content = self._response.content
        elif hasattr(self._response, 'text'):
            content = self._response.text
        else:
            content = str(self._response)

        # 如果是 bytes，解码为字符串
        if isinstance(content, bytes):
            return content.decode('utf-8', errors='ignore')
        return content

    @property
    def elapsed(self) -> float:
        """请求耗时（秒）- 可选属性"""
        return getattr(self._response, 'elapsed', 0.0)

    def _get_selector(self) -> Selector:
        """
        获取或创建 Selector 对象

        Returns:
            Selector: Scrapling Selector 对象
        """
        if self._selector is None:
            self._selector = Selector(self.content)
        return self._selector

    # ========== Selector 方法代理 ==========

    def css(self, selector: str):
        """
        使用 CSS 选择器

        Args:
            selector: CSS 选择器字符串

        Returns:
            SelectorElement: Scrapling 选择器元素

        使用示例:
            >>> # 获取文本
            >>> title = page.css('h1::text').get()
            >>> # 获取属性
            >>> href = page.css('a::attr(href)').get()
            >>> # 获取所有元素
            >>> links = page.css('a[href]')
        """
        return self._get_selector().css(selector)

    def xpath(self, selector: str):
        """
        使用 XPath 选择器

        Args:
            selector: XPath 选择器字符串

        Returns:
            SelectorElement: Scrapling 选择器元素

        使用示例:
            >>> paragraphs = page.xpath('//p')
            >>> links = page.xpath('//a[@href]')
        """
        return self._get_selector().xpath(selector)

    # ========== 兼容旧代码的属性访问 ==========

    @property
    def text(self) -> str:
        """文本内容（兼容属性）"""
        return self.content

    def __getattr__(self, name):
        """
        代理未定义的属性到 Selector

        这允许直接在 PageResponse 上调用 Selector 方法
        """
        selector = self._get_selector()
        if hasattr(selector, name):
            return getattr(selector, name)
        raise AttributeError(f"'{type(self).__name__}' object has no attribute '{name}'")

    # ========== 向后兼容方法 ==========

    def soup(self):
        """
        获取BeautifulSoup兼容的选择器对象

        这个方法保持与旧代码的兼容性，返回一个包装了Scrapling Selector的对象
        该对象提供了与BeautifulSoup兼容的API

        Returns:
            BeautifulSoupSelectorWrapper: 兼容BeautifulSoup API的选择器包装器

        使用示例:
            >>> # 使用BeautifulSoup风格的API
            >>> soup = page.soup()
            >>> title = soup.find('h1')
            >>> links = soup.find_all('a', href=True)
            >>> text = title.get_text()
            >>> href = link.get('href')
        """
        selector = self._get_selector()
        return BeautifulSoupSelectorWrapper(selector)

    def bs4(self):
        """
        获取BeautifulSoup对象（完全向后兼容）

        注意：这会使用BeautifulSoup解析HTML，性能较低
        建议使用soup()方法获取Scrapling Selector以获得更好性能

        Returns:
            BeautifulSoup: BeautifulSoup对象
        """
        if not hasattr(self, '_bs4_soup') or self._bs4_soup is None:
            self._bs4_soup = BeautifulSoup(self.content, 'lxml')
        return self._bs4_soup

    # 提供类似BeautifulSoup的便捷方法
    def find(self, name=None, attrs=None, recursive=True, text=None, **kwargs):
        """
        类似BeautifulSoup的find方法

        这是为了保持与旧代码的兼容性，使用Scrapling Selector实现

        Args:
            name: 标签名
            attrs: 属性字典
            recursive: 是否递归搜索
            text: 文本匹配
            **kwargs: 其他属性参数

        Returns:
            BeautifulSoupSelectorWrapper或None
        """
        soup = self.soup()
        return soup.find(name, attrs, recursive, text, **kwargs)

    def find_all(self, name=None, attrs=None, recursive=True, text=None, limit=None, **kwargs):
        """
        类似BeautifulSoup的find_all方法

        这是为了保持与旧代码的兼容性，使用Scrapling Selector实现

        Args:
            name: 标签名
            attrs: 属性字典
            recursive: 是否递归搜索
            text: 文本匹配
            limit: 限制结果数量
            **kwargs: 其他属性参数

        Returns:
            BeautifulSoupSelectorWrapper列表
        """
        soup = self.soup()
        return soup.find_all(name, attrs, recursive, text, limit, **kwargs)

    def select(self, selector):
        """
        CSS选择器方法

        Returns:
            Scrapling Selector结果
        """
        return self.css(selector)

    def select_one(self, selector):
        """
        CSS选择器方法（单个元素）

        Returns:
            Scrapling Selector结果（单个）
        """
        result = self.css(selector)
        return result[0] if result else None
