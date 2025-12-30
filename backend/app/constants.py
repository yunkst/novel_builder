"""
应用常量定义.

定义应用中使用的各种常量，避免魔法数字。
"""

# HTTP 超时常量（秒）
TIMEOUT_FAST = 5  # 健康检查、快速请求
TIMEOUT_NORMAL = 10  # 普通请求
TIMEOUT_MEDIUM = 15  # 中等请求（一般页面加载）
TIMEOUT_SLOW = 30  # 慢速请求（复杂操作、图片生成）
TIMEOUT_DIFY = 60  # Dify 工作流（AI 处理可能较慢）
TIMEOUT_VIDEO_GENERATION = 3600  # 视频生成（1小时）

# HTTP 缓存常量（秒）
CACHE_NO_CACHE = 0  # 不缓存
CACHE_ONE_HOUR = 3600  # 1小时
CACHE_ONE_DAY = 86400  # 1天

# 数据库字段长度限制
MAX_IMAGES_JSON_LENGTH = 5000  # 图片列表JSON字符串的最大长度
