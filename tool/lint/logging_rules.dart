/// 日志规范检查工具
///
/// 用法: dart run tool/lint/logging_rules.dart
///
/// 功能:
/// - 扫描所有 .dart 文件中的 debugPrint 使用
/// - 生成迁移进度报告
/// - 按优先级分类需要迁移的文件
/// - 提供详细的统计信息

import 'dart:io';
import 'dart:collection';

void main() async {
  print('🔍 开始检查日志使用规范...\n');

  final libDir = Directory('lib');
  if (!libDir.existsSync()) {
    print('❌ 未找到 lib 目录');
    print('💡 请在项目根目录运行此脚本');
    return;
  }

  // 统计数据
  int totalDebugPrint = 0;
  int filesWithDebugPrint = 0;
  final filesWithIssues = <String, List<String>>{};
  final categoryStats = {
    'high': <String>[],
    'medium': <String>[],
    'low': <String>[],
  };

  // 遍历所有 .dart 文件
  await for (final entity in libDir.list(recursive: true, followLinks: false)) {
    if (entity.path.endsWith('.dart') && !entity.path.contains('.g.dart')) {
      final file = File(entity.path);
      final contents = await file.readAsString();
      final lines = contents.split('\n');

      final issues = <String>[];
      int debugPrintCount = 0;

      // 统计每一行的 debugPrint 使用
      for (int i = 0; i < lines.length; i++) {
        final line = lines[i];

        if (line.contains('debugPrint(')) {
          debugPrintCount++;
          totalDebugPrint++;

          // 检查是否有对应的 LoggerService 调用
          bool hasLoggerService = false;
          final startLine = i > 2 ? i - 2 : 0;
          final endLine = (i + 3) < lines.length ? i + 3 : lines.length;

          for (int j = startLine; j < endLine; j++) {
            if (lines[j].contains('LoggerService.instance.')) {
              hasLoggerService = true;
              break;
            }
          }

          if (!hasLoggerService) {
            final lineNumber = i + 1;
            issues.add('  行 $lineNumber: debugPrint 使用');
          }
        }
      }

      if (issues.isNotEmpty) {
        filesWithIssues[entity.path] = issues;
        filesWithDebugPrint++;

        // 按文件路径分类优先级
        final relativePath = entity.path.replaceFirst('lib${Platform.pathSeparator}', '');

        if (relativePath.contains('services') &&
            (relativePath.contains('database') ||
                relativePath.contains('dify') ||
                relativePath.contains('api'))) {
          categoryStats['high']!.add(relativePath);
        } else if (relativePath.contains('services')) {
          categoryStats['medium']!.add(relativePath);
        } else {
          categoryStats['low']!.add(relativePath);
        }
      }
    }
  }

  // 打印报告
  print('📊 检查结果:\n');
  print('  总 debugPrint 使用次数: $totalDebugPrint');
  print('  涉及文件数: $filesWithDebugPrint');
  print('  需要迁移的文件: ${filesWithIssues.length}\n');

  // 按优先级打印文件
  if (categoryStats['high']!.isNotEmpty) {
    print('🔴 高优先级 - 核心服务（必须迁移）:');
    for (final file in categoryStats['high']!) {
      final count = filesWithIssues.entries
          .firstWhere((e) => e.key.contains(file))
          .value.length;
      print('  • $file ($count 处)');
    }
    print('');
  }

  if (categoryStats['medium']!.isNotEmpty) {
    print('🟡 中优先级 - 业务服务（建议迁移）:');
    for (final file in categoryStats['medium']!) {
      final count = filesWithIssues.entries
          .firstWhere((e) => e.key.contains(file))
          .value.length;
      print('  • $file ($count 处)');
    }
    print('');
  }

  if (categoryStats['low']!.length > 0 && categoryStats['low']!.length <= 20) {
    print('🟢 低优先级 - 其他文件（可选迁移）:');
    for (final file in categoryStats['low']!) {
      print('  • $file');
    }
    print('');
  } else if (categoryStats['low']!.length > 20) {
    print('🟢 低优先级 - 其他文件（可选迁移）:');
    print('  共 ${categoryStats['low']!.length} 个文件');
    print('');
  }

  // 详细问题列表（仅显示前10个）
  if (filesWithIssues.isNotEmpty) {
    print('⚠️  详细问题（前10个文件）:\n');
    int count = 0;
    filesWithIssues.forEach((file, issues) {
      if (count < 10) {
        print('📄 $file');
        issues.forEach(print);
        print('');
        count++;
      }
    });

    if (filesWithIssues.length > 10) {
      print('... 还有 ${filesWithIssues.length - 10} 个文件未显示\n');
    }
  }

  if (filesWithIssues.isEmpty) {
    print('✅ 所有文件都符合日志规范！');
  } else {
    print('\n💡 迁移建议:');
    print('  1. 优先迁移高优先级文件（核心服务）');
    print('  2. 参考 docs/logging-guidelines.md 获取详细指南');
    print('  3. 迁移顺序: 错误日志 → 业务流程 → 临时调试');
    print('  4. 运行此工具定期检查迁移进度');
  }
}
