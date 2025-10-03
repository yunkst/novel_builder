import { defineStore } from 'pinia'
import { ref, computed } from 'vue'
import type { DifyConfig } from '@/services/difyApi'

export interface Template {
  id: string
  name: string
  type: 'background' | 'ai_writer'
  content: string
  description?: string
  createdAt: number
  updatedAt: number
}

export interface Character {
  id: string
  novelId: string
  name: string
  description: string
  createdAt: number
  updatedAt: number
}

export interface Novel {
  id: string
  title: string
  backgroundSetting: string      // 背景设定
  aiWriterSetting: string       // AI作家设定
  createdAt: number
  updatedAt: number
}

export interface Chapter {
  id: string
  novelId: string
  title: string
  content: string
  order: number
  nextChapterOverview: string   // 下一章概览
  createdAt: number
  updatedAt: number
}

export interface WritingSession {
  novelId: string
  currentChapterId?: string
  userInput: string             // 用户输入
  generatedContent: string      // AI生成的内容
  isGenerating: boolean
  hasUnsavedChanges: boolean    // 是否有未保存的更改
  originalContent: string       // 原始章节内容，用于比较是否有更改
}

export type ThemeMode = 'light' | 'dark' | 'system'

export interface AppSettings {
  themeMode: ThemeMode
  historyChaptersMaxChars: number  // 历史章节最大字符数
}

