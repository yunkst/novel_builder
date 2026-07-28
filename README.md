<div align="center">

# 随心阅读
### Novel Builder · AI 原生小说阅读平台

**读喜欢的 · 改不爽的 · 写自己的**

[⬇️ 下载 APK](https://github.com/yunkst/novel_builder/releases/latest)  ·  [🌐 在线介绍](https://yunkst.github.io/novel_builder/)  ·  [⭐ 给个 Star](https://github.com/yunkst/novel_builder)

本地书架 · 任意网站阅读 · 离线缓存 · AI 改写 · AI 创作

</div>

---

## 📖 读 · APP 里就能逛任意小说站

打开 APP 就有一个**内置浏览器**。用它打开任意小说站，翻到目录页，右下角会浮出「加入书架」按钮——点一下就进书架了。

- 🌍 **任意站点都能加**：第一次访问某个站时，**AI 现场帮你生成提取脚本**（你要做的只是等一下、确认预览），之后这个站就一劳永逸——下次直接用，不用再生成
- 📖 **干净的正文**：从原页提取正文文本，正文里那些弹窗广告、"请下载 APP 继续"、推广链接，通通没有
- 💾 **看过的章节自动存本地**：断网、飞机上、地铁里，照样翻回去重读；还会偷偷预加载下一章，翻页时不卡
- 🔤 **字体反爬也能读**（番茄这类把字做成乱码的站）：端侧 OCR 自动把乱码还原成正常汉字，不用你管
- 🔎 **书内找东西**：在已缓存章节里搜关键词，按上下文定位；也能让 AI 帮你搜"某个道具第一次出现在第几章"

<details>
<summary>🔧 技术细节（给开发者审阅真实性）</summary>

- **加书流程**：内置浏览器打开站点 → 目录页 FAB 浮出（条件 = 当前 URL 是 http(s)）→ 该域名有 `chapter_list_js` 脚本则直接执行；**无脚本则走 webview_extract 场景 agent 现场生成脚本**（`save_script` 工具），生成后落库，下次复用（`webview_add_novel_button.dart` + `webview_extract_scenario.dart`）
- **正文提取**：`HeadlessWebViewContentService.fetchContent`，前台 high 优先级可抢占后台 low 预加载，HeadlessInAppWebView 单例 + 互斥锁
- **预加载**：`PreloadService` 当前章渲染后入队后续章，FIFO + 30s/任务速率限制，命中缓存 reset
- **OCR 还原**：`site_scripts.chapter_content_ocr` 列标 true → `OcrRestoreService.restorePuaInText` → 端侧 PP-OCRv6（onnxruntime）把 PUA 码点渲染成图再识别
- **搜索双入口**：UI 走 `chapter_search_screen.dart`（已缓存章节全文）；Agent 走 `search_in_chapters` 工具（返回 ~80 字上下文片段）
- **用户章节保护**：`is_user_inserted=1` 章节不被自动更新覆盖

</details>

<!-- ===== Task 3-6 段落占位 ===== -->

---

## 📄 许可证

本项目采用 [MIT 许可证](LICENSE)。
