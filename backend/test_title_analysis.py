#!/usr/bin/env python3
"""
节点标题分析测试
"""

import json

def analyze_workflow_titles():
    """分析工作流中的节点标题"""
    print("🔍 分析工作流节点标题...")

    try:
        # 加载工作流
        with open("./comfyui_json/text2img/image_netayume_lumina_t2i.json", 'r', encoding='utf-8') as f:
            workflow = json.load(f)

        print("📋 完整节点分析:")

        # 定义常用的提示词相关标题模式
        prompt_titles = [
            "prompts", "prompt", "提示词", "text", "文本", "positive", "negative",
            "CLIP", "Encode", "文本编码", "CLIP文本"
        ]

        matching_nodes = {}

        for node_id, node_data in workflow.items():
            if node_id == "config":
                continue

            class_type = node_data.get("class_type", "")
            meta = node_data.get("_meta", {})
            title = meta.get("title", "")

            print(f"\n节点 {node_id}:")
            print(f"  类型: {class_type}")
            print(f"  标题: '{title}'")

            # 检查是否包含提示词相关的标题
            is_prompt_related = any(keyword.lower() in title.lower() for keyword in prompt_titles)

            if is_prompt_related:
                print(f"  🎯 匹配提示词标题: ✅")
                matching_nodes[node_id] = {
                    "title": title,
                    "class_type": class_type,
                    "reasons": [keyword for keyword in prompt_titles if keyword.lower() in title.lower()]
                }
            else:
                print(f"  📝 普通节点")

            # 检查是否有text输入
            inputs = node_data.get("inputs", {})
            has_text = "text" in inputs
            if has_text:
                print(f"  ✅ 包含text输入")

                # 显示当前text内容预览
                text_content = inputs["text"]
                if isinstance(text_content, str):
                    print(f"      内容: {text_content[:50]}...")
            else:
                print(f"  ❌ 无text输入")

        print(f"\n" + "=" * 60)
        print(f"📊 分析结果:")
        print(f"   总节点数: {len(workflow)}")
        print(f"   匹配提示词的节点: {len(matching_nodes)}")

        print(f"\n🎯 推荐替换策略:")
        for node_id, info in matching_nodes.items():
            print(f"   节点 {node_id}: '{info['title']}'")
            print(f"      匹配原因: {', '.join(info['reasons'])}")
            print(f"      类型: {info['class_type']}")

            # 检查是否适合作为主要替换目标
            if "prompts" in info['title'].lower():
                print(f"      🏆 推荐作为主要替换目标!")
            elif "positive" in info['title'].lower():
                print(f"      ✅ 可以作为正面提示词替换目标")
            elif "negative" in info['title'].lower():
                print(f"      ⚠️  这是负面提示词节点")

        # 提供最终的替换建议
        print(f"\n💡 最佳实践建议:")
        print(f"   1. 优先替换标题为 'prompts' 的节点 (节点4)")
        print(f"   2. 如果找不到 'prompts' 节点，可以查找包含 'positive' 的节点")
        print(f"   3. 避免替换包含 'negative' 的节点")
        print(f"   4. 使用模糊匹配 (如包含 'text' 或 'CLIP' 的节点)")

        return matching_nodes

    except Exception as e:
        print(f"❌ 分析失败: {e}")
        return {}

def main():
    """主函数"""
    print("🎯 工作流节点标题完整分析")
    print("=" * 70)

    result = analyze_workflow_titles()

    print("\n" + "=" * 70)
    print("✅ 分析完成!")

    if result:
        print(f"\n🎉 找到 {len(result)} 个可替换的提示词节点!")
    else:
        print("\n⚠️  未找到合适的提示词节点，请检查工作流结构")

if __name__ == "__main__":
    main()