# 小说同步功能实现计划

> **面向 AI 代理的工作者：** 必需子技能：使用 superpowers:subagent-driven-development（推荐）或 superpowers:executing-plans 逐任务实现此计划。步骤使用复选框（`- [ ]`）语法来跟踪进度。

**目标：** 实现小说通过后台服务同步的功能，支持上传小说数据到服务器文件系统，并支持下载同步回来，便于在电脑上进行快速的小说编辑。

**架构：**
- 后端新增两个REST API端点（上传/下载），将小说数据存储为目录结构（一本小说一个目录，背景设定、人物关系等用单独TXT文件）
- APP在目录界面新增上传/下载按钮，上传时打包所有小说数据，下载时解析并替换本地数据
- 使用JSON格式进行数据传输，后端负责JSON与TXT文件的相互转换

**技术栈：**
- 后端：FastAPI, Pydantic, Python pathlib
- APP：Flutter, Dart, Riverpod, http

---

## 文件结构

### 后端新增/修改文件

| 文件路径 | 职责 |
|---------|------|
| `backend/app/api/routes/novel_sync.py` | **新建** - 小说同步API路由，包含上传/下载端点 |
| `backend/app/services/novel_sync_service.py` | **新建** - 同步服务，处理JSON与文件系统的转换 |
| `backend/app/schemas.py` | **修改** - 添加NovelSyncData等Pydantic模型 |
| `backend/app/main.py` | **修改** - 注册新路由 |
| `backend/app/config.py` | **修改** - 添加同步目录配置项 |

### APP新增/修改文件

| 文件路径 | 职责 |
|---------|------|
| `novel_app/lib/services/novel_sync_service.dart` | **新建** - 同步服务，封装上传/下载逻辑 |
| `novel_app/lib/core/providers/novel_sync_providers.dart` | **新建** - Riverpod状态管理 |
| `novel_app/lib/screens/chapter_list_screen_riverpod.dart` | **修改** - 添加上传/下载按钮到菜单 |
| `novel_app/lib/widgets/novel_sync_dialog.dart` | **新建** - 同步进度对话框 |
| `novel_app/lib/repositories/novel_export_repository.dart` | **新建** - 小说数据导出/导入Repository |
| `novel_app/lib/services/api_service_wrapper.dart` | **修改** - 添加同步API调用方法 |

### 后端文件存储结构

```
novel_sync/
├── {novel_title_hash}/           # 以标题哈希作为目录名
│   ├── meta.json                 # 小说元数据（标题、作者、URL等）
│   ├── background_setting.txt    # 背景设定
│   ├── outline.txt               # 大纲内容
│   ├── characters.json           # 角色列表（JSON格式更合适）
│   ├── character_relations.json  # 角色关系
│   └── chapters/
│       ├── 001_第一章_标题.txt   # 章节内容
│       ├── 002_第二章_标题.txt
│       └── ...
```

---

## 任务分解

---

### 任务 1：后端 - 定义数据模型和Schema

**文件：**
- 修改：`backend/app/schemas.py`
- 修改：`backend/app/config.py`

- [ ] **步骤 1：添加配置项**

在 `backend/app/config.py` 中添加同步目录配置：

```python
# 在 Settings 类中添加
novel_sync_dir: str = "novel_sync"  # 小说同步目录
```

- [ ] **步骤 2：定义同步数据Schema**

在 `backend/app/schemas.py` 末尾添加：

```python
# ==================== 小说同步相关 ====================

class ChapterSyncData(BaseModel):
    """章节数据"""
    title: str
    url: str
    content: Optional[str] = None
    chapter_index: int
    is_user_inserted: bool = False
    read_at: Optional[int] = None
    is_accompanied: bool = False


class CharacterSyncData(BaseModel):
    """角色数据"""
    name: str
    age: Optional[int] = None
    gender: Optional[str] = None
    occupation: Optional[str] = None
    personality: Optional[str] = None
    body_type: Optional[str] = None
    clothing_style: Optional[str] = None
    appearance_features: Optional[str] = None
    background_story: Optional[str] = None
    face_prompts: Optional[str] = None
    body_prompts: Optional[str] = None
    aliases: List[str] = []


class CharacterRelationSyncData(BaseModel):
    """角色关系数据"""
    source_character_name: str
    target_character_name: str
    relationship_type: str
    description: Optional[str] = None


class OutlineSyncData(BaseModel):
    """大纲数据"""
    title: str
    content: str


class NovelSyncData(BaseModel):
    """完整小说同步数据"""
    # 小说元数据
    title: str
    author: str
    url: str
    cover_url: Optional[str] = None
    description: Optional[str] = None
    background_setting: Optional[str] = None

    # 关联数据
    chapters: List[ChapterSyncData] = []
    characters: List[CharacterSyncData] = []
    character_relations: List[CharacterRelationSyncData] = []
    outline: Optional[OutlineSyncData] = None

    # 同步时间戳
    synced_at: Optional[str] = None


class NovelSyncUploadRequest(BaseModel):
    """上传请求"""
    novel: NovelSyncData


class NovelSyncUploadResponse(BaseModel):
    """上传响应"""
    success: bool
    message: str
    sync_path: Optional[str] = None  # 服务器上的存储路径


class NovelSyncDownloadRequest(BaseModel):
    """下载请求"""
    novel_url: str  # 使用URL作为唯一标识


class NovelSyncDownloadResponse(BaseModel):
    """下载响应"""
    success: bool
    message: str
    novel: Optional[NovelSyncData] = None


class NovelSyncListResponse(BaseModel):
    """同步列表响应"""
    success: bool
    novels: List[dict]  # [{title, author, url, synced_at}]
```

- [ ] **步骤 3：Commit**

```bash
git add backend/app/schemas.py backend/app/config.py
git commit -m "feat(backend): add novel sync data models and config"
```

---

### 任务 2：后端 - 实现同步服务

**文件：**
- 创建：`backend/app/services/novel_sync_service.py`

