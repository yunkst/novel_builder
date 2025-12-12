"""
Dify工作流API客户端服务.

本章提供与Dify工作流交互的客户端功能，用于生成图片提示词和插入位置。
"""

import json
import logging
import os
from typing import Dict, Any, List, Optional

import requests
from requests.exceptions import RequestException, Timeout

from ..schemas import DifyPromptResult, DifyPhotoResult

logger = logging.getLogger(__name__)


class DifyClient:
    """Dify工作流API客户端."""

    def __init__(self, api_url: str, api_token: str):
        """初始化Dify客户端.

        Args:
            api_url: Dify API基础URL
            api_token: Dify API认证token
        """
        self.api_url = api_url.rstrip('/')
        self.api_token = api_token
        self.headers = {
            "Authorization": f"Bearer {api_token}",
            "Content-Type": "application/json"
        }

    async def generate_prompts(self, novel_content: str, roles: Optional[Dict[str, Any]] = None,
                             require: str = "") -> List[DifyPromptResult]:
        """生成图片提示词.

        Args:
            novel_content: 小说内容
            roles: 角色信息
            require: 配图要求

        Returns:
            生成的提示词结果列表
        """
        try:
            # 准备请求数据
            request_data = {
                "inputs": {
                    "chapters_content": novel_content,
                    "roles": json.dumps(roles) if roles else "{}",
                    "user_input": require,
                    "cmd": "文生图"
                },
                "response_mode": "blocking",
                "user": "text2img_user"
            }

            logger.info(f"调用Dify工作流: {self.api_url}")

            # 发送请求
            response = requests.post(
                self.api_url,
                headers=self.headers,
                json=request_data,
                timeout=60  # Dify工作流可能需要较长时间
            )

            if response.status_code == 200:
                result = response.json()
                logger.info("Dify工作流调用成功")

                # 解析返回结果
                return self._parse_dify_response(result)

            else:
                logger.error(f"Dify API请求失败: {response.status_code} - {response.text}")
                return []

        except Timeout:
            logger.error("Dify API请求超时")
            return []
        except RequestException as e:
            logger.error(f"Dify API请求异常: {e}")
            return []
        except Exception as e:
            logger.error(f"Dify工作流调用失败: {e}")
            return []

    def _parse_dify_response(self, response_data: Dict[str, Any]) -> List[DifyPromptResult]:
        """解析Dify工作流返回结果.

        Args:
            response_data: Dify API响应数据

        Returns:
            解析后的提示词结果列表
        """
        try:
            # 获取工作流输出数据
            data = response_data.get("data", {})
            outputs = data.get("outputs", {})

            # 查找图片提示词结果
            # 根据Dify工作流的实际输出结构调整这里
            if "result" in outputs:
                result_data = outputs["result"]

                # 如果是字符串，尝试解析JSON
                if isinstance(result_data, str):
                    try:
                        result_list = json.loads(result_data)
                    except json.JSONDecodeError:
                        logger.error("Dify返回的不是有效的JSON格式")
                        return []
                elif isinstance(result_data, list):
                    result_list = result_data
                else:
                    logger.error(f"不支持的Dify返回数据类型: {type(result_data)}")
                    return []

                # 转换为DifyPromptResult对象
                prompts = []
                for item in result_list:
                    if isinstance(item, dict) and "index" in item and "img_prompt" in item:
                        prompts.append(DifyPromptResult(
                            index=int(item["index"]),
                            img_prompt=str(item["img_prompt"])
                        ))

                logger.info(f"从Dify获取到 {len(prompts)} 个图片提示词")
                return prompts

            else:
                logger.error("Dify响应中未找到result字段")
                return []

        except Exception as e:
            logger.error(f"解析Dify响应失败: {e}")
            return []

    async def health_check(self) -> bool:
        """检查Dify服务健康状态.

        Returns:
            服务是否可用
        """
        try:
            # 尝试调用一个简单的请求来检查连通性
            test_request = {
                "inputs": {
                    "chapters_content": "test",
                    "roles": "{}",
                    "user_input": "test",
                    "cmd": "test"
                },
                "response_mode": "blocking",
                "user": "health_check"
            }

            response = requests.post(
                self.api_url,
                headers=self.headers,
                json=test_request,
                timeout=10
            )

            # 只要能连通就认为健康，不管业务逻辑结果
            return response.status_code in [200, 400, 422]  # 422可能是因为参数验证失败，但说明服务可用

        except Exception as e:
            logger.error(f"Dify健康检查失败: {e}")
            return False

    async def generate_photo_prompts(self, roles: Dict[str, Any], user_input: str) -> List[str]:
        """生成人物卡拍照提示词.

        Args:
            roles: 人物卡设定信息
            user_input: 用户要求

        Returns:
            生成的拍照提示词列表
        """
        try:
            # 准备请求数据
            request_data = {
                "inputs": {
                    "roles": json.dumps(roles, ensure_ascii=False),
                    "user_input": user_input,
                    "cmd": "拍照"
                },
                "response_mode": "blocking",
                "user": "role_card_user"
            }

            logger.info(f"调用Dify拍照工作流: {self.api_url}")

            # 发送请求
            response = requests.post(
                self.api_url,
                headers=self.headers,
                json=request_data,
                timeout=60
            )

            if response.status_code == 200:
                result = response.json()
                logger.info("Dify拍照工作流调用成功")

                # 解析返回结果
                return self._parse_photo_response(result)

            else:
                logger.error(f"Dify拍照API请求失败: {response.status_code} - {response.text}")
                return []

        except Timeout:
            logger.error("Dify拍照API请求超时")
            return []
        except RequestException as e:
            logger.error(f"Dify拍照API请求异常: {e}")
            return []
        except Exception as e:
            logger.error(f"Dify拍照工作流调用失败: {e}")
            return []

    def _parse_photo_response(self, response_data: Dict[str, Any]) -> List[str]:
        """解析Dify拍照工作流返回结果.

        Args:
            response_data: Dify API响应数据

        Returns:
            解析后的提示词列表
        """
        try:
            # 获取工作流输出数据
            data = response_data.get("data", {})
            outputs = data.get("outputs", {})

            # 查找拍照提示词结果
            if "content" in outputs:
                content_data = outputs["content"]

                # 添加调试信息
                logger.info(f"Dify返回的content数据类型: {type(content_data)}")
                logger.info(f"Dify返回的content内容: {content_data}")

                # 如果是字符串，尝试解析JSON
                if isinstance(content_data, str):
                    try:
                        content_list = json.loads(content_data)
                    except json.JSONDecodeError:
                        # 如果不是JSON，可能是直接的字符串列表
                        content_list = [content_data]
                elif isinstance(content_data, list):
                    content_list = content_data
                elif isinstance(content_data, dict):
                    # 如果是字典，尝试提取提示词列表
                    content_list = []
                    for key, value in content_data.items():
                        if isinstance(value, str):
                            content_list.append(value)
                        elif isinstance(value, list):
                            content_list.extend([str(item) for item in value if item])
                    logger.info(f"从dict中提取的content_list: {content_list}")
                else:
                    logger.error(f"不支持的Dify拍照返回数据类型: {type(content_data)}")
                    return []

                # 确保返回字符串列表
                prompts = []
                for item in content_list:
                    if isinstance(item, str):
                        prompts.append(item)
                    elif isinstance(item, dict) and "prompt" in item:
                        prompts.append(str(item["prompt"]))
                    else:
                        logger.warning(f"跳过无效的提示词项: {item}")

                logger.info(f"从Dify获取到 {len(prompts)} 个拍照提示词")
                return prompts

            else:
                logger.error("Dify拍照响应中未找到content字段")
                return []

        except Exception as e:
            logger.error(f"解析Dify拍照响应失败: {e}")
            return []


def create_dify_client() -> DifyClient:
    """创建Dify客户端实例."""
    api_url = os.getenv("DIFY_API_URL", "http://host.docker.internal/v1/workflows/run")
    api_token = os.getenv("DIFY_API_TOKEN")

    if not api_token:
        raise ValueError("DIFY_API_TOKEN环境变量未设置")

    return DifyClient(api_url, api_token)