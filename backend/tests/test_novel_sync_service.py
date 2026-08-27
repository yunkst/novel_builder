#!/usr/bin/env python3
"""
小说同步服务单元测试.
测试 NovelSyncService 的核心功能：保存、加载、列表、删除小说数据。
"""

import json
from datetime import datetime
from pathlib import Path

import pytest

from app.schemas import (
    CharacterRelationSyncData,
    CharacterSyncData,
    ChapterSyncData,
    NovelSyncData,
    OutlineSyncData,
)
from app.services.novel_sync_service import NovelSyncService, NovelSyncServiceError


class TestNovelSyncService:
    """小说同步服务测试类."""

    @pytest.fixture
    def sync_service(self, tmp_path: Path) -> NovelSyncService:
        """创建使用临时目录的同步服务实例."""
        return NovelSyncService(sync_dir=str(tmp_path / "novel_sync"))

    @pytest.fixture
    def sample_chapter(self) -> ChapterSyncData:
        """创建示例章节数据."""
        return ChapterSyncData(
            chapter_id=1,
            title="第一章：开始",
            content="这是第一章的内容，讲述了一个精彩的故事...",
            chapter_index=1,
            is_user_inserted=False,
            created_at="2024-01-01T10:00:00",
            updated_at="2024-01-01T10:00:00",
        )

    @pytest.fixture
    def sample_character(self) -> CharacterSyncData:
        """创建示例角色数据."""
        return CharacterSyncData(
            character_id=1,
            name="张三",
            gender="男",
            age=25,
            occupation="剑客",
            personality="沉稳内敛",
            appearance_features="身材高大",
            body_type="健壮",
            clothing_style="朴素",
            background_story="出身名门",
            face_prompts="英俊的面容",
            body_prompts="健硕的身材",
            created_at="2024-01-01T10:00:00",
            updated_at="2024-01-01T10:00:00",
        )

    @pytest.fixture
    def sample_character_relation(self) -> CharacterRelationSyncData:
        """创建示例角色关系数据."""
        return CharacterRelationSyncData(
            relation_id=1,
            character1_id=1,
            character2_id=2,
            relation_type="朋友",
            description="生死之交",
            created_at="2024-01-01T10:00:00",
            updated_at="2024-01-01T10:00:00",
        )

    @pytest.fixture
    def sample_outline(self) -> OutlineSyncData:
        """创建示例大纲数据."""
        return OutlineSyncData(
            outline_id=1,
            title="第一卷",
            content="主角的成长历程",
            outline_type="volume",
            parent_id=None,
            sort_order=1,
            created_at="2024-01-01T10:00:00",
            updated_at="2024-01-01T10:00:00",
        )

    @pytest.fixture
    def sample_novel_data(
        self,
        sample_chapter: ChapterSyncData,
        sample_character: CharacterSyncData,
        sample_character_relation: CharacterRelationSyncData,
        sample_outline: OutlineSyncData,
    ) -> NovelSyncData:
        """创建完整的示例小说数据."""
        return NovelSyncData(
            novel_id=1,
            title="测试小说",
            author="测试作者",
            description="这是一本用于测试的小说",
            cover_url="https://example.com/cover.jpg",
            source_url="https://example.com/novel/1",
            total_chapters=100,
            total_words=100000,
            last_read_chapter_id=1,
            last_read_position=100,
            is_favorite=True,
            created_at="2024-01-01T10:00:00",
            updated_at="2024-01-01T10:00:00",
            chapters=[sample_chapter],
            characters=[sample_character],
            character_relations=[sample_character_relation],
            outlines=[sample_outline],
        )

    @pytest.fixture
    def minimal_novel_data(self) -> NovelSyncData:
        """创建最小化的小说数据（仅必填字段）."""
        return NovelSyncData(
            novel_id=2,
            title="最小小说",
        )


