/// Agent 工具定义（OpenAI Function Calling schema）
///
/// 全面 ID 化：所有工具使用数字 ID 而非 URL 作为标识参数
/// - chapterId: 来自 list_chapters 返回的 id 字段
/// - novelId: 来自 list_novels 返回的 id 字段
library;

import 'package:novel_app/services/logger_service.dart';

class AgentTools {
  AgentTools._();

  /// 全部工具定义
  static const List<Map<String, dynamic>> allTools = [
    // ===== 小说 =====
    _listNovels,
    // ===== 章节读取 =====
    _readChapterContent,
    _listChapters,
    _searchInChapters,
    // ===== 章节写入 =====
    _updateChapterContent,
    _createCustomChapter,
    // ===== 角色 =====
    _listCharacters,
    _updateCharacter,
    _createCharacter,
    // ===== 设定 / 大纲 =====
    _updateBackgroundSetting,
    _updateOutline,
    _getOutline,
  ];

  /// 破坏性工具列表（需要用户确认）
  static const Set<String> destructiveTools = {
    'update_chapter_content',
    'create_custom_chapter',
    'update_character',
    'create_character',
    'update_background_setting',
    'update_outline',
  };

  /// 查找工具定义（带日志）
  ///
  /// [name] 工具名
  /// 返回工具定义 Map，未找到返回 null
  static Map<String, dynamic>? findTool(String name) {
    for (final tool in allTools) {
      if (tool['function']['name'] == name) {
        return tool;
      }
    }
    return null;
  }

  /// 校验工具是否破坏性（带日志）
  static bool isDestructive(String name) {
    final destructive = destructiveTools.contains(name);
    LoggerService.instance.d('工具元数据查询: $name (destructive=$destructive)',
        category: LogCategory.ai, tags: ['agent', 'tool', 'metadata', name]);
    return destructive;
  }

  // ===== 章节读取 =====

  static const _readChapterContent = {
    'type': 'function',
    'function': {
      'name': 'read_chapter_content',
      'description':
          '读取指定章节的完整正文内容。修改章节前应先调用此工具了解当前内容。chapterId 来自 list_chapters 返回的 id 字段。',
      'parameters': {
        'type': 'object',
        'properties': {
          'chapterId': {
            'type': 'integer',
            'description': '章节ID（从 list_chapters 获取）。如不确定ID，请先调用 list_chapters。',
          },
        },
        'required': ['chapterId'],
      },
    },
  };

  static const _listChapters = {
    'type': 'function',
    'function': {
      'name': 'list_chapters',
      'description':
          '列出指定小说的所有章节目录。每个章节包含 id、标题、索引和缓存状态。id 是其他章节操作工具的必填参数。novelId 来自 list_novels 返回的 id 字段。',
      'parameters': {
        'type': 'object',
        'properties': {
          'novelId': {
            'type': 'integer',
            'description': '小说ID（从 list_novels 获取）。如不确定ID，请先调用 list_novels。',
          },
        },
        'required': ['novelId'],
      },
    },
  };

  static const _searchInChapters = {
    'type': 'function',
    'function': {
      'name': 'search_in_chapters',
      'description':
          '在指定小说的所有已缓存章节中搜索包含指定关键词的内容。返回匹配的章节列表和上下文片段。novelId 来自 list_novels 返回的 id 字段。',
      'parameters': {
        'type': 'object',
        'properties': {
          'novelId': {
            'type': 'integer',
            'description': '小说ID（从 list_novels 获取）。如不确定ID，请先调用 list_novels。',
          },
          'keyword': {
            'type': 'string',
            'description': '搜索关键词',
          },
        },
        'required': ['novelId', 'keyword'],
      },
    },
  };

  // ===== 章节写入 =====

  static const _updateChapterContent = {
    'type': 'function',
    'function': {
      'name': 'update_chapter_content',
      'description':
          '完全替换指定章节的正文内容。⚠️ 此操作会覆盖原有内容，请先调用 read_chapter_content 确认当前内容。chapterId 来自 list_chapters。',
      'parameters': {
        'type': 'object',
        'properties': {
          'chapterId': {
            'type': 'integer',
            'description': '章节ID（从 list_chapters 获取）。',
          },
          'content': {
            'type': 'string',
            'description': '新的完整章节内容（将替换原有全文）',
          },
        },
        'required': ['chapterId', 'content'],
      },
    },
  };

