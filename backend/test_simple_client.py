#!/usr/bin/env python3
"""
简化的客户端测试
"""

import asyncio
import sys
import os

# 添加app目录到Python路径
sys.path.append(os.path.join(os.path.dirname(__file__), '.'))

from app.services.comfyui_client import create_comfyui_client

async def test_simple_client():
    """测试简化的ComfyUI客户端"""
    print("测试简化的ComfyUI客户端...")

    try:
        # 创建客户端
        client = create_comfyui_client()

        # 检查目标标题配置
        print(f"目标标题: {client.target_titles}")

        # 分析工作流
        analysis = client.analyze_workflow()
        print(f"总节点数: {analysis['total_nodes']}")
        print(f"有标题的节点: {analysis['nodes_with_titles']}")
        print(f"CLIP文本节点: {analysis['clip_text_nodes']}")

        # 查找匹配的节点
        matching_nodes = {}
        for node_id, node_data in client.workflow_json.items():
            if node_id == "config":
                continue

            meta = node_data.get("_meta", {})
            title = meta.get("title", "")

            # 检查是否匹配目标标题
            for target_title in client.target_titles:
                if target_title.lower() in title.lower():
                    matching_nodes[node_id] = {
                        "title": title,
                        "class_type": node_data.get("class_type"),
                        "has_text": "text" in node_data.get("inputs", {})
                    }
                    break

        print(f"\n匹配的节点:")
        for node_id, info in matching_nodes.items():
            print(f"  节点 {node_id}: {info['title']} ({info['class_type']})")
            if info['has_text']:
                inputs = client.workflow_json[node_id]['inputs']
                current_text = inputs['text']
                print(f"    当前文本: {str(current_text)[:50]}...")

        print(f"\n测试完成，找到 {len(matching_nodes)} 个可替换的节点")

        return len(matching_nodes) > 0

    except Exception as e:
        print(f"测试失败: {e}")
        import traceback
        traceback.print_exc()
        return False

async def main():
    """主函数"""
    print("ComfyUI客户端简化测试")
    print("=" * 40)

    success = await test_simple_client()

    print("\n" + "=" * 40)
    if success:
        print("测试成功!")
    else:
        print("测试失败!")

if __name__ == "__main__":
    asyncio.run(main())