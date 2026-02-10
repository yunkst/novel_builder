#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Flutter App Architecture Diagram Generator
创建博物馆级技术架构图 - 建筑制图美学风格
"""

import sys
import io

# 设置标准输出为UTF-8编码
if sys.platform == 'win32':
    sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8')

from PIL import Image, ImageDraw, ImageFont
import os

# 配置
OUTPUT_DIR = "D:/myspace/novel_builder/diagrams"
os.makedirs(OUTPUT_DIR, exist_ok=True)

# 图纸尺寸 (16:9 横向, 高分辨率)
WIDTH = 3840
HEIGHT = 2160
MARGIN = 120

# 颜色方案 - 建筑制图美学
COLORS = {
    'background': '#1A1A1A',          # 深色背景
    'foundation': '#2C2C2C',          # 基础层
    'layer2': '#3A4A5A',              # 中间层底色
    'steel_blue': '#4A6B8A',          # 钢蓝色 - 主要组件
    'titanium': '#6B7B8B',            # 钛色 - 次要组件
    'line_light': '#E8E8E8',          # 浅色线条
    'line_dim': '#6B6B6B',            # 暗色线条
    'accent_red': '#FF4444',          # 关键错误
    'accent_amber': '#FFC107',        # 回归问题
    'accent_blue': '#4FC3F7',         # 架构演进
    'accent_green': '#4CAF50',        # 已完成
    'accent_gold': '#FFD700',         # 成就
    'text_primary': '#F5F5F5',        # 主要文字
    'text_secondary': '#B0B0B0',      # 次要文字
    'grid': '#2A2A2A',                # 网格线
}

def get_font(size, bold=False):
    """获取字体 - 降级策略"""
    try:
        # 尝试系统字体
        font_names = [
            "C:\\Windows\\Fonts\\arial.ttf",
            "C:\\Windows\\Fonts\\Arial.ttf",
            "/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf",
            "/System/Library/Fonts/Helvetica.ttc"
        ]
        for font_name in font_names:
            if os.path.exists(font_name):
                return ImageFont.truetype(font_name, size)
    except:
        pass

    # 降级到默认字体
    return ImageFont.load_default()

def create_base_canvas():
    """创建基础画布"""
    img = Image.new('RGB', (WIDTH, HEIGHT), COLORS['background'])
    draw = ImageDraw.Draw(img)

    # 绘制网格背景 (建筑制图风格)
    grid_size = 40
    for x in range(0, WIDTH, grid_size):
        color = COLORS['grid'] if x % (grid_size * 5) != 0 else '#333333'
        draw.line([(x, 0), (x, HEIGHT)], fill=color, width=1)
    for y in range(0, HEIGHT, grid_size):
        color = COLORS['grid'] if y % (grid_size * 5) != 0 else '#333333'
        draw.line([(0, y), (WIDTH, y)], fill=color, width=1)

    return img, draw

def draw_rounded_rect(draw, box, radius, fill, outline=None, outline_width=1):
    """绘制圆角矩形"""
    x1, y1, x2, y2 = box
    draw.rectangle([x1 + radius, y1, x2 - radius, y2], fill=fill)
    draw.rectangle([x1, y1 + radius, x2, y2 - radius], fill=fill)
    draw.pieslice([x1, y1, x1 + radius * 2, y1 + radius * 2], 180, 270, fill=fill)
    draw.pieslice([x2 - radius * 2, y1, x2, y1 + radius * 2], 270, 360, fill=fill)
    draw.pieslice([x1, y2 - radius * 2, x1 + radius * 2, y2], 90, 180, fill=fill)
    draw.pieslice([x2 - radius * 2, y2 - radius * 2, x2, y2], 0, 90, fill=fill)

    if outline:
        draw.arc([x1, y1, x1 + radius * 2, y1 + radius * 2], 180, 270, fill=outline, width=outline_width)
        draw.arc([x2 - radius * 2, y1, x2, y1 + radius * 2], 270, 360, fill=outline, width=outline_width)
        draw.arc([x1, y2 - radius * 2, x1 + radius * 2, y2], 90, 180, fill=outline, width=outline_width)
        draw.arc([x2 - radius * 2, y2 - radius * 2, x2, y2], 0, 90, fill=outline, width=outline_width)
        draw.line([(x1 + radius, y1), (x2 - radius, y1)], fill=outline, width=outline_width)
        draw.line([(x1 + radius, y2), (x2 - radius, y2)], fill=outline, width=outline_width)
        draw.line([(x1, y1 + radius), (x1, y2 - radius)], fill=outline, width=outline_width)
        draw.line([(x2, y1 + radius), (x2, y2 - radius)], fill=outline, width=outline_width)

def draw_cylinder(draw, x, y, width, height, fill, label, font):
    """绘制圆柱体 (数据库)"""
    # 圆柱体顶部
    ellipse_height = 30
    draw.ellipse([x, y, x + width, y + ellipse_height], fill=fill, outline=COLORS['line_light'], width=2)

    # 圆柱体主体
    draw.rectangle([x, y + ellipse_height // 2, x + width, y + height], fill=fill, outline=COLORS['line_light'], width=2)

    # 圆柱体底部
    draw.ellipse([x, y + height - ellipse_height // 2, x + width, y + height + ellipse_height // 2],
                 fill=fill, outline=COLORS['line_light'], width=2)

    # 标签
    text_bbox = draw.textbbox((0, 0), label, font=font)
    text_width = text_bbox[2] - text_bbox[0]
    text_x = x + (width - text_width) // 2
    text_y = y + height // 2 - 10
    draw.text((text_x, text_y), label, fill=COLORS['text_primary'], font=font)

def draw_cloud(draw, x, y, width, height, fill, label, font):
    """绘制云朵 (API)"""
    # 简化的云朵形状
    draw.ellipse([x, y + height // 3, x + width // 3, y + height], fill=fill, outline=COLORS['line_light'], width=2)
    draw.ellipse([x + width * 2 // 3, y + height // 3, x + width, y + height], fill=fill, outline=COLORS['line_light'], width=2)
    draw.ellipse([x + width // 4, y, x + width * 3 // 4, y + height * 2 // 3], fill=fill, outline=COLORS['line_light'], width=2)

    # 标签
    text_bbox = draw.textbbox((0, 0), label, font=font)
    text_width = text_bbox[2] - text_bbox[0]
    text_x = x + (width - text_width) // 2
    text_y = y + height // 2 - 10
    draw.text((text_x, text_y), label, fill=COLORS['text_primary'], font=font)

def draw_layer_label(draw, x, y, text, font, font_large):
    """绘制层标签"""
    # 背景条
    draw_rounded_rect(draw, (x - 10, y - 25, x + 200, y + 5), 8, COLORS['foundation'],
                     outline=COLORS['line_light'], outline_width=1)

    # 文字
    draw.text((x, y - 22), text, fill=COLORS['text_primary'], font=font_large)

def draw_dashed_line(draw, start, end, color, width=1, dash_length=5):
    """绘制虚线"""
    x1, y1 = start
    x2, y2 = end

    if x1 == x2:  # 垂直线
        for y in range(y1, y2, dash_length * 2):
            draw.line([(x1, y), (x1, min(y + dash_length, y2))], fill=color, width=width)
    else:  # 水平线
        for x in range(x1, x2, dash_length * 2):
            draw.line([(x, y1), (min(x + dash_length, x2), y2)], fill=color, width=width)

def draw_architecture_diagram():
    """绘制完整的架构图"""
    img, draw = create_base_canvas()

    # 字体
    font_tiny = get_font(14)
    font_small = get_font(18)
    font_medium = get_font(24)
    font_large = get_font(32, bold=True)
    font_title = get_font(48, bold=True)

    # 标题
    title = "Flutter App Architecture - Novel Builder"
    title_bbox = draw.textbbox((0, 0), title, font=font_title)
    title_x = (WIDTH - (title_bbox[2] - title_bbox[0])) // 2
    draw.text((title_x, MARGIN - 80), title, fill=COLORS['text_primary'], font=font_title)

    # 副标题
    subtitle = "Technical Debt & Evolution Map"
    subtitle_bbox = draw.textbbox((0, 0), subtitle, font=font_medium)
    subtitle_x = (WIDTH - (subtitle_bbox[2] - subtitle_bbox[0])) // 2
    draw.text((subtitle_x, MARGIN - 30), subtitle, fill=COLORS['text_secondary'], font=font_medium)

    # ====== LAYER 3: FOUNDATION (最底层) ======
    foundation_y = HEIGHT - MARGIN - 250
    foundation_height = 250

    # 层标签
    draw_layer_label(draw, MARGIN + 20, foundation_y - 40, "LAYER 1: FOUNDATION", font_small, font_medium)

    # 基础层背景
    draw_rounded_rect(draw, (MARGIN, foundation_y, WIDTH - MARGIN, foundation_y + foundation_height),
                     12, COLORS['foundation'], outline=COLORS['line_dim'], outline_width=2)

    # Flutter Framework
    draw_rounded_rect(draw, (MARGIN + 40, foundation_y + 40, MARGIN + 580, foundation_y + 210),
                     8, COLORS['steel_blue'], outline=COLORS['line_light'], outline_width=2)
    draw.text((MARGIN + 80, foundation_y + 110), "Flutter Framework", fill=COLORS['text_primary'], font=font_large)

    # Dart SDK
    draw_rounded_rect(draw, (WIDTH // 2 - 270, foundation_y + 40, WIDTH // 2 + 270, foundation_y + 210),
                     8, COLORS['steel_blue'], outline=COLORS['line_light'], outline_width=2)
    draw.text((WIDTH // 2 - 70, foundation_y + 110), "Dart SDK", fill=COLORS['text_primary'], font=font_large)

    # Build Tools
    draw_rounded_rect(draw, (WIDTH - MARGIN - 580, foundation_y + 40, WIDTH - MARGIN - 40, foundation_y + 210),
                     8, COLORS['steel_blue'], outline=COLORS['line_light'], outline_width=2)
    draw.text((WIDTH - MARGIN - 440, foundation_y + 110), "Build Tools", fill=COLORS['text_primary'], font=font_large)

    # ====== LAYER 2: CORE ARCHITECTURE (中间层) ======
    layer2_y = 900
    layer2_height = HEIGHT - MARGIN - foundation_height - layer2_y - 100

    # 层标签
    draw_layer_label(draw, MARGIN + 20, layer2_y - 40, "LAYER 2: CORE ARCHITECTURE", font_small, font_medium)

    # Layer 2 背景
    draw_rounded_rect(draw, (MARGIN, layer2_y, WIDTH - MARGIN, layer2_y + layer2_height),
                     12, COLORS['layer2'], outline=COLORS['line_dim'], outline_width=2)

    # --- UI Layer (上层) ---
    ui_y = layer2_y + 50
    ui_height = 280

    # UI层标签
    draw.text((MARGIN + 30, ui_y + 10), "UI LAYER", fill=COLORS['text_secondary'], font=font_medium)

    # Screens (7个主要屏幕)
    screens = [
        "reader_screen", "character_edit", "insert_chapter",
        "multi_role_chat", "character_mgmt", "settings", "bookshelf"
    ]
    screen_width = 380
    screen_height = 180
    screen_gap = 45
    start_x = MARGIN + 200

    for i, screen in enumerate(screens):
        x = start_x + i * (screen_width + screen_gap)
        draw_rounded_rect(draw, (x, ui_y + 50, x + screen_width, ui_y + 50 + screen_height),
                         8, COLORS['steel_blue'], outline=COLORS['line_light'], outline_width=2)

        # Screen标签
        display_name = screen.replace('_', ' ').title()
        draw.text((x + 20, ui_y + 60), display_name, fill=COLORS['text_primary'], font=font_medium)

        # 添加一些小方框表示widgets
        for wx in range(3):
            for wy in range(2):
                draw_rounded_rect(draw, (x + 20 + wx * 110, ui_y + 110 + wy * 50,
                                        x + 100 + wx * 110, ui_y + 140 + wy * 50),
                                 4, COLORS['titanium'], outline=COLORS['line_dim'], outline_width=1)

    # --- State Management (中层) ---
    state_y = ui_y + ui_height + 40
    state_height = 260

    # State层标签
    draw.text((MARGIN + 30, state_y + 10), "STATE MANAGEMENT", fill=COLORS['text_secondary'], font=font_medium)

    # Riverpod Providers (中心大框)
    provider_width = 600
    provider_height = 180
    provider_x = WIDTH // 2 - provider_width // 2
    draw_rounded_rect(draw, (provider_x, state_y + 50, provider_x + provider_width, state_y + 50 + provider_height),
                     10, COLORS['titanium'], outline=COLORS['line_light'], outline_width=2)
    draw.text((provider_x + 200, state_y + 130), "Riverpod Providers", fill=COLORS['text_primary'], font=font_large)

    # Controllers (左侧)
    controllers = ["Chapter", "Character", "Reader", "TTS"]
    ctrl_width = 200
    ctrl_height = 80
    ctrl_start_x = MARGIN + 150

    for i, ctrl in enumerate(controllers):
        x = ctrl_start_x + i * (ctrl_width + 20)
        draw_rounded_rect(draw, (x, state_y + 100, x + ctrl_width, state_y + 100 + ctrl_height),
                         6, COLORS['steel_blue'], outline=COLORS['line_light'], outline_width=2)
        draw.text((x + 50, state_y + 130), f"{ctrl}\nController", fill=COLORS['text_primary'], font=font_small)

        # 连接到Providers的虚线
        draw_dashed_line(draw, (x + ctrl_width, state_y + 140), (provider_x, state_y + 140),
                        COLORS['line_dim'], width=1, dash_length=8)

    # Repositories (右侧)
    repositories = ["Chapter", "Character", "Illustration", "Novel", "Bookshelf", "Relation"]
    repo_width = 180
    repo_height = 70
    repo_start_x = WIDTH - MARGIN - 6 * (repo_width + 20)

    for i, repo in enumerate(repositories):
        x = repo_start_x + i * (repo_width + 20)
        draw_rounded_rect(draw, (x, state_y + 80, x + repo_width, state_y + 80 + repo_height),
                         6, COLORS['steel_blue'], outline=COLORS['line_light'], outline_width=2)
        draw.text((x + 40, state_y + 105), f"{repo}\nRepo", fill=COLORS['text_primary'], font=font_small)

        # 连接到Providers的虚线
        draw_dashed_line(draw, (provider_x + provider_width, state_y + 115 + (i % 2) * 40),
                        (x, state_y + 115), COLORS['line_dim'], width=1, dash_length=8)

    # --- Service Layer (下层) ---
    service_y = state_y + state_height + 40
    service_height = 200

    # Service层标签
    draw.text((MARGIN + 30, service_y + 10), "SERVICE LAYER", fill=COLORS['text_secondary'], font=font_medium)

    # Services (15+个小框)
    services = [
        "DifyService", "TTSPlayer", "SceneIllustration", "CharacterAvatar",
        "ChapterManager", "CacheSearch", "BackupService", "PreloadService",
        "RewriteService", "ThemeService", "PreferencesService", "LoggerService",
        "DatabaseService*", "AIService", "APIServiceWrapper"
    ]

    svc_width = 220
    svc_height = 70
    svc_gap = 15
    svc_cols = 7
    svc_start_x = MARGIN + 100

    for i, svc in enumerate(services):
        col = i % svc_cols
        row = i // svc_cols
        x = svc_start_x + col * (svc_width + svc_gap)
        y = service_y + 50 + row * (svc_height + svc_gap)

        # DatabaseService 标记为deprecated
        if "DatabaseService*" in svc:
            fill_color = COLORS['accent_amber']
            label = "DatabaseService"
        else:
            fill_color = COLORS['steel_blue']
            label = svc.replace("Service", "").replace("*", "")

        draw_rounded_rect(draw, (x, y, x + svc_width, y + svc_height),
                         6, fill_color, outline=COLORS['line_light'], outline_width=2)
        draw.text((x + 20, y + 25), label, fill=COLORS['text_primary'], font=font_small)

    # ====== LAYER 3: DATA LAYER (最底层) ======
    data_y = foundation_y + foundation_height + 30

    # 层标签
    draw_layer_label(draw, MARGIN + 20, data_y - 40, "LAYER 3: DATA LAYER", font_small, font_medium)

    # SQLite Database
    draw_cylinder(draw, MARGIN + 200, data_y, 400, 180, COLORS['steel_blue'], "SQLite Database", font_large)

    # Backend API (云朵)
    draw_cloud(draw, WIDTH // 2 - 300, data_y, 600, 180, COLORS['steel_blue'], "Backend API", font_large)

    # File System
    fs_x = WIDTH - MARGIN - 600
    for i in range(3):
        draw_rounded_rect(draw, (fs_x, data_y + 30 + i * 50, fs_x + 400, data_y + 70 + i * 50),
                         8, COLORS['steel_blue'], outline=COLORS['line_light'], outline_width=2)
    draw.text((fs_x + 140, data_y + 140), "File System", fill=COLORS['text_primary'], font=font_large)

    # ====== 技术债务注释 ======

    # 关键错误 (红色)
    error_x = WIDTH - MARGIN - 450
    error_y = layer2_y + 50
    draw_rounded_rect(draw, (error_x, error_y, error_x + 400, error_y + 120),
                     8, COLORS['accent_red'], outline=COLORS['line_light'], outline_width=3)
    draw.text((error_x + 20, error_y + 20), "⚠️ CRITICAL ERROR", fill=COLORS['text_primary'], font=font_medium)
    draw.text((error_x + 20, error_y + 55), "scene_illustration_service.dart", fill=COLORS['text_primary'], font=font_small)
    draw.text((error_x + 20, error_y + 80), "undefined_method: getById", fill=COLORS['text_primary'], font=font_small)

    # 回归问题 (琥珀色)
    regression_y = error_y + 140
    draw_rounded_rect(draw, (error_x, regression_y, error_x + 400, regression_y + 200),
                     8, COLORS['accent_amber'], outline=COLORS['line_light'], outline_width=2)
    draw.text((error_x + 20, regression_y + 15), "🟡 REGRESSION (Phase 1)", fill='#000000', font=font_medium)
    draw.text((error_x + 20, regression_y + 50), "• withOpacity → withValues (3 locs)",
              fill='#000000', font=font_small)
    draw.text((error_x + 20, regression_y + 80), "• RadioListTile → ListTile+Radio (6)",
              fill='#000000', font=font_small)
    draw.text((error_x + 20, regression_y + 110), "• BuildContext mounted checks (15)",
              fill='#000000', font=font_small)

    # 架构演进 (蓝色)
    evolution_y = regression_y + 220
    draw_rounded_rect(draw, (error_x, evolution_y, error_x + 400, evolution_y + 180),
                     8, COLORS['accent_blue'], outline=COLORS['line_light'], outline_width=2)
    draw.text((error_x + 20, evolution_y + 15), "ℹ️ ARCHITECTURE EVOLUTION",
              fill='#000000', font=font_medium)
    draw.text((error_x + 20, evolution_y + 50), "• Controllers: Phase 2 compatible",
              fill='#000000', font=font_small)
    draw.text((error_x + 20, evolution_y + 80), "• Services: 7/15 migrated",
              fill='#000000', font=font_small)
    draw.text((error_x + 20, evolution_y + 110), "• DatabaseService: 38 deprecated",
              fill='#000000', font=font_small)

    # 成就 (金色)
    achievement_y = evolution_y + 200
    draw_rounded_rect(draw, (error_x, achievement_y, error_x + 400, achievement_y + 220),
                     8, COLORS['accent_gold'], outline=COLORS['line_light'], outline_width=2)
    draw.text((error_x + 20, achievement_y + 15), "✅ PHASE 0-5 ACHIEVEMENTS",
              fill='#000000', font=font_medium)
    draw.text((error_x + 20, achievement_y + 50), "• Tech debt: 133 → 92 (-30.8%)",
              fill='#000000', font=font_small)
    draw.text((error_x + 20, achievement_y + 80), "• Documentation: 0% → 85%",
              fill='#000000', font=font_small)
    draw.text((error_x + 20, achievement_y + 110), "• Print statements: 27 → 0",
              fill='#000000', font=font_small)
    draw.text((error_x + 20, achievement_y + 140), "• TODO comments: 8 → 0",
              fill='#000000', font=font_small)
    draw.text((error_x + 20, achievement_y + 170), "• Unused imports: All cleared",
              fill='#000000', font=font_small)

    # ====== 图例 (右下角) ======
    legend_x = WIDTH - MARGIN - 450
    legend_y = HEIGHT - MARGIN - 280
    legend_width = 430
    legend_height = 260

    # 图例背景
    draw_rounded_rect(draw, (legend_x, legend_y, legend_x + legend_width, legend_y + legend_height),
                     10, COLORS['foundation'], outline=COLORS['line_light'], outline_width=2)

    # 图例标题
    draw.text((legend_x + 20, legend_y + 20), "LEGEND", fill=COLORS['text_primary'], font=font_large)

    # 图例项
    legend_items = [
        (COLORS['accent_red'], "🔴 Critical Error"),
        (COLORS['accent_amber'], "🟡 Regression Issues"),
        (COLORS['accent_blue'], "ℹ️ Architecture Evolution"),
        (COLORS['accent_gold'], "✅ Achievements"),
        (COLORS['steel_blue'], "Active Components"),
        (COLORS['titanium'], "Supporting Components"),
        (COLORS['line_dim'], "Deprecated/Deprecated Usage"),
    ]

    item_y = legend_y + 60
    for color, text in legend_items:
        draw_rounded_rect(draw, (legend_x + 20, item_y, legend_x + 50, item_y + 30),
                         4, color, outline=COLORS['line_light'], outline_width=1)
        draw.text((legend_x + 60, item_y + 5), text, fill=COLORS['text_secondary'], font=font_small)
        item_y += 35

    # ====== 连接线 ======
    # UI层到State层的连接
    for i in range(7):
        screen_x = start_x + i * (screen_width + screen_gap) + screen_width // 2
        draw_dashed_line(draw, (screen_x, ui_y + 50 + screen_height),
                        (screen_x, state_y + 50), COLORS['line_dim'], width=1, dash_length=8)

    # State层到Service层的连接
    for i in range(7):
        svc_x = svc_start_x + i * (svc_width + svc_gap) + svc_width // 2
        draw_dashed_line(draw, (svc_x, state_y + 50 + state_height),
                        (svc_x, service_y + 50), COLORS['line_dim'], width=1, dash_length=8)

    # Service层到Data层的连接
    for i in range(3):
        data_points = [
            (MARGIN + 400, data_y + 90),  # SQLite
            (WIDTH // 2, data_y + 90),     # API
            (WIDTH - MARGIN - 400, data_y + 90)  # File System
        ]
        for j, (dx, dy) in enumerate(data_points):
            if i < len(services) // 3:
                svc_x = svc_start_x + j * (svc_width + svc_gap) + svc_width // 2
                draw_dashed_line(draw, (svc_x, service_y + 200),
                                (dx, dy), COLORS['line_dim'], width=1, dash_length=8)

    # 添加比例尺 (建筑制图风格)
    scale_x = MARGIN + 50
    scale_y = HEIGHT - MARGIN - 100
    scale_length = 300

    draw.line([(scale_x, scale_y), (scale_x + scale_length, scale_y)], fill=COLORS['line_light'], width=2)
    for i in range(0, scale_length + 1, 50):
        tick_length = 10 if i % 100 == 0 else 5
        draw.line([(scale_x + i, scale_y), (scale_x + i, scale_y + tick_length)],
                 fill=COLORS['line_light'], width=2)

    draw.text((scale_x + scale_length // 2 - 50, scale_y + 20), "SCALE: 1:100",
              fill=COLORS['text_secondary'], font=font_small)

    # 添加北向箭头
    north_x = WIDTH - MARGIN - 100
    north_y = HEIGHT - MARGIN - 150
    draw.polygon([(north_x, north_y - 40), (north_x - 15, north_y), (north_x + 15, north_y)],
                fill=COLORS['line_light'])
    draw.text((north_x - 25, north_y + 10), "N", fill=COLORS['text_primary'], font=font_medium)

    # 添加版本信息
    version_text = "v2.0.0 | 2026-02-03 | Generated by Claude"
    version_bbox = draw.textbbox((0, 0), version_text, font=font_small)
    version_x = WIDTH - MARGIN - (version_bbox[2] - version_bbox[0])
    draw.text((version_x, MARGIN - 50), version_text, fill=COLORS['text_secondary'], font=font_small)

    return img

def main():
    """主函数"""
    print("Starting Flutter App architecture diagram generation...")

    try:
        # 生成架构图
        img = draw_architecture_diagram()

        # 保存为PNG
        png_path = os.path.join(OUTPUT_DIR, "flutter_architecture_diagram.png")
        img.save(png_path, "PNG", dpi=(300, 300))
        print(f"PNG diagram saved: {png_path}")

        # 保存为PDF
        pdf_path = os.path.join(OUTPUT_DIR, "flutter_architecture_diagram.pdf")
        img_rgb = img.convert('RGB')
        img_rgb.save(pdf_path, "PDF", resolution=300, quality=100)
        print(f"PDF diagram saved: {pdf_path}")

        # 保存高分辨率版本 (4K)
        img_4k = img.resize((7680, 4320), Image.Resampling.LANCZOS)
        png_4k_path = os.path.join(OUTPUT_DIR, "flutter_architecture_diagram_4k.png")
        img_4k.save(png_4k_path, "PNG", dpi=(600, 600))
        print(f"4K PNG diagram saved: {png_4k_path}")

        print("\nArchitecture diagram generation completed!")
        print(f"Output directory: {OUTPUT_DIR}")
        print("\nGenerated files:")
        print(f"   - {png_path}")
        print(f"   - {pdf_path}")
        print(f"   - {png_4k_path}")

    except Exception as e:
        print(f"Generation failed: {e}")
        import traceback
        traceback.print_exc()

if __name__ == "__main__":
    main()
