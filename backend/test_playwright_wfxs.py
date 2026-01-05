#!/usr/bin/env python3
"""
测试 Playwright 访问 wfxs.tw 的能力
"""

import asyncio
from playwright.async_api import async_playwright
from bs4 import BeautifulSoup


async def test_wfxs_access():
    """测试访问 wfxs.tw 站点"""

    test_url = "https://m.wfxs.tw/xiaoshuo/7840069/82012408/"

    print(f"正在测试访问: {test_url}")
    print("=" * 60)

    try:
        async with async_playwright() as p:
            print("✓ 启动 Playwright")

            # 启动浏览器
            browser = await p.chromium.launch(
                headless=True,
                args=[
                    "--no-sandbox",
                    "--disable-dev-shm-usage",
                    "--disable-blink-features=AutomationControlled",
                ]
            )
            print("✓ 浏览器启动成功")

            # 创建上下文
            context = await browser.new_context(
                user_agent="Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36",
                viewport={"width": 1920, "height": 1080},
                locale="zh-TW",
            )
            print("✓ 浏览器上下文创建成功")

            # 创建页面
            page = await context.new_page()
            page.set_default_timeout(15000)
            print("✓ 页面创建成功")

            # 访问目标URL
            print(f"\n正在访问: {test_url}")
            response = await page.goto(test_url, timeout=15000)

            if response.ok:
                print(f"✓ HTTP 状态码: {response.status}")
                print(f"✓ 页面加载成功")

                # 获取页面内容
                content = await page.content()
                print(f"✓ 内容长度: {len(content)} 字符")

                # 使用 BeautifulSoup 解析
                soup = BeautifulSoup(content, 'lxml')

                # 提取标题
                title_elem = soup.select_one('article h1') or soup.select_one('h1')
                title = title_elem.get_text(strip=True) if title_elem else '未找到标题'
                print(f"\n章节标题: {title}")

                # 提取正文内容
                article = soup.select_one('article')
                if article:
                    paragraphs = article.select('p')
                    content_parts = []

                    for i, p in enumerate(paragraphs[:10]):  # 只显示前10段
                        text = p.get_text(strip=True)
                        if text:
                            content_parts.append(text)
                            if i == 0:
                                print(f"\n正文预览 (前10段):")
                                print(f"  {text}")

                    print(f"\n✓ 成功提取 {len(paragraphs)} 个段落")
                    print(f"✓ 总内容长度: {sum(len(p.get_text(strip=True)) for p in paragraphs)} 字符")

                    # 检查是否有分页
                    next_page_link = soup.find('a', string=lambda text: text and '下一頁' in text)
                    if next_page_link:
                        print(f"\n⚠ 发现分页链接: {next_page_link.get('href', 'N/A')}")
                    else:
                        print(f"\n✓ 无分页")

                else:
                    print("❌ 未找到 article 标签")

                await browser.close()
                print("\n" + "=" * 60)
                print("✓ 测试成功！Playwright 可以正常访问 wfxs.tw")

            else:
                print(f"❌ HTTP 错误: {response.status}")
                await browser.close()
                return False

    except Exception as e:
        print(f"\n❌ 测试失败: {e}")
        import traceback
        traceback.print_exc()
        return False

    return True


if __name__ == "__main__":
    asyncio.run(test_wfxs_access())