class TestSaveNovel(TestNovelSyncService):
    """测试 save_novel 方法."""

    def test_save_novel_basic(
        self, sync_service: NovelSyncService, sample_novel_data: NovelSyncData
    ):
        """测试基本的保存功能."""
        # When - 保存小说
        result = sync_service.save_novel(sample_novel_data)

        # Then - 验证返回结果
        assert result["success"] is True
        assert result["novel_id"] == 1
        assert result["sync_version"] == 1
        assert "synced_at" in result

    def test_save_novel_creates_directory(
        self, sync_service: NovelSyncService, sample_novel_data: NovelSyncData
    ):
        """测试保存小说会创建目录结构."""
        # When
        sync_service.save_novel(sample_novel_data)

        # Then - 验证目录被创建（使用标题作为目录名）
        novel_dir = sync_service._find_novel_dir_by_url(sample_novel_data.source_url)
        assert novel_dir is not None
        assert novel_dir.exists()
        assert (novel_dir / "meta.json").exists()
        assert (novel_dir / "chapters").exists()

    def test_save_novel_uses_title_as_directory_name(
        self, sync_service: NovelSyncService, sample_novel_data: NovelSyncData
    ):
        """测试保存小说时目录名使用小说标题."""
        # When
        sync_service.save_novel(sample_novel_data)

        # Then - 验证目录名是小说标题
        novel_dir = sync_service._find_novel_dir_by_url(sample_novel_data.source_url)
        assert novel_dir is not None
        # 目录名应该是小说标题（经过非法字符清理）
        assert novel_dir.name == sample_novel_data.title

    def test_save_novel_creates_meta_file(
        self, sync_service: NovelSyncService, sample_novel_data: NovelSyncData
    ):
        """测试保存小说会创建正确的 meta.json 文件."""
        # When
        sync_service.save_novel(sample_novel_data)

        # Then - 验证 meta.json 内容
        novel_dir = sync_service._find_novel_dir_by_url(sample_novel_data.source_url)
        assert novel_dir is not None
        meta_file = novel_dir / "meta.json"
        assert meta_file.exists()

        meta_data = json.loads(meta_file.read_text(encoding="utf-8"))
        assert meta_data["novel_id"] == 1
        assert meta_data["title"] == "测试小说"
        assert meta_data["author"] == "测试作者"
        assert meta_data["description"] == "这是一本用于测试的小说"
        assert meta_data["total_chapters"] == 100
        assert meta_data["sync_version"] == 1

        # 验证 chapters_info 存在（存储章节元数据）
        assert "chapters_info" in meta_data
        assert len(meta_data["chapters_info"]) == 1
        chapter_info = meta_data["chapters_info"][0]
        assert chapter_info["chapter_id"] == 1
        assert chapter_info["title"] == "第一章：开始"
        assert chapter_info["chapter_index"] == 1
        assert chapter_info["is_user_inserted"] is False
        assert "filename" in chapter_info
        # 文件名中的冒号被替换为下划线
        assert chapter_info["filename"] == "001_第一章_开始.txt"

        # 验证 outlines_info 存在（存储大纲元数据）
        assert "outlines_info" in meta_data
        assert len(meta_data["outlines_info"]) == 1
        outline_info = meta_data["outlines_info"][0]
        assert outline_info["outline_id"] == 1
        assert outline_info["title"] == "第一卷"
        assert outline_info["outline_type"] == "volume"
        assert "filename" in outline_info
        assert outline_info["filename"] == "第一卷.txt"

    def test_save_novel_creates_chapter_files(
        self, sync_service: NovelSyncService, sample_novel_data: NovelSyncData
    ):
        """测试保存小说会创建章节文件（纯文本格式）."""
        # When
        sync_service.save_novel(sample_novel_data)

        # Then - 验证章节文件
        novel_dir = sync_service._find_novel_dir_by_url(sample_novel_data.source_url)
        assert novel_dir is not None
        chapters_dir = novel_dir / "chapters"
        assert chapters_dir.exists()

        # 新格式：章节文件为 txt 格式，文件名格式为 {index:03d}_{title}.txt
        chapter_files = list(chapters_dir.glob("*.txt"))
        assert len(chapter_files) == 1

        # 验证文件名格式
        # 注意：章节标题 "第一章：开始" 包含冒号，会被替换为下划线
        chapter_file = chapter_files[0]
        assert chapter_file.name == "001_第一章_开始.txt"

        # 验证文件内容为纯文本（只保存章节内容）
        content = chapter_file.read_text(encoding="utf-8")
        assert content == "这是第一章的内容，讲述了一个精彩的故事..."

    def test_save_novel_creates_character_files(
        self, sync_service: NovelSyncService, sample_novel_data: NovelSyncData
    ):
        """测试保存小说会创建角色文件（每人一个 JSON）."""
        # When
        sync_service.save_novel(sample_novel_data)

        # Then - 验证角色文件
        novel_dir = sync_service._find_novel_dir_by_url(sample_novel_data.source_url)
        assert novel_dir is not None
        characters_dir = novel_dir / "characters"
        assert characters_dir.exists()

        # 新格式：每个角色一个 JSON 文件
        character_files = list(characters_dir.glob("*.json"))
        assert len(character_files) == 1

        # 验证文件名（使用角色名）
        character_file = character_files[0]
        assert character_file.name == "张三.json"

        # 验证文件内容（完整的角色数据）
        character_data = json.loads(character_file.read_text(encoding="utf-8"))
        assert character_data["name"] == "张三"
        assert character_data["occupation"] == "剑客"
        assert character_data["gender"] == "男"
        assert character_data["age"] == 25

    def test_save_novel_creates_character_relations_file(
        self, sync_service: NovelSyncService, sample_novel_data: NovelSyncData
    ):
        """测试保存小说会创建角色关系文件."""
        # When
        sync_service.save_novel(sample_novel_data)

        # Then - 验证角色关系文件
        novel_dir = sync_service._find_novel_dir_by_url(sample_novel_data.source_url)
        assert novel_dir is not None
        relations_file = novel_dir / "character_relations.json"
        assert relations_file.exists()

        # 验证文件内容
        relations_data = json.loads(relations_file.read_text(encoding="utf-8"))
        assert len(relations_data) == 1
        assert relations_data[0]["relation_type"] == "朋友"
        assert relations_data[0]["description"] == "生死之交"

    def test_save_novel_creates_outline_files(
        self, sync_service: NovelSyncService, sample_novel_data: NovelSyncData
    ):
        """测试保存小说会创建大纲文件（纯文本格式）."""
        # When
        sync_service.save_novel(sample_novel_data)

        # Then - 验证大纲文件
        novel_dir = sync_service._find_novel_dir_by_url(sample_novel_data.source_url)
        assert novel_dir is not None
        outlines_dir = novel_dir / "outlines"
        assert outlines_dir.exists()

        # 新格式：大纲文件为 txt 格式
        outline_files = list(outlines_dir.glob("*.txt"))
        assert len(outline_files) == 1

        # 验证文件名和内容
        # 文件名是大纲标题（经过非法字符清理）
        outline_file = outline_files[0]
        assert outline_file.name == "第一卷.txt"

        # 文件内容为纯文本（只保存大纲内容）
        content = outline_file.read_text(encoding="utf-8")
        assert content == "主角的成长历程"

    def test_save_novel_minimal_data(
        self, sync_service: NovelSyncService, minimal_novel_data: NovelSyncData
    ):
        """测试保存最小化的小说数据."""
        # When
        result = sync_service.save_novel(minimal_novel_data)

        # Then
        assert result["success"] is True
        assert result["novel_id"] == 2

        novel_dir = sync_service._find_novel_dir_by_url(f"local_{minimal_novel_data.novel_id}")
        assert novel_dir is not None
        assert (novel_dir / "meta.json").exists()

    def test_save_novel_complete_directory_structure(
        self, sync_service: NovelSyncService, sample_novel_data: NovelSyncData
    ):
        """测试保存小说后目录结构完整."""
        # When
        sync_service.save_novel(sample_novel_data)

        # Then - 验证完整的目录结构
        novel_dir = sync_service._find_novel_dir_by_url(sample_novel_data.source_url)
        assert novel_dir is not None

        # 验证目录名使用小说标题
        assert novel_dir.name == "测试小说"

        # 验证所有必要的文件和目录存在
        assert (novel_dir / "meta.json").exists()
        assert (novel_dir / "chapters").is_dir()
        assert (novel_dir / "outlines").is_dir()
        assert (novel_dir / "characters").is_dir()
        assert (novel_dir / "character_relations.json").exists()

        # 验证章节文件格式
        chapter_files = list((novel_dir / "chapters").glob("*.txt"))
        assert len(chapter_files) == 1
        assert chapter_files[0].name == "001_第一章_开始.txt"

        # 验证大纲文件格式
        outline_files = list((novel_dir / "outlines").glob("*.txt"))
        assert len(outline_files) == 1
        assert outline_files[0].name == "第一卷.txt"

        # 验证角色文件格式
        character_files = list((novel_dir / "characters").glob("*.json"))
        assert len(character_files) == 1
        assert character_files[0].name == "张三.json"

    def test_save_novel_updates_version(
        self, sync_service: NovelSyncService, sample_novel_data: NovelSyncData
    ):
        """测试保存已存在的小说会增加版本号."""
        # Given - 第一次保存
        result1 = sync_service.save_novel(sample_novel_data)
        assert result1["sync_version"] == 1

        # When - 第二次保存
        sample_novel_data.title = "更新后的标题"
        result2 = sync_service.save_novel(sample_novel_data)

        # Then - 版本号增加
        assert result2["sync_version"] == 2

    def test_save_novel_multiple_chapters(
        self, sync_service: NovelSyncService, sample_novel_data: NovelSyncData
    ):
        """测试保存包含多个章节的小说."""
        # Given - 添加更多章节
        sample_novel_data.chapters = [
            ChapterSyncData(
                chapter_id=i,
                title=f"第{i}章",
                content=f"第{i}章内容",
                chapter_index=i,
                is_user_inserted=False,
            )
            for i in range(1, 6)
        ]

        # When
        result = sync_service.save_novel(sample_novel_data)

        # Then
        assert result["success"] is True

        novel_dir = sync_service._find_novel_dir_by_url(sample_novel_data.source_url)
        assert novel_dir is not None
        chapters_dir = novel_dir / "chapters"
        assert len(list(chapters_dir.glob("*.txt"))) == 5

    def test_save_novel_sanitizes_filename(
        self, sync_service: NovelSyncService
    ):
        """测试保存小说时清理非法文件名字符."""
        # Given - 标题包含非法字符
        novel_data = NovelSyncData(
            novel_id=1,
            title='测试:小说<>"|?*',  # 包含非法字符
            source_url="https://example.com/novel/test",
            chapters=[
                ChapterSyncData(
                    chapter_id=1,
                    title='章节:标题',  # 包含非法字符
                    content="内容",
                    chapter_index=1,
                )
            ],
        )

        # When
        result = sync_service.save_novel(novel_data)

        # Then - 验证非法字符被替换
        assert result["success"] is True
        novel_dir = sync_service._find_novel_dir_by_url(novel_data.source_url)
        assert novel_dir is not None
        # 目录名应该是清理后的标题
        assert ":" not in novel_dir.name
        assert "<" not in novel_dir.name

        # 验证章节文件名也清理了非法字符
        chapters_dir = novel_dir / "chapters"
        for chapter_file in chapters_dir.glob("*.txt"):
            assert ":" not in chapter_file.name

    def test_save_novel_handles_title_conflict(
        self, sync_service: NovelSyncService
    ):
        """测试保存小说时处理标题冲突."""
        # Given - 保存第一本小说
        novel1 = NovelSyncData(
            novel_id=1,
            title="同名小说",
            source_url="https://example.com/novel/1",
        )
        sync_service.save_novel(novel1)

        # When - 保存第二本同名小说（不同 source_url）
        novel2 = NovelSyncData(
            novel_id=2,
            title="同名小说",
            source_url="https://example.com/novel/2",
        )
        result = sync_service.save_novel(novel2)

        # Then - 第二本应该使用带数字后缀的目录
        assert result["success"] is True
        novel2_dir = sync_service._find_novel_dir_by_url(novel2.source_url)
        assert novel2_dir is not None
        # 目录名应该有数字后缀
        assert novel2_dir.name == "同名小说_1"

    def test_save_novel_multiple_characters(
        self, sync_service: NovelSyncService, sample_novel_data: NovelSyncData
    ):
        """测试保存包含多个角色的小说."""
        # Given - 添加更多角色
        sample_novel_data.characters = [
            CharacterSyncData(
                character_id=1,
                name="张三",
                occupation="剑客",
            ),
            CharacterSyncData(
                character_id=2,
                name="李四",
                occupation="法师",
            ),
            CharacterSyncData(
                character_id=3,
                name="王五",
                occupation="盗贼",
            ),
        ]

        # When
        result = sync_service.save_novel(sample_novel_data)

        # Then
        assert result["success"] is True

        novel_dir = sync_service._find_novel_dir_by_url(sample_novel_data.source_url)
        assert novel_dir is not None
        characters_dir = novel_dir / "characters"
        character_files = list(characters_dir.glob("*.json"))
        assert len(character_files) == 3

        # 验证每个角色文件都存在
        character_names = {f.stem for f in character_files}
        assert character_names == {"张三", "李四", "王五"}

    def test_save_novel_multiple_outlines(
        self, sync_service: NovelSyncService, sample_novel_data: NovelSyncData
    ):
        """测试保存包含多个大纲的小说."""
        # Given - 添加更多大纲
        sample_novel_data.outlines = [
            OutlineSyncData(
                outline_id=1,
                title="主线大纲",
                content="主线剧情发展",
                outline_type="main",
                sort_order=1,
            ),
            OutlineSyncData(
                outline_id=2,
                title="支线大纲",
                content="支线剧情发展",
                outline_type="sub",
                sort_order=2,
            ),
        ]

        # When
        result = sync_service.save_novel(sample_novel_data)

        # Then
        assert result["success"] is True

        novel_dir = sync_service._find_novel_dir_by_url(sample_novel_data.source_url)
        assert novel_dir is not None
        outlines_dir = novel_dir / "outlines"
        outline_files = list(outlines_dir.glob("*.txt"))
        assert len(outline_files) == 2

        # 验证每个大纲文件都存在
        outline_titles = {f.stem for f in outline_files}
        assert outline_titles == {"主线大纲", "支线大纲"}

        # 验证大纲内容
        for outline_file in outline_files:
            content = outline_file.read_text(encoding="utf-8")
            assert "剧情发展" in content


