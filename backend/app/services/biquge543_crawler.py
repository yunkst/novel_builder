import logging
import re
import urllib.parse
from typing import Any

from .base_crawler import BaseCrawler, RequestStrategy
from .cache_decorator import cacheable
from .cache_types import CacheType

logger = logging.getLogger(__name__)


class Biquge543Crawler(BaseCrawler):
    """Biquge543 (笔趣阁) 爬虫"""

    def __init__(self):
        super().__init__(
            base_url="https://m.biquge543.com",
            strategy=RequestStrategy.SIMPLE,  # 使用简单策略
        )

        self.custom_headers = {
            "Accept": "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8",
            "Accept-Language": "zh-CN,zh;q=0.9",
            "Accept-Encoding": "",  # 覆盖session的Accept-Encoding以避免压缩
            "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36",
        }

        # 外部搜索服务
        self.search_base_url = "https://www.sososhu.com"

    async def search_novels(self, keyword: str) -> list[dict[str, Any]]:
        """搜索小说 - 此站点禁用搜索功能"""
        # 该站点搜索功能有频率限制，暂不启用
        return []

    @cacheable(
        cache_type=CacheType.CHAPTER_LIST,
        key_params=["novel_url"],
    )
    async def get_chapter_list(
        self, novel_url: str, force_refresh: bool = False
    ) -> list[dict[str, Any]]:
        """获取章节列表 - 支持分页"""
        try:
            # 从 novel_url 提取小说ID
            novel_id_match = re.search(r"/shu/(\d+)/?", novel_url)
            if not novel_id_match:
                return []

            novel_id = novel_id_match.group(1)
            chapters = []
            page_num = 1  # 从第1页开始

            while True:
                # 构建章节列表页面URL
                list_url = f"{self.base_url}/shu/{novel_id}_{page_num}/"

                logger.info(f"[Biquge543] 获取第 {page_num} 页章节列表: {list_url}")

                response = await self.get_page(
                    list_url, custom_headers=self.custom_headers, timeout=30
                )
                if response.status_code != 200:
                    logger.warning(f"[Biquge543] 第 {page_num} 页请求失败: {response.status_code}")
                    break

                soup = response.soup()

                # 查找章节列表 - 使用BeautifulSoup风格的find_all方法
                chapter_links = []

                # 使用find_all查找章节列表区域
                # 从调试结果看，正确的章节列表在 div class=mulu, id=pageinput 或 div class=mululist, id=pageinput 中
                catalog_section = None
                all_divs = soup.find_all("div")
                for div in all_divs:
                    div_class = div.get('class')
                    div_id = div.get('id')
                    # 检查是否是目标元素
                    if div_id == "pageinput" and div_class and ("mulu" in div_class or "mululist" in div_class):
                        catalog_section = div
                        break

                if catalog_section:
                    # 从文章目录区域提取章节链接
                    links_in_catalog = catalog_section.find_all("a", href=True)
                    for link in links_in_catalog:
                        href = link.get('href', '')
                        # 匹配 /chapter/数字ID/数字.html 格式
                        if re.match(rf'^/chapter/{re.escape(novel_id)}/\d+\.html$', href):
                            chapter_links.append(link)
                else:
                    # 如果找不到文章目录区域，回退到原来的方法（匹配整个页面）
                    all_links = soup.find_all("a", href=True)
                    for link in all_links:
                        href = link.get('href', '')
                        # 匹配 /chapter/数字ID/数字.html 格式
                        if re.match(rf'^/chapter/{re.escape(novel_id)}/\d+\.html$', href):
                            chapter_links.append(link)

                if chapter_links:
                    logger.debug(f"[Biquge543] 找到 {len(chapter_links)} 个章节链接")

                logger.info(f"[Biquge543] 第 {page_num} 页找到 {len(chapter_links)} 个章节链接")

                # 如果没有找到章节链接，说明没有更多页面
                if not chapter_links:
                    logger.info(f"[Biquge543] 第 {page_num} 页没有章节，停止")
                    break

                # 检查是否是新章节（用URL去重）
                new_chapters = False
                for link in chapter_links:
                    chapter_title = link.get_text(strip=True)
                    chapter_href = link.get("href")
                    chapter_url = urllib.parse.urljoin(self.base_url, chapter_href)

                    # 用URL去重
                    if not any(ch["url"] == chapter_url for ch in chapters):
                        chapters.append(
                            {
                                "title": chapter_title,
                                "url": chapter_url,
                                "index": len(chapters) + 1,
                            }
                        )
                        new_chapters = True

                logger.debug(f"[Biquge543] 第 {page_num} 页新增 {len([ch for ch in chapters if new_chapters])} 章，总计 {len(chapters)} 章")

                # 如果没有新章节，说明到达最后一页
                if not new_chapters:
                    logger.info(f"[Biquge543] 第 {page_num} 页无新章节，停止")
                    break

                # 检查是否有下一页
                # 注意：Scrapling 的 soup 对象需要使用 text 参数而不是 string
                next_page_link = soup.find("a", text="下一页")
                if not next_page_link:
                    logger.info(f"[Biquge543] 第 {page_num} 页没有下一页链接，停止")
                    break

                page_num += 1

            # 按章节号排序所有章节（确保跨页面的章节顺序正确）
            def get_chapter_num(chapter):
                match = re.search(r'第(\d+)章', chapter['title'])
                return int(match.group(1)) if match else 0

            chapters.sort(key=get_chapter_num)

            # 重新分配索引
            for i, ch in enumerate(chapters, 1):
                ch['index'] = i

            logger.info(f"[Biquge543] 总共获取 {len(chapters)} 章")
            return chapters
        except Exception as e:
            logger.error(f"获取章节列表失败: {e}")
            return []

    @cacheable(
        cache_type=CacheType.CHAPTER_CONTENT,
        key_params=["chapter_url"],
        min_valid_length=300,
    )
    async def get_chapter_content(
        self, chapter_url: str, novel_url: str = "", force_refresh: bool = False
    ) -> dict[str, Any]:
        """获取章节内容"""
        try:
            response = await self.get_page(
                chapter_url, custom_headers=self.custom_headers, timeout=30
            )
            if response.status_code != 200:
                return {"title": "", "content": ""}

            soup = response.soup()

            # 提取章节标题
            title_elem = soup.find("h1")
            title = title_elem.get_text(strip=True) if title_elem else ""

            # 提取章节内容
            content = self._extract_chapter_content(soup)

            return {"title": title, "content": content}
        except Exception as e:
            logger.error(f"获取章节内容失败: {e}")
            return {"title": "", "content": ""}

    def _extract_chapter_content(self, soup) -> str:
        """提取章节内容的辅助方法"""
        content = ""

        # 针对biquge543的特殊处理：id="neirong"
        content_div = soup.find("div", id="neirong")

        if content_div:
            # 直接获取文本内容，不复制div（Scrapling不支持复制）
            # 提取文本内容
            text = content_div.get_text("\n", strip=True)

            # 清理广告和无关文本
            if text:
                lines = text.split("\n")
                cleaned_lines = []
                for line in lines:
                    line = line.strip()
                    # 跳过广告和无关文本
                    if line and len(line) > 10 and not any(
                        ad_word in line
                        for ad_word in [
                            "一秒记住",
                            "biquge",
                            "笔趣阁",
                            "更新快",
                            "无弹窗",
                            "本章完",
                            "下载APP",
                            "免登陆",
                            "章节报错",
                            "本站所有小说",
                            "转载而来",
                            "宣传本书",
                            "请选择错误类型",
                            "更新太慢",
                            "缺少章节",
                            "章节内容错误",
                            "验证码",
                            "提交关闭",
                        ]
                    ):
                        cleaned_lines.append(line)

                content = "\n\n".join(cleaned_lines)
                content = content.strip()

        return content

    async def get_novel_info(self, novel_url: str) -> dict[str, Any]:
        """获取小说详细信息和章节列表"""
        try:
            response = await self.get_page(
                novel_url, custom_headers=self.custom_headers, timeout=30
            )
            if response.status_code != 200:
                return {
                    "title": "未知小说",
                    "author": "未知作者",
                    "url": novel_url,
                    "cover_url": "",
                    "description": "",
                    "chapters": [],
                }

            soup = response.soup()

            # 提取小说基本信息
            title = self._extract_novel_title(soup)
            author = self._extract_novel_author(soup)
            cover_url = self._extract_novel_cover(soup)
            description = self._extract_novel_description(soup)

            # 获取章节列表

            chapters = await self.get_chapter_list(novel_url)

            return {
                "title": title,
                "author": author,
                "url": novel_url,
                "cover_url": cover_url,
                "description": description,
                "chapters": chapters,
            }
        except Exception as e:
            logger.error(f"获取小说信息失败: {e}")
            return {
                "title": "未知小说",
                "author": "未知作者",
                "url": novel_url,
                "cover_url": "",
                "description": "",
                "chapters": [],
            }

    def _extract_novel_title(self, soup) -> str:
        """提取小说标题"""
        title_elem = soup.find("h1")
        if title_elem:
            title = title_elem.get_text(strip=True)
            if title:
                # 清理标题中的网站名称等后缀
                title = re.sub(r"_.*$", "", title).strip()
                title = re.sub(r"-.*$", "", title).strip()
                return title
        return "未知小说"

    def _extract_novel_author(self, soup) -> str:
        """提取小说作者"""
        # 尝试查找作者信息
        text = soup.get_text()

        # 尝试查找"作者：XXX"或"作者:XXX"格式
        author_match = re.search(r"作者[：:]\s*([^\s\n\r<>/]+)", text)
        if author_match:
            return author_match.group(1).strip()

        # 查找"作者：XXX"格式（带中文标点）
        author_match = re.search(r"作者[：]\s*([^\s\n\r<>/]+)", text)
        if author_match:
            return author_match.group(1).strip()

        # 尝试从列表项中提取
        list_items = soup.find_all("li")
        for item in list_items:
            text = item.get_text()
            if "作者" in text:
                author = text.replace("作者：", "").replace("作者:", "").strip()
                if author and len(author) < 20:
                    return author

        return "未知作者"

    def _extract_novel_cover(self, soup) -> str:
        """提取小说封面URL"""
        # 查找图片
        all_imgs = soup.find_all("img")
        for img in all_imgs:
            src = img.get("src", "") or img.get("data-src", "")
            if src and any(ext in src.lower() for ext in [".jpg", ".jpeg", ".png", ".webp"]):
                # 转换为绝对URL
                if src.startswith("/"):
                    return urllib.parse.urljoin(self.base_url, src)
                elif src.startswith("http"):
                    return src
        return ""

    def _extract_novel_description(self, soup) -> str:
        """提取小说简介"""
        # 尝试查找简介区域 - 使用 CSS 选择器
        desc_selectors = [
            "div.intro",
            "div.description",
            "p.intro",
        ]

        for selector in desc_selectors:
            desc_elem = soup.select_one(selector)
            if desc_elem:
                desc = desc_elem.get_text().strip()
                if desc and len(desc) > 10:
                    return desc[:500]

        # 尝试查找 h2 标题后的 p 元素
        intro_heading = soup.find("h2")
        if intro_heading:
            text = intro_heading.get_text(strip=True)
            if any(keyword in text for keyword in ["文章简介", "简介", "作品介绍"]):
                # 尝试使用 CSS 选择器查找父元素中的 p
                parent = intro_heading
                # 查找所有 p 标签
                all_p = soup.find_all("p")
                for p in all_p:
                    p_text = p.get_text(strip=True)
                    if p_text and len(p_text) > 10 and "简介" not in p_text:
                        return p_text[:500]

        return ""


# 向后兼容别名
Biquge543CrawlerRefactored = Biquge543Crawler
