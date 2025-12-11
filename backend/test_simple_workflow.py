#!/usr/bin/env python3
"""
针对当前工作流JSON的简化测试脚本
"""

import asyncio
import json
import os
import time
import requests

def test_current_workflow():
    """测试当前工作流结构"""
    print("🎨 测试当前工作流结构...")

    try:
        # 加载工作流
        with open("./comfyui_json/text2img/image_netayume_lumina_t2i.json", 'r', encoding='utf-8') as f:
            workflow = json.load(f)

        print("📋 当前工作流分析:")

        # 分析所有节点
        for node_id, node_data in workflow.items():
            if node_id == "config":
                continue

            class_type = node_data.get("class_type", "")
            title = node_data.get("_meta", {}).get("title", "")

            print(f"   节点 {node_id}: {class_type} - {title}")

            # 特别关注CLIPTextEncode节点
            if class_type == "CLIPTextEncode":
                inputs = node_data.get("inputs", {})
                text = inputs.get("text", "")
                if isinstance(text, str):
                    print(f"      📝 提示词: {text[:80]}...")
                elif isinstance(text, list):
                    print(f"      🔗 连接到: {text}")

        print("\n" + "=" * 60)

        # 创建西施的完整提示词
        xishi_prompt = """masterpiece, best quality, high resolution, 1girl, solo,
        Xishi from Honor of Kings, beautiful ancient Chinese girl, elegant face,
        long flowing black hair, wearing purple hanfu traditional dress,
        holding magical purple staff, standing in ancient Chinese palace garden,
        gentle smile, soft lighting, fantasy art, detailed eyes, anime style,
        mystical atmosphere, detailed background, beautiful scenery"""

        print(f"🎯 目标提示词: {xishi_prompt[:100]}...")

        # 修改工作流
        if "4" in workflow:
            original_text = workflow["4"]["inputs"]["text"]
            print(f"📝 原始提示词: {original_text[:50]}...")

            # 替换为我们想要的西施提示词
            workflow["4"]["inputs"]["text"] = xishi_prompt
            print("✅ 已替换节点4的提示词")

        # 可选：也可以优化负面提示词
        if "5" in workflow:
            # 清理一下负面提示词，移除特定角色相关内容
            negative_prompt = """low quality, worst quality, blurry, jpeg artifacts, signature, watermark,
            username, error, deformed hands, bad anatomy, extra limbs, poorly drawn hands,
            poorly drawn face, mutation, deformed, extra eyes, extra arms, extra legs,
            malformed limbs, fused fingers, too many fingers, long neck, cross-eyed,
            bad proportions, missing arms, missing legs, extra digit, fewer digits, cropped"""

            workflow["5"]["inputs"]["text"] = negative_prompt
            print("✅ 已优化节点5的负面提示词")

        # 提交任务
        print("\n🚀 提交生图任务...")
        prompt_data = {"prompt": workflow}
        response = requests.post("http://host.docker.internal:8000/prompt", json=prompt_data, timeout=30)

        print(f"📤 响应状态: {response.status_code}")

        if response.status_code == 200:
            result = response.json()
            task_id = result.get("prompt_id")

            if task_id:
                print(f"✅ 任务ID: {task_id}")
                print("⏳ 等待图片生成...")

                # 轮询状态
                start_time = time.time()
                max_wait = 120  # 2分钟

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

                            # 获取生成的图片
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
                                    url = f"http://host.docker.internal:8000/view?filename={filename}"
                                    print(f"🖼️  URL: {url}")

                                    # 下载图片
                                    img_response = requests.get(url, timeout=30)
                                    if img_response.status_code == 200:
                                        local_path = f"/app/xishi_current_{filename}"
                                        with open(local_path, 'wb') as f:
                                            f.write(img_response.content)
                                        print(f"✅ 已保存: {local_path}")
                                        print(f"📁 大小: {len(img_response.content)} bytes")

                                        return {
                                            "filename": filename,
                                            "url": url,
                                            "local_path": local_path,
                                            "size": len(img_response.content)
                                        }

                            break
                        elif status_str in ["error", "failed"]:
                            print(f"❌ 任务失败: {status}")
                            break

                    time.sleep(5)

                else:
                    print("⏰ 任务超时")
            else:
                print("❌ 未找到任务ID")
        else:
            print(f"❌ 提交失败: {response.text}")

        return None

    except Exception as e:
        print(f"❌ 测试失败: {e}")
        import traceback
        traceback.print_exc()
        return None

def main():
    """主函数"""
    print("🔍 分析当前工作流JSON结构并测试西施生成")
    print("=" * 70)

    result = test_current_workflow()

    if result:
        print("\n🎉 测试成功!")
        print(f"📸 西施图片: {result['url']}")
        print(f"💾 本地路径: {result['local_path']}")
    else:
        print("\n❌ 测试失败")

    print("=" * 70)
    print("✅ 分析完成")

if __name__ == "__main__":
    main()