class TestLoadNovel(TestNovelSyncService):
    """测试 load_novel 方法."""

    def test_load_novel_success(
        self, sync_service: NovelSyncService, sample_novel_data: NovelSyncData
    ):
        """测试成功加载已保存的小说."""
        # Given - 先保存小说
        sync_service.save_novel(sample_novel_data)

        # When - 加载小说
        loaded_novel = sync_service.load_novel(sample_novel_data.source_url)

        # Then - 验证加载的数据
        assert loaded_novel is not None
        assert loaded_novel.novel_id == 1
        assert loaded_novel.title == "测试小说"
        assert loaded_novel.author == "测试作者"
        assert loaded_novel.total_chapters == 100
        assert len(loaded_novel.chapters) == 1
        assert loaded_novel.chapters[0].title == "第一章：开始"
        assert loaded_novel.chapters[0].content == "这是第一章的内容，讲述了一个精彩的故事..."

    def test_load_novel_not_found(self, sync_service: NovelSyncService):
        """测试加载不存在的小说返回 None."""
        # When
        result = sync_service.load_novel("https://example.com/nonexistent")

        # Then
        assert result is None

    def test_load_novel_with_chapters(
        self, sync_service: NovelSyncService, sample_novel_data: NovelSyncData
    ):
        """测试加载包含章节数据的小说."""
        # Given - 添加多个章节
        sample_novel_data.chapters = [
            ChapterSyncData(
                chapter_id=i,
                title=f"第{i}章",
                content=f"第{i}章内容",
                chapter_index=i,
                is_user_inserted=False,
            )
            for i in range(1, 4)
        ]
        sync_service.save_novel(sample_novel_data)

        # When
        loaded_novel = sync_service.load_novel(sample_novel_data.source_url)

        # Then
        assert loaded_novel is not None
        assert len(loaded_novel.chapters) == 3
        # 验证章节按 chapter_index 排序
        for i, chapter in enumerate(loaded_novel.chapters, 1):
            assert chapter.chapter_index == i
            assert chapter.content == f"第{i}章内容"

    def test_load_novel_with_characters(
        self, sync_service: NovelSyncService, sample_novel_data: NovelSyncData
    ):
        """测试加载包含角色数据的小说."""
        # Given
        sync_service.save_novel(sample_novel_data)

        # When
        loaded_novel = sync_service.load_novel(sample_novel_data.source_url)

        # Then
        assert loaded_novel is not None
        assert len(loaded_novel.characters) == 1
        assert loaded_novel.characters[0].name == "张三"
        assert loaded_novel.characters[0].occupation == "剑客"

    def test_load_novel_with_character_relations(
        self, sync_service: NovelSyncService, sample_novel_data: NovelSyncData
    ):
        """测试加载包含角色关系数据的小说."""
        # Given
        sync_service.save_novel(sample_novel_data)

        # When
        loaded_novel = sync_service.load_novel(sample_novel_data.source_url)

        # Then
        assert loaded_novel is not None
        assert len(loaded_novel.character_relations) == 1
        assert loaded_novel.character_relations[0].relation_type == "朋友"

    def test_load_novel_with_outlines(
        self, sync_service: NovelSyncService, sample_novel_data: NovelSyncData
    ):
        """测试加载包含大纲数据的小说."""
        # Given
        sync_service.save_novel(sample_novel_data)

        # When
        loaded_novel = sync_service.load_novel(sample_novel_data.source_url)

        # Then
        assert loaded_novel is not None
        assert len(loaded_novel.outlines) == 1
        assert loaded_novel.outlines[0].title == "第一卷"
        assert loaded_novel.outlines[0].content == "主角的成长历程"