- [ ] **步骤 1：创建同步服务类**

创建文件 `backend/app/services/novel_sync_service.py`：

```python
"""
小说同步服务

负责将小说数据在JSON格式和文件系统之间转换
"""
import json
import hashlib
from pathlib import Path
from datetime import datetime
from typing import Optional, List

from ..schemas import (
    NovelSyncData,
    ChapterSyncData,
    CharacterSyncData,
    CharacterRelationSyncData,
    OutlineSyncData,
)
from ..config import settings


class NovelSyncService:
    """小说同步服务"""

    def __init__(self):
        self.sync_dir = Path(settings.novel_sync_dir)
        self.sync_dir.mkdir(parents=True, exist_ok=True)

    def _get_novel_dir(self, novel_url: str) -> Path:
        """获取小说目录路径"""
        # 使用URL的MD5作为目录名，确保唯一性
        url_hash = hashlib.md5(novel_url.encode()).hexdigest()[:12]
        return self.sync_dir / url_hash

    def _sanitize_filename(self, name: str, max_length: int = 50) -> str:
        """清理文件名，移除非法字符"""
        # 移除Windows/Linux不允许的字符
        invalid_chars = '<>:"/\\|?*'
        for char in invalid_chars:
            name = name.replace(char, '_')
        return name[:max_length].strip()

    def save_novel(self, novel_data: NovelSyncData) -> tuple[bool, str, str]:
        """
        保存小说数据到文件系统

        Returns:
            (success, message, sync_path)
        """
        try:
            novel_dir = self._get_novel_dir(novel_data.url)
            novel_dir.mkdir(parents=True, exist_ok=True)

            # 创建章节目录
            chapters_dir = novel_dir / "chapters"
            chapters_dir.mkdir(exist_ok=True)

            # 1. 保存元数据
            meta = {
                "title": novel_data.title,
                "author": novel_data.author,
                "url": novel_data.url,
                "cover_url": novel_data.cover_url,
                "description": novel_data.description,
                "synced_at": datetime.now().isoformat(),
            }
            with open(novel_dir / "meta.json", "w", encoding="utf-8") as f:
                json.dump(meta, f, ensure_ascii=False, indent=2)

            # 2. 保存背景设定
            if novel_data.background_setting:
                with open(novel_dir / "background_setting.txt", "w", encoding="utf-8") as f:
                    f.write(novel_data.background_setting)

            # 3. 保存大纲
            if novel_data.outline:
                with open(novel_dir / "outline.txt", "w", encoding="utf-8") as f:
                    f.write(f"# {novel_data.outline.title}\n\n{novel_data.outline.content}")

            # 4. 保存角色列表
            if novel_data.characters:
                characters_data = [c.model_dump() for c in novel_data.characters]
                with open(novel_dir / "characters.json", "w", encoding="utf-8") as f:
                    json.dump(characters_data, f, ensure_ascii=False, indent=2)

            # 5. 保存角色关系
            if novel_data.character_relations:
                relations_data = [r.model_dump() for r in novel_data.character_relations]
                with open(novel_dir / "character_relations.json", "w", encoding="utf-8") as f:
                    json.dump(relations_data, f, ensure_ascii=False, indent=2)

            # 6. 保存章节
            for chapter in novel_data.chapters:
                # 文件名格式: 001_章节标题.txt
                index_str = str(chapter.chapter_index).zfill(4)
                title_safe = self._sanitize_filename(chapter.title)
                filename = f"{index_str}_{title_safe}.txt"

                # 章节内容格式：标题 + 元数据 + 内容
                content_lines = [
                    f"# {chapter.title}",
                    f"",
                    f"<!-- url: {chapter.url} -->",
                    f"<!-- is_user_inserted: {chapter.is_user_inserted} -->",
                    f"<!-- is_accompanied: {chapter.is_accompanied} -->",
                    f"",
                    chapter.content or "",
                ]
                with open(chapters_dir / filename, "w", encoding="utf-8") as f:
                    f.write("\n".join(content_lines))

            return True, "保存成功", str(novel_dir)

        except Exception as e:
            return False, f"保存失败: {str(e)}", ""

    def load_novel(self, novel_url: str) -> tuple[bool, str, Optional[NovelSyncData]]:
        """
        从文件系统加载小说数据

        Returns:
            (success, message, novel_data)
        """
        try:
            novel_dir = self._get_novel_dir(novel_url)

            if not novel_dir.exists():
                return False, f"小说不存在: {novel_url}", None

            # 1. 读取元数据
            meta_path = novel_dir / "meta.json"
            if not meta_path.exists():
                return False, "元数据文件不存在", None

            with open(meta_path, "r", encoding="utf-8") as f:
                meta = json.load(f)

            # 2. 读取背景设定
            background_setting = None
            bg_path = novel_dir / "background_setting.txt"
            if bg_path.exists():
                with open(bg_path, "r", encoding="utf-8") as f:
                    background_setting = f.read()

            # 3. 读取大纲
            outline = None
            outline_path = novel_dir / "outline.txt"
            if outline_path.exists():
                with open(outline_path, "r", encoding="utf-8") as f:
                    content = f.read()
                    # 解析标题（第一行 # 开头）
                    lines = content.split("\n")
                    title = lines[0].replace("# ", "").strip() if lines else "大纲"
                    body = "\n".join(lines[2:]) if len(lines) > 2 else ""
                    outline = OutlineSyncData(title=title, content=body)

            # 4. 读取角色列表
            characters: List[CharacterSyncData] = []
            chars_path = novel_dir / "characters.json"
            if chars_path.exists():
                with open(chars_path, "r", encoding="utf-8") as f:
                    chars_data = json.load(f)
                    characters = [CharacterSyncData(**c) for c in chars_data]

            # 5. 读取角色关系
            character_relations: List[CharacterRelationSyncData] = []
            rels_path = novel_dir / "character_relations.json"
            if rels_path.exists():
                with open(rels_path, "r", encoding="utf-8") as f:
                    rels_data = json.load(f)
                    character_relations = [CharacterRelationSyncData(**r) for r in rels_data]

            # 6. 读取章节
            chapters: List[ChapterSyncData] = []
            chapters_dir = novel_dir / "chapters"
            if chapters_dir.exists():
                # 按文件名排序
                chapter_files = sorted(chapters_dir.glob("*.txt"))
                for cf in chapter_files:
                    with open(cf, "r", encoding="utf-8") as f:
                        content = f.read()

                    # 解析章节信息
                    lines = content.split("\n")
                    title = lines[0].replace("# ", "").strip() if lines else ""

                    # 解析注释中的元数据
                    url = ""
                    is_user_inserted = False
                    is_accompanied = False

                    for line in lines[1:6]:  # 检查前几行
                        if line.startswith("<!-- url:"):
                            url = line.split(":")[1].strip().replace(" -->", "")
                        elif line.startswith("<!-- is_user_inserted:"):
                            is_user_inserted = "true" in line.lower()
                        elif line.startswith("<!-- is_accompanied:"):
                            is_accompanied = "true" in line.lower()

                    # 内容从元数据之后开始
                    content_start = 0
                    for i, line in enumerate(lines):
                        if line.strip() == "" and i > 3:
                            content_start = i + 1
                            break

                    chapter_content = "\n".join(lines[content_start:]) if content_start > 0 else ""

                    # 从文件名提取索引
                    try:
                        index = int(cf.stem.split("_")[0])
                    except (ValueError, IndexError):
                        index = len(chapters)

                    chapters.append(ChapterSyncData(
                        title=title,
                        url=url,
                        content=chapter_content,
                        chapter_index=index,
                        is_user_inserted=is_user_inserted,
                        is_accompanied=is_accompanied,
                    ))

            # 构建返回数据
            novel_data = NovelSyncData(
                title=meta["title"],
                author=meta["author"],
                url=meta["url"],
                cover_url=meta.get("cover_url"),
                description=meta.get("description"),
                background_setting=background_setting,
                chapters=chapters,
                characters=characters,
                character_relations=character_relations,
                outline=outline,
                synced_at=meta.get("synced_at"),
            )

            return True, "加载成功", novel_data

        except Exception as e:
            return False, f"加载失败: {str(e)}", None

    def list_synced_novels(self) -> List[dict]:
        """列出所有已同步的小说"""
        novels = []
        if not self.sync_dir.exists():
            return novels

        for novel_dir in self.sync_dir.iterdir():
            if novel_dir.is_dir():
                meta_path = novel_dir / "meta.json"
                if meta_path.exists():
                    try:
                        with open(meta_path, "r", encoding="utf-8") as f:
                            meta = json.load(f)
                        novels.append({
                            "title": meta.get("title", "未知"),
                            "author": meta.get("author", "未知"),
                            "url": meta.get("url", ""),
                            "synced_at": meta.get("synced_at", ""),
                        })
                    except Exception:
                        pass

        return novels

    def delete_novel(self, novel_url: str) -> tuple[bool, str]:
        """删除已同步的小说"""
        try:
            novel_dir = self._get_novel_dir(novel_url)
            if not novel_dir.exists():
                return False, "小说不存在"

            import shutil
            shutil.rmtree(novel_dir)
            return True, "删除成功"

        except Exception as e:
            return False, f"删除失败: {str(e)}"


# 单例实例
_novel_sync_service: Optional[NovelSyncService] = None


def get_novel_sync_service() -> NovelSyncService:
    """获取同步服务单例"""
    global _novel_sync_service
    if _novel_sync_service is None:
        _novel_sync_service = NovelSyncService()
    return _novel_sync_service
```

