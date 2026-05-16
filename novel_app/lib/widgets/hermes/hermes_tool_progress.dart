import 'package:flutter/material.dart';
import 'package:novel_app/services/hermes_sse_parser.dart';

/// 工具执行进度展示组件
class HermesToolProgress extends StatelessWidget {
  final List<ToolProgress> progressList;

  const HermesToolProgress({
    super.key,
    required this.progressList,
  });

  @override
  Widget build(BuildContext context) {
    if (progressList.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: progressList.map((progress) => _buildProgressItem(context, progress)).toList(),
    );
  }

  Widget _buildProgressItem(BuildContext context, ToolProgress progress) {
    final theme = Theme.of(context);
    final isRunning = progress.status == 'running';
    final isCompleted = progress.status == 'completed' || progress.status == 'done';
    final isError = progress.status == 'error';

    Color statusColor;
    IconData statusIcon;
    if (isRunning) {
      statusColor = Colors.blue;
      statusIcon = Icons.sync;
    } else if (isCompleted) {
      statusColor = Colors.green;
      statusIcon = Icons.check_circle;
    } else if (isError) {
      statusColor = Colors.red;
      statusIcon = Icons.error;
    } else {
      statusColor = Colors.orange;
      statusIcon = Icons.pending;
    }

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: statusColor.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(statusIcon, size: 14, color: statusColor),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  progress.toolName,
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: statusColor,
                  ),
                ),
              ),
              if (isRunning)
                SizedBox(
                  width: 12,
                  height: 12,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: statusColor,
                  ),
                ),
            ],
          ),
          if (progress.message != null) ...[
            const SizedBox(height: 4),
            Text(
              progress.message!,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
              ),
            ),
          ],
          if (progress.progress != null) ...[
            const SizedBox(height: 4),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: progress.progress! / 100.0,
                backgroundColor: statusColor.withValues(alpha: 0.1),
                color: statusColor,
                minHeight: 3,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