class TestListSyncedNovels(TestNovelSyncService):
    """测试 list_synced_novels 方法."""

    def test_list_synced_novels_empty(self, sync_service: NovelSyncService):
        """测试列出空的同步列表."""
        # When
        result = sync_service.list_synced_novels()

        # Then
        assert result["novels"] == []
        assert result["total_count"] == 0
        assert result["page"] == 1
        assert result["page_size"] == 20

    def test_list_synced_novels_single(
        self, sync_service: NovelSyncService, sample_novel_data: NovelSyncData
    ):
        """测试列出单个已同步的小说."""
        # Given
        sync_service.save_novel(sample_novel_data)

        # When
        result = sync_service.list_synced_novels()

        # Then
        assert result["total_count"] == 1
        assert len(result["novels"]) == 1
        assert result["novels"][0]["novel_id"] == 1
        assert result["novels"][0]["title"] == "测试小说"

    def test_list_synced_novels_multiple(
        self, sync_service: NovelSyncService, sample_novel_data: NovelSyncData
    ):
        """测试列出多个已同步的小说."""
        # Given - 保存多个小说
        for i in range(5):
            novel = NovelSyncData(
                novel_id=i,
                title=f"小说{i}",
                source_url=f"https://example.com/novel/{i}",
            )
            sync_service.save_novel(novel)

        # When
        result = sync_service.list_synced_novels()

        # Then
        assert result["total_count"] == 5
        assert len(result["novels"]) == 5

    def test_list_synced_novels_pagination(
        self, sync_service: NovelSyncService, sample_novel_data: NovelSyncData
    ):
        """测试分页功能."""
        # Given - 保存多个小说
        for i in range(25):
            novel = NovelSyncData(
                novel_id=i,
                title=f"小说{i}",
                source_url=f"https://example.com/novel/{i}",
            )
            sync_service.save_novel(novel)

        # When - 获取第一页
        result_page1 = sync_service.list_synced_novels(page=1, page_size=10)

        # Then
        assert result_page1["total_count"] == 25
        assert len(result_page1["novels"]) == 10
        assert result_page1["page"] == 1

        # When - 获取第二页
        result_page2 = sync_service.list_synced_novels(page=2, page_size=10)

        # Then
        assert result_page2["total_count"] == 25
        assert len(result_page2["novels"]) == 10
        assert result_page2["page"] == 2

        # When - 获取最后一页
        result_page3 = sync_service.list_synced_novels(page=3, page_size=10)

        # Then
        assert result_page3["total_count"] == 25
        assert len(result_page3["novels"]) == 5  # 剩余5个

    def test_list_synced_novels_returns_basic_info_only(
        self, sync_service: NovelSyncService, sample_novel_data: NovelSyncData
    ):
        """测试列表返回的只是基本信息，不包含章节内容."""
        # Given
        sync_service.save_novel(sample_novel_data)

        # When
        result = sync_service.list_synced_novels()

        # Then - 验证返回字段
        novel_info = result["novels"][0]
        assert "novel_id" in novel_info
        assert "title" in novel_info
        assert "author" in novel_info
        assert "source_url" in novel_info
        assert "total_chapters" in novel_info
        assert "sync_version" in novel_info
        assert "synced_at" in novel_info
        # 不应该包含章节内容
        assert "chapters" not in novel_info
        assert "description" not in novel_info

    def test_list_synced_novels_sorted_by_sync_time(
        self, sync_service: NovelSyncService
    ):
        """测试列表按同步时间倒序排列."""
        # Given - 保存多个小说
        novel_ids = []
        for i in range(3):
            novel = NovelSyncData(
                novel_id=i,
                title=f"小说{i}",
                source_url=f"https://example.com/novel/{i}",
            )
            sync_service.save_novel(novel)
            novel_ids.append(i)

        # When
        result = sync_service.list_synced_novels()

        # Then - 最后保存的应该在最前面
        assert result["novels"][0]["novel_id"] == 2  # 最后保存的
        assert result["novels"][-1]["novel_id"] == 0  # 最先保存的