- [ ] **步骤 2：Commit**

```bash
git add backend/app/services/novel_sync_service.py
git commit -m "feat(backend): implement novel sync service"
```

---

### 任务 3：后端 - 实现API路由

**文件：**
- 创建：`backend/app/api/routes/novel_sync.py`
- 修改：`backend/app/main.py`

- [ ] **步骤 1：创建API路由文件**

创建文件 `backend/app/api/routes/novel_sync.py`：

```python
"""
小说同步API路由
"""
from fastapi import APIRouter, Depends, HTTPException, status

from ...schemas import (
    NovelSyncUploadRequest,
    NovelSyncUploadResponse,
    NovelSyncDownloadRequest,
    NovelSyncDownloadResponse,
    NovelSyncListResponse,
)
from ...services.novel_sync_service import get_novel_sync_service
from ...deps.auth import verify_token

router = APIRouter(prefix="/sync", tags=["novel-sync"])


@router.post("/upload", response_model=NovelSyncUploadResponse)
async def upload_novel(
    request: NovelSyncUploadRequest,
    _: bool = Depends(verify_token),
):
    """
    上传小说数据到服务器

    将小说的所有数据（元数据、章节、角色、大纲等）保存到服务器文件系统
    """
    service = get_novel_sync_service()
    success, message, sync_path = service.save_novel(request.novel)

    if not success:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=message,
        )

    return NovelSyncUploadResponse(
        success=True,
        message=message,
        sync_path=sync_path,
    )


@router.post("/download", response_model=NovelSyncDownloadResponse)
async def download_novel(
    request: NovelSyncDownloadRequest,
    _: bool = Depends(verify_token),
):
    """
    从服务器下载小说数据

    根据小说URL获取之前上传的小说数据
    """
    service = get_novel_sync_service()
    success, message, novel_data = service.load_novel(request.novel_url)

    if not success:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=message,
        )

    return NovelSyncDownloadResponse(
        success=True,
        message=message,
        novel=novel_data,
    )


@router.get("/list", response_model=NovelSyncListResponse)
async def list_synced_novels(
    _: bool = Depends(verify_token),
):
    """
    列出所有已同步的小说
    """
    service = get_novel_sync_service()
    novels = service.list_synced_novels()

    return NovelSyncListResponse(
        success=True,
        novels=novels,
    )


@router.delete("/delete")
async def delete_synced_novel(
    novel_url: str,
    _: bool = Depends(verify_token),
):
    """
    删除已同步的小说
    """
    service = get_novel_sync_service()
    success, message = service.delete_novel(novel_url)

    if not success:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=message,
        )

    return {"success": True, "message": message}
```

