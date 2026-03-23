#!/usr/bin/env python3
"""
小说同步服务模块.

This module contains services for syncing novel data between APP and server,
including file-based storage for novel metadata, chapters, characters, etc.
"""

import hashlib
import json
import shutil
from datetime import datetime
from pathlib import Path
from typing import Any

from ..config import settings
from ..exceptions import NovelBuilderException
from ..schemas import (
    CharacterRelationSyncData,
    CharacterSyncData,
    ChapterSyncData,
    NovelSyncData,
    OutlineSyncData,
)


class NovelSyncServiceError(NovelBuilderException):
    """小说同步服务异常."""

    error_code = "NOVEL_SYNC_ERROR"


class NovelSyncService:
    """小说同步服务 - 管理小说数据在JSON格式和文件系统之间的转换."""

    def __init__(self, sync_dir: str | None = None):
        """
        初始化小说同步服务.

        Args:
            sync_dir: 小说同步数据存储目录
        """
        self.sync_dir = Path(sync_dir or settings.novel_sync_dir)
        self._ensure_sync_dir()

    def _ensure_sync_dir(self) -> None:
        """确保同步目录存在."""
        self.sync_dir.mkdir(parents=True, exist_ok=True)

    def _get_url_hash(self, url: str) -> str:
        """
        根据URL生成唯一的目录哈希值.

        Args:
            url: 小说URL

        Returns:
            URL的MD5哈希值（前16位）
        """
        return hashlib.md5(url.encode("utf-8")).hexdigest()[:16]

    def _get_novel_dir(self, url: str) -> Path:
        """
        获取小说存储目录路径.

        Args:
            url: 小说URL

        Returns:
            小说存储目录路径
        """
        url_hash = self._get_url_hash(url)
        return self.sync_dir / url_hash

    def _ensure_novel_dir(self, url: str) -> Path:
        """
        确保小说目录存在并返回路径.

        Args:
            url: 小说URL

        Returns:
            小说存储目录路径
        """
        novel_dir = self._get_novel_dir(url)
        novel_dir.mkdir(parents=True, exist_ok=True)
        return novel_dir

    def _save_meta(
        self,
        novel_dir: Path,
        novel_data: NovelSyncData,
        sync_version: int = 1,
    ) -> None:
        """
        保存小说元数据到meta.json.

        Args:
            novel_dir: 小说目录
            novel_data: 小说数据
            sync_version: 同步版本号
        """
        synced_at = datetime.now().isoformat()
        meta_data = {
            "novel_id": novel_data.novel_id,
            "title": novel_data.title,
            "author": novel_data.author,
            "description": novel_data.description,
            "cover_url": novel_data.cover_url,
            "source_url": novel_data.source_url,
            "total_chapters": novel_data.total_chapters,
            "total_words": novel_data.total_words,
            "last_read_chapter_id": novel_data.last_read_chapter_id,
            "last_read_position": novel_data.last_read_position,
            "is_favorite": novel_data.is_favorite,
            "created_at": novel_data.created_at,
            "updated_at": novel_data.updated_at,
            "sync_version": sync_version,
            "synced_at": synced_at,
        }

        meta_file = novel_dir / "meta.json"
        meta_file.write_text(
            json.dumps(meta_data, ensure_ascii=False, indent=2), encoding="utf-8"
        )
        return synced_at

    def _save_chapters(self, novel_dir: Path, chapters: list[ChapterSyncData]) -> None:
        """
        保存章节数据到chapters目录.

        Args:
            novel_dir: 小说目录
            chapters: 章节列表
        """
        chapters_dir = novel_dir / "chapters"
        chapters_dir.mkdir(exist_ok=True)

        for chapter in chapters:
            # 使用章节ID作为文件名
            chapter_file = chapters_dir / f"{chapter.chapter_id}.json"
            chapter_data = {
                "chapter_id": chapter.chapter_id,
                "title": chapter.title,
                "content": chapter.content,
                "chapter_index": chapter.chapter_index,
                "is_user_inserted": chapter.is_user_inserted,
                "created_at": chapter.created_at,
                "updated_at": chapter.updated_at,
            }
            chapter_file.write_text(
                json.dumps(chapter_data, ensure_ascii=False, indent=2), encoding="utf-8"
            )

    def _save_characters(
        self, novel_dir: Path, characters: list[CharacterSyncData]
    ) -> None:
        """
        保存角色数据到characters.json.

        Args:
            novel_dir: 小说目录
            characters: 角色列表
        """
        characters_data = [char.model_dump() for char in characters]
        characters_file = novel_dir / "characters.json"
        characters_file.write_text(
            json.dumps(characters_data, ensure_ascii=False, indent=2), encoding="utf-8"
        )

    def _save_character_relations(
        self, novel_dir: Path, relations: list[CharacterRelationSyncData]
    ) -> None:
        """
        保存角色关系数据到character_relations.json.

        Args:
            novel_dir: 小说目录
            relations: 角色关系列表
        """
        relations_data = [rel.model_dump() for rel in relations]
        relations_file = novel_dir / "character_relations.json"
        relations_file.write_text(
            json.dumps(relations_data, ensure_ascii=False, indent=2), encoding="utf-8"
        )

    def _save_outlines(
        self, novel_dir: Path, outlines: list[OutlineSyncData]
    ) -> None:
        """
        保存大纲数据到outline.json.

        Args:
            novel_dir: 小说目录
            outlines: 大纲列表
        """
        outlines_data = [outline.model_dump() for outline in outlines]
        outlines_file = novel_dir / "outline.json"
        outlines_file.write_text(
            json.dumps(outlines_data, ensure_ascii=False, indent=2), encoding="utf-8"
        )

    def save_novel(
        self,
        novel_data: NovelSyncData,
        force_overwrite: bool = False,
    ) -> dict[str, Any]:
        """
        保存小说数据到文件系统.

        Args:
            novel_data: 完整的小说同步数据
            force_overwrite: 是否强制覆盖（暂未实现，预留扩展）

        Returns:
            包含同步结果的字典：
            - success: 是否成功
            - novel_id: 小说ID
            - sync_version: 同步版本号
            - synced_at: 同步时间

        Raises:
            NovelSyncServiceError: 保存失败
        """
        try:
            # 使用source_url作为唯一标识
            url = novel_data.source_url or f"local_{novel_data.novel_id}"
            novel_dir = self._ensure_novel_dir(url)

            # 读取现有的meta.json获取sync_version（如果存在）
            meta_file = novel_dir / "meta.json"
            sync_version = 1
            if meta_file.exists():
                try:
                    existing_meta = json.loads(meta_file.read_text(encoding="utf-8"))
                    sync_version = existing_meta.get("sync_version", 1) + 1
                except (json.JSONDecodeError, KeyError):
                    pass

            # 保存元数据（包含sync_version，避免重复读写）
            synced_at = self._save_meta(novel_dir, novel_data, sync_version)

            # 保存章节数据
            if novel_data.chapters:
                self._save_chapters(novel_dir, novel_data.chapters)

            # 保存角色数据
            if novel_data.characters:
                self._save_characters(novel_dir, novel_data.characters)

            # 保存角色关系
            if novel_data.character_relations:
                self._save_character_relations(novel_dir, novel_data.character_relations)

            # 保存大纲数据
            if novel_data.outlines:
                self._save_outlines(novel_dir, novel_data.outlines)

            return {
                "success": True,
                "novel_id": novel_data.novel_id,
                "sync_version": sync_version,
                "synced_at": synced_at,
            }

        except Exception as e:
            raise NovelSyncServiceError(
                message=f"保存小说数据失败: {e}",
                details=f"小说ID: {novel_data.novel_id}, 标题: {novel_data.title}",
            )

    def _load_meta(self, novel_dir: Path) -> dict[str, Any] | None:
        """
        从meta.json加载小说元数据.

        Args:
            novel_dir: 小说目录

        Returns:
            元数据字典，如果文件不存在则返回None
        """
        meta_file = novel_dir / "meta.json"
        if not meta_file.exists():
            return None

        return json.loads(meta_file.read_text(encoding="utf-8"))

    def _load_chapters(self, novel_dir: Path) -> list[ChapterSyncData]:
        """
        从chapters目录加载章节数据.

        Args:
            novel_dir: 小说目录

        Returns:
            章节数据列表
        """
        chapters_dir = novel_dir / "chapters"
        if not chapters_dir.exists():
            return []

        chapters = []
        for chapter_file in sorted(chapters_dir.glob("*.json")):
            try:
                chapter_data = json.loads(chapter_file.read_text(encoding="utf-8"))
                chapters.append(ChapterSyncData(**chapter_data))
            except (json.JSONDecodeError, TypeError):
                continue  # 跳过无效的章节文件

        # 按章节序号排序
        chapters.sort(key=lambda x: x.chapter_index)
        return chapters

    def _load_characters(self, novel_dir: Path) -> list[CharacterSyncData]:
        """
        从characters.json加载角色数据.

        Args:
            novel_dir: 小说目录

        Returns:
            角色数据列表
        """
        characters_file = novel_dir / "characters.json"
        if not characters_file.exists():
            return []

        try:
            characters_data = json.loads(characters_file.read_text(encoding="utf-8"))
            return [CharacterSyncData(**char) for char in characters_data]
        except (json.JSONDecodeError, TypeError):
            return []

    def _load_character_relations(
        self, novel_dir: Path
    ) -> list[CharacterRelationSyncData]:
        """
        从character_relations.json加载角色关系数据.

        Args:
            novel_dir: 小说目录

        Returns:
            角色关系数据列表
        """
        relations_file = novel_dir / "character_relations.json"
        if not relations_file.exists():
            return []

        try:
            relations_data = json.loads(relations_file.read_text(encoding="utf-8"))
            return [CharacterRelationSyncData(**rel) for rel in relations_data]
        except (json.JSONDecodeError, TypeError):
            return []

    def _load_outlines(self, novel_dir: Path) -> list[OutlineSyncData]:
        """
        从outline.json加载大纲数据.

        Args:
            novel_dir: 小说目录

        Returns:
            大纲数据列表
        """
        outlines_file = novel_dir / "outline.json"
        if not outlines_file.exists():
            return []

        try:
            outlines_data = json.loads(outlines_file.read_text(encoding="utf-8"))
            return [OutlineSyncData(**outline) for outline in outlines_data]
        except (json.JSONDecodeError, TypeError):
            return []

    def load_novel(self, novel_url: str) -> NovelSyncData | None:
        """
        从文件系统加载小说数据.

        Args:
            novel_url: 小说URL（用于定位存储目录）

        Returns:
            完整的小说同步数据，如果不存在则返回None

        Raises:
            NovelSyncServiceError: 加载失败
        """
        try:
            novel_dir = self._get_novel_dir(novel_url)
            if not novel_dir.exists():
                return None

            meta_data = self._load_meta(novel_dir)
            if not meta_data:
                return None

            # 构建NovelSyncData
            novel_data = NovelSyncData(
                novel_id=meta_data["novel_id"],
                title=meta_data["title"],
                author=meta_data.get("author"),
                description=meta_data.get("description"),
                cover_url=meta_data.get("cover_url"),
                source_url=meta_data.get("source_url"),
                total_chapters=meta_data.get("total_chapters", 0),
                total_words=meta_data.get("total_words", 0),
                last_read_chapter_id=meta_data.get("last_read_chapter_id"),
                last_read_position=meta_data.get("last_read_position", 0),
                is_favorite=meta_data.get("is_favorite", False),
                created_at=meta_data.get("created_at"),
                updated_at=meta_data.get("updated_at"),
                chapters=self._load_chapters(novel_dir),
                characters=self._load_characters(novel_dir),
                character_relations=self._load_character_relations(novel_dir),
                outlines=self._load_outlines(novel_dir),
            )

            return novel_data

        except Exception as e:
            raise NovelSyncServiceError(
                message=f"加载小说数据失败: {e}",
                details=f"小说URL: {novel_url}",
            )

    def list_synced_novels(
        self, page: int = 1, page_size: int = 20
    ) -> dict[str, Any]:
        """
        列出已同步的小说列表.

        Args:
            page: 页码（从1开始）
            page_size: 每页数量

        Returns:
            包含小说列表和分页信息的字典：
            - novels: 小说元数据列表
            - total_count: 总数
            - page: 当前页码
            - page_size: 每页数量
        """
        novels = []

        # 遍历同步目录下的所有小说目录
        for novel_dir in self.sync_dir.iterdir():
            if not novel_dir.is_dir():
                continue

            meta_data = self._load_meta(novel_dir)
            if meta_data:
                # 只返回基本信息，不包含章节内容
                novels.append({
                    "novel_id": meta_data["novel_id"],
                    "title": meta_data["title"],
                    "author": meta_data.get("author"),
                    "source_url": meta_data.get("source_url"),
                    "total_chapters": meta_data.get("total_chapters", 0),
                    "sync_version": meta_data.get("sync_version", 1),
                    "synced_at": meta_data.get("synced_at"),
                })

        # 按同步时间倒序排列
        novels.sort(key=lambda x: x.get("synced_at") or "", reverse=True)

        # 分页
        total_count = len(novels)
        start_idx = (page - 1) * page_size
        end_idx = start_idx + page_size
        paginated_novels = novels[start_idx:end_idx]

        return {
            "novels": paginated_novels,
            "total_count": total_count,
            "page": page,
            "page_size": page_size,
        }

    def delete_novel(self, novel_url: str) -> bool:
        """
        删除已同步的小说数据.

        Args:
            novel_url: 小说URL

        Returns:
            是否成功删除

        Raises:
            NovelSyncServiceError: 删除失败
        """
        try:
            novel_dir = self._get_novel_dir(novel_url)
            if not novel_dir.exists():
                return False

            shutil.rmtree(novel_dir)
            return True

        except Exception as e:
            raise NovelSyncServiceError(
                message=f"删除小说数据失败: {e}",
                details=f"小说URL: {novel_url}",
            )

    def get_sync_status(self, novel_url: str) -> dict[str, Any] | None:
        """
        获取小说同步状态.

        Args:
            novel_url: 小说URL

        Returns:
            同步状态信息，如果不存在则返回None
        """
        novel_dir = self._get_novel_dir(novel_url)
        if not novel_dir.exists():
            return None

        meta_data = self._load_meta(novel_dir)
        if not meta_data:
            return None

        # 统计章节数量
        chapters_dir = novel_dir / "chapters"
        chapter_count = len(list(chapters_dir.glob("*.json"))) if chapters_dir.exists() else 0

        return {
            "novel_id": meta_data["novel_id"],
            "title": meta_data["title"],
            "sync_version": meta_data.get("sync_version", 1),
            "synced_at": meta_data.get("synced_at"),
            "chapter_count": chapter_count,
            "has_characters": (novel_dir / "characters.json").exists(),
            "has_character_relations": (novel_dir / "character_relations.json").exists(),
            "has_outlines": (novel_dir / "outline.json").exists(),
        }

    def novel_exists(self, novel_url: str) -> bool:
        """
        检查小说是否已同步.

        Args:
            novel_url: 小说URL

        Returns:
            是否存在
        """
        novel_dir = self._get_novel_dir(novel_url)
        return novel_dir.exists() and (novel_dir / "meta.json").exists()


# 创建单例实例
novel_sync_service = NovelSyncService()


def get_novel_sync_service() -> NovelSyncService:
    """获取小说同步服务实例."""
    return novel_sync_service