class TestDeleteNovel(TestNovelSyncService):
    """测试 delete_novel 方法."""

    def test_delete_novel_success(
        self, sync_service: NovelSyncService, sample_novel_data: NovelSyncData
    ):
        """测试成功删除已同步的小说."""
        # Given
        sync_service.save_novel(sample_novel_data)
        assert sync_service.novel_exists(sample_novel_data.source_url)

        # When
        result = sync_service.delete_novel(sample_novel_data.source_url)

        # Then
        assert result is True
        assert not sync_service.novel_exists(sample_novel_data.source_url)

    def test_delete_novel_not_found(self, sync_service: NovelSyncService):
        """测试删除不存在的小说返回 False."""
        # When
        result = sync_service.delete_novel("https://example.com/nonexistent")

        # Then
        assert result is False

    def test_delete_novel_removes_all_files(
        self, sync_service: NovelSyncService, sample_novel_data: NovelSyncData
    ):
        """测试删除小说会移除所有相关文件."""
        # Given
        sync_service.save_novel(sample_novel_data)
        novel_dir = sync_service._find_novel_dir_by_url(sample_novel_data.source_url)

        # 验证文件存在
        assert novel_dir is not None
        assert novel_dir.exists()
        assert (novel_dir / "meta.json").exists()
        assert (novel_dir / "chapters").exists()
        assert (novel_dir / "characters").exists()
        assert (novel_dir / "outlines").exists()
        assert (novel_dir / "character_relations.json").exists()

        # When
        sync_service.delete_novel(sample_novel_data.source_url)

        # Then - 目录应该被完全删除
        assert not novel_dir.exists()

    def test_delete_novel_can_save_again(
        self, sync_service: NovelSyncService, sample_novel_data: NovelSyncData
    ):
        """测试删除后可以重新保存."""
        # Given
        sync_service.save_novel(sample_novel_data)
        sync_service.delete_novel(sample_novel_data.source_url)

        # When - 重新保存
        result = sync_service.save_novel(sample_novel_data)

        # Then
        assert result["success"] is True
        assert result["sync_version"] == 1  # 版本号应该重置

    def test_delete_one_novel_keeps_others(
        self, sync_service: NovelSyncService
    ):
        """测试删除一个小说不影响其他小说."""
        # Given - 保存两个小说
        novel1 = NovelSyncData(
            novel_id=1, title="小说1", source_url="https://example.com/novel/1"
        )
        novel2 = NovelSyncData(
            novel_id=2, title="小说2", source_url="https://example.com/novel/2"
        )
        sync_service.save_novel(novel1)
        sync_service.save_novel(novel2)

        # When - 删除第一个
        sync_service.delete_novel("https://example.com/novel/1")

        # Then - 第二个应该还存在
        assert not sync_service.novel_exists("https://example.com/novel/1")
        assert sync_service.novel_exists("https://example.com/novel/2")