- [ ] **步骤 2：在main.py中注册路由**

在 `backend/app/main.py` 中添加路由导入和注册：

```python
# 在导入部分添加
from .api.routes.novel_sync import router as novel_sync_router

# 在路由注册部分添加
app.include_router(novel_sync_router, prefix="/api/novel")
```

- [ ] **步骤 3：Commit**

```bash
git add backend/app/api/routes/novel_sync.py backend/app/main.py
git commit -m "feat(backend): add novel sync API routes"
```

---

### 任务 4：APP - 创建数据导出/导入Repository

**文件：**
- 创建：`novel_app/lib/repositories/novel_export_repository.dart`

- [ ] **步骤 1：创建Repository类**

创建文件 `novel_app/lib/repositories/novel_export_repository.dart`：

```dart
import 'dart:convert';
import 'package:novel_reader/models/novel.dart';
import 'package:novel_reader/models/chapter.dart';
import 'package:novel_reader/models/character.dart';
import 'package:novel_reader/models/outline.dart' as app_outline;
import 'package:novel_reader/models/character_relationship.dart';
import 'package:novel_reader/repositories/chapter_repository.dart';
import 'package:novel_reader/repositories/character_repository.dart';
import 'package:novel_reader/repositories/character_relation_repository.dart';
import 'package:novel_reader/repositories/outline_repository.dart';
import 'package:novel_reader/repositories/illustration_repository.dart';
import 'package:novel_reader/services/logger_service.dart';

/// 小说导出数据模型
class NovelExportData {
  final String title;
  final String author;
  final String url;
  final String? coverUrl;
  final String? description;
  final String? backgroundSetting;
  final List<ChapterExportData> chapters;
  final List<CharacterExportData> characters;
  final List<CharacterRelationExportData> characterRelations;
  final OutlineExportData? outline;
  final String? syncedAt;

  NovelExportData({
    required this.title,
    required this.author,
    required this.url,
    this.coverUrl,
    this.description,
    this.backgroundSetting,
    this.chapters = const [],
    this.characters = const [],
    this.characterRelations = const [],
    this.outline,
    this.syncedAt,
  });

  Map<String, dynamic> toJson() => {
        'title': title,
        'author': author,
        'url': url,
        'cover_url': coverUrl,
        'description': description,
        'background_setting': backgroundSetting,
        'chapters': chapters.map((c) => c.toJson()).toList(),
        'characters': characters.map((c) => c.toJson()).toList(),
        'character_relations': characterRelations.map((r) => r.toJson()).toList(),
        'outline': outline?.toJson(),
        'synced_at': syncedAt,
      };

  factory NovelExportData.fromJson(Map<String, dynamic> json) =>
      NovelExportData(
        title: json['title'] as String,
        author: json['author'] as String,
        url: json['url'] as String,
        coverUrl: json['cover_url'] as String?,
        description: json['description'] as String?,
        backgroundSetting: json['background_setting'] as String?,
        chapters: (json['chapters'] as List?)
                ?.map((c) => ChapterExportData.fromJson(c))
                .toList() ??
            [],
        characters: (json['characters'] as List?)
                ?.map((c) => CharacterExportData.fromJson(c))
                .toList() ??
            [],
        characterRelations: (json['character_relations'] as List?)
                ?.map((r) => CharacterRelationExportData.fromJson(r))
                .toList() ??
            [],
        outline: json['outline'] != null
            ? OutlineExportData.fromJson(json['outline'])
            : null,
        syncedAt: json['synced_at'] as String?,
      );
}

class ChapterExportData {
  final String title;
  final String url;
  final String? content;
  final int chapterIndex;
  final bool isUserInserted;
  final int? readAt;
  final bool isAccompanied;

  ChapterExportData({
    required this.title,
    required this.url,
    this.content,
    required this.chapterIndex,
    this.isUserInserted = false,
    this.readAt,
    this.isAccompanied = false,
  });

  Map<String, dynamic> toJson() => {
        'title': title,
        'url': url,
        'content': content,
        'chapter_index': chapterIndex,
        'is_user_inserted': isUserInserted,
        'read_at': readAt,
        'is_accompanied': isAccompanied,
      };

  factory ChapterExportData.fromJson(Map<String, dynamic> json) =>
      ChapterExportData(
        title: json['title'] as String,
        url: json['url'] as String,
        content: json['content'] as String?,
        chapterIndex: json['chapter_index'] as int,
        isUserInserted: json['is_user_inserted'] as bool? ?? false,
        readAt: json['read_at'] as int?,
        isAccompanied: json['is_accompanied'] as bool? ?? false,
      );
}

class CharacterExportData {
  final String name;
  final int? age;
  final String? gender;
  final String? occupation;
  final String? personality;
  final String? bodyType;
  final String? clothingStyle;
  final String? appearanceFeatures;
  final String? backgroundStory;
  final String? facePrompts;
  final String? bodyPrompts;
  final List<String> aliases;

  CharacterExportData({
    required this.name,
    this.age,
    this.gender,
    this.occupation,
    this.personality,
    this.bodyType,
    this.clothingStyle,
    this.appearanceFeatures,
    this.backgroundStory,
    this.facePrompts,
    this.bodyPrompts,
    this.aliases = const [],
  });

  Map<String, dynamic> toJson() => {
        'name': name,
        'age': age,
        'gender': gender,
        'occupation': occupation,
        'personality': personality,
        'body_type': bodyType,
        'clothing_style': clothingStyle,
        'appearance_features': appearanceFeatures,
        'background_story': backgroundStory,
        'face_prompts': facePrompts,
        'body_prompts': bodyPrompts,
        'aliases': aliases,
      };

  factory CharacterExportData.fromJson(Map<String, dynamic> json) =>
      CharacterExportData(
        name: json['name'] as String,
        age: json['age'] as int?,
        gender: json['gender'] as String?,
        occupation: json['occupation'] as String?,
        personality: json['personality'] as String?,
        bodyType: json['body_type'] as String?,
        clothingStyle: json['clothing_style'] as String?,
        appearanceFeatures: json['appearance_features'] as String?,
        backgroundStory: json['background_story'] as String?,
        facePrompts: json['face_prompts'] as String?,
        bodyPrompts: json['body_prompts'] as String?,
        aliases: (json['aliases'] as List?)?.map((e) => e.toString()).toList() ?? [],
      );
}

class CharacterRelationExportData {
  final String sourceCharacterName;
  final String targetCharacterName;
  final String relationshipType;
  final String? description;

  CharacterRelationExportData({
    required this.sourceCharacterName,
    required this.targetCharacterName,
    required this.relationshipType,
    this.description,
  });

  Map<String, dynamic> toJson() => {
        'source_character_name': sourceCharacterName,
        'target_character_name': targetCharacterName,
        'relationship_type': relationshipType,
        'description': description,
      };

  factory CharacterRelationExportData.fromJson(Map<String, dynamic> json) =>
      CharacterRelationExportData(
        sourceCharacterName: json['source_character_name'] as String,
        targetCharacterName: json['target_character_name'] as String,
        relationshipType: json['relationship_type'] as String,
        description: json['description'] as String?,
      );
}

class OutlineExportData {
  final String title;
  final String content;

  OutlineExportData({required this.title, required this.content});

  Map<String, dynamic> toJson() => {'title': title, 'content': content};

  factory OutlineExportData.fromJson(Map<String, dynamic> json) =>
      OutlineExportData(
        title: json['title'] as String,
        content: json['content'] as String,
      );
}

/// 小说导出/导入Repository
///
/// 负责将小说数据打包为导出格式，以及从导出格式恢复数据
class NovelExportRepository {
  final ChapterRepository _chapterRepository;
  final CharacterRepository _characterRepository;
  final CharacterRelationRepository _relationRepository;
  final OutlineRepository _outlineRepository;

  NovelExportRepository({
    required ChapterRepository chapterRepository,
    required CharacterRepository characterRepository,
    required CharacterRelationRepository relationRepository,
    required OutlineRepository outlineRepository,
  })  : _chapterRepository = chapterRepository,
        _characterRepository = characterRepository,
        _relationRepository = relationRepository,
        _outlineRepository = outlineRepository;

  /// 导出小说数据
  Future<NovelExportData> exportNovel(Novel novel) async {
    try {
      // 获取章节列表
      final chapters = await _chapterRepository.getChapters(novel.url);
      final chapterExportData = <ChapterExportData>[];

      for (final chapter in chapters) {
        // 获取章节内容
        final content = await _chapterRepository.getChapterContent(
          novel.url,
          chapter.url,
        );

        chapterExportData.add(ChapterExportData(
          title: chapter.title,
          url: chapter.url,
          content: content,
          chapterIndex: chapter.chapterIndex ?? 0,
          isUserInserted: chapter.isUserInserted,
          readAt: chapter.readAt,
          isAccompanied: chapter.isAccompanied,
        ));
      }

      // 获取角色列表
      final characters = await _characterRepository.getCharacters(novel.url);
      final characterExportData = characters.map((c) {
        return CharacterExportData(
          name: c.name,
          age: c.age,
          gender: c.gender,
          occupation: c.occupation,
          personality: c.personality,
          bodyType: c.bodyType,
          clothingStyle: c.clothingStyle,
          appearanceFeatures: c.appearanceFeatures,
          backgroundStory: c.backgroundStory,
          facePrompts: c.facePrompts,
          bodyPrompts: c.bodyPrompts,
          aliases: c.aliases ?? [],
        );
      }).toList();

      // 获取角色关系
      final relations =
          await _relationRepository.getRelationsForNovel(novel.url);
      final relationExportData = relations.map((r) {
        return CharacterRelationExportData(
          sourceCharacterName: r.sourceCharacterName,
          targetCharacterName: r.targetCharacterName,
          relationshipType: r.relationshipType,
          description: r.description,
        );
      }).toList();

      // 获取大纲
      final outline = await _outlineRepository.getOutline(novel.url);
      final outlineExportData = outline != null
          ? OutlineExportData(
              title: outline.title,
              content: outline.content,
            )
          : null;

      return NovelExportData(
        title: novel.title,
        author: novel.author,
        url: novel.url,
        coverUrl: novel.coverUrl,
        description: novel.description,
        backgroundSetting: novel.backgroundSetting,
        chapters: chapterExportData,
        characters: characterExportData,
        characterRelations: relationExportData,
        outline: outlineExportData,
      );
    } catch (e, stackTrace) {
      LoggerService.instance.e(
        '导出小说数据失败: $e',
        stackTrace: stackTrace.toString(),
        category: LogCategory.repository,
      );
      rethrow;
    }
  }

  /// 导入小说数据（替换现有数据）
  Future<void> importNovel(NovelExportData data) async {
    try {
      // 1. 删除现有章节数据
      await _chapterRepository.deleteAllChapters(data.url);

      // 2. 导入章节数据
      for (final chapterData in data.chapters) {
        await _chapterRepository.insertChapter(
          novelUrl: data.url,
          title: chapterData.title,
          url: chapterData.url,
          chapterIndex: chapterData.chapterIndex,
          isUserInserted: chapterData.isUserInserted,
        );

        if (chapterData.content != null && chapterData.content!.isNotEmpty) {
          await _chapterRepository.cacheChapterContent(
            novelUrl: data.url,
            chapterUrl: chapterData.url,
            title: chapterData.title,
            content: chapterData.content!,
            chapterIndex: chapterData.chapterIndex,
          );
        }
      }

      // 3. 删除现有角色数据
      await _characterRepository.deleteAllCharacters(data.url);

      // 4. 导入角色数据
      for (final charData in data.characters) {
        await _characterRepository.insertCharacter(Character(
          novelUrl: data.url,
          name: charData.name,
          age: charData.age,
          gender: charData.gender,
          occupation: charData.occupation,
          personality: charData.personality,
          bodyType: charData.bodyType,
          clothingStyle: charData.clothingStyle,
          appearanceFeatures: charData.appearanceFeatures,
          backgroundStory: charData.backgroundStory,
          facePrompts: charData.facePrompts,
          bodyPrompts: charData.bodyPrompts,
          aliases: charData.aliases,
        ));
      }

      // 5. 删除现有角色关系
      await _relationRepository.deleteAllRelations(data.url);

      // 6. 导入角色关系
      for (final relData in data.characterRelations) {
        await _relationRepository.insertRelation(CharacterRelationship(
          novelUrl: data.url,
          sourceCharacterName: relData.sourceCharacterName,
          targetCharacterName: relData.targetCharacterName,
          relationshipType: relData.relationshipType,
          description: relData.description,
        ));
      }

      // 7. 删除现有大纲
      await _outlineRepository.deleteOutline(data.url);

      // 8. 导入大纲
      if (data.outline != null) {
        await _outlineRepository.insertOutline(app_outline.Outline(
          novelUrl: data.url,
          title: data.outline!.title,
          content: data.outline!.content,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ));
      }

      LoggerService.instance.i(
        '导入小说数据成功: ${data.title}',
        category: LogCategory.repository,
      );
    } catch (e, stackTrace) {
      LoggerService.instance.e(
        '导入小说数据失败: $e',
        stackTrace: stackTrace.toString(),
        category: LogCategory.repository,
      );
      rethrow;
    }
  }
}
```

