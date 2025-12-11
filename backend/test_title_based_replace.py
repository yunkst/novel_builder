#!/usr/bin/env python3
"""
基于节点标题的通用替换测试
"""

import asyncio
import json
import os
import time
import requests

def find_nodes_by_title(workflow_data, target_titles):
    """根据节点标题查找节点"""
    matching_nodes = {}

    for node_id, node_data in workflow_data.items():
        if node_id == "config":
            continue

        meta = node_data.get("_meta", {})
        title = meta.get("title", "")

        # 检查标题是否匹配目标标题
        for target_title in target_titles:
            if target_title.lower() in title.lower():
                matching_nodes[node_id] = {
                    "title": title,
                    "class_type": node_data.get("class_type"),
                    "inputs": node_data.get("inputs", {})
                }
                break

    return matching_nodes

def test_title_based_replacement():
    """测试基于节点标题的替换逻辑"""
    print("🔍 测试基于节点标题的替换逻辑...")

    try:
        # 加载工作流
        with open("./comfyui_json/text2img/image_netayume_lumina_t2i.json", 'r', encoding='utf-8') as f:
            workflow = json.load(f)

        print("📋 分析节点标题:")

        # 查找所有节点及其标题
        all_nodes = {}
        for node_id, node_data in workflow.items():
            if node_id == "config":
                continue
            meta = node_data.get("_meta", {})
            title = meta.get("title", "")
            class_type = node_data.get("class_type", "")

            print(f"   节点 {node_id}: {class_type} - '{title}'")
            all_nodes[node_id] = {
                "title": title,
                "class_type": class_type,
                "inputs": node_data.get("inputs", {})
            }

        print("\n" + "=" * 60)

        # 定义目标标题列表
        target_titles = ["prompts", "提示词", "CLIP Text Encode", "prompt", "positive"]

        print(f"🎯 目标标题: {target_titles}")

        # 查找匹配的节点
        matching_nodes = find_nodes_by_title(workflow, target_titles)

        print(f"\n📍 找到 {len(matching_nodes)} 个匹配节点:")
        for node_id, info in matching_nodes.items():
            print(f"   节点 {node_id}: {info['class_type']} - '{info['title']}'")
            if "text" in info["inputs"]:
                text = info["inputs"]["text"]
                print(f"      📝 当前内容: {str(text)[:60]}...")

        # 创建西施提示词
        xishi_prompt = """masterpiece, best quality, high resolution, 1girl, solo,
        Xishi from Honor of Kings, beautiful ancient Chinese girl, elegant face,
        long flowing black hair, wearing purple hanfu traditional dress,
        holding magical purple staff, standing in ancient Chinese palace garden,
        gentle smile, soft lighting, fantasy art, detailed eyes, anime style"""

        print(f"\n🎨 准备替换为: {xishi_prompt[:100]}...")

        # 执行替换
        replaced_count = 0
        for node_id in matching_nodes.keys():
            if "text" in workflow[node_id]["inputs"]:
                original_text = workflow[node_id]["inputs"]["text"]
                workflow[node_id]["inputs"]["text"] = xishi_prompt
                print(f"✅ 已替换节点 {node_id}")
                replaced_count += 1

        print(f"\n📊 总共替换了 {replaced_count} 个节点")

        # 验证替换结果
        print("\n🔍 验证替换结果:")
        for node_id, info in matching_nodes.items():
            if "text" in workflow[node_id]["inputs"]:
                new_text = workflow[node_id]["inputs"]["text"]
                print(f"   节点 {node_id}: {str(new_text)[:80]}...")

        # 提交任务测试
        print("\n" + "=" * 60)
        print("🚀 提交生图任务测试...")

        prompt_data = {"prompt": workflow}
        response = requests.post("http://host.docker.internal:8000/prompt", json=prompt_data, timeout=30)

        if response.status_code == 200:
            result = response.json()
            task_id = result.get("prompt_id")
            if task_id:
                print(f"✅ 任务提交成功: {task_id}")

                # 轮询状态
                start_time = time.time()
                max_wait = 120

                while time.time() - start_time < max_wait:
                    response = requests.get(f"http://host.docker.internal:8000/history/{task_id}", timeout=10)
                    if response.status_code == 200:
                        history = response.json()
                        task_info = history.get(task_id, {})
                        status = task_info.get("status", {})
                        status_str = status.get('status_str', 'unknown')
                        print(f"⏳ 状态: {status_str}")

                        if status_str in ["completed", "success"]:
                            print("🎉 任务完成!")

                            outputs = task_info.get("outputs", {})
                            images = []
                            for node_id, node_output in outputs.items():
                                if "images" in node_output:
                                    for image in node_output["images"]:
                                        filename = image.get("filename")
                                        if filename:
                                            images.append(filename)

                            if images:
                                print(f"📸 生成图片: {images}")
                                for filename in images:
                                    url = f"http://localhost:8000/view?filename={filename}"
                                    print(f"🖼️ URL: {url}")
                                    return {
                                        "success": True,
                                        "filename": filename,
                                        "url": url,
                                        "task_id": task_id,
                                        "replaced_nodes": len(matching_nodes)
                                    }
                            break
                        elif status_str in ["error", "failed"]:
                            print(f"❌ 任务失败: {status}")
                            break

                    time.sleep(5)

                print("⏰ 任务超时")
            else:
                print("❌ 未找到任务ID")
        else:
            print(f"❌ 任务提交失败: {response.status_code}")

    except Exception as e:
        print(f"❌ 测试失败: {e}")
        import traceback
        traceback.print_exc()

    return {"success": False}

def main():
    """主函数"""
    print("🔍 基于节点标题的通用替换测试")
    print("=" * 70)

    result = test_title_based_replacement()

    print("\n" + "=" * 70)
    if result.get("success"):
        print("🎉 基于标题的替换测试成功!")
        print(f"📸 图片: {result['url']}")
        print(f"🔧 替换节点数: {result.get('replaced_nodes', 0)}")
    else:
        print("❌ 测试失败")

    print("✅ 测试完成")

if __name__ == "__main__":
    main()