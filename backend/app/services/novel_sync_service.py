#!/usr/bin/env python3
"""
小说同步服务模块.

存储格式:
novel_sync/
└── 斗破苍穹/                  # 用小说标题做目录名
    ├── meta.json             # 仅保留 title, author, description, cover_url
    ├── 背景.txt               # 背景设定（可选）
    ├── _sync_info.json       # 内部同步元数据（不暴露给用户）
    ├── chapters/
    │   ├── 001_第一章.txt     # 格式：{序号}_{标题}.txt
    │   └── ...
    ├── outlines/             # 大纲目录
    │   ├── 大纲.txt           # 主线大纲（固定文件名）
    │   ├── 第一卷.txt         # 卷级大纲
    │   └── 第一卷/            # 卷目录（可选）
    │       ├── 第一章.txt     # 章级细纲
    │       └── ...
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
    """小说同步服务 - 管理小说数据在简化格式和文件系统之间的转换."""

    ILLEGAL_FILENAME_CHARS = r'<>:"/\|?*'

    def __init__(self, sync_dir: str | None = None):
        self.sync_dir = Path(sync_dir or settings.novel_sync_dir)
        self._ensure_sync_dir()

    def _ensure_sync_dir(self) -> None:
        self.sync_dir.mkdir(parents=True, exist_ok=True)

    def _sanitize_filename(self, name: str) -> str:
        safe_name = name
        for char in self.ILLEGAL_FILENAME_CHARS:
            safe_name = safe_name.replace(char, "_")
        safe_name = safe_name.strip(" .")
        return safe_name or "unnamed"

    # ========================================================================
    # 目录查找
    # ========================================================================

    def _find_novel_dir_by_title(self, title: str) -> Path | None:
        """通过目录名查找小说目录."""
        safe_title = self._sanitize_filename(title)
        novel_dir = self.sync_dir / safe_title
        if novel_dir.exists() and novel_dir.is_dir():
            return novel_dir
        return None

    def _find_or_create_novel_dir(self, title: str) -> Path:
        """查找或创建小说目录."""
        safe_title = self._sanitize_filename(title)
        novel_dir = self.sync_dir / safe_title

        # 处理标题冲突
        if novel_dir.exists():
            meta_file = novel_dir / "meta.json"
            is_same_novel = False
            if meta_file.exists():
                try:
                    meta_data = json.loads(meta_file.read_text(encoding="utf-8"))
                    if meta_data.get("title") == title:
                        is_same_novel = True
                except (json.JSONDecodeError, KeyError):
                    pass

            if not is_same_novel:
                counter = 1
                while novel_dir.exists():
                    novel_dir = self.sync_dir / f"{safe_title}_{counter}"
                    counter += 1

        novel_dir.mkdir(parents=True, exist_ok=True)
        return novel_dir

    def _get_novel_dir(self, title: str) -> Path | None:
        """获取小说存储目录路径（仅查找，不创建）."""
        return self._find_novel_dir_by_title(title)

    # ========================================================================
    # meta.json（仅 4 字段）
    # ========================================================================

    def _save_meta(self, novel_dir: Path, novel_data: NovelSyncData) -> None:
        """保存小说元数据到 meta.json（仅 title, author, description, cover_url）."""
        meta_data = {
            "title": novel_data.title,
            "author": novel_data.author,
            "description": novel_data.description,
            "cover_url": novel_data.cover_url,
        }
        meta_file = novel_dir / "meta.json"
        meta_file.write_text(
            json.dumps(meta_data, ensure_ascii=False, indent=2), encoding="utf-8"
        )

    def _load_meta(self, novel_dir: Path) -> dict[str, Any] | None:
        """从 meta.json 加载小说元数据."""
        meta_file = novel_dir / "meta.json"
        if not meta_file.exists():
            return None
        return json.loads(meta_file.read_text(encoding="utf-8"))

    # ========================================================================
    # _sync_info.json（内部同步元数据）
    # ========================================================================

    def _save_sync_info(self, novel_dir: Path, sync_version: int, synced_at: str) -> None:
        """保存内部同步元数据到 _sync_info.json."""
        sync_info = {
            "sync_version": sync_version,
            "synced_at": synced_at,
            "storage_version": "2.0",
        }
        sync_file = novel_dir / "_sync_info.json"
        sync_file.write_text(
            json.dumps(sync_info, ensure_ascii=False, indent=2), encoding="utf-8"
        )

    def _load_sync_info(self, novel_dir: Path) -> dict[str, Any] | None:
        """从 _sync_info.json 加载内部同步元数据."""
        sync_file = novel_dir / "_sync_info.json"
        if not sync_file.exists():
            return None
        return json.loads(sync_file.read_text(encoding="utf-8"))

    # ========================================================================
    # 背景设定
    # ========================================================================

    def _save_background_setting(self, novel_dir: Path, background_setting: str | None) -> None:
        """保存背景设定到 背景.txt."""
        bg_file = novel_dir / "背景.txt"
        if background_setting:
            bg_file.write_text(background_setting, encoding="utf-8")
        elif bg_file.exists():
            bg_file.unlink()

    def _load_background_setting(self, novel_dir: Path) -> str | None:
        """从 背景.txt 加载背景设定."""
        bg_file = novel_dir / "背景.txt"
        if bg_file.exists():
            return bg_file.read_text(encoding="utf-8")
        return None

    # ========================================================================
    # 章节存储
    # ========================================================================

    def _save_chapters(self, novel_dir: Path, chapters: list[ChapterSyncData]) -> None:
        """保存章节数据到 chapters 目录."""
        chapters_dir = novel_dir / "chapters"

        with tempfile.TemporaryDirectory() as temp_dir:
            temp_chapters_dir = Path(temp_dir) / "chapters"
            temp_chapters_dir.mkdir()

            for chapter in chapters:
                safe_title = self._sanitize_filename(chapter.title)
                filename = f"{chapter.chapter_index:03d}_{safe_title}.txt"
                chapter_file = temp_chapters_dir / filename
                chapter_file.write_text(chapter.content, encoding="utf-8")

            if chapters_dir.exists():
                shutil.rmtree(chapters_dir)
            shutil.move(str(temp_chapters_dir), str(chapters_dir))

    def _parse_chapter_filename(self, filename: str) -> tuple[int, str] | None:
        """解析章节文件名: {chapter_index:03d}_{title}.txt."""
        if not filename.endswith(".txt"):
            return None
        name_without_ext = filename[:-4]
        parts = name_without_ext.split("_", 1)
        if len(parts) != 2:
            return None
        try:
            return int(parts[0]), parts[1]
        except ValueError:
            return None

    def _load_chapters(self, novel_dir: Path) -> list[ChapterSyncData]:
        """从 chapters 目录加载章节数据（完全从文件系统推断）."""
        chapters_dir = novel_dir / "chapters"
        if not chapters_dir.exists():
            return []

        chapters = []
        for chapter_file in chapters_dir.glob("*.txt"):
            parsed = self._parse_chapter_filename(chapter_file.name)
            if not parsed:
                logger.warning("无法解析章节文件名: %s", chapter_file.name)
                continue

            chapter_index, title = parsed
            try:
                content = chapter_file.read_text(encoding="utf-8")
            except (OSError, IOError) as e:
                logger.warning("读取章节文件失败: %s, 错误: %s", chapter_file, e)
                continue

            chapters.append(ChapterSyncData(
                title=title,
                content=content,
                chapter_index=chapter_index,
                is_user_inserted=False,
            ))

        chapters.sort(key=lambda x: x.chapter_index)
        return chapters

    # ========================================================================
    # 角色存储
    # ========================================================================

    def _save_characters(self, novel_dir: Path, characters: list[CharacterSyncData]) -> None:
        """保存角色数据到 characters 目录."""
        characters_dir = novel_dir / "characters"

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

            if characters_dir.exists():
                shutil.rmtree(characters_dir)
            shutil.move(str(temp_characters_dir), str(characters_dir))

    def _load_characters(self, novel_dir: Path) -> list[CharacterSyncData]:
        """从 characters 目录加载角色数据."""
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

    # ========================================================================
    # 角色关系存储（使用名称而非 ID）
    # ========================================================================

    def _save_character_relations(
        self, novel_dir: Path, relations: list[CharacterRelationSyncData]
    ) -> None:
        """保存角色关系数据到 character_relations.json."""
        relations_data = [rel.model_dump() for rel in relations]
        relations_file = novel_dir / "character_relations.json"
        relations_file.write_text(
            json.dumps(relations_data, ensure_ascii=False, indent=2), encoding="utf-8"
        )

    def _load_character_relations(
        self, novel_dir: Path
    ) -> list[CharacterRelationSyncData]:
        """从 character_relations.json 加载角色关系数据."""
        relations_file = novel_dir / "character_relations.json"
        if not relations_file.exists():
            return []

        try:
            relations_data = json.loads(relations_file.read_text(encoding="utf-8"))
            return [CharacterRelationSyncData(**rel) for rel in relations_data]
        except (json.JSONDecodeError, TypeError):
            return []

    # ========================================================================
    # 大纲存储（支持目录结构）
    # ========================================================================

    def _save_outlines(self, novel_dir: Path, outlines: list[OutlineSyncData]) -> None:
        """保存大纲数据到 outlines 目录."""
        outlines_dir = novel_dir / "outlines"

        # 保留子目录结构，只替换 .txt 文件
        outlines_dir.mkdir(parents=True, exist_ok=True)

        for outline in outlines:
            safe_title = self._sanitize_filename(outline.title)
            outline_file = outlines_dir / f"{safe_title}.txt"
            outline_file.write_text(outline.content, encoding="utf-8")

    def _load_outlines(self, novel_dir: Path) -> list[OutlineSyncData]:
        """从 outlines 目录加载大纲数据（递归扫描，支持目录结构）."""
        outlines_dir = novel_dir / "outlines"
        if not outlines_dir.exists():
            return []

        outlines = []
        for outline_file in outlines_dir.rglob("*.txt"):
            title = outline_file.stem
            if not title:
                continue

            try:
                content = outline_file.read_text(encoding="utf-8")
            except (OSError, IOError) as e:
                logger.warning("读取大纲文件失败: %s, 错误: %s", outline_file, e)
                continue

            outlines.append(OutlineSyncData(
                title=title,
                content=content,
            ))

        return outlines

    # ========================================================================
    # 主操作
    # ========================================================================

    def save_novel(
        self,
        novel_data: NovelSyncData,
        force_overwrite: bool = False,
    ) -> dict[str, Any]:
        """保存小说数据到文件系统."""
        try:
            novel_dir = self._find_or_create_novel_dir(novel_data.title)

            # 读取现有 sync_version
            sync_version = 1
            sync_info = self._load_sync_info(novel_dir)
            if sync_info:
                sync_version = sync_info.get("sync_version", 1) + 1

            synced_at = datetime.now().isoformat()

            # 保存 meta.json
            self._save_meta(novel_dir, novel_data)

            # 保存背景设定
            self._save_background_setting(novel_dir, novel_data.background_setting)

            # 保存内部同步元数据
            self._save_sync_info(novel_dir, sync_version, synced_at)

            # 保存章节数据
            if novel_data.chapters:
                self._save_chapters(novel_dir, novel_data.chapters)

            # 保存大纲数据
            if novel_data.outlines:
                self._save_outlines(novel_dir, novel_data.outlines)

            # 保存角色数据
            if novel_data.characters:
                self._save_characters(novel_dir, novel_data.characters)

            # 保存角色关系
            if novel_data.character_relations:
                self._save_character_relations(novel_dir, novel_data.character_relations)

            return {
                "success": True,
                "title": novel_data.title,
                "sync_version": sync_version,
                "synced_at": synced_at,
            }

        except Exception as e:
            raise NovelSyncServiceError(
                message=f"保存小说数据失败: {e}",
                details=f"标题: {novel_data.title}",
            )

    def load_novel(self, title: str) -> NovelSyncData | None:
        """从文件系统加载小说数据."""
        try:
            novel_dir = self._get_novel_dir(title)
            if not novel_dir or not novel_dir.exists():
                return None

            meta_data = self._load_meta(novel_dir)

            if not meta_data:
                # 无 meta.json，从目录名推断
                chapters_dir = novel_dir / "chapters"
                if not chapters_dir.exists() or not list(chapters_dir.glob("*.txt")):
                    return None

                inferred_title = novel_dir.name
                chapters = self._load_chapters(novel_dir)

                return NovelSyncData(
                    title=inferred_title,
                    chapters=chapters,
                    characters=self._load_characters(novel_dir),
                    character_relations=self._load_character_relations(novel_dir),
                    outlines=self._load_outlines(novel_dir),
                    background_setting=self._load_background_setting(novel_dir),
                )

            # 有 meta.json，正常加载
            return NovelSyncData(
                title=meta_data["title"],
                author=meta_data.get("author"),
                description=meta_data.get("description"),
                cover_url=meta_data.get("cover_url"),
                background_setting=self._load_background_setting(novel_dir),
                chapters=self._load_chapters(novel_dir),
                characters=self._load_characters(novel_dir),
                character_relations=self._load_character_relations(novel_dir),
                outlines=self._load_outlines(novel_dir),
            )

        except Exception as e:
            raise NovelSyncServiceError(
                message=f"加载小说数据失败: {e}",
                details=f"标题: {title}",
            )

    def list_synced_novels(
        self, page: int = 1, page_size: int = 20
    ) -> dict[str, Any]:
        """列出已同步的小说列表."""
        novels = []

        for novel_dir in self.sync_dir.iterdir():
            if not novel_dir.is_dir():
                continue

            meta_data = self._load_meta(novel_dir)
            sync_info = self._load_sync_info(novel_dir)

            if meta_data:
                novels.append({
                    "title": meta_data["title"],
                    "author": meta_data.get("author"),
                    "sync_version": sync_info.get("sync_version", 1) if sync_info else 1,
                    "synced_at": sync_info.get("synced_at") if sync_info else None,
                })
            else:
                chapters_dir = novel_dir / "chapters"
                if chapters_dir.exists() and list(chapters_dir.glob("*.txt")):
                    novels.append({
                        "title": novel_dir.name,
                        "author": None,
                        "sync_version": 0,
                        "synced_at": None,
                    })

        novels.sort(key=lambda x: x.get("synced_at") or "", reverse=True)

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

    def delete_novel(self, title: str) -> bool:
        """删除已同步的小说数据."""
        try:
            novel_dir = self._get_novel_dir(title)
            if not novel_dir or not novel_dir.exists():
                return False

            shutil.rmtree(novel_dir)
            return True

        except Exception as e:
            raise NovelSyncServiceError(
                message=f"删除小说数据失败: {e}",
                details=f"标题: {title}",
            )

    def get_sync_status(self, title: str) -> dict[str, Any] | None:
        """获取小说同步状态."""
        novel_dir = self._get_novel_dir(title)
        if not novel_dir or not novel_dir.exists():
            return None

        meta_data = self._load_meta(novel_dir)
        sync_info = self._load_sync_info(novel_dir)

        if not meta_data:
            chapters_dir = novel_dir / "chapters"
            if not chapters_dir.exists() or not list(chapters_dir.glob("*.txt")):
                return None

            return {
                "title": novel_dir.name,
                "sync_version": 0,
                "synced_at": None,
                "has_characters": (novel_dir / "characters").exists(),
                "has_character_relations": (novel_dir / "character_relations.json").exists(),
                "has_outlines": (novel_dir / "outlines").exists(),
                "has_background_setting": (novel_dir / "背景.txt").exists(),
            }

        chapters_dir = novel_dir / "chapters"
        chapter_count = len(list(chapters_dir.glob("*.txt"))) if chapters_dir.exists() else 0

        return {
            "title": meta_data["title"],
            "sync_version": sync_info.get("sync_version", 1) if sync_info else 1,
            "synced_at": sync_info.get("synced_at") if sync_info else None,
            "chapter_count": chapter_count,
            "has_characters": (novel_dir / "characters").exists(),
            "has_character_relations": (novel_dir / "character_relations.json").exists(),
            "has_outlines": (novel_dir / "outlines").exists(),
            "has_background_setting": (novel_dir / "背景.txt").exists(),
        }

    def novel_exists(self, title: str) -> bool:
        """检查小说是否已同步."""
        novel_dir = self._get_novel_dir(title)
        if novel_dir is None or not novel_dir.exists():
            return False

        if (novel_dir / "meta.json").exists():
            return True

        chapters_dir = novel_dir / "chapters"
        return chapters_dir.exists() and bool(list(chapters_dir.glob("*.txt")))


novel_sync_service = NovelSyncService()


def get_novel_sync_service() -> NovelSyncService:
    """获取小说同步服务实例."""
    return novel_sync_service