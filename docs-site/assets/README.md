# 预览素材目录

把录屏 / 截图放到这里，文件名与 `index.html` 中预览卡片的 `data-video` / `data-img` 对应即可，
页面会自动按 **录屏 → 截图 → 占位** 的顺序降级显示。

## 文件名约定（4 个预览位）

| 预览位 | 录屏（优先） | 截图（兜底） |
|--------|--------------|--------------|
| 书架主页 | `demo-bookshelf.mp4` | `demo-bookshelf.png` |
| 阅读界面 | `demo-reader.mp4` | `demo-reader.png` |
| AI 对话  | `demo-agent.mp4` | `demo-agent.png` |
| 角色关系图 | `demo-relation.mp4` | `demo-relation.png` |

> 只放截图也行：页面检测到没有 `.mp4` 就直接用 `.png`。
> 两个都没有则显示带说明的占位框，不影响发布。

## 录屏建议

- 格式：H.264 / MP4，**无声轨**（页面静音循环播放）
- 时长：5–10 秒，能完整展示一次操作动作为佳
- 比例：横屏 **16:10** 最佳（与卡片比例一致，不裁切）
- 录制：Android 用系统录屏 / `scrcpy`；Windows 用 `Win+G` 或 OBS
