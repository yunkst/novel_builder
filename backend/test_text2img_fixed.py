#!/usr/bin/env python3
"""
修复的文生图测试脚本 - 正确修改提示词节点
"""

import asyncio
import json
import os
import sys
import time

def test_fixed_workflow():
    """使用正确修改的工作流测试"""
    print("🎨 使用修复的工作流测试西施生成...")

    try:
        import requests

        # 加载工作流
        with open("./comfyui_json/text2img/image_netayume_lumina_t2i.json", 'r', encoding='utf-8') as f:
            workflow = json.load(f)

        # 创建西施的详细提示词
        xishi_prompt = """masterpiece, best quality, high resolution, 1girl, solo,
        Xishi from Honor of Kings, beautiful Chinese girl, elegant face, long flowing black hair,
        purple traditional hanfu dress, holding magical staff, standing in ancient Chinese palace,
        gentle smile, soft lighting, fantasy art, detailed eyes, ancient Chinese beauty,
        elegant pose, mystical atmosphere, anime style"""

        print(f"📝 西施提示词: {xishi_prompt[:100]}...")

        # 正确修改工作流：找到正面提示词的StringConcatenate节点 (26:22)
        # 26:22 连接了 26:23 (system prompt) + 26:24 (我们需要的提示词部分)

        # 方法1：直接修改 26:24 节点的内容
        if "26:24" in workflow:
            workflow["26:24"]["inputs"]["value"] = xishi_prompt
            print("✅ 直接修改 26:24 节点内容")

        # 方法2：备用 - 修改 26:22 的 string_b
        elif "26:22" in workflow:
            workflow["26:22"]["inputs"]["string_b"] = [xishi_prompt, 0]
            print("✅ 修改 26:22 节点的 string_b")

        # 提交任务
        prompt_data = {"prompt": workflow}
        response = requests.post("http://host.docker.internal:8000/prompt", json=prompt_data, timeout=30)
        print(f"📤 提交任务响应: {response.status_code}")

        if response.status_code == 200:
            result = response.json()
            task_id = result.get("prompt_id")
            if task_id:
                print(f"✅ 任务ID: {task_id}")

                # 轮询检查状态
                start_time = time.time()
                max_wait = 180  # 3分钟

                while time.time() - start_time < max_wait:
                    response = requests.get(f"http://host.docker.internal:8000/history/{task_id}", timeout=10)
                    if response.status_code == 200:
                        history = response.json()
                        task_info = history.get(task_id, {})
                        status = task_info.get("status", {})

                        status_str = status.get('status_str', 'unknown')
                        print(f"⏳ 任务状态: {status_str}")

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
                                print(f"📸 生成的图片: {images}")
                                for filename in images:
                                    url = f"http://host.docker.internal:8000/view?filename={filename}"
                                    print(f"🖼️  图片URL: {url}")

                                    # 下载图片
                                    img_response = requests.get(url, timeout=30)
                                    if img_response.status_code == 200:
                                        local_path = f"/app/xishi_fixed_{filename}"
                                        with open(local_path, 'wb') as f:
                                            f.write(img_response.content)
                                        print(f"✅ 图片已保存: {local_path}")
                                        print(f"📁 文件大小: {len(img_response.content)} bytes")

                                        return {
                                            "filename": filename,
                                            "url": url,
                                            "local_path": local_path,
                                            "size": len(img_response.content),
                                            "prompt": xishi_prompt
                                        }
                                    else:
                                        print(f"❌ 图片下载失败: {img_response.status_code}")
                            break
                        elif status_str in ["error", "failed"]:
                            print(f"❌ 任务失败: {status}")
                            break

                    time.sleep(5)  # 等待5秒再检查

                else:
                    print("⏰ 任务超时")
            else:
                print("❌ 未找到任务ID")
        else:
            print(f"❌ 任务提交失败: {response.status_code} - {response.text}")

        return None

    except Exception as e:
        print(f"❌ 修复测试失败: {e}")
        import traceback
        traceback.print_exc()
        return None


def main():
    """主测试函数"""
    print("🚀 开始修复版王者荣耀西施文生图测试")
    print("=" * 60)

    # 检查工作流结构
    with open("./comfyui_json/text2img/image_netayume_lumina_t2i.json", 'r', encoding='utf-8') as f:
        workflow = json.load(f)

    print("📋 工作流结构分析:")
    print(f"   节点总数: {len(workflow)}")

    # 找到关键节点
    for node_id, node_data in workflow.items():
        if "26:24" in node_id or "26:22" in node_id or "26:7" in node_id:
            class_type = node_data.get("class_type", "")
            print(f"   {node_id}: {class_type}")
            if "inputs" in node_data:
                for key, value in node_data["inputs"].items():
                    if key in ["string_a", "string_b", "value"]:
                        if isinstance(value, str):
                            print(f"     {key}: {value[:50]}...")
                        elif isinstance(value, list):
                            print(f"     {key}: [连接到其他节点]")

    print("\n" + "=" * 60)

    # 执行测试
    result = test_fixed_workflow()

    if result:
        print("\n🎉 修复版测试成功!")
        print(f"📸 西施动漫风图片生成成功!")
        print(f"🔗 访问URL: {result['url']}")
        print(f"💾 本地路径: {result['local_path']}")
        print(f"📝 使用的提示词: {result['prompt'][:100]}...")
    else:
        print("\n❌ 修复版测试失败")
        print("💡 建议:")
        print("1. 检查工作流JSON结构是否正确")
        print("2. 确认节点ID是否匹配")
        print("3. 检查ComfyUI服务状态")


if __name__ == "__main__":
    main()