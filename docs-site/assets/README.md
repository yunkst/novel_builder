# docs-site 静态素材目录

放 `index.html` 引用的静态资源：封面、社交分享卡、favicon 等。

## 当前需要

| 用途 | 文件名 | 建议尺寸 | 说明 |
|------|--------|----------|------|
| OG 分享卡 | `og-cover.png` | 1200×630 | 链接分享到微信/Twitter 时显示的缩略图，含 APP 名 + slogan + 一张代表图 |
| Favicon | `favicon.png` | 32×32 / 192×192 | 浏览器标签页图标，可只放一份多尺寸 |

> 放入文件后，`index.html` 的 `<head>` 需要补 og 标签 + favicon 引用。
> 当前 head 还没有这两段，等素材备齐再加。