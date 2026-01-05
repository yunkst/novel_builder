#!/bin/bash
# 为视频集成测试添加skip标记

file="video_controller_integration_test.dart"

# 在每个test的末尾添加skip参数
sed -i "s/\(test('.*') {/\1, skip: '需要真实视频平台，使用mock版本替代';/" "$file"

echo "✅ 已为 $file 添加skip标记"