- [ ] **步骤 2：添加Repository Provider**

在 `novel_app/lib/core/providers/repository_providers.dart` 中添加：

```dart
// 导入
import 'package:novel_reader/repositories/novel_export_repository.dart';

// 添加Provider
final novelExportRepositoryProvider = Provider<NovelExportRepository>((ref) {
  return NovelExportRepository(
    chapterRepository: ref.watch(chapterRepositoryProvider),
    characterRepository: ref.watch(characterRepositoryProvider),
    relationRepository: ref.watch(characterRelationRepositoryProvider),
    outlineRepository: ref.watch(outlineRepositoryProvider),
  );
});
```

- [ ] **步骤 3：Commit**

```bash
git add novel_app/lib/repositories/novel_export_repository.dart novel_app/lib/core/providers/repository_providers.dart
git commit -m "feat(app): add novel export/import repository"
```

---

### 任务 5：APP - 创建同步服务

**文件：**
- 创建：`novel_app/lib/services/novel_sync_service.dart`
- 修改：`novel_app/lib/services/api_service_wrapper.dart`

- [ ] **步骤 1：创建同步服务**

创建文件 `novel_app/lib/services/novel_sync_service.dart`：

```dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:novel_reader/models/novel.dart';
import 'package:novel_reader/repositories/novel_export_repository.dart';
import 'package:novel_reader/services/logger_service.dart';
import 'package:novel_reader/services/preferences_service.dart';

/// 同步结果
class SyncResult {
  final bool success;
  final String message;
  final String? syncPath;

  SyncResult({
    required this.success,
    required this.message,
    this.syncPath,
  });
}

/// 小说同步服务
///
/// 负责将小说数据上传到服务器或从服务器下载
class NovelSyncService {
  final PreferencesService _preferencesService;
  final NovelExportRepository _exportRepository;

  NovelSyncService({
    required PreferencesService preferencesService,
    required NovelExportRepository exportRepository,
  })  : _preferencesService = preferencesService,
        _exportRepository = exportRepository;

  String get _apiToken => _preferencesService.apiToken ?? '';
  String get _baseUrl => _preferencesService.backendUrl ?? 'http://localhost:8000';

  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        'X-API-TOKEN': _apiToken,
      };

  /// 上传小说到服务器
  Future<SyncResult> uploadNovel(Novel novel) async {
    try {
      LoggerService.instance.i(
        '开始上传小说: ${novel.title}',
        category: LogCategory.service,
      );

      // 1. 导出小说数据
      final exportData = await _exportRepository.exportNovel(novel);
      final jsonData = exportData.toJson();

      // 2. 发送到服务器
      final response = await http.post(
        Uri.parse('$_baseUrl/api/novel/sync/upload'),
        headers: _headers,
        body: jsonEncode({'novel': jsonData}),
      );

      if (response.statusCode == 200) {
        final result = jsonDecode(response.body);
        LoggerService.instance.i(
          '上传小说成功: ${novel.title}',
          category: LogCategory.service,
        );
        return SyncResult(
          success: true,
          message: result['message'] ?? '上传成功',
          syncPath: result['sync_path'],
        );
      } else {
        final error = jsonDecode(response.body);
        LoggerService.instance.e(
          '上传小说失败: ${error['detail']}',
          category: LogCategory.service,
        );
        return SyncResult(
          success: false,
          message: error['detail'] ?? '上传失败',
        );
      }
    } catch (e, stackTrace) {
      LoggerService.instance.e(
        '上传小说异常: $e',
        stackTrace: stackTrace.toString(),
        category: LogCategory.service,
      );
      return SyncResult(
        success: false,
        message: '上传失败: $e',
      );
    }
  }

  /// 从服务器下载小说
  Future<SyncResult> downloadNovel(Novel novel) async {
    try {
      LoggerService.instance.i(
        '开始下载小说: ${novel.title}',
        category: LogCategory.service,
      );

      // 1. 从服务器获取数据
      final response = await http.post(
        Uri.parse('$_baseUrl/api/novel/sync/download'),
        headers: _headers,
        body: jsonEncode({'novel_url': novel.url}),
      );

      if (response.statusCode == 200) {
        final result = jsonDecode(response.body);

        if (result['novel'] == null) {
          return SyncResult(
            success: false,
            message: '服务器上没有该小说的数据',
          );
        }

        // 2. 解析并导入数据
        final exportData = NovelExportData.fromJson(result['novel']);
        await _exportRepository.importNovel(exportData);

        LoggerService.instance.i(
          '下载小说成功: ${novel.title}',
          category: LogCategory.service,
        );
        return SyncResult(
          success: true,
          message: '下载成功',
        );
      } else {
        final error = jsonDecode(response.body);
        LoggerService.instance.e(
          '下载小说失败: ${error['detail']}',
          category: LogCategory.service,
        );
        return SyncResult(
          success: false,
          message: error['detail'] ?? '下载失败',
        );
      }
    } catch (e, stackTrace) {
      LoggerService.instance.e(
        '下载小说异常: $e',
        stackTrace: stackTrace.toString(),
        category: LogCategory.service,
      );
      return SyncResult(
        success: false,
        message: '下载失败: $e',
      );
    }
  }

  /// 获取已同步的小说列表
  Future<List<Map<String, dynamic>>> listSyncedNovels() async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/api/novel/sync/list'),
        headers: _headers,
      );

      if (response.statusCode == 200) {
        final result = jsonDecode(response.body);
        return List<Map<String, dynamic>>.from(result['novels'] ?? []);
      }
      return [];
    } catch (e) {
      LoggerService.instance.e(
        '获取同步列表失败: $e',
        category: LogCategory.service,
      );
      return [];
    }
  }
}
```

