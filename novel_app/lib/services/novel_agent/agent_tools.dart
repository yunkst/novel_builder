/// Agent 工具定义（OpenAI Function Calling schema）
///
/// 上下文驱动设计：所有工具不再接受 novelId，而是作用于"当前小说"。
/// - `list_novels` 用于发现书架上的小说
/// - `select_novel` 用于切换当前小说
/// - 章节操作使用 `position`（list_chapters 返回的连续 1-based 顺序号）
library;

class AgentTools {
  AgentTools._();

  /// 全部工具定义
  static const List<Map<String, dynamic>> allTools = [
    // ===== 小说导航 =====
    _listNovels,
    _selectNovel,
    _createNovel,
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
    // ===== 提示标签 =====
    _listPromptTags,
    _savePromptTag,
  ];

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

  // ===== 小说导航 =====

  static const _listNovels = {
    'type': 'function',
    'function': {
      'name': 'list_novels',
      'description':
          '列出书架中的所有小说，包括id、标题、作者和简介。'
          'id 是 select_novel 的必填参数。每次新会话开始时建议先调用本工具。',
      'parameters': {
        'type': 'object',
        'properties': <String, dynamic>{},
        'required': <String>[],
      },
    },
  };

  static const _selectNovel = {
    'type': 'function',
    'function': {
      'name': 'select_novel',
      'description':
          '切换当前工作小说。切换成功后，所有不传 novelId 的工具将作用于该小说，'
          'UI 窗口也会更新展示。\n'
          '使用场景：\n'
          '- 首次对话时选择目标小说\n'
          '- 用户要求"切换到另一本"时\n'
          '- 操作多本小说时切换上下文\n'
          'novelId 来自 list_novels 返回的 id 字段。',
      'parameters': {
        'type': 'object',
        'properties': {
          'novelId': {
            'type': 'integer',
            'description': '目标小说 ID（从 list_novels 获取）',
          },
        },
        'required': ['novelId'],
      },
    },
  };

  static const _createNovel = {
    'type': 'function',
    'function': {
      'name': 'create_novel',
      'description':
          '创建一本新的原创小说并自动切换为当前工作小说。'
          '创建成功后无需再调用 select_novel。\n'
          '使用场景：\n'
          '- 用户要求"新建一本小说"\n'
          '- 用户想从头开始写一本原创小说\n'
          '- 用户需要一本空白小说来组织章节内容',
      'parameters': {
        'type': 'object',
        'properties': {
          'title': {
            'type': 'string',
            'description': '小说标题',
          },
          'description': {
            'type': 'string',
            'description': '小说简介（可选）',
          },
        },
        'required': ['title'],
      },
    },
  };

  // ===== 章节读取 =====

  static const _readChapterContent = {
    'type': 'function',
    'function': {
      'name': 'read_chapter_content',
      'description':
          '读取指定章节的完整正文内容。修改章节前应先调用此工具了解当前内容。'
          'position 来自 list_chapters 返回的 position 字段（1-based 顺序号）。',
      'parameters': {
        'type': 'object',
        'properties': {
          'position': {
            'type': 'integer',
            'description':
                '章节在当前小说列表中的位置（1-based）。如不确定，请先调用 list_chapters。',
          },
        },
        'required': ['position'],
      },
    },
  };

  static const _listChapters = {
    'type': 'function',
    'function': {
      'name': 'list_chapters',
      'description':
          '列出当前小说的所有章节目录。返回的每个章节包含 position（1-based 顺序号）、'
          'title、chapterIndex 和 isCached。position 是其他章节操作工具的必填参数。',
      'parameters': {
        'type': 'object',
        'properties': <String, dynamic>{},
        'required': <String>[],
      },
    },
  };

  static const _searchInChapters = {
    'type': 'function',
    'function': {
      'name': 'search_in_chapters',
      'description':
          '在当前小说所有已缓存章节中搜索包含指定关键词的内容。'
          '返回匹配的章节列表和上下文片段，结果中包含每个章节的 position。',
      'parameters': {
        'type': 'object',
        'properties': {
          'keyword': {
            'type': 'string',
            'description': '搜索关键词',
          },
        },
        'required': ['keyword'],
      },
    },
  };

  // ===== 章节写入 =====

  static const _updateChapterContent = {
    'type': 'function',
    'function': {
      'name': 'update_chapter_content',
      'description':
          '完全替换指定章节的正文内容。⚠️ 此操作会覆盖原有内容，请先调用 '
          'read_chapter_content 确认当前内容。position 来自 list_chapters。',
      'parameters': {
        'type': 'object',
        'properties': {
          'position': {
            'type': 'integer',
            'description': '章节在当前小说列表中的位置（1-based，从 list_chapters 获取）。',
          },
          'content': {
            'type': 'string',
            'description': '新的完整章节内容（将替换原有全文）',
          },
        },
        'required': ['position', 'content'],
      },
    },
  };

