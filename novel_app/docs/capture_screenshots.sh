#!/bin/bash
# Novel Builder 自动化截图脚本

SCREENSHOT_DIR="docs/images"

echo "📱 Novel Builder 截图工具"
echo "================================"

# 检查设备连接
echo "检查设备..."
adb devices | grep -q "device$" || { echo "❌ 错误: 没有检测到安卓设备"; exit 1; }

# 确保目录存在
mkdir -p "$SCREENSHOT_DIR/interfaces"
mkdir -p "$SCREENSHOT_DIR/ai-features"
mkdir -p "$SCREENSHOT_DIR/flow"

echo "✅ 设备已连接"
echo ""

# 函数: 启动应用到主页
start_app() {
    echo "🚀 启动应用..."
    adb shell am start -n com.example.novel_app/.MainActivity
    sleep 3
}

# 函数: 截图
capture() {
    local name=$1
    local path="$SCREENSHOT_DIR/$name"
    adb exec-out screencap -p > "$path"
    echo "📸 已保存: $path"
}

# 函数: 点击屏幕
tap() {
    local x=$1
    local y=$2
    adb shell input tap $x $y
    sleep 1
}

# 函数: 返回键
back() {
    adb shell input keyevent 4
    sleep 1
}

# ========== 核心功能截图 ==========
echo "📸 开始获取核心功能界面截图..."

# 1. 书架界面
echo ""
echo "1️⃣ 书架界面"
start_app
capture "interfaces/bookshelf.png"

# 2. 阅读界面（点击第一本书）
echo ""
echo "2️⃣ 阅读界面"
tap 540 500
sleep 2
capture "interfaces/reader.png"

# 3. 设置界面
echo ""
echo "3️⃣ 设置界面"
back
tap 100 2200
sleep 2
capture "interfaces/settings.png"

echo ""
echo "✅ 核心功能界面截图完成！"
echo ""

# ========== AI功能截图 ==========
echo "🤖 开始获取AI功能界面截图..."
echo "⚠️ 注意: AI功能截图需要手动操作或更复杂的自动化"
echo ""
echo "提示："
echo "  - 进入阅读页面"
echo "  - 长按段落触发菜单"
echo "  - 选择相应AI功能"
echo "  - 运行: adb exec-out screencap -p > docs/images/ai-features/xxx.png"

echo ""
echo "🎉 截图完成！"
echo ""
echo "📂 图片保存在: $SCREENSHOT_DIR"
echo ""
echo "查看截图:"
echo "  - Windows: start $SCREENSHOT_DIR"
echo "  - Linux: xdg-open $SCREENSHOT_DIR"
echo "  - macOS: open $SCREENSHOT_DIR"
