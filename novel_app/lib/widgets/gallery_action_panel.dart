import 'package:flutter/material.dart';
import '../models/role_gallery.dart';
import 'generate_more_dialog.dart';

/// 图集操作面板
class GalleryActionPanel extends StatefulWidget {
  final RoleImage currentImage;
  final int currentIndex;
  final int totalCount;
  final VoidCallback? onDelete;
  final Future<void> Function(int)? onGenerateMore;
  final VoidCallback? onSetAsAvatar;

  const GalleryActionPanel({
    super.key,
    required this.currentImage,
    required this.currentIndex,
    required this.totalCount,
    this.onDelete,
    this.onGenerateMore,
    this.onSetAsAvatar,
  });

  @override
  State<GalleryActionPanel> createState() => _GalleryActionPanelState();
}

class _GalleryActionPanelState extends State<GalleryActionPanel> {
  bool _isProcessing = false;

  void _handleDelete() {
    if (_isProcessing) return;

    // 直接调用删除操作，无需确认对话框
    widget.onDelete?.call();
  }

  void _handleGenerateMore() {
    if (_isProcessing) return;

    showDialog(
      context: context,
      builder: (context) => GenerateMoreDialog(
        apiType: 't2i', // 人物卡重新生成使用文生图模型
        onConfirm: (count, modelName) {
          setState(() {
            _isProcessing = true;
          });

          // TODO: 需要更新回调以支持模型参数
          widget.onGenerateMore?.call(count).then((_) {
            if (mounted) {
              setState(() {
                _isProcessing = false;
              });
            }
          }).catchError((error) {
            if (mounted) {
              setState(() {
                _isProcessing = false;
              });
            }
          });
        },
      ),
    );
  }

  void _handleSetAsAvatar() {
    if (_isProcessing) return;

    // 直接调用设置头像功能，无需确认弹框
    widget.onSetAsAvatar?.call();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 120,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [
            Colors.black.withValues(alpha: 0.7),
            Colors.transparent,
          ],
        ),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Column(
            children: [
              // 图片指示器
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  widget.totalCount,
                  (index) => Container(
                    width: 8,
                    height: 8,
                    margin: const EdgeInsets.symmetric(horizontal: 2),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: index == widget.currentIndex
                          ? Colors.white
                          : Colors.white.withValues(alpha: 0.4),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              // 操作按钮
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  // 删除按钮
                  _ActionButton(
                    icon: Icons.delete_outline,
                    label: '删除',
                    onPressed: _handleDelete,
                    color: Colors.red,
                  ),
                  // 多来几张按钮
                  _ActionButton(
                    icon: Icons.add_photo_alternate_outlined,
                    label: _isProcessing ? '生成中...' : '多来几张',
                    onPressed: _handleGenerateMore,
                    color: Colors.blue,
                    isLoading: _isProcessing,
                  ),
                  // 设为头像按钮
                  _ActionButton(
                    icon: Icons.face,
                    label: '设为头像',
                    onPressed: _handleSetAsAvatar,
                    color: Colors.blue,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 操作按钮组件
class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onPressed;
  final Color color;
  final bool isLoading;

  const _ActionButton({
    required this.icon,
    required this.label,
    this.onPressed,
    required this.color,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: isLoading ? null : onPressed,
      child: Opacity(
        opacity: (onPressed != null && !isLoading) ? 1.0 : 0.5,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: color.withValues(alpha: 0.2),
                border: Border.all(
                  color: color.withValues(alpha: 0.8),
                  width: 2,
                ),
              ),
              child: isLoading
                  ? SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(color),
                      ),
                    )
                  : Icon(
                      icon,
                      color: color,
                      size: 24,
                    ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}