  static const _createCustomChapter = {
    'type': 'function',
    'function': {
      'name': 'create_custom_chapter',
      'description':
          '在当前小说中创建一个全新的自定义章节。返回新章节的 position，'
          '可用于后续章节操作（如 read_chapter_content、update_chapter_content）。\n'
          'position 参数说明：\n'
          '- 不填或省略 → 追加到末尾\n'
          '- 填 1 → 插入到第 1 章位置（原第 1 章及后续章节后移）\n'
          '- 填 N → 插入到第 N 章位置（原第 N 章及后续章节后移）\n'
          '- 合法范围：1 ~ 当前章节数 + 1',
      'parameters': {
        'type': 'object',
        'properties': {
          'title': {
            'type': 'string',
            'description': '新章节的标题',
          },
          'content': {
            'type': 'string',
            'description': '新章节的正文内容',
          },
          'position': {
            'type': 'integer',
            'description': '插入位置（1-based 顺序号）。新章节将出现在该位置，'
                '原该位置及之后的章节自动后移。不填则追加到末尾。',
          },
        },
        'required': ['title', 'content'],
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
        'properties': <String, dynamic>{},
        'required': <String>[],
      },
    },
  };

  static const _updateCharacter = {
    'type': 'function',
    'function': {
      'name': 'update_character',
      'description': '更新当前小说中已有角色的信息。只更新传入的字段，未传入的字段保持不变。',
      'parameters': {
        'type': 'object',
        'properties': {
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
        'required': ['name'],
      },
    },
  };

  static const _createCharacter = {
    'type': 'function',
    'function': {
      'name': 'create_character',
      'description': '在当前小说中创建一个新角色。',
      'parameters': {
        'type': 'object',
        'properties': {
          'name': {
            'type': 'string',
            'description': '角色名称',
          },
          'description': {
            'type': 'string',
            'description': '角色描述（外貌、性格、背景等）',
          },
        },
        'required': ['name'],
      },
    },
  };

  // ===== 设定 / 大纲 =====

  static const _updateBackgroundSetting = {
    'type': 'function',
    'function': {
      'name': 'update_background_setting',
      'description':
          '更新当前小说的世界观和背景设定。会替换原有设定，请包含完整内容。',
      'parameters': {
        'type': 'object',
        'properties': {
          'setting': {
            'type': 'string',
            'description': '新的背景设定全文',
          },
        },
        'required': ['setting'],
      },
    },
  };

  static const _updateOutline = {
    'type': 'function',
    'function': {
      'name': 'update_outline',
      'description': '创建或更新当前小说的大纲。',
      'parameters': {
        'type': 'object',
        'properties': {
          'title': {
            'type': 'string',
            'description': '大纲标题',
          },
          'content': {
            'type': 'string',
            'description': '大纲内容（Markdown格式）',
          },
        },
        'required': ['title', 'content'],
      },
    },
  };

  static const _getOutline = {
    'type': 'function',
    'function': {
      'name': 'get_outline',
      'description': '获取当前小说的大纲内容。如果存在多个大纲，返回最新的一个。',
      'parameters': {
        'type': 'object',
        'properties': <String, dynamic>{},
        'required': <String>[],
      },
    },
  };

  // ===== 提示标签 =====

  static const _listPromptTags = {
    'type': 'function',
    'function': {
      'name': 'list_prompt_tags',
      'description':
          '获取写作提示标签列表，支持按分类名筛选或获取全部。'
          '标签按分类分组返回，每个标签包含名称、使用场景和提示词摘要。\n'
          '使用场景：\n'
          '- 用户想查看或了解可用的写作技巧标签\n'
          '- 需要为写作选择合适的标签风格\n'
          '- 想了解某个分类下有哪些标签',
      'parameters': {
        'type': 'object',
        'properties': {
          'categoryName': {
            'type': 'string',
            'description': '分类名称筛选（如"风格"、"场景"、"人物"、"情节"）。不填则返回全部分类及其标签。',
          },
        },
        'required': <String>[],
      },
    },
  };

  static const _savePromptTag = {
    'type': 'function',
    'function': {
      'name': 'save_prompt_tag',
      'description':
          '创建新标签或更新已有标签。\n'
          '- 传入 id 表示更新已有标签（仅更新传入的字段）\n'
          '- 不传 id 表示创建新标签（自动获取排序序号）\n'
          '- 通过分类名指定所属分类（如"风格"、"场景"、"人物"、"情节"）\n'
          '使用场景：\n'
          '- 用户想创建新的写作技巧标签\n'
          '- 用户想修改已有标签的提示词或使用场景描述',
      'parameters': {
        'type': 'object',
        'properties': {
          'id': {
            'type': 'integer',
            'description': '已有标签的 ID（从 list_prompt_tags 获取）。不传则创建新标签。',
          },
          'categoryName': {
            'type': 'string',
            'description': '所属分类名称（如"风格"、"场景"、"人物"、"情节"）',
          },
          'name': {
            'type': 'string',
            'description': '标签名称',
          },
          'reason': {
            'type': 'string',
            'description': '使用场景描述（简短一句话，说明何时该用这个标签）',
          },
          'promptText': {
            'type': 'string',
            'description': '标签的完整提示词文本',
          },
        },
        'required': ['categoryName', 'name', 'promptText'],
      },
    },
  };
}
