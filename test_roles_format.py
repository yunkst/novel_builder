#!/usr/bin/env python3
"""
测试角色信息格式化功能
"""

import json
import sys
import os

# 添加 backend 到路径
sys.path.insert(0, os.path.join(os.path.dirname(__file__), 'backend'))

from app.schemas import RoleInfo
from app.services.scene_illustration_service import SceneIllustrationService
from app.services.dify_client import DifyClient

def test_roles_formatting():
    """测试角色信息格式化功能"""

    # 创建测试数据
    test_roles = [
        {
            "id": 1,
            "name": "张三",
            "face_prompts": "英俊的面容，明亮的眼睛",
            "body_prompts": "健壮的身体"
        },
        {
            "id": 2,
            "name": "李四",
            "face_prompts": "美丽的容颜",
            "body_prompts": ""  # 空 body_prompts
        },
        {
            "id": 3,
            "name": "王五",
            "face_prompts": None,  # None face_prompts
            "body_prompts": "苗条的身材"
        },
        {
            "id": 4,
            "name": "赵六"  # 没有 face_prompts 和 body_prompts
        }
    ]

    # 转换为 JSON 字符串（模拟数据库存储）
    roles_json = json.dumps(test_roles, ensure_ascii=False)

    print("=== 测试数据 ===")
    print(f"原始数据: {roles_json}")
    print()

    # 创建 SceneIllustrationService 实例进行测试
    class MockDifyClient:
        pass

    scene_service = SceneIllustrationService(MockDifyClient())

    # 调用格式化方法
    result = scene_service._restore_roles_from_json(roles_json)

    print("=== 格式化结果 ===")
    print(result)
    print()

    # 验证结果
    print("=== 验证结果 ===")
    assert "1. 张三" in result
    assert "2. 李四" in result
    assert "3. 王五" in result
    assert "4. 赵六" in result
    assert "面部描述：英俊的面容，明亮的眼睛" in result
    assert "身材描述：健壮的身体" in result
    assert "面部描述：美丽的容颜" in result
    assert "苗条的身材" in result
    assert "body_prompts" not in result  # 确保字段名不在结果中
    assert "face_prompts" not in result  # 确保字段名不在结果中

    print("✅ 所有验证通过！")

def test_empty_data():
    """测试空数据"""
    scene_service = SceneIllustrationService(object())

    # 测试空字符串
    result = scene_service._restore_roles_from_json("")
    assert result == ""

    # 测试 None
    result = scene_service._restore_roles_from_json(None)
    assert result == ""

    print("✅ 空数据测试通过！")

if __name__ == "__main__":
    print("开始测试角色信息格式化功能...\n")

    try:
        test_empty_data()
        test_roles_formatting()
        print("\n🎉 所有测试完成！")
    except Exception as e:
        print(f"\n❌ 测试失败: {e}")
        sys.exit(1)