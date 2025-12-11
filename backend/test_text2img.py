#!/usr/bin/env python3
"""
文生图功能测试脚本
"""

import asyncio
import json
import os
import sys
import requests

# 确保能导入当前app模块
from app.services.comfyui_client import create_comfyui_client
from app.services.dify_client import create_dify_client


async def test_comfyui_simple():
    """简单直接测试ComfyUI API"""
    print("🎨 简单测试 ComfyUI API...")

    try:
        # 直接使用requests测试
        import requests
        import uuid
        import time

        # 检查ComfyUI连接
        response = requests.get("http://host.docker.internal:8000/system_stats", timeout=10)
        print(f"✅ ComfyUI连接成功: {response.status_code}")

        # 加载工作流
        with open("./comfyui_json/text2img/image_netayume_lumina_t2i.json", 'r', encoding='utf-8') as f:
            workflow = json.load(f)

        # 修改提示词
        prompt = "anime style, Xishi from Honor of Kings, beautiful Chinese girl, purple dress, magical staff, masterpiece, best quality"
        print(f"📝 提示词: {prompt}")

        # 查找并修改提示词节点
        for node_id, node_data in workflow.items():
            if node_data.get("class_type") == "CLIPTextEncode":
                inputs = node_data.get("inputs", {})
                text = inputs.get("text", [])
                # 简单修改正面提示词
                if isinstance(text, str):
                    inputs["text"] = prompt
                elif isinstance(text, list):
                    # 找到正面提示词节点
                    for i, text_input in enumerate(text):
                        if isinstance(text_input, list) and len(text_input) > 1:
                            # 假设第一个是StringConcatenate节点
                            concat_node_id = str(text_input[0])
                            if concat_node_id in workflow:
                                concat_node = workflow[concat_node_id]
                                if concat_node.get("class_type") == "StringConcatenate":
                                    # 修改prompt输入
                                    for key in concat_node["inputs"]:
                                        if key not in ["string_a", "string_b", "delimiter"]:
                                            concat_node["inputs"][key] = prompt
                                            break
                break

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

                        # 检查各种完成状态
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
                                        local_path = f"/app/xishi_{filename}"
                                        with open(local_path, 'wb') as f:
                                            f.write(img_response.content)
                                        print(f"✅ 图片已保存: {local_path}")
                                        print(f"📁 文件大小: {len(img_response.content)} bytes")

                                        return {
                                            "filename": filename,
                                            "url": url,
                                            "local_path": local_path,
                                            "size": len(img_response.content)
                                        }
                                    else:
                                        print(f"❌ 图片下载失败: {img_response.status_code}")
                            break
                        elif status_str in ["error", "failed"]:
                            print(f"❌ 任务失败: {status}")
                            break

                    await asyncio.sleep(5)  # 等待5秒再检查

                else:
                    print("⏰ 任务超时")
            else:
                print("❌ 未找到任务ID")
        else:
            print(f"❌ 任务提交失败: {response.status_code} - {response.text}")

        return None

    except Exception as e:
        print(f"❌ 简单测试失败: {e}")
        import traceback
        traceback.print_exc()
        return None


async def test_comfyui_client():
    """使用客户端测试"""
    print("🎨 使用客户端测试 ComfyUI...")

    try:
        # 设置环境变量
        os.environ["COMFYUI_API_URL"] = "http://host.docker.internal:8000"
        os.environ["COMFYUI_WORKFLOW_PATH"] = "./comfyui_json/text2img/image_netayume_lumina_t2i.json"

        # 测试健康检查
        comfyui_client = create_comfyui_client()
        health = await comfyui_client.health_check()
        print(f"ComfyUI健康状态: {health}")

        if not health:
            print("❌ ComfyUI不健康，跳过生成测试")
            return None

        # 生成图片
        prompt = "anime style, Xishi from Honor of Kings, beautiful Chinese girl, purple dress, magical staff, masterpiece, best quality"
        print(f"📝 提示词: {prompt}")

        task_id = await comfyui_client.generate_image(prompt)
        print(f"✅ 任务ID: {task_id}")

        if task_id:
            print("⏳ 等待图片生成...")
            filenames = await comfyui_client.wait_for_completion(task_id, timeout=120)

            if filenames:
                print(f"🎉 生成成功: {filenames}")
                return filenames
            else:
                print("❌ 生成失败或超时")

        return None

    except Exception as e:
        print(f"❌ 客户端测试失败: {e}")
        return None


async def test_dify_simple():
    """简单测试Dify连接"""
    print("🧪 测试 Dify 连接...")

    try:
        os.environ["DIFY_API_URL"] = "http://host.docker.internal/v1/workflows/run"
        os.environ["DIFY_API_TOKEN"] = "test_dify_token_for_demo"

        dify_client = create_dify_client()

        # 健康检查
        health = await dify_client.health_check()
        print(f"Dify健康状态: {health}")

        return health

    except Exception as e:
        print(f"❌ Dify连接测试失败: {e}")
        return False


async def main():
    """主测试函数"""
    print("🚀 开始测试王者荣耀西施文生图功能")
    print("=" * 60)

    # 首先简单测试
    print("步骤1: 简单直接测试ComfyUI API")
    result = await test_comfyui_simple()

    if not result:
        print("\n步骤2: 使用客户端测试ComfyUI")
        result = await test_comfyui_client()

    if result:
        print("\n🎉 ComfyUI生图测试成功!")
        if isinstance(result, list) and result:
            print(f"生成了 {len(result)} 张图片")
        elif isinstance(result, dict):
            print(f"图片信息: {result}")
    else:
        print("\n❌ ComfyUI生图测试失败")

    # 简单测试Dify
    print("\n步骤3: 测试Dify连接")
    dify_health = await test_dify_simple()

    print("\n" + "=" * 60)
    print("✅ 测试完成")

    # 最终结果
    if result:
        print("\n🎯 最终结果:")
        print("📸 西施动漫风图片生成成功!")
        if isinstance(result, dict):
            print(f"🔗 访问URL: {result.get('url', 'N/A')}")
            print(f"💾 本地路径: {result.get('local_path', 'N/A')}")
    else:
        print("\n⚠️  建议:")
        print("1. 检查ComfyUI服务是否在 http://host.docker.internal:8000 运行")
        print("2. 确认工作流文件路径是否正确")
        print("3. 检查网络连接和代理设置")


if __name__ == "__main__":
    asyncio.run(main())