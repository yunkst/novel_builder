#!/usr/bin/env python3
"""
小说同步服务模块.

This module contains services for syncing novel data between APP and server,
including file-based storage for novel metadata, chapters, characters, etc.

存储格式:
novel_sync/
└── 斗破苍穹/                  # 用小说标题做目录名（需处理非法字符）
    ├── meta.json             # 琐碎元数据（novel_id, source_url, sync_version 等）
    ├── chapters/
    │   ├── 001_第一章.txt     # 章节用纯文本，格式：{序号}_{标题}.txt
    │   └── ...
    ├── outlines/             # 大纲目录
    │   ├── 主线大纲.txt
    │   └── ...
    └── characters/           # 人物卡目录
        ├── 萧炎.json         # 每个人物单独一个 JSON
        └── 药老.json
"""

import json
import logging
import shutil
import tempfile
from datetime import datetime
from pathlib import Path
from typing import Any

logger = logging.getLogger(__name__)

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

    # Windows 文件名非法字符
    ILLEGAL_FILENAME_CHARS = r'<>:"/\|?*'

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

    def _sanitize_filename(self, name: str) -> str:
        """
        清理文件名中的非法字符.

        Args:
            name: 原始文件名

        Returns:
            清理后的安全文件名
        """
        # 替换非法字符为下划线
        safe_name = name
        for char in self.ILLEGAL_FILENAME_CHARS:
            safe_name = safe_name.replace(char, "_")
        # 移除首尾空格和点
        safe_name = safe_name.strip(" .")
        # 如果清理后为空，使用默认名称
        return safe_name or "unnamed"

    def _find_novel_dir_by_url(self, source_url: str) -> Path | None:
        """
        通过遍历目录查找小说目录（基于 meta.json 中的 source_url）.

        Args:
            source_url: 小说来源 URL

        Returns:
            小说目录路径，如果未找到则返回 None
        """
        for novel_dir in self.sync_dir.iterdir():
            if not novel_dir.is_dir():
                continue

            meta_file = novel_dir / "meta.json"
            if not meta_file.exists():
                continue

            try:
                meta_data = json.loads(meta_file.read_text(encoding="utf-8"))
                if meta_data.get("source_url") == source_url:
                    return novel_dir
            except (json.JSONDecodeError, KeyError):
                continue

        return None

    def _find_novel_dir_by_name(self, name: str) -> Path | None:
        """
        通过目录名查找小说目录.

        Args:
            name: 小说目录名（即小说标题）

        Returns:
            小说目录路径，如果未找到则返回 None
        """
        safe_name = self._sanitize_filename(name)
        novel_dir = self.sync_dir / safe_name
        if novel_dir.exists() and novel_dir.is_dir():
            return novel_dir
        return None

    def _find_or_create_novel_dir(self, title: str, source_url: str | None) -> Path:
        """
        查找或创建小说目录.

        如果找到匹配 source_url 的目录则返回该目录，
        否则根据标题创建新目录（处理标题冲突）。

        Args:
            title: 小说标题
            source_url: 小说来源 URL

        Returns:
            小说目录路径
        """
        # 首先尝试通过 source_url 查找已存在的目录
        if source_url:
            existing_dir = self._find_novel_dir_by_url(source_url)
            if existing_dir:
                return existing_dir

        # 根据标题创建新目录
        safe_title = self._sanitize_filename(title)
        novel_dir = self.sync_dir / safe_title

        # 处理标题冲突：如果目录已存在且不是当前小说的目录，追加数字后缀
        if novel_dir.exists():
            # 检查该目录是否属于当前小说（通过 meta.json 的 source_url）
            meta_file = novel_dir / "meta.json"
            is_same_novel = False
            if meta_file.exists():
                try:
                    meta_data = json.loads(meta_file.read_text(encoding="utf-8"))
                    if meta_data.get("source_url") == source_url:
                        is_same_novel = True
                except (json.JSONDecodeError, KeyError):
                    pass

            # 如果不是同一本小说，追加数字后缀
            if not is_same_novel:
                counter = 1
                while novel_dir.exists():
                    novel_dir = self.sync_dir / f"{safe_title}_{counter}"
                    counter += 1

        novel_dir.mkdir(parents=True, exist_ok=True)
        return novel_dir

    def _get_novel_dir(self, source_url: str) -> Path | None:
        """
        获取小说存储目录路径（仅查找，不创建）.

        优先通过 meta.json 中的 source_url 查找，
        如果找不到则尝试通过目录名（即小说标题）查找。

        Args:
            source_url: 小说来源 URL 或小说标题

        Returns:
            小说存储目录路径，如果不存在则返回 None
        """
        # 首先尝试通过 URL 查找
        novel_dir = self._find_novel_dir_by_url(source_url)
        if novel_dir:
            return novel_dir

        # 如果通过 URL 找不到，尝试通过目录名查找
        return self._find_novel_dir_by_name(source_url)

    def _save_meta(
        self,
        novel_dir: Path,
        novel_data: NovelSyncData,
        chapters_info: list[dict[str, Any]] | None = None,
        outlines_info: list[dict[str, Any]] | None = None,
        sync_version: int = 1,
    ) -> str:
        """
        保存小说元数据到 meta.json.

        Args:
            novel_dir: 小说目录
            novel_data: 小说数据
            chapters_info: 章节元数据列表
            outlines_info: 大纲元数据列表
            sync_version: 同步版本号

        Returns:
            同步时间字符串
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
            "chapters_info": chapters_info or [],
            "outlines_info": outlines_info or [],
        }

        meta_file = novel_dir / "meta.json"
        meta_file.write_text(
            json.dumps(meta_data, ensure_ascii=False, indent=2), encoding="utf-8"
        )
        return synced_at

    def _save_chapters(self, novel_dir: Path, chapters: list[ChapterSyncData]) -> list[dict[str, Any]]:
        """
        保存章节数据到 chapters 目录.

        每个章节保存为一个纯文本文件，格式：{chapter_index:03d}_{title}.txt
        元数据（如 is_user_inserted）返回并存到 meta.json。

        使用临时目录写入，确认成功后再替换，确保数据安全。

        Args:
            novel_dir: 小说目录
            chapters: 章节列表

        Returns:
            章节元数据列表，用于存入 meta.json
        """
        chapters_dir = novel_dir / "chapters"

        # 使用临时目录写入，确保数据安全
        with tempfile.TemporaryDirectory() as temp_dir:
            temp_chapters_dir = Path(temp_dir) / "chapters"
            temp_chapters_dir.mkdir()

            chapters_info = []
            for chapter in chapters:
                # 文件名格式：{chapter_index:03d}_{title}.txt
                safe_title = self._sanitize_filename(chapter.title)
                filename = f"{chapter.chapter_index:03d}_{safe_title}.txt"
                chapter_file = temp_chapters_dir / filename

                # 文件内容：纯文本，只存章节内容
                chapter_file.write_text(chapter.content, encoding="utf-8")

                # 收集元数据
                chapters_info.append({
                    "chapter_id": chapter.chapter_id,
                    "title": chapter.title,
                    "chapter_index": chapter.chapter_index,
                    "is_user_inserted": chapter.is_user_inserted,
                    "url": chapter.url,
                    "created_at": chapter.created_at,
                    "updated_at": chapter.updated_at,
                    "filename": filename,
                })

            # 所有文件写入成功后，删除旧目录并移动新目录
            if chapters_dir.exists():
                shutil.rmtree(chapters_dir)
            shutil.move(str(temp_chapters_dir), str(chapters_dir))

        return chapters_info

    def _parse_chapter_filename(self, filename: str) -> tuple[int, str] | None:
        """
        解析章节文件名.

        格式: {chapter_index:03d}_{title}.txt
        示例: 001_第一章.txt → (1, "第一章")

        Args:
            filename: 章节文件名

        Returns:
            (chapter_index, title) 元组，解析失败返回 None
        """
        if not filename.endswith(".txt"):
            return None

        name_without_ext = filename[:-4]  # 移除 .txt
        parts = name_without_ext.split("_", 1)

        if len(parts) != 2:
            return None

        try:
            chapter_index = int(parts[0])
            title = parts[1]
            return chapter_index, title
        except ValueError:
            return None

    def _get_file_created_time(self, file_path: Path) -> str:
        """
        获取文件创建时间的 ISO 格式字符串.

        Args:
            file_path: 文件路径

        Returns:
            ISO 格式的时间字符串
        """
        stat = file_path.stat()
        return datetime.fromtimestamp(stat.st_ctime).isoformat()

    def _load_chapters(self, novel_dir: Path, chapters_info: list[dict[str, Any]] | None = None) -> list[ChapterSyncData]:
        """
        从 chapters 目录加载章节数据.

        优先扫描目录文件，再合并 meta.json 中的元数据。
        支持直接插入章节文件，无需修改 meta.json。

        Args:
            novel_dir: 小说目录
            chapters_info: 从 meta.json 读取的章节元数据（可选）

        Returns:
            章节数据列表
        """
        chapters_dir = novel_dir / "chapters"
        if not chapters_dir.exists():
            return []

        chapters_info = chapters_info or []

        # 构建 chapter_index -> meta_info 的映射
        meta_map: dict[int, dict[str, Any]] = {}
        for info in chapters_info:
            chapter_index = info.get("chapter_index")
            if chapter_index is not None:
                meta_map[chapter_index] = info

        chapters = []

        # 扫描目录下的所有 .txt 文件
        for chapter_file in chapters_dir.glob("*.txt"):
            filename = chapter_file.name

            # 从文件名解析 chapter_index 和 title
            parsed = self._parse_chapter_filename(filename)
            if not parsed:
                logger.warning("无法解析章节文件名: %s", filename)
                continue

            chapter_index, title = parsed

            # 读取内容
            try:
                content = chapter_file.read_text(encoding="utf-8")
            except (OSError, IOError) as e:
                logger.warning("读取章节文件失败: %s, 错误: %s", chapter_file, e)
                continue

            # 从 meta.json 合并元数据（如果存在）
            meta = meta_map.get(chapter_index, {})

            # 构建章节数据
            # 新文件（不在 meta.json 中）默认为用户插入
            is_new_file = chapter_index not in meta_map
            chapters.append(ChapterSyncData(
                chapter_id=meta.get("chapter_id", chapter_index),
                title=title,
                content=content,
                chapter_index=chapter_index,
                is_user_inserted=meta.get("is_user_inserted", is_new_file),
                url=meta.get("url"),
                created_at=meta.get("created_at") or self._get_file_created_time(chapter_file),
                updated_at=meta.get("updated_at"),
            ))

        # 按章节序号排序
        chapters.sort(key=lambda x: x.chapter_index)
        return chapters

    def _save_characters(
        self, novel_dir: Path, characters: list[CharacterSyncData]
    ) -> None:
        """
        保存角色数据到 characters 目录.

        每个角色保存为一个独立的 JSON 文件，文件名：{name}.json。
        使用临时目录写入，确认成功后再替换，确保数据安全。

        Args:
            novel_dir: 小说目录
            characters: 角色列表
        """
        characters_dir = novel_dir / "characters"

        # 使用临时目录写入，确保数据安全
        with tempfile.TemporaryDirectory() as temp_dir:
            temp_characters_dir = Path(temp_dir) / "characters"
            temp_characters_dir.mkdir()

            for character in characters:
                safe_name = self._sanitize_filename(character.name)
                character_file = temp_characters_dir / f"{safe_name}.json"
                character_file.write_text(
                    json.dumps(character.model_dump(), ensure_ascii=False, indent=2),
                    encoding="utf-8"
                )

            # 所有文件写入成功后，删除旧目录并移动新目录
            if characters_dir.exists():
                shutil.rmtree(characters_dir)
            shutil.move(str(temp_characters_dir), str(characters_dir))

    def _load_characters(self, novel_dir: Path) -> list[CharacterSyncData]:
        """
        从 characters 目录加载角色数据.

        Args:
            novel_dir: 小说目录

        Returns:
            角色数据列表
        """
        characters_dir = novel_dir / "characters"
        if not characters_dir.exists():
            return []

        characters = []
        for character_file in characters_dir.glob("*.json"):
            try:
                character_data = json.loads(character_file.read_text(encoding="utf-8"))
                characters.append(CharacterSyncData(**character_data))
            except (json.JSONDecodeError, TypeError):
                continue

        return characters

    def _save_character_relations(
        self, novel_dir: Path, relations: list[CharacterRelationSyncData]
    ) -> None:
        """
        保存角色关系数据到 character_relations.json.

        Args:
            novel_dir: 小说目录
            relations: 角色关系列表
        """
        relations_data = [rel.model_dump() for rel in relations]
        relations_file = novel_dir / "character_relations.json"
        relations_file.write_text(
            json.dumps(relations_data, ensure_ascii=False, indent=2), encoding="utf-8"
        )

    def _load_character_relations(
        self, novel_dir: Path
    ) -> list[CharacterRelationSyncData]:
        """
        从 character_relations.json 加载角色关系数据.

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

    def _save_outlines(
        self, novel_dir: Path, outlines: list[OutlineSyncData]
    ) -> list[dict[str, Any]]:
        """
        保存大纲数据到 outlines 目录.

        每个大纲保存为一个纯文本文件，文件名：{title}.txt。
        元数据返回并存到 meta.json。
        使用临时目录写入，确认成功后再替换，确保数据安全。

        Args:
            novel_dir: 小说目录
            outlines: 大纲列表

        Returns:
            大纲元数据列表，用于存入 meta.json
        """
        outlines_dir = novel_dir / "outlines"

        # 使用临时目录写入，确保数据安全
        with tempfile.TemporaryDirectory() as temp_dir:
            temp_outlines_dir = Path(temp_dir) / "outlines"
            temp_outlines_dir.mkdir()

            outlines_info = []
            for outline in outlines:
                safe_title = self._sanitize_filename(outline.title)
                filename = f"{safe_title}.txt"
                outline_file = temp_outlines_dir / filename

                # 文件内容：纯文本
                outline_file.write_text(outline.content, encoding="utf-8")

                # 收集元数据
                outlines_info.append({
                    "outline_id": outline.outline_id,
                    "title": outline.title,
                    "outline_type": outline.outline_type,
                    "parent_id": outline.parent_id,
                    "sort_order": outline.sort_order,
                    "created_at": outline.created_at,
                    "updated_at": outline.updated_at,
                    "filename": filename,
                })

            # 所有文件写入成功后，删除旧目录并移动新目录
            if outlines_dir.exists():
                shutil.rmtree(outlines_dir)
            shutil.move(str(temp_outlines_dir), str(outlines_dir))

        return outlines_info

    def _load_outlines(self, novel_dir: Path, outlines_info: list[dict[str, Any]] | None = None) -> list[OutlineSyncData]:
        """
        从 outlines 目录加载大纲数据.

        优先扫描目录文件，再合并 meta.json 中的元数据。
        支持无 meta.json 的情况下加载大纲。

        Args:
            novel_dir: 小说目录
            outlines_info: 从 meta.json 读取的大纲元数据（可选）

        Returns:
            大纲数据列表
        """
        outlines_dir = novel_dir / "outlines"
        if not outlines_dir.exists():
            return []

        outlines_info = outlines_info or []

        # 构建 title -> meta_info 的映射
        meta_map: dict[str, dict[str, Any]] = {}
        for info in outlines_info:
            title = info.get("title")
            if title:
                meta_map[title] = info

        outlines = []

        # 扫描目录下的所有 .txt 文件
        for outline_file in outlines_dir.glob("*.txt"):
            filename = outline_file.name
            # 大纲文件名格式: {title}.txt
            title = filename[:-4] if filename.endswith(".txt") else filename  # 移除 .txt

            if not title:
                continue

            # 读取内容
            try:
                content = outline_file.read_text(encoding="utf-8")
            except (OSError, IOError) as e:
                logger.warning("读取大纲文件失败: %s, 错误: %s", outline_file, e)
                continue

            # 从 meta.json 合并元数据（如果存在）
            meta = meta_map.get(title, {})

            # 构建大纲数据
            outlines.append(OutlineSyncData(
                outline_id=meta.get("outline_id", hash(title) % 1000000),
                title=title,
                content=content,
                outline_type=meta.get("outline_type", "main"),
                parent_id=meta.get("parent_id"),
                sort_order=meta.get("sort_order", 0),
                created_at=meta.get("created_at"),
                updated_at=meta.get("updated_at"),
            ))

        # 按 sort_order 排序
        outlines.sort(key=lambda x: x.sort_order)
        return outlines

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
            # 使用 source_url 作为唯一标识，如果没有则使用本地标识
            source_url = novel_data.source_url or f"local_{novel_data.novel_id}"

            # 查找或创建小说目录
            novel_dir = self._find_or_create_novel_dir(novel_data.title, source_url)

            # 读取现有的 meta.json 获取 sync_version（如果存在）
            meta_file = novel_dir / "meta.json"
            sync_version = 1
            if meta_file.exists():
                try:
                    existing_meta = json.loads(meta_file.read_text(encoding="utf-8"))
                    sync_version = existing_meta.get("sync_version", 1) + 1
                except (json.JSONDecodeError, KeyError):
                    pass

            # 保存章节数据，获取章节元数据
            chapters_info = []
            if novel_data.chapters:
                chapters_info = self._save_chapters(novel_dir, novel_data.chapters)

            # 保存大纲数据，获取大纲元数据
            outlines_info = []
            if novel_data.outlines:
                outlines_info = self._save_outlines(novel_dir, novel_data.outlines)

            # 保存元数据（包含章节和大纲元数据）
            synced_at = self._save_meta(
                novel_dir, novel_data, chapters_info, outlines_info, sync_version
            )

            # 保存角色数据
            if novel_data.characters:
                self._save_characters(novel_dir, novel_data.characters)

            # 保存角色关系
            if novel_data.character_relations:
                self._save_character_relations(novel_dir, novel_data.character_relations)

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
        从 meta.json 加载小说元数据.

        Args:
            novel_dir: 小说目录

        Returns:
            元数据字典，如果文件不存在则返回 None
        """
        meta_file = novel_dir / "meta.json"
        if not meta_file.exists():
            return None

        return json.loads(meta_file.read_text(encoding="utf-8"))

    def load_novel(self, novel_url: str) -> NovelSyncData | None:
        """
        从文件系统加载小说数据.

        支持：
        1. 通过 meta.json 加载完整信息
        2. 无 meta.json 时，从目录名推断标题并加载章节

        Args:
            novel_url: 小说 URL 或小说标题（用于定位存储目录）

        Returns:
            完整的小说同步数据，如果不存在则返回 None

        Raises:
            NovelSyncServiceError: 加载失败
        """
        try:
            novel_dir = self._get_novel_dir(novel_url)
            if not novel_dir or not novel_dir.exists():
                return None

            meta_data = self._load_meta(novel_dir)

            # 如果没有 meta.json，检查是否有章节目录
            if not meta_data:
                chapters_dir = novel_dir / "chapters"
                if not chapters_dir.exists() or not list(chapters_dir.glob("*.txt")):
                    return None

                # 从目录名推断标题，使用默认值构建基本数据
                title = novel_dir.name
                chapters = self._load_chapters(novel_dir)

                return NovelSyncData(
                    novel_id=hash(title) % 1000000,  # 生成一个基于标题的 ID
                    title=title,
                    author=None,
                    description=None,
                    cover_url=None,
                    source_url=None,
                    total_chapters=len(chapters),
                    total_words=sum(len(c.content) for c in chapters),
                    last_read_chapter_id=None,
                    last_read_position=0,
                    is_favorite=False,
                    created_at=None,
                    updated_at=None,
                    chapters=chapters,
                    characters=self._load_characters(novel_dir),
                    character_relations=self._load_character_relations(novel_dir),
                    outlines=self._load_outlines(novel_dir),
                )

            # 有 meta.json，正常加载
            # 加载章节数据
            chapters_info = meta_data.get("chapters_info", [])
            chapters = self._load_chapters(novel_dir, chapters_info)

            # 加载大纲数据
            outlines_info = meta_data.get("outlines_info", [])
            outlines = self._load_outlines(novel_dir, outlines_info)

            # 构建 NovelSyncData
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
                chapters=chapters,
                characters=self._load_characters(novel_dir),
                character_relations=self._load_character_relations(novel_dir),
                outlines=outlines,
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

        支持：
        1. 有 meta.json 的小说：返回完整元数据
        2. 无 meta.json 但有章节目录的小说：从目录名推断标题

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
                # 有 meta.json，返回完整元数据
                novels.append({
                    "novel_id": meta_data["novel_id"],
                    "title": meta_data["title"],
                    "author": meta_data.get("author"),
                    "source_url": meta_data.get("source_url"),
                    "total_chapters": meta_data.get("total_chapters", 0),
                    "sync_version": meta_data.get("sync_version", 1),
                    "synced_at": meta_data.get("synced_at"),
                    "has_meta": True,
                })
            else:
                # 无 meta.json，检查是否有章节目录
                chapters_dir = novel_dir / "chapters"
                if chapters_dir.exists():
                    chapter_files = list(chapters_dir.glob("*.txt"))
                    if chapter_files:
                        # 从目录名推断标题
                        novels.append({
                            "novel_id": hash(novel_dir.name) % 1000000,
                            "title": novel_dir.name,
                            "author": None,
                            "source_url": None,
                            "total_chapters": len(chapter_files),
                            "sync_version": 0,
                            "synced_at": None,
                            "has_meta": False,
                        })

        # 按同步时间倒序排列（无同步时间的排最后）
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
            novel_url: 小说 URL

        Returns:
            是否成功删除

        Raises:
            NovelSyncServiceError: 删除失败
        """
        try:
            novel_dir = self._get_novel_dir(novel_url)
            if not novel_dir or not novel_dir.exists():
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

        支持：
        1. 有 meta.json 的小说：返回完整状态
        2. 无 meta.json 但有章节目录的小说：返回基本状态

        Args:
            novel_url: 小说 URL 或小说标题

        Returns:
            同步状态信息，如果不存在则返回 None
        """
        novel_dir = self._get_novel_dir(novel_url)
        if not novel_dir or not novel_dir.exists():
            return None

        meta_data = self._load_meta(novel_dir)

        # 无 meta.json，从章节目录推断
        if not meta_data:
            chapters_dir = novel_dir / "chapters"
            if not chapters_dir.exists():
                return None

            chapter_files = list(chapters_dir.glob("*.txt"))
            if not chapter_files:
                return None

            return {
                "novel_id": hash(novel_dir.name) % 1000000,
                "title": novel_dir.name,
                "sync_version": 0,
                "synced_at": None,
                "chapter_count": len(chapter_files),
                "has_characters": (novel_dir / "characters").exists(),
                "has_character_relations": (novel_dir / "character_relations.json").exists(),
                "has_outlines": (novel_dir / "outlines").exists(),
                "has_meta": False,
            }

        # 有 meta.json，正常返回
        # 统计章节数量
        chapters_info = meta_data.get("chapters_info", [])
        chapter_count = len(chapters_info)

        return {
            "novel_id": meta_data["novel_id"],
            "title": meta_data["title"],
            "sync_version": meta_data.get("sync_version", 1),
            "synced_at": meta_data.get("synced_at"),
            "chapter_count": chapter_count,
            "has_characters": (novel_dir / "characters").exists(),
            "has_character_relations": (novel_dir / "character_relations.json").exists(),
            "has_outlines": (novel_dir / "outlines").exists(),
            "has_meta": True,
        }

    def novel_exists(self, novel_url: str) -> bool:
        """
        检查小说是否已同步.

        支持：
        1. 有 meta.json 的小说
        2. 无 meta.json 但有章节目录的小说

        Args:
            novel_url: 小说 URL 或小说标题

        Returns:
            是否存在
        """
        novel_dir = self._get_novel_dir(novel_url)
        if novel_dir is None or not novel_dir.exists():
            return False

        # 有 meta.json 或有章节目录都算存在
        if (novel_dir / "meta.json").exists():
            return True

        chapters_dir = novel_dir / "chapters"
        return chapters_dir.exists() and bool(list(chapters_dir.glob("*.txt")))


# 创建单例实例
novel_sync_service = NovelSyncService()


def get_novel_sync_service() -> NovelSyncService:
    """获取小说同步服务实例."""
    return novel_sync_service