class TestNovelExists(TestNovelSyncService):
    """测试 novel_exists 方法."""

    def test_novel_exists_true(
        self, sync_service: NovelSyncService, sample_novel_data: NovelSyncData
    ):
        """测试存在的小说返回 True."""
        # Given
        sync_service.save_novel(sample_novel_data)

        # When & Then
        assert sync_service.novel_exists(sample_novel_data.source_url) is True

    def test_novel_exists_false(self, sync_service: NovelSyncService):
        """测试不存在的小说返回 False."""
        # When & Then
        assert sync_service.novel_exists("https://example.com/nonexistent") is False

    def test_novel_exists_requires_meta_file(
        self, sync_service: NovelSyncService, sample_novel_data: NovelSyncData
    ):
        """测试小说存在需要 meta.json 文件."""
        # Given - 创建目录但不创建 meta.json
        novel_dir = sync_service.sync_dir / "test_novel"
        novel_dir.mkdir(parents=True, exist_ok=True)
        assert novel_dir.exists()

        # When & Then - 没有 meta.json 应该返回 False
        assert sync_service.novel_exists("https://example.com/test_novel") is False


class TestGetSyncStatus(TestNovelSyncService):
    """测试 get_sync_status 方法."""

    def test_get_sync_status_success(
        self, sync_service: NovelSyncService, sample_novel_data: NovelSyncData
    ):
        """测试获取已同步小说的状态."""
        # Given
        sync_service.save_novel(sample_novel_data)

        # When
        status = sync_service.get_sync_status(sample_novel_data.source_url)

        # Then
        assert status is not None
        assert status["novel_id"] == 1
        assert status["title"] == "测试小说"
        assert status["sync_version"] == 1
        assert status["chapter_count"] == 1
        assert status["has_characters"] is True
        assert status["has_character_relations"] is True
        assert status["has_outlines"] is True

    def test_get_sync_status_not_found(self, sync_service: NovelSyncService):
        """测试获取不存在小说的状态返回 None."""
        # When
        status = sync_service.get_sync_status("https://example.com/nonexistent")

        # Then
        assert status is None

    def test_get_sync_status_minimal_data(
        self, sync_service: NovelSyncService, minimal_novel_data: NovelSyncData
    ):
        """测试获取最小化数据小说的状态."""
        # Given
        sync_service.save_novel(minimal_novel_data)

        # When
        status = sync_service.get_sync_status(f"local_{minimal_novel_data.novel_id}")

        # Then
        assert status is not None
        assert status["chapter_count"] == 0
        assert status["has_characters"] is False
        assert status["has_character_relations"] is False
        assert status["has_outlines"] is False