- [ ] **步骤 2：添加同步服务Provider**

在 `novel_app/lib/core/providers/service_providers.dart` 中添加：

```dart
// 导入
import 'package:novel_reader/services/novel_sync_service.dart';

// 添加Provider
final novelSyncServiceProvider = Provider<NovelSyncService>((ref) {
  return NovelSyncService(
    preferencesService: ref.watch(preferencesServiceProvider),
    exportRepository: ref.watch(novelExportRepositoryProvider),
  );
});
```

- [ ] **步骤 3：Commit**

```bash
git add novel_app/lib/services/novel_sync_service.dart novel_app/lib/core/providers/service_providers.dart
git commit -m "feat(app): add novel sync service"
```

---

### 任务 6：APP - 创建同步UI组件

**文件：**
- 创建：`novel_app/lib/widgets/novel_sync_dialog.dart`
- 创建：`novel_app/lib/core/providers/novel_sync_providers.dart`

- [ ] **步骤 1：创建状态Provider**

创建文件 `novel_app/lib/core/providers/novel_sync_providers.dart`：

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:novel_reader/models/novel.dart';
import 'package:novel_reader/services/novel_sync_service.dart';
import 'package:novel_reader/core/providers/service_providers.dart';

/// 同步状态
enum SyncStatus {
  idle,
  uploading,
  downloading,
  success,
  error,
}

