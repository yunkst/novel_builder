#!/usr/bin/env python3
"""
SQLAlchemy database models.

This module contains database model definitions for the application.
"""

# 重新导出分散在各个文件中的模型，确保使用统一的Base
from .models.cache import CacheTask, ChapterCache
from .models.scene_illustration import SceneIllustrationTask, SceneImageGallery
from .models.text2img import RoleCardTask, RoleImageGallery

# 导出所有模型，方便其他模块导入
__all__ = [
    "CacheTask",
    "ChapterCache",
    "RoleCardTask",
    "RoleImageGallery",
    "SceneIllustrationTask",
    "SceneImageGallery",
]