class TestFilenameSanitization(TestNovelSyncService):
    """测试文件名清理功能."""

    def test_sanitize_filename_removes_illegal_chars(self, sync_service: NovelSyncService):
        """测试清理非法字符."""
        # Given
        illegal_name = 'test<>:"/\\|?*file'

        # When
        safe_name = sync_service._sanitize_filename(illegal_name)

        # Then - 所有非法字符应被替换
        for char in NovelSyncService.ILLEGAL_FILENAME_CHARS:
            assert char not in safe_name

    def test_sanitize_filename_handles_empty_string(self, sync_service: NovelSyncService):
        """测试处理空字符串."""
        # When
        safe_name = sync_service._sanitize_filename("")

        # Then - 应返回默认名称
        assert safe_name == "unnamed"

    def test_sanitize_filename_handles_whitespace_only(self, sync_service: NovelSyncService):
        """测试处理只有空格的字符串."""
        # When
        safe_name = sync_service._sanitize_filename("   ")

        # Then - 应返回默认名称
        assert safe_name == "unnamed"


class TestUserInsertedChapter(TestNovelSyncService):
    """测试用户插入章节功能."""

    def test_save_and_load_user_inserted_chapter(self, sync_service: NovelSyncService):
        """测试保存和加载用户插入章节."""
        # Given - 包含用户插入章节的小说
        novel_data = NovelSyncData(
            novel_id=1,
            title="测试小说",
            source_url="https://example.com/novel/1",
            chapters=[
                ChapterSyncData(
                    chapter_id=1,
                    title="第一章",
                    content="正常章节内容",
                    chapter_index=1,
                    is_user_inserted=False,
                ),
                ChapterSyncData(
                    chapter_id=2,
                    title="番外：我的故事",
                    content="用户插入的章节内容",
                    chapter_index=2,
                    is_user_inserted=True,
                ),
            ],
        )

        # When
        sync_service.save_novel(novel_data)
        loaded_novel = sync_service.load_novel(novel_data.source_url)

        # Then
        assert loaded_novel is not None
        assert len(loaded_novel.chapters) == 2
        assert loaded_novel.chapters[0].is_user_inserted is False
        assert loaded_novel.chapters[1].is_user_inserted is True
        assert loaded_novel.chapters[1].title == "番外：我的故事"