/// 同步状态数据
class SyncState {
  final SyncStatus status;
  final String message;
  final String? syncPath;

  const SyncState({
    this.status = SyncStatus.idle,
    this.message = '',
    this.syncPath,
  });

  SyncState copyWith({
    SyncStatus? status,
    String? message,
    String? syncPath,
  }) {
    return SyncState(
      status: status ?? this.status,
      message: message ?? this.message,
      syncPath: syncPath ?? this.syncPath,
    );
  }

  bool get isBusy => status == SyncStatus.uploading || status == SyncStatus.downloading;
}

/// 同步状态Notifier
class SyncNotifier extends StateNotifier<SyncState> {
  final NovelSyncService _syncService;

  SyncNotifier(this._syncService) : super(const SyncState());

  Future<void> uploadNovel(Novel novel) async {
    state = SyncState(status: SyncStatus.uploading, message: '正在上传...');

    final result = await _syncService.uploadNovel(novel);

    state = SyncState(
      status: result.success ? SyncStatus.success : SyncStatus.error,
      message: result.message,
      syncPath: result.syncPath,
    );
  }

  Future<void> downloadNovel(Novel novel) async {
    state = SyncState(status: SyncStatus.downloading, message: '正在下载...');

    final result = await _syncService.downloadNovel(novel);

    state = SyncState(
      status: result.success ? SyncStatus.success : SyncStatus.error,
      message: result.message,
    );
  }

  void reset() {
    state = const SyncState();
  }
}

