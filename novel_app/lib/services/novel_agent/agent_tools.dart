/// Agent 工具定义（OpenAI Function Calling schema）
///
/// Phase 2: 14 个工具的完整定义，按功能域分组
library;

import 'package:novel_app/services/logger_service.dart';

class AgentTools {
  AgentTools._();

  /// 全部工具定义
  static const List<Map<String, dynamic>> allTools = [
    // ===== 章节读取 =====
    _readChapterContent,
    _listChapters,
    _searchInChapters,
    // ===== 章节写入 =====
    _updateChapterContent,
    _rewriteChapterParagraph,
    _insertParagraph,
    _deleteParagraph,
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
    'rewrite_chapter_paragraph',
    'delete_paragraph',
    'insert_paragraph',
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
      'description': '读取指定章节的完整正文内容。修改章节前应先调用此工具了解当前内容。返回章节全文。',
      'parameters': {
        'type': 'object',
        'properties': {
          'chapterUrl': {
            'type': 'string',
            'description': '章节的唯一标识URL',
          },
        },
        'required': ['chapterUrl'],
      },
    },
  };

  static const _listChapters = {
    'type': 'function',
    'function': {
      'name': 'list_chapters',
      'description': '列出当前小说的所有章节目录，包括标题和URL。用于了解小说结构或定位特定章节。',
      'parameters': {
        'type': 'object',
        'properties': {
          'novelUrl': {
            'type': 'string',
            'description': '小说的唯一标识URL',
          },
        },
        'required': ['novelUrl'],
      },
    },
  };

  static const _searchInChapters = {
    'type': 'function',
    'function': {
      'name': 'search_in_chapters',
      'description': '在小说的所有已缓存章节中搜索包含指定关键词的内容。返回匹配的章节列表和上下文片段。',
      'parameters': {
        'type': 'object',
        'properties': {
          'novelUrl': {
            'type': 'string',
            'description': '小说的唯一标识URL',
          },
          'keyword': {
            'type': 'string',
            'description': '搜索关键词',
          },
        },
        'required': ['novelUrl', 'keyword'],
      },
    },
  };

  // ===== 章节写入 =====

  static const _updateChapterContent = {
    'type': 'function',
    'function': {
      'name': 'update_chapter_content',
      'description': '完全替换指定章节的正文内容。⚠️ 此操作会覆盖原有内容，请先调用 read_chapter_content 确认当前内容。',
      'parameters': {
        'type': 'object',
        'properties': {
          'chapterUrl': {
            'type': 'string',
            'description': '章节的唯一标识URL',
          },
          'content': {
            'type': 'string',
            'description': '新的完整章节内容（将替换原有全文）',
          },
        },
        'required': ['chapterUrl', 'content'],
      },
    },
  };

  static const _rewriteChapterParagraph = {
    'type': 'function',
    'function': {
      'name': 'rewrite_chapter_paragraph',
      'description': '使用 AI 改写章节中的指定段落。保留其他段落不变。段落以空行分隔，索引从 0 开始。',
      'parameters': {
        'type': 'object',
        'properties': {
          'chapterUrl': {
            'type': 'string',
            'description': '章节的唯一标识URL',
          },
          'paragraphIndex': {
            'type': 'integer',
            'description': '要改写的段落索引（从0开始，以空行分隔）',
          },
          'instruction': {
            'type': 'string',
            'description': '改写要求，如"改写得更有悬念"、"增加环境描写"等',
          },
        },
        'required': ['chapterUrl', 'paragraphIndex', 'instruction'],
      },
    },
  };

  static const _insertParagraph = {
    'type': 'function',
    'function': {
      'name': 'insert_paragraph',
      'description': '在章节的指定位置后插入一段新文本。段落以空行分隔。',
      'parameters': {
        'type': 'object',
        'properties': {
          'chapterUrl': {
            'type': 'string',
            'description': '章节的唯一标识URL',
          },
          'afterParagraphIndex': {
            'type': 'integer',
            'description': '在哪个段落之后插入（-1表示插入到最前面）',
          },
          'newParagraph': {
            'type': 'string',
            'description': '要插入的新段落文本',
          },
        },
        'required': ['chapterUrl', 'afterParagraphIndex', 'newParagraph'],
      },
    },
  };

  static const _deleteParagraph = {
    'type': 'function',
    'function': {
      'name': 'delete_paragraph',
      'description': '删除章节中的指定段落。段落以空行分隔，索引从 0 开始。',
      'parameters': {
        'type': 'object',
        'properties': {
          'chapterUrl': {
            'type': 'string',
            'description': '章节的唯一标识URL',
          },
          'paragraphIndex': {
            'type': 'integer',
            'description': '要删除的段落索引',
          },
        },
        'required': ['chapterUrl', 'paragraphIndex'],
      },
    },
  };

  static const _createCustomChapter = {
    'type': 'function',
    'function': {
      'name': 'create_custom_chapter',
      'description': '在小说中创建一个全新的自定义章节。',
      'parameters': {
        'type': 'object',
        'properties': {
          'novelUrl': {
            'type': 'string',
            'description': '小说的唯一标识URL',
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
        'required': ['novelUrl', 'title', 'content'],
      },
    },
  };

  // ===== 角色 =====

  static const _listCharacters = {
    'type': 'function',
    'function': {
      'name': 'list_characters',
      'description': '获取当前小说的所有角色信息列表，包括名称、描述等。',
      'parameters': {
        'type': 'object',
        'properties': {
          'novelUrl': {
            'type': 'string',
            'description': '小说的唯一标识URL',
          },
        },
        'required': ['novelUrl'],
      },
    },
  };

  static const _updateCharacter = {
    'type': 'function',
    'function': {
      'name': 'update_character',
      'description': '更新已有角色的信息。只更新传入的字段，未传入的字段保持不变。',
      'parameters': {
        'type': 'object',
        'properties': {
          'novelUrl': {
            'type': 'string',
            'description': '小说的唯一标识URL',
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
        'required': ['novelUrl', 'name'],
      },
    },
  };

  static const _createCharacter = {
    'type': 'function',
    'function': {
      'name': 'create_character',
      'description': '创建一个新角色。',
      'parameters': {
        'type': 'object',
        'properties': {
          'novelUrl': {
            'type': 'string',
            'description': '小说的唯一标识URL',
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
        'required': ['novelUrl', 'name'],
      },
    },
  };

  // ===== 设定 / 大纲 =====

  static const _updateBackgroundSetting = {
    'type': 'function',
    'function': {
      'name': 'update_background_setting',
      'description': '更新小说的世界观和背景设定。会替换原有设定，请包含完整内容。',
      'parameters': {
        'type': 'object',
        'properties': {
          'novelUrl': {
            'type': 'string',
            'description': '小说的唯一标识URL',
          },
          'setting': {
            'type': 'string',
            'description': '新的背景设定全文',
          },
        },
        'required': ['novelUrl', 'setting'],
      },
    },
  };

  static const _updateOutline = {
    'type': 'function',
    'function': {
      'name': 'update_outline',
      'description': '创建或更新小说的大纲。',
      'parameters': {
        'type': 'object',
        'properties': {
          'novelUrl': {
            'type': 'string',
            'description': '小说的唯一标识URL',
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
        'required': ['novelUrl', 'title', 'content'],
      },
    },
  };

  static const _getOutline = {
    'type': 'function',
    'function': {
      'name': 'get_outline',
      'description': '获取小说的大纲内容。如果存在多个大纲，返回最新的一个。',
      'parameters': {
        'type': 'object',
        'properties': {
          'novelUrl': {
            'type': 'string',
            'description': '小说的唯一标识URL',
          },
        },
        'required': ['novelUrl'],
      },
    },
  };
}