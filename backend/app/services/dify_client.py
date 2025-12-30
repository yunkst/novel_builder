"""
Dify工作流API客户端服务.

本章提供与Dify工作流交互的客户端功能，用于生成图片提示词和插入位置。
"""

import json
import logging
import os
from typing import Any

import requests
from requests.exceptions import RequestException, Timeout

from ..schemas import RoleInfo

logger = logging.getLogger(__name__)


class DifyClient:
    """Dify工作流API客户端."""

    def __init__(self, api_url: str, api_token: str):
        """初始化Dify客户端.

        Args:
            api_url: Dify API基础URL
            api_token: Dify API认证token
        """
        self.api_url = api_url.rstrip("/")
        self.api_token = api_token
        self.headers = {
            "Authorization": f"Bearer {api_token}",
            "Content-Type": "application/json",
        }

    async def generate_prompts(
        self, novel_content: str, roles: dict[str, Any] | None = None, require: str = ""
    ) -> list[str]:
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
                    "cmd": "文生图",
                },
                "response_mode": "blocking",
                "user": "text2img_user",
            }

            logger.info(f"调用Dify工作流: {self.api_url}")

            # 发送请求
            response = requests.post(
                self.api_url,
                headers=self.headers,
                json=request_data,
                timeout=60,  # Dify工作流可能需要较长时间
            )

            if response.status_code == 200:
                result = response.json()
                logger.info("Dify工作流调用成功")

                # 解析返回结果
                return self._parse_dify_response(result)

            else:
                logger.error(
                    f"Dify API请求失败: {response.status_code} - {response.text}"
                )
                return []

        except Timeout:
            logger.error("Dify API请求超时")
            return []
        except RequestException as e:
            logger.error(f"Dify API请求异常: {e}")
            return []
        except (OSError, requests.RequestException, ValueError, json.JSONDecodeError) as e:
            logger.error(f"Dify工作流调用失败: {e}")
            return []

    def _parse_dify_response(self, response_data: dict[str, Any]) -> list[str]:
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

                # 转换为字符串列表
                prompts = []
                for item in result_list:
                    if isinstance(item, str):
                        prompts.append(item)
                    elif isinstance(item, dict) and "img_prompt" in item:
                        prompts.append(str(item["img_prompt"]))
                    else:
                        prompts.append(str(item))

                logger.info(f"从Dify获取到 {len(prompts)} 个图片提示词")
                return prompts

            else:
                logger.error("Dify响应中未找到result字段")
                return []

        except (OSError, requests.RequestException, ValueError, json.JSONDecodeError) as e:
            logger.error(f"解析Dify响应失败: {e}")
            return []

    async def generate_photo_prompts(self, roles: list[RoleInfo]) -> list[str]:
        """生成人物卡拍照提示词.

        Args:
            roles: 人物卡设定信息列表 (RoleInfo 对象列表)

        Returns:
            生成的拍照提示词列表
        """
        try:
            # 将角色信息格式化为便于 AI 阅读的文本
            formatted_roles = self._format_roles_for_ai(roles)

            # 准备请求数据
            request_data = {
                "inputs": {
                    "roles": formatted_roles,
                    "user_input": "生成人物卡",
                    "cmd": "拍照",
                },
                "response_mode": "blocking",
                "user": "role_card_user",
            }

            logger.info(f"调用Dify拍照工作流: {self.api_url}")

            # 发送请求
            response = requests.post(
                self.api_url, headers=self.headers, json=request_data, timeout=60
            )

            if response.status_code == 200:
                result = response.json()
                logger.info("Dify拍照工作流调用成功")

                # 解析返回结果
                return self._parse_photo_response(result)

            else:
                logger.error(
                    f"Dify拍照API请求失败: {response.status_code} - {response.text}"
                )
                return []

        except Timeout:
            logger.error("Dify拍照API请求超时")
            return []
        except RequestException as e:
            logger.error(f"Dify拍照API请求异常: {e}")
            return []
        except (OSError, requests.RequestException, ValueError, json.JSONDecodeError) as e:
            logger.error(f"Dify拍照工作流调用失败: {e}")
            return []

    def _parse_photo_response(self, response_data: dict[str, Any]) -> list[str]:
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
                    for value in content_data.values():
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

        except (OSError, requests.RequestException, ValueError, json.JSONDecodeError) as e:
            logger.error(f"解析Dify拍照响应失败: {e}")
            return []

    async def generate_scene_prompts(
        self, chapters_content: str, roles: str
    ) -> str | None:
        """生成场面绘制提示词.

        Args:
            chapters_content: 章节内容
            roles: 格式化的角色信息字符串

        Returns:
            生成的提示词字符串，失败时返回None
        """
        try:
            request_data = {
                "inputs": {
                    "chapters_content": chapters_content,
                    "roles": roles,
                    "cmd": "场面绘制",
                },
                "response_mode": "blocking",
                "user": "scene_illustration_user",
            }

            logger.info(f"调用Dify场面绘制工作流: {self.api_url}")

            # 发送请求
            response = requests.post(
                self.api_url, headers=self.headers, json=request_data, timeout=60
            )

            if response.status_code == 200:
                result = response.json()
                logger.info("Dify场面绘制工作流调用成功")

                # 解析返回结果 - 期望格式: {content:{prompts:xx}}
                return self._parse_scene_response(result)

            else:
                logger.error(
                    f"Dify场面绘制API请求失败: {response.status_code} - {response.text}"
                )
                return None

        except Timeout:
            logger.error("Dify场面绘制API请求超时")
            return None
        except RequestException as e:
            logger.error(f"Dify场面绘制API请求异常: {e}")
            return None
        except (OSError, requests.RequestException, ValueError, json.JSONDecodeError) as e:
            logger.error(f"Dify场面绘制工作流调用失败: {e}")
            return None

    def _parse_scene_response(self, response_data: dict[str, Any]) -> str | None:
        """解析Dify场面绘制工作流返回结果.

        Args:
            response_data: Dify API响应数据

        Returns:
            解析后的提示词字符串，失败时返回None
        """
        try:
            # 获取工作流输出数据
            data = response_data.get("data", {})
            outputs = data.get("outputs", {})

            # 查找场面绘制提示词结果
            if "content" in outputs:
                content_data = outputs["content"]

                # 添加调试信息
                logger.info(f"Dify场面绘制返回的content数据类型: {type(content_data)}")
                logger.info(f"Dify场面绘制返回的content内容: {content_data}")

                # 期望格式: {content:{prompts:xx}}
                if isinstance(content_data, dict) and "prompts" in content_data:
                    prompts = content_data["prompts"]
                    if isinstance(prompts, str):
                        logger.info(f"从Dify获取到场面绘制提示词: {prompts}")
                        return prompts
                    else:
                        logger.warning(f"prompts不是字符串类型: {type(prompts)}")
                        return str(prompts) if prompts else None
                elif isinstance(content_data, str):
                    # 如果直接是字符串，返回该字符串
                    logger.info(
                        f"从Dify获取到场面绘制提示词(直接字符串): {content_data}"
                    )
                    return content_data
                else:
                    logger.error(f"Dify场面绘制返回数据格式不符合预期: {content_data}")
                    return None
            else:
                logger.error("Dify场面绘制响应中未找到content字段")
                return None

        except (OSError, requests.RequestException, ValueError, json.JSONDecodeError) as e:
            logger.error(f"解析Dify场面绘制响应失败: {e}")
            return None

    def _format_roles_for_ai(self, roles: list[RoleInfo] | dict[str, Any]) -> str:
        """将角色信息格式化为便于 AI 阅读的文本格式.

        Args:
            roles: 角色信息列表 (List[RoleInfo]) 或字典 (向后兼容)

        Returns:
            格式化后的角色描述文本

        Raises:
            TypeError: 当角色数据类型不支持时
            ValueError: 当角色列表包含无效对象时
        """
        if not roles:
            return "无特定角色信息"

        # 严格的类型检查
        if isinstance(roles, list):
            if not roles:
                return "无特定角色信息"

            # 验证列表中所有元素都是RoleInfo类型
            if not all(isinstance(role, RoleInfo) for role in roles):
                invalid_types = [
                    type(role).__name__
                    for role in roles
                    if not isinstance(role, RoleInfo)
                ]
                raise ValueError(
                    f"角色列表包含无效的对象类型: {', '.join(invalid_types)}"
                )

            role_description = "【出场人物】\n"

            for i, role in enumerate(roles, 1):
                # 验证必需字段
                if not hasattr(role, "name") or not role.name:
                    logger.warning(f"角色 {i} 缺少名称字段，跳过处理")
                    continue

                role_description += f"\n{i}. {role.name}\n"

                # 基本信息 - 安全的空值检查
                basic_info_parts = []
                if hasattr(role, "gender") and role.gender:
                    basic_info_parts.append(str(role.gender))
                if hasattr(role, "age") and role.age is not None:
                    basic_info_parts.append(f"{role.age}岁")
                if hasattr(role, "occupation") and role.occupation:
                    basic_info_parts.append(str(role.occupation))

                if basic_info_parts:
                    role_description += f"   基本信息：{'，'.join(basic_info_parts)}\n"

                # 其他字段的安全处理
                field_mappings = [
                    ("personality", "性格特点"),
                    ("appearance_features", "外貌特征"),
                    ("body_type", "身材体型"),
                    ("clothing_style", "穿衣风格"),
                    ("background_story", "背景经历"),
                ]

                for field, label in field_mappings:
                    if hasattr(role, field):
                        value = getattr(role, field)
                        if value:
                            role_description += f"   {label}：{value}\n"

                # AI绘图专用提示词
                has_face_prompts = hasattr(role, "face_prompts") and role.face_prompts
                has_body_prompts = hasattr(role, "body_prompts") and role.body_prompts

                if has_face_prompts or has_body_prompts:
                    role_description += "   【AI绘图提示词】\n"
                    if has_face_prompts:
                        role_description += f"   面部描述：{role.face_prompts}\n"
                    if has_body_prompts:
                        role_description += f"   身材描述：{role.body_prompts}\n"

            return role_description.strip()

        # 向后兼容：处理旧的Dict格式
        elif isinstance(roles, dict):
            if not roles:
                return "无特定角色信息"

            role_description = "【角色信息】\n"

            # 预定义的字段映射
            field_mappings = {
                "name": "姓名",
                "age": "年龄",
                "gender": "性别",
                "occupation": "职业",
                "personality": "性格特点",
                "appearance_features": "外貌特征",
                "body_type": "身材体型",
                "clothing_style": "穿衣风格",
                "face_prompts": "面部描述",
                "body_prompts": "身材描述",
            }

            for field, label in field_mappings.items():
                if roles.get(field):
                    value = roles[field]
                    # 特殊处理AI绘图提示词
                    if field in ["face_prompts", "body_prompts"]:
                        if not any(
                            keyword in role_description
                            for keyword in ["【AI绘图提示词】"]
                        ):
                            role_description += "\n【AI绘图提示词】\n"
                        role_description += f"{label}：{value}\n"
                    else:
                        role_description += f"{label}：{value}\n"

            return role_description.strip()

        else:
            raise TypeError(
                f"不支持的角色数据类型: {type(roles).__name__}，期望 List[RoleInfo] 或 Dict[str, Any]"
            )

    async def generate_video_prompts(self, prompts: str, user_input: str) -> str | None:
        """生成图生视频提示词.

        Args:
            prompts: 图片对应的提示词内容
            user_input: 用户要求

        Returns:
            生成的视频提示词字符串，失败时返回None
        """
        try:
            request_data = {
                "inputs": {
                    "prompts": prompts,
                    "user_input": user_input,
                    "cmd": "图生视频",
                },
                "response_mode": "blocking",
                "user": "image_to_video_user",
            }

            logger.info(f"调用Dify图生视频工作流: {self.api_url}")

            # 发送请求
            response = requests.post(
                self.api_url, headers=self.headers, json=request_data, timeout=60
            )

            if response.status_code == 200:
                result = response.json()
                logger.info("Dify图生视频工作流调用成功")

                # 解析返回结果 - 期望格式: {content:{prompts:xx}}
                return self._parse_video_response(result)

            else:
                logger.error(
                    f"Dify图生视频API请求失败: {response.status_code} - {response.text}"
                )
                return None

        except Timeout:
            logger.error("Dify图生视频API请求超时")
            return None
        except RequestException as e:
            logger.error(f"Dify图生视频API请求异常: {e}")
            return None
        except (OSError, requests.RequestException, ValueError, json.JSONDecodeError) as e:
            logger.error(f"Dify图生视频工作流调用失败: {e}")
            return None

    def _parse_video_response(self, response_data: dict[str, Any]) -> str | None:
        """解析Dify图生视频工作流返回结果.

        Args:
            response_data: Dify API响应数据

        Returns:
            解析后的视频提示词字符串，失败时返回None
        """
        try:
            # 获取工作流输出数据
            data = response_data.get("data", {})
            outputs = data.get("outputs", {})

            # 查找图生视频提示词结果
            if "content" in outputs:
                content_data = outputs["content"]

                # 添加调试信息
                logger.info(f"Dify图生视频返回的content数据类型: {type(content_data)}")
                logger.info(f"Dify图生视频返回的content内容: {content_data}")

                # 期望格式: {content:{prompts:xx}}
                if isinstance(content_data, dict) and "prompts" in content_data:
                    prompts = content_data["prompts"]
                    if isinstance(prompts, str):
                        logger.info(f"从Dify获取到图生视频提示词: {prompts}")
                        return prompts
                    else:
                        logger.warning(f"prompts不是字符串类型: {type(prompts)}")
                        return str(prompts) if prompts else None
                elif isinstance(content_data, str):
                    # 如果直接是字符串，返回该字符串
                    logger.info(
                        f"从Dify获取到图生视频提示词(直接字符串): {content_data}"
                    )
                    return content_data
                else:
                    logger.error(f"Dify图生视频返回数据格式不符合预期: {content_data}")
                    return None
            else:
                logger.error("Dify图生视频响应中未找到content字段")
                return None

        except (OSError, requests.RequestException, ValueError, json.JSONDecodeError) as e:
            logger.error(f"解析Dify图生视频响应失败: {e}")
            return None


def create_dify_client() -> DifyClient:
    """创建Dify客户端实例."""
    api_url = os.getenv("DIFY_API_URL", "http://host.docker.internal/v1/workflows/run")
    api_token = os.getenv("DIFY_API_TOKEN")

    if not api_token:
        raise ValueError("DIFY_API_TOKEN环境变量未设置")

    return DifyClient(api_url, api_token)
