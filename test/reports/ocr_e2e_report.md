# OCR 提取器端到端验证报告

> 本报告由 Task 17 文档子任务创建为模板。实际验证项数据由 main session 在 Android 设备上跑通后填入。

- **创建日期**: 2026-07-15
- **关联计划**: `docs/superpowers/plans/2026-07-15-agent-ocr-extractor.md`
- **关联 PoC**: `novel_app/lib/main_ppocr_demo.dart`（已标注产品化替代）
- **产品路径**: `novel_app/lib/services/ocr_restore_service.dart`、`novel_app/lib/poc/ocr_predictor.dart`

## 验证场景

番茄小说字体反爬章节端到端提取与还原。

- 测试 URL: `https://fanqienovel.com/reader/7069991698582995470`
- 真值参照: `fanqie-evidence/chapter_restored.txt`（PC PoC 产物）

## 验证项清单

| # | 验证项 | 状态 | 备注 |
|---|--------|------|------|
| 1 | 番茄真实章节加载 | 待手工验证 | main session 在 Android 设备跑 |
| 2 | 字符符合率 ≥ 95% | 待手工验证 | 与 biquge55 真值对比 |
| 3 | 性能 profile（单章 OCR 还原 < 90s） | 待手工验证 | 目标 < 90s |
| 4 | 故意写错 JS 诊断闭环 | 待手工验证 | 漏返回 font_family 触发 success:false |

## 验证步骤详情

### 1. 番茄真实章节加载

**状态**: 待手工验证

**验证步骤**:
1. 启动 app（`flutter run -d <android_device>`）
2. 进入 Agent WebView 提取场景，URL 填 `https://fanqienovel.com/reader/7069991698582995470`
3. 观察 agent 流程：execute_js 探测 → 检测到 PUA → 两次 save_script（list + content，ocr=true）
4. 验证 save_script 返回 `success: true` + `restored_sample` 含可读中文
5. 进入阅读器加载该章节，确认正文 PUA 被还原为可读文字

**预期结果**:
- agent 自动识别 PUA 字体反爬
- save_script 返回 success，`restored_sample` 为可读中文（非 PUA 占位符）
- 阅读器正文显示正常中文

**实际结果**:

_(待 main session 填入)_

---

### 2. 字符符合率（与 biquge55 真值对比）

**状态**: 待手工验证

**验证步骤**:
1. 取上一步还原的章节正文
2. 与 `fanqie-evidence/chapter_restored.txt`（PC PoC 产物）逐字符对比
3. 计算符合率 = 相同字符数 / 总字符数

**预期结果**: 符合率 ≥ 95%

**实际结果**:

- 还原字符数: _(待填)_
- 真值字符数: _(待填)_
- 相同字符数: _(待填)_
- 符合率: _(待填)_

---

### 3. 性能 profile（单章 OCR 还原时间）

**状态**: 待手工验证

**验证步骤**:
1. 在 agent 调用 save_script 时记录开始时间戳
2. save_script 返回（含 OCR 还原）记录结束时间戳
3. 单章总耗时 = 结束 - 开始
4. （可选）拆分：字体下载 / canvas 渲染 / ONNX 推理 / 映射替换 各阶段耗时

**预期结果**: 单章 OCR 还原时间 < 90s

**实际结果**:

- 总耗时: _(待填)_ s
- 字体下载: _(待填)_ s
- canvas 渲染: _(待填)_ s
- ONNX 推理: _(待填)_ s
- 映射替换: _(待填)_ s

---

### 4. 故意写错 JS 诊断闭环

**状态**: 待手工验证

**验证步骤**:
1. 在 agent 写 chapter_content_js 时故意漏返回 `font_family` 字段
2. 调用 save_script 保存该脚本
3. 观察 save_script 返回值
4. agent 收到失败信号后修 JS 补回 font_family 重试

**预期结果**:
- 第一次 save_script 返回 `success: false, reason: font_family_missing`
- agent 诊断信号清晰（reason 字段可读）
- 修正后重试 save_script 返回 `success: true`

**实际结果**:

- 第一次返回: _(待填)_
- 诊断信号是否清晰: _(待填)_
- 修正后重试结果: _(待填)_

---

## 结论

_(待 main session 全部验证完成后填入总结)_

## 失败/阻塞记录

_(如有失败项，记录现象 + 复现步骤 + 初步归因)_