export const useAppStore = defineStore('app', () => {
  // Dify 配置
  const difyConfig = ref<DifyConfig>({
    apiBaseUrl: 'https://api.dify.ai/v1',
    apiKey: ''
  })

  // 小说数据
  const novels = ref<Novel[]>([])
  const chapters = ref<Chapter[]>([])
  const characters = ref<Character[]>([])
  const currentNovel = ref<Novel | null>(null)

  // 模板数据
  const templates = ref<Template[]>([])

  // 应用设置
  const settings = ref<AppSettings>({
    themeMode: 'system',
    historyChaptersMaxChars: 20000  // 默认2万字
  })

  // 创作会话状态
  const writingSession = ref<WritingSession>({
    novelId: '',
    userInput: '',
    generatedContent: '',
    isGenerating: false,
    hasUnsavedChanges: false,
    originalContent: ''
  })

  // 界面状态
  const isLoading = ref(false)
  const error = ref<string | null>(null)

  // 计算属性
  const currentNovelChapters = computed(() => {
    if (!currentNovel.value) return []
    return chapters.value
      .filter(chapter => chapter.novelId === currentNovel.value!.id)
      .sort((a, b) => a.order - b.order)
  })

  const canSendToAI = computed(() => {
    if (!currentNovel.value || writingSession.value.isGenerating) return false

    const novel = currentNovel.value
    const session = writingSession.value

    // 检查必需字段：用户输入、背景设定、AI作家设定、下一章概览
    return !!(
      session.userInput.trim() &&
      novel.backgroundSetting.trim() &&
      novel.aiWriterSetting.trim() &&
      getCurrentChapterNextOverview()
    )
  })

  const isConfigured = computed(() => {
    return difyConfig.value.apiKey.length > 0
  })

  const backgroundTemplates = computed(() => {
    return templates.value.filter(t => t.type === 'background').sort((a, b) => b.updatedAt - a.updatedAt)
  })

  const aiWriterTemplates = computed(() => {
    return templates.value.filter(t => t.type === 'ai_writer').sort((a, b) => b.updatedAt - a.updatedAt)
  })

  // 当前小说的人物列表
  const currentNovelCharacters = computed(() => {
    if (!currentNovel.value) return []
    return characters.value
      .filter(character => character.novelId === currentNovel.value!.id)
      .sort((a, b) => b.updatedAt - a.updatedAt)
  })

  // 当前生效的主题
  const currentTheme = computed(() => {
    if (settings.value.themeMode === 'system') {
      return window.matchMedia('(prefers-color-scheme: dark)').matches ? 'dark' : 'light'
    }
    return settings.value.themeMode
  })

  // Dify 配置方法
  function updateDifyConfig(config: Partial<DifyConfig>) {
    difyConfig.value = { ...difyConfig.value, ...config }
    saveDifyConfig()
  }

  function saveDifyConfig() {
    localStorage.setItem('dify-config', JSON.stringify(difyConfig.value))
  }

  function loadDifyConfig() {
    const saved = localStorage.getItem('dify-config')
    if (saved) {
      try {
        difyConfig.value = JSON.parse(saved)
      } catch (e) {
        console.warn('Failed to load Dify config from localStorage')
      }
    }
  }

  // 小说管理方法
  function createNovel(title: string, backgroundSetting: string, aiWriterSetting: string): Novel {
    const novel: Novel = {
      id: Date.now().toString(),
      title,
      backgroundSetting,
      aiWriterSetting,
      createdAt: Date.now(),
      updatedAt: Date.now()
    }
    novels.value.push(novel)
    saveNovels()
    return novel
  }

  function updateNovel(id: string, updates: Partial<Omit<Novel, 'id' | 'createdAt'>>) {
    const novel = novels.value.find(n => n.id === id)
    if (novel) {
      Object.assign(novel, updates, { updatedAt: Date.now() })
      saveNovels()
    }
  }

  function deleteNovel(id: string) {
    novels.value = novels.value.filter(n => n.id !== id)
    chapters.value = chapters.value.filter(c => c.novelId !== id)
    characters.value = characters.value.filter(c => c.novelId !== id) // 删除相关人物
    if (currentNovel.value?.id === id) {
      currentNovel.value = null
      resetWritingSession()
    }
    saveNovels()
    saveChapters()
    saveCharacters() // 保存人物数据
  }

  function setCurrentNovel(novel: Novel | null) {
    currentNovel.value = novel
    if (novel) {
      writingSession.value.novelId = novel.id
    } else {
      resetWritingSession()
    }
    saveWritingSession()
  }

  // 章节管理方法
  function createChapter(novelId: string, title: string, nextChapterOverview: string = ''): Chapter {
    const existingChapters = chapters.value.filter(c => c.novelId === novelId)
    const maxOrder = Math.max(0, ...existingChapters.map(c => c.order))

    const chapter: Chapter = {
      id: Date.now().toString(),
      novelId,
      title,
      content: '',
      nextChapterOverview,
      order: maxOrder + 1,
      createdAt: Date.now(),
      updatedAt: Date.now()
    }
    chapters.value.push(chapter)
    saveChapters()
    return chapter
  }

  function updateChapter(id: string, updates: Partial<Omit<Chapter, 'id' | 'novelId' | 'createdAt'>>) {
    const chapter = chapters.value.find(c => c.id === id)
    if (chapter) {
      Object.assign(chapter, updates, { updatedAt: Date.now() })
      saveChapters()
    }
  }

  function deleteChapter(id: string) {
    chapters.value = chapters.value.filter(c => c.id !== id)
    saveChapters()
  }

  // 模板管理方法
  function createTemplate(name: string, type: 'background' | 'ai_writer', content: string, description?: string): Template {
    const template: Template = {
      id: Date.now().toString(),
      name,
      type,
      content,
      description,
      createdAt: Date.now(),
      updatedAt: Date.now()
    }
    templates.value.push(template)
    saveTemplates()
    return template
  }

  function updateTemplate(id: string, updates: Partial<Omit<Template, 'id' | 'createdAt'>>) {
    const template = templates.value.find(t => t.id === id)
    if (template) {
      Object.assign(template, updates, { updatedAt: Date.now() })
      saveTemplates()
    }
  }

  function deleteTemplate(id: string) {
    templates.value = templates.value.filter(t => t.id !== id)
    saveTemplates()
  }

  function getTemplate(id: string): Template | null {
    return templates.value.find(t => t.id === id) || null
  }

  // 人物管理方法
  function createCharacter(novelId: string, name: string, description: string): Character {
    const character: Character = {
      id: Date.now().toString(),
      novelId,
      name,
      description,
      createdAt: Date.now(),
      updatedAt: Date.now()
    }
    characters.value.push(character)
    saveCharacters()
    return character
  }

  function updateCharacter(id: string, updates: Partial<Omit<Character, 'id' | 'novelId' | 'createdAt'>>) {
    const character = characters.value.find(c => c.id === id)
    if (character) {
      Object.assign(character, updates, { updatedAt: Date.now() })
      saveCharacters()
    }
  }

  function deleteCharacter(id: string) {
    characters.value = characters.value.filter(c => c.id !== id)
    saveCharacters()
  }

  function getCharacter(id: string): Character | null {
    return characters.value.find(c => c.id === id) || null
  }

  // 创作会话方法
  function setUserInput(input: string) {
    writingSession.value.userInput = input
    saveWritingSession()
  }

  function setGenerating(generating: boolean) {
    writingSession.value.isGenerating = generating
    saveWritingSession()
  }

  function resetWritingSession() {
    writingSession.value = {
      novelId: '',
      userInput: '',
      generatedContent: '',
      isGenerating: false,
      hasUnsavedChanges: false,
      originalContent: ''
    }
    saveWritingSession()
  }

  function startEditingChapter(chapterId: string) {
    const chapter = chapters.value.find(c => c.id === chapterId)
    if (chapter) {
      // 检查是否切换到了不同的章节
      const isDifferentChapter = writingSession.value.currentChapterId !== chapterId

      writingSession.value.currentChapterId = chapterId
      writingSession.value.originalContent = chapter.content

      // 如果是切换到不同章节，或者没有生成内容，则重置为章节内容
      if (isDifferentChapter || !writingSession.value.generatedContent) {
        writingSession.value.generatedContent = chapter.content
        writingSession.value.hasUnsavedChanges = false
      }
      // 如果是同一章节且有生成内容，检查是否有未保存的更改
      else {
        writingSession.value.hasUnsavedChanges = writingSession.value.generatedContent !== chapter.content
      }

      saveWritingSession()
    }
  }

  function setGeneratedContent(content: string) {
    writingSession.value.generatedContent = content
    // 检查是否有更改
    writingSession.value.hasUnsavedChanges = content !== writingSession.value.originalContent
    saveWritingSession()
  }

  function discardChanges() {
    // 恢复到原始内容
    writingSession.value.generatedContent = writingSession.value.originalContent
    writingSession.value.hasUnsavedChanges = false
    writingSession.value.userInput = ''
    saveWritingSession()
  }

  function getCurrentChapter(): Chapter | null {
    if (!writingSession.value.currentChapterId) return null
    return chapters.value.find(c => c.id === writingSession.value.currentChapterId) || null
  }

  function getCurrentChapterNextOverview(): string {
    const currentChapter = getCurrentChapter()
    return currentChapter?.nextChapterOverview || ''
  }

  function getCurrentChapterContent(): string {
    const currentChapter = getCurrentChapter()
    return currentChapter?.content || ''
  }

  function getCurrentChapterLatestContent(): string {
    // 返回当前章节的最新内容：优先返回生成但未保存的内容，否则返回已保存的内容
    return writingSession.value.generatedContent || getCurrentChapterContent()
  }

  function getHistoryChapters(): Chapter[] {
    if (!currentNovel.value) return []
    const currentOrder = getCurrentChapter()?.order || 0
    return currentNovelChapters.value.filter(c => c.order < currentOrder)
  }

  function getHistoryChaptersContent(maxChars?: number): string {
    const historyChapters = getHistoryChapters()
    if (historyChapters.length === 0) return ''

    // 使用设置中的字数限制，如果没有提供参数的话
    const charLimit = maxChars ?? settings.value.historyChaptersMaxChars

    // 从最近的章节开始，逐步添加完整章节，直到接近字数限制
    let selectedChapters: Chapter[] = []
    let totalChars = 0

    // 倒序遍历（从最近的章节开始）
    for (let i = historyChapters.length - 1; i >= 0; i--) {
      const chapter = historyChapters[i]
      const chapterText = `Chapter ${chapter.order} ${chapter.title}: ${chapter.content}`

      // 如果添加这个完整章节会超过字数限制，就停止添加
      if (totalChars + chapterText.length > charLimit) {
        break
      }

      selectedChapters.unshift(chapter) // 添加到开头，保持章节顺序
      totalChars += chapterText.length + (selectedChapters.length > 1 ? 2 : 0) // 加上换行符的长度
    }

    // 构建最终内容
    return selectedChapters
      .map(c => `Chapter ${c.order} ${c.title}: ${c.content}`)
      .join('\n\n')
  }

  function saveWritingSession() {
    // 不保存 isGenerating 状态，避免页面恢复时显示错误的生成状态
    const sessionToSave = {
      ...writingSession.value,
      isGenerating: false
    }
    localStorage.setItem('writing-session', JSON.stringify(sessionToSave))
  }

  function loadWritingSession() {
    const saved = localStorage.getItem('writing-session')
    if (saved) {
      try {
        const loadedSession = JSON.parse(saved)
        // 确保加载时不在生成状态
        loadedSession.isGenerating = false
        writingSession.value = { ...writingSession.value, ...loadedSession }
      } catch (e) {
        console.warn('Failed to load writing session from localStorage')
      }
    }
  }

  function saveCurrentChapter() {
    if (!writingSession.value.currentChapterId || !writingSession.value.generatedContent) return false

    updateChapter(writingSession.value.currentChapterId, {
      content: writingSession.value.generatedContent
    })

    // 更新原始内容，重置未保存状态
    writingSession.value.originalContent = writingSession.value.generatedContent
    writingSession.value.hasUnsavedChanges = false

    // 清空生成的内容
    writingSession.value.generatedContent = ''

    // 保存会话状态
    saveWritingSession()

    return true
  }

  // 本地存储方法
  function saveNovels() {
    localStorage.setItem('novels', JSON.stringify(novels.value))
  }

  function loadNovels() {
    const saved = localStorage.getItem('novels')
    if (saved) {
      try {
        novels.value = JSON.parse(saved)
      } catch (e) {
        console.warn('Failed to load novels from localStorage')
      }
    }
  }

  function saveChapters() {
    localStorage.setItem('chapters', JSON.stringify(chapters.value))
  }

  function loadChapters() {
    const saved = localStorage.getItem('chapters')
    if (saved) {
      try {
        chapters.value = JSON.parse(saved)
      } catch (e) {
        console.warn('Failed to load chapters from localStorage')
      }
    }
  }

  function saveTemplates() {
    localStorage.setItem('templates', JSON.stringify(templates.value))
  }

  function loadTemplates() {
    const saved = localStorage.getItem('templates')
    if (saved) {
      try {
        templates.value = JSON.parse(saved)
      } catch (e) {
        console.warn('Failed to load templates from localStorage')
      }
    }
  }

  function saveCharacters() {
    localStorage.setItem('characters', JSON.stringify(characters.value))
  }

  function loadCharacters() {
    const saved = localStorage.getItem('characters')
    if (saved) {
      try {
        characters.value = JSON.parse(saved)
      } catch (e) {
        console.warn('Failed to load characters from localStorage')
      }
    }
  }

  function loadAllData() {
    loadDifyConfig()
    loadNovels()
    loadChapters()
    loadTemplates()
    loadCharacters()
    loadSettings()
    loadWritingSession()
    // 应用主题设置
    applyTheme()

    // 监听系统主题变化
    if (window.matchMedia) {
      const mediaQuery = window.matchMedia('(prefers-color-scheme: dark)')
      mediaQuery.addEventListener('change', () => {
        if (settings.value.themeMode === 'system') {
          applyTheme()
        }
      })
    }

    // 监听页面可见性变化，当页面隐藏时保存状态
    if (typeof document !== 'undefined') {
      document.addEventListener('visibilitychange', () => {
        if (document.hidden) {
          // 页面即将隐藏（锁屏、切换应用等），保存所有状态
          saveWritingSession()
        }
      })

      // 监听页面卸载事件
      window.addEventListener('beforeunload', () => {
        saveWritingSession()
      })

      // 监听页面重新获得焦点
      window.addEventListener('focus', () => {
        // 页面重新获得焦点时，重新加载最新数据
        loadWritingSession()
      })

      // 设置定期自动保存（每30秒保存一次创作会话）
      setInterval(() => {
        if (writingSession.value.currentChapterId && writingSession.value.generatedContent) {
          saveWritingSession()
        }
      }, 30000) // 30秒
    }
  }

  // 工具方法
  function setLoading(loading: boolean) {
    isLoading.value = loading
  }

  function setError(errorMessage: string | null) {
    error.value = errorMessage
  }

  function clearError() {
    error.value = null
  }

  // 主题管理方法
  function setThemeMode(mode: ThemeMode) {
    settings.value.themeMode = mode
    saveSettings()
    applyTheme()
  }

  function setHistoryChaptersMaxChars(maxChars: number) {
    settings.value.historyChaptersMaxChars = maxChars
    saveSettings()
  }

  function applyTheme() {
    const theme = currentTheme.value
    document.documentElement.setAttribute('data-theme', theme)
  }

  function saveSettings() {
    localStorage.setItem('app-settings', JSON.stringify(settings.value))
  }

  function loadSettings() {
    const saved = localStorage.getItem('app-settings')
    if (saved) {
      try {
        settings.value = { ...settings.value, ...JSON.parse(saved) }
      } catch (e) {
        console.warn('Failed to load app settings from localStorage')
      }
    }
  }

  return {
    // 状态
    difyConfig,
    novels,
    chapters,
    templates,
    characters,
    currentNovel,
    writingSession,
    settings,
    isLoading,
    error,

    // 计算属性
    currentNovelChapters,
    currentNovelCharacters,
    canSendToAI,
    isConfigured,
    backgroundTemplates,
    aiWriterTemplates,
    currentTheme,

    // 方法
    updateDifyConfig,
    createNovel,
    updateNovel,
    deleteNovel,
    setCurrentNovel,
    createChapter,
    updateChapter,
    deleteChapter,
    createTemplate,
    updateTemplate,
    deleteTemplate,
    getTemplate,
    createCharacter,
    updateCharacter,
    deleteCharacter,
    getCharacter,
    setUserInput,
    setGeneratedContent,
    setGenerating,
    resetWritingSession,
    startEditingChapter,
    discardChanges,
    getCurrentChapter,
    getCurrentChapterNextOverview,
    getCurrentChapterContent,
    getCurrentChapterLatestContent,
    getHistoryChapters,
    getHistoryChaptersContent,
    saveCurrentChapter,
    loadAllData,
    setLoading,
    setError,
    clearError,
    setThemeMode,
    setHistoryChaptersMaxChars,
    applyTheme
  }
})