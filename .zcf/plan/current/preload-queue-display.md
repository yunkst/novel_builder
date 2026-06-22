# 预加载队列展示页改造

## 任务
1. 点击统计卡片切换队列信息展示（6 张卡可点，选中态高亮，下方详情面板按选中索引切换）
2. 队列展示章节标题（小说标题+第N章），不再显示 URL

## 方案
方案 A：选中态切换详情面板

## 改动文件
1. `lib/services/preload_progress_update.dart` - 新增 novelTitle/chapterIndex
2. `lib/services/preload_history_entry.dart` - 新增历史记录模型
3. `lib/services/preload_service.dart` - 数据层扩展
4. `lib/screens/preload_queue_debug_screen.dart` - UI 重写
5. 测试文件适配

## 执行步骤
1-10 见计划详情