  static const _createCustomChapter = {
    'type': 'function',
    'function': {
      'name': 'create_custom_chapter',
      'description':
          '在小说中创建一个全新的自定义章节。返回新章节的 id，可用于后续章节操作。novelId 来自 list_novels。',
      'parameters': {
        'type': 'object',
        'properties': {
          'novelId': {
            'type': 'integer',
            'description': '小说ID（从 list_novels 获取）。',
          },
          'title': {
            'type': 'string',
            'description': '新章节的标题',
          },
          'content': {
            'type': 'string',
            'description': '新章节的正文内容',
          },
          'index': {
            'type': 'integer',
            'description': '插入位置（章节序号，不填则添加到末尾）',
          },
        },
        'required': ['novelId', 'title', 'content'],
      },
    },
  };

  // ===== 角色 =====

  static const _listCharacters = {
    'type': 'function',
    'function': {
      'name': 'list_characters',
      'description':
          '获取指定小说的所有角色信息列表，包括名称、描述等。novelId 来自 list_novels。',
      'parameters': {
        'type': 'object',
        'properties': {
          'novelId': {
            'type': 'integer',
            'description': '小说ID（从 list_novels 获取）。',
          },
        },
        'required': ['novelId'],
      },
    },
  };

  static const _updateCharacter = {
    'type': 'function',
    'function': {
      'name': 'update_character',
      'description':
          '更新已有角色的信息。只更新传入的字段，未传入的字段保持不变。novelId 来自 list_novels。',
      'parameters': {
        'type': 'object',
        'properties': {
          'novelId': {
            'type': 'integer',
            'description': '小说ID（从 list_novels 获取）。',
          },
          'name': {
            'type': 'string',
            'description': '要更新的角色名称',
          },
          'description': {
            'type': 'string',
            'description': '新的角色描述',
          },
          'avatarUrl': {
            'type': 'string',
            'description': '新的头像URL',
          },
        },
        'required': ['novelId', 'name'],
      },
    },
  };

  static const _createCharacter = {
    'type': 'function',
    'function': {
      'name': 'create_character',
      'description':
          '创建一个新角色。novelId 来自 list_novels。',
      'parameters': {
        'type': 'object',
        'properties': {
          'novelId': {
            'type': 'integer',
            'description': '小说ID（从 list_novels 获取）。',
          },
          'name': {
            'type': 'string',
            'description': '角色名称',
          },
          'description': {
            'type': 'string',
            'description': '角色描述（外貌、性格、背景等）',
          },
        },
        'required': ['novelId', 'name'],
      },
    },
  };

  // ===== 设定 / 大纲 =====

  static const _updateBackgroundSetting = {
    'type': 'function',
    'function': {
      'name': 'update_background_setting',
      'description':
          '更新小说的世界观和背景设定。会替换原有设定，请包含完整内容。novelId 来自 list_novels。',
      'parameters': {
        'type': 'object',
        'properties': {
          'novelId': {
            'type': 'integer',
            'description': '小说ID（从 list_novels 获取）。',
          },
          'setting': {
            'type': 'string',
            'description': '新的背景设定全文',
          },
        },
        'required': ['novelId', 'setting'],
      },
    },
  };

  static const _updateOutline = {
    'type': 'function',
    'function': {
      'name': 'update_outline',
      'description':
          '创建或更新小说的大纲。novelId 来自 list_novels。',
      'parameters': {
        'type': 'object',
        'properties': {
          'novelId': {
            'type': 'integer',
            'description': '小说ID（从 list_novels 获取）。',
          },
          'title': {
            'type': 'string',
            'description': '大纲标题',
          },
          'content': {
            'type': 'string',
            'description': '大纲内容（Markdown格式）',
          },
        },
        'required': ['novelId', 'title', 'content'],
      },
    },
  };

  static const _getOutline = {
    'type': 'function',
    'function': {
      'name': 'get_outline',
      'description':
          '获取小说的大纲内容。如果存在多个大纲，返回最新的一个。novelId 来自 list_novels。',
      'parameters': {
        'type': 'object',
        'properties': {
          'novelId': {
            'type': 'integer',
            'description': '小说ID（从 list_novels 获取）。',
          },
        },
        'required': ['novelId'],
      },
    },
  };

  // ===== 小说 =====

  static const _listNovels = {
    'type': 'function',
    'function': {
      'name': 'list_novels',
      'description': '列出书架中的所有小说，包括id、标题、作者和简介。id 是其他小说操作工具的必填参数。',
      'parameters': {
        'type': 'object',
        'properties': <String, dynamic>{},
        'required': <String>[],
      },
    },
  };
}
