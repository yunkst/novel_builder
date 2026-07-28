# GitHub Star 引导功能 · 手动验收清单

**日期**: 2026-07-28
**功能范围**: StarPromptService + StarPromptDialog + main.dart 启动挂钩 + 设置页常驻入口
**实现 commits**: `ee0cd9b..ebea148`（7 task: d6d29c5 / 8986181 / a3eaa42 / 8a14c94 / 6259af3 / ebea148 + 本清单）

---

## 0. 自动化测试基线（已通过）

- `flutter analyze`：2 info（预存 PoC 遗留 main_ppocr_demo / main_pua_ocr_diag，与本功能无关），本功能 7 文件 0 issue
- `flutter test test/unit/services/star_prompt_service_test.dart`：9 测试 GREEN
- `flutter test test/unit/widgets/star_prompt_dialog_test.dart`：2 widget 测试 GREEN
- 合计 **11 测试全过**

---

## 1. 全新安装路径

| # | 操作 | 预期 | 结果 |
|---|---|---|---|
| 1.1 | 全新安装（卸载重装或清数据）后启动 App | 不弹 star 弹窗（count=1，未达 7） | ☐ |
| 1.2 | 重启 6 次（每次退出再开，count 累加到 6，仍不足 3 天） | 第 6 次启动不弹 | ☐ |
| 1.3 | 改系统时间到 4 天后，重启 App（count=7 + install 满 3 天 + 无 dismiss + 无 next_show） | 弹出 star 弹窗 | ☐ |
| 1.4 | 弹窗文案含「开源」「Star」「GitHub」字样 | 全部命中 | ☐ |
| 1.5 | 弹窗有两个按钮：「去 GitHub 点 Star」+「关闭」 | 2 个 | ☐ |

## 2. 主按钮路径

| # | 操作 | 预期 | 结果 |
|---|---|---|---|
| 2.1 | 点「去 GitHub 点 Star」 | 跳转到 https://github.com/yunkst/novel_builder，弹窗关闭 | ☐ |
| 2.2 | 主按钮点过后再重启 App | 不再弹（永久关闭） | ☐ |
| 2.3 | 检查 SharedPreferences（adb shell 或 debug 入口） | `star_prompt_dismissed = true` | ☐ |

## 3. 关闭路径

| # | 操作 | 预期 | 结果 |
|---|---|---|---|
| 3.1 | 满足门槛时点「关闭」 | 弹窗关闭，不跳转 | ☐ |
| 3.2 | 立即重启 App | 不弹（冷却期内） | ☐ |
| 3.3 | 改系统时间到 7 天后，重启 App（4 门槛全满足） | 再次弹窗 | ☐ |
| 3.4 | 检查 SharedPreferences | `star_prompt_next_show_time ≈ now + 7 天` | ☐ |

## 4. 设置页常驻入口

| # | 操作 | 预期 | 结果 |
|---|---|---|---|
| 4.1 | 打开设置页，滚到最末「支持项目」段 | 看到「支持项目 · 去 GitHub 点 Star」ListTile | ☐ |
| 4.2 | ListTile leading 是 `Icons.star_outline` 图标（琥珀色） | 星星轮廓 | ☐ |
| 4.3 | ListTile trailing 是 `Icons.open_in_new` 图标 | 外部链接图标 | ☐ |
| 4.4 | 点击该 ListTile | 跳转到 https://github.com/yunkst/novel_builder | ☐ |
| 4.5 | 即使点过主按钮（永久关闭弹窗），该入口仍在 | 可用 | ☐ |

## 5. 边界与异常

| # | 操作 | 预期 | 结果 |
|---|---|---|---|
| 5.1 | 卸载重装清数据 | 4 个 key 全部清空，install_time 重新记录 | ☐ |
| 5.2 | 关闭网络后启动 App（满足门槛） | 弹窗正常显示（外链跳转会失败被 catch） | ☐ |
| 5.3 | 同时存在 native crash dump | crash 弹窗优先弹出，关闭后才弹 star 弹窗（或不弹） | ☐ |
| 5.4 | launchUrl 失败（无浏览器等异常） | 弹窗已关闭、状态已写，App 不崩 | ☐ |

---

**验收人**: _______________
**日期**: _______________
**结果**: ☐ 全部通过 / ☐ 有项未通过（请注明）