/// 同步状态Provider
final syncStateProvider = StateNotifierProvider<SyncNotifier, SyncState>((ref) {
  final syncService = ref.watch(novelSyncServiceProvider);
  return SyncNotifier(syncService);
});
```

- [ ] **步骤 2：创建同步对话框**

创建文件 `novel_app/lib/widgets/novel_sync_dialog.dart`：

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:novel_reader/core/providers/novel_sync_providers.dart';
import 'package:novel_reader/models/novel.dart';

/// 同步对话框
class NovelSyncDialog extends ConsumerWidget {
  final Novel novel;
  final bool isUpload; // true: 上传, false: 下载

  const NovelSyncDialog({
    super.key,
    required this.novel,
    required this.isUpload,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final syncState = ref.watch(syncStateProvider);
    final syncNotifier = ref.read(syncStateProvider.notifier);

    // 自动开始同步
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (syncState.status == SyncStatus.idle) {
        if (isUpload) {
          syncNotifier.uploadNovel(novel);
        } else {
          syncNotifier.downloadNovel(novel);
        }
      }
    });

    return AlertDialog(
      title: Text(isUpload ? '上传小说' : '下载小说'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            novel.title,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          _buildContent(syncState),
        ],
      ),
      actions: syncState.isBusy
          ? null
          : [
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop(syncState.status == SyncStatus.success);
                },
                child: const Text('关闭'),
              ),
            ],
    );
  }

  Widget _buildContent(SyncState state) {
    switch (state.status) {
      case SyncStatus.idle:
        return const Text('准备中...');

      case SyncStatus.uploading:
        return const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(width: 16),
            Text('正在上传...'),
          ],
        );

      case SyncStatus.downloading:
        return const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(width: 16),
            Text('正在下载...'),
          ],
        );

      case SyncStatus.success:
        return Column(
          children: [
            const Icon(Icons.check_circle, color: Colors.green, size: 48),
            const SizedBox(height: 8),
            Text(state.message),
            if (state.syncPath != null) ...[
              const SizedBox(height: 8),
              Text(
                '存储路径: ${state.syncPath}',
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ],
        );

      case SyncStatus.error:
        return Column(
          children: [
            const Icon(Icons.error, color: Colors.red, size: 48),
            const SizedBox(height: 8),
            Text(
              state.message,
              style: const TextStyle(color: Colors.red),
              textAlign: TextAlign.center,
            ),
          ],
        );
    }
  }
}

/// 显示同步对话框
Future<bool?> showSyncDialog({
  required BuildContext context,
  required Novel novel,
  required bool isUpload,
}) {
  return showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (context) => NovelSyncDialog(novel: novel, isUpload: isUpload),
  );
}
```

- [ ] **步骤 3：Commit**

```bash
git add novel_app/lib/core/providers/novel_sync_providers.dart novel_app/lib/widgets/novel_sync_dialog.dart
git commit -m "feat(app): add sync dialog and state providers"
```

---

### 任务 7：APP - 集成到章节列表界面

**文件：**
- 修改：`novel_app/lib/screens/chapter_list_screen_riverpod.dart`

- [ ] **步骤 1：添加上传/下载菜单项**

在 `chapter_list_screen_riverpod.dart` 中：

1. 添加导入：
```dart
import '../widgets/novel_sync_dialog.dart';
```

2. 在 `_buildPopupMenu` 方法中添加菜单项（查找现有的 PopupMenuButton，在其中添加）：

```dart
// 在 PopupMenuButton 的 items 中添加
PopupMenuItem(
  value: 'upload',
  child: const ListTile(
    leading: Icon(Icons.cloud_upload),
    title: Text('上传到服务器'),
  ),
),
PopupMenuItem(
  value: 'download',
  child: const ListTile(
    leading: Icon(Icons.cloud_download),
    title: Text('从服务器下载'),
  ),
),
```

3. 在菜单的 `onSelected` 回调中添加处理逻辑：

```dart
case 'upload':
  final result = await showSyncDialog(
    context: context,
    novel: widget.novel,
    isUpload: true,
  );
  if (result == true && mounted) {
    ToastUtils.show('上传成功');
    // 刷新章节列表
    ref.read(chapterListProvider(widget.novel).notifier).refreshChapters(context);
  }
  break;

case 'download':
  // 先确认是否覆盖
  final confirm = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('确认下载'),
      content: const Text('下载将覆盖本地的章节数据，是否继续？'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('取消'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, true),
          child: const Text('确认'),
        ),
      ],
    ),
  );

  if (confirm == true && mounted) {
    final result = await showSyncDialog(
      context: context,
      novel: widget.novel,
      isUpload: false,
    );
    if (result == true && mounted) {
      ToastUtils.show('下载成功');
      // 刷新章节列表
      ref.read(chapterListProvider(widget.novel).notifier).refreshChapters(context);
    }
  }
  break;
```

- [ ] **步骤 2：Commit**

```bash
git add novel_app/lib/screens/chapter_list_screen_riverpod.dart
git commit -m "feat(app): integrate sync buttons into chapter list screen"
```

---

### 任务 8：集成测试和验证

**文件：**
- 无需新建文件，验证功能

- [ ] **步骤 1：启动后端服务**

```bash
cd backend
python -m uvicorn app.main:app --reload --port 8000
```

- [ ] **步骤 2：验证API端点**

访问 http://localhost:8000/docs 确认新增的API端点：
- POST /api/novel/sync/upload
- POST /api/novel/sync/download
- GET /api/novel/sync/list
- DELETE /api/novel/sync/delete

- [ ] **步骤 3：运行Flutter应用**

```bash
cd novel_app
flutter run
```

- [ ] **步骤 4：功能测试**

1. 打开一本小说的章节列表
2. 点击右上角菜单
3. 选择"上传到服务器"
4. 验证对话框显示上传进度和结果
5. 检查后端 `novel_sync/` 目录是否生成了对应文件
6. 修改服务器上的章节文件
7. 在APP中选择"从服务器下载"
8. 验证本地数据是否更新

- [ ] **步骤 5：最终Commit**

```bash
git add -A
git commit -m "feat: complete novel sync functionality

- Add backend sync API endpoints (upload/download/list/delete)
- Add novel sync service for file system operations
- Add Flutter sync service and repository
- Integrate sync buttons into chapter list screen
- Support bidirectional sync between APP and PC"
```

---

## 风险与注意事项

### 数据安全
- 上传前建议APP端备份本地数据
- 下载前显示确认对话框，提醒用户会覆盖本地数据
- 建议添加数据版本/时间戳比较，避免意外覆盖

### 文件编码
- 所有TXT文件使用UTF-8编码
- JSON文件确保 `ensure_ascii=False`

### 性能考虑
- 大型小说（1000+章节）可能需要较长时间
- 考虑添加进度回调显示
- 未来可考虑增量同步

### 兼容性
- Windows/Linux文件名处理
- 特殊字符转义

---

## 后续优化方向

1. **增量同步**：只同步变更的章节
2. **冲突解决**：添加版本对比和合并功能
3. **压缩传输**：大小说使用gzip压缩
4. **批量操作**：支持多本小说批量同步
5. **自动同步**：定时自动同步功能