import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:novel_app/widgets/hermes/hermes_chat_dialog.dart';

/// Hermes 全局悬浮按钮
///
/// 使用 Stack + Positioned 实现可拖动悬浮按钮，
/// 点击展开聊天对话框。
class HermesFloatingButton extends ConsumerStatefulWidget {
  const HermesFloatingButton({super.key});

  @override
  ConsumerState<HermesFloatingButton> createState() => _HermesFloatingButtonState();
}

class _HermesFloatingButtonState extends ConsumerState<HermesFloatingButton> {
  double _x = 16.0;
  double _y = 100.0;
  bool _isDragging = false;
  Offset _dragStart = Offset.zero;
  double _startX = 0;
  double _startY = 0;

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;

    return Stack(
      children: [
        Positioned(
          left: _x,
          bottom: _y,
          child: GestureDetector(
            onPanStart: (details) {
              _isDragging = true;
              _dragStart = details.globalPosition;
              _startX = _x;
              _startY = _y;
            },
            onPanUpdate: (details) {
              if (!_isDragging) return;
              final dx = details.globalPosition.dx - _dragStart.dx;
              final dy = details.globalPosition.dy - _dragStart.dy;

              setState(() {
                _x = (_startX + dx).clamp(0.0, screenSize.width - 56);
                _y = (_startY - dy).clamp(0.0, screenSize.height - 56);
              });
            },
            onPanEnd: (details) {
              final dx = (_x - _startX).abs();
              final dy = (_y - _startY).abs();

              if (dx < 5 && dy < 5) {
                _showChatDialog();
              }

              _isDragging = false;

              setState(() {
                if (_x < screenSize.width / 2) {
                  _x = 16.0;
                } else {
                  _x = screenSize.width - 56;
                }
              });
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF6366F1).withValues(alpha: 0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: const Material(
                color: Colors.transparent,
                child: Icon(
                  Icons.auto_awesome,
                  color: Colors.white,
                  size: 24,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  void _showChatDialog() {
    showDialog(
      context: context,
      builder: (context) => const HermesChatDialog(),
    );
  }
}

/// Hermes 悬浮外壳
///
/// 包裹在应用外层，在所有页面之上渲染悬浮按钮。
class HermesFloatingShell extends StatelessWidget {
  final Widget child;

  const HermesFloatingShell({
    super.key,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        child,
        const HermesFloatingButton(),
      ],
    );
  }
}
