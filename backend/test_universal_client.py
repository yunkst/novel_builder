#!/usr/bin/env python3
"""
通用客户端完整测试
"""

import asyncio
import time

from app.services.comfyui_client_title_based import create_comfyui_client_title_based

async def test_universal_client():
    """测试通用客户端"""
    print("🔧 测试基于标题的通用ComfyUI客户端")
    print("=" * 60)

    try:
        # 创建客户端
        client = create_comfyui_client_title_based()

        # 分析工作流结构
        print("📊 分析工作流结构:")
        analysis = client.analyze_workflow()

        print(f"   总节点数: {analysis['total_nodes']}")
        print(f"   有标题的节点: {analysis['nodes_with_titles']}")
        print(f"   CLIP文本节点: {analysis['clip_text_nodes']}")

        print("\n🎯 节点详情:")
        for node_id, details in analysis["node_details"].items():
            target_mark = "🎯" if details["is_target"] else "  "
            print(f"   {target_mark} 节点 {node_id}: {details['class_type']} - '{details['title']}'")
            if details["has_text_input"]:
                print(f"      ✅ 包含文本输入")

        # 测试不同的提示词
        test_prompts = [
            {
                "name": "西施-古代美女",
                "prompt": """masterpiece, best quality, 1girl, solo,
                Xishi from Honor of Kings, beautiful ancient Chinese girl,
                elegant face, long flowing black hair, wearing purple hanfu dress,
                gentle smile, ancient Chinese palace background"""
            },
            {
                "name": "现代女孩",
                "prompt": """masterpiece, best quality, 1girl, solo,
                beautiful modern girl, long hair, casual clothes,
                smiling, outdoor scene, soft lighting, detailed face"""
            },
            {
                "name": "动漫风景",
                "prompt": """masterpiece, best quality, anime scenery,
                beautiful sunset over mountains, vibrant colors,
                detailed landscape, fantasy art, high resolution"""
            }
        ]

        print(f"\n🚀 开始测试 {len(test_prompts)} 个不同场景:")

        for i, test_case in enumerate(test_prompts, 1):
            print(f"\n{i}. 📝 测试: {test_case['name']}")
            print(f"   提示词: {test_case['prompt'][:60]}...")

            # 提交生成任务
            task_id = await client.generate_image_by_title(test_case['prompt'])

            if task_id:
                print(f"   ✅ 任务ID: {task_id}")

                # 等待完成
                start_time = time.time()
                max_wait = 60  # 1分钟

                while time.time() - start_time < max_wait:
                    status = await client.check_task_status(task_id)
                    status_str = status.get("status_str", "unknown")
                    print(f"   ⏳ 状态: {status_str}")

                    if status_str in ["completed", "success"]:
                        print(f"   🎉 完成!")

                        # 获取图片信息
                        filenames = await client.wait_for_completion(task_id, timeout=1)
                        if filenames:
                            print(f"   📸 生成图片: {filenames[0]}")
                            url = client.get_image_url(filenames[0])
                            print(f"   🔗 URL: {url}")
                        break
                    elif status_str in ["error", "failed"]:
                        print(f"   ❌ 失败")
                        break

                    await asyncio.sleep(5)

                if time.time() - start_time >= max_wait:
                    print(f"   ⏰ 超时")

            else:
                print(f"   ❌ 任务提交失败")

        print(f"\n✅ 测试完成!")

    except Exception as e:
        print(f"❌ 测试失败: {e}")
        import traceback
        traceback.print_exc()

async def main():
    """主函数"""
    print("🎯 ComfyUI通用客户端完整测试")
    print("=" * 70)

    await test_universal_client()

    print("\n" + "=" * 70)
    print("✅ 所有测试完成!")

if __name__ == "__main__":
    asyncio.run(main())