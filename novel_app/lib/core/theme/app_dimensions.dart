/// 应用尺寸/间距/圆角设计令牌
///
/// 集中管理 Material 3 风格的设计令牌，避免散落硬编码。
/// 颜色见 [AppColors]；本文件只承载几何尺寸。
///
/// 设计原则：
/// - 间距档位遵循 4 的倍数（M3 spacing tokens 习惯）
/// - 圆角档位 4/8/12/16 对应 M3 shape tokens
/// - 预制常量（`allMd`、`gapSm` 等）减少使用点噪音
///
/// 使用方式：
/// ```dart
/// Container(
///   padding: AppSpacing.allLg,            // EdgeInsets.all(16)
///   decoration: BoxDecoration(
///     borderRadius: AppRadius.brMd,       // BorderRadius.circular(12)
///   ),
/// )
/// const SizedBox(height: 8) → AppSpacing.gapSm
/// ```
library;

import 'package:flutter/material.dart';

/// 标准间距令牌（4 的倍数）
///
/// 命名风格遵循 Material 3 spacing tokens 习惯（xs/sm/md/lg/xl/xxl）。
abstract final class AppSpacing {
  /// 4 - 极小间距（内联图标与文字）
  static const double xs = 4;

  /// 8 - 默认小间距（列表项之间）
  static const double sm = 8;

  /// 12 - 中间距（小卡片内边距）
  static const double md = 12;

  /// 16 - 大间距（页面/大块卡片标准内边距）
  static const double lg = 16;

  /// 24 - 加大间距（区块之间）
  static const double xl = 24;

  /// 32 - 极大间距（页面边距、独立居中元素）
  static const double xxl = 32;

  // ─── 预制 EdgeInsets（const 友好）────────────────────────────────
  /// `EdgeInsets.all(4)`
  static const EdgeInsets allXs = EdgeInsets.all(xs);

  /// `EdgeInsets.all(8)` - 小元素内边距
  static const EdgeInsets allSm = EdgeInsets.all(sm);

  /// `EdgeInsets.all(12)` - 中等内容卡片内边距
  static const EdgeInsets allMd = EdgeInsets.all(md);

  /// `EdgeInsets.all(16)` - 页面/大块卡片标准内边距
  static const EdgeInsets allLg = EdgeInsets.all(lg);

  /// `EdgeInsets.all(24)` - 加大内边距
  static const EdgeInsets allXl = EdgeInsets.all(xl);

  /// `EdgeInsets.symmetric(horizontal: 16)` - 页面水平边距
  static const EdgeInsets pageHorizontal =
      EdgeInsets.symmetric(horizontal: lg);

  /// `EdgeInsets.symmetric(horizontal: 16, vertical: 8)` - 卡片复合内边距
  static const EdgeInsets cardInner =
      EdgeInsets.symmetric(horizontal: lg, vertical: sm);

  /// `EdgeInsets.symmetric(horizontal: 8, vertical: 4)` - 紧凑徽标内边距
  static const EdgeInsets badgeCompact =
      EdgeInsets.symmetric(horizontal: sm, vertical: xs);

  // ─── 预制 SizedBox（height 版本；width 在 UI 中按需 SizedBox(width: AppSpacing.sm)）──
  /// `SizedBox(height: 4)`
  static const SizedBox gapXs = SizedBox(height: xs);

  /// `SizedBox(height: 8)` - 默认小间距
  static const SizedBox gapSm = SizedBox(height: sm);

  /// `SizedBox(height: 12)` - 中间距
  static const SizedBox gapMd = SizedBox(height: md);

  /// `SizedBox(height: 16)` - 大间距
  static const SizedBox gapLg = SizedBox(height: lg);

  /// `SizedBox(height: 24)` - 加大间距
  static const SizedBox gapXl = SizedBox(height: xl);

  /// `SizedBox(height: 32)` - 极大间距
  static const SizedBox gapXxl = SizedBox(height: xxl);
}

/// 圆角设计令牌（Material 3 shape tokens）
///
/// 三档约定：**外框 16 / 内容卡片 12 / 徽标 8**。
abstract final class AppRadius {
  /// 4 - 极小（输入框内部、装饰条）
  static const double xs = 4;

  /// 8 - 徽标、小标签
  static const double sm = 8;

  /// 12 - 次级卡片、特殊徽章
  static const double md = 12;

  /// 16 - 对话框、底部抽屉外框
  static const double lg = 16;

  /// 999 - 完全胶囊（用 BorderRadius.all 表达，配合大宽高）
  static const double full = 999;

  // ─── 预制 BorderRadius（const 友好）────────────────────────────────
  /// `BorderRadius.circular(4)`
  static const BorderRadius brXs = BorderRadius.all(Radius.circular(xs));

  /// `BorderRadius.circular(8)` - 徽标
  static const BorderRadius brSm = BorderRadius.all(Radius.circular(sm));

  /// `BorderRadius.circular(12)` - 内容卡片
  static const BorderRadius brMd = BorderRadius.all(Radius.circular(md));

  /// `BorderRadius.circular(16)` - 对话框外框
  static const BorderRadius brLg = BorderRadius.all(Radius.circular(lg));

  /// `BorderRadius.vertical(top: Radius.circular(16))` - BottomSheet 顶部圆角
  static const BorderRadius sheetTop =
      BorderRadius.vertical(top: Radius.circular(lg));
}
