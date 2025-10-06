<script setup lang="ts">
import { ref, computed, onMounted } from 'vue'
import { useRouter } from 'vue-router'
import { useAppStore } from '@/stores/app'
import { difyApi } from '@/services/difyApi'

const props = defineProps<{
  novelId: string
}>()

const appStore = useAppStore()
const router = useRouter()

const showSettingsDialog = ref(false)
const showNextChapterDialog = ref(false)
const nextChapterOverviewInput = ref('')
const showTemplateSelector = ref<'background' | 'ai_writer' | null>(null)

// 特写功能相关状态
const showCloseupDialog = ref(false)
const closeupContent = ref('')
const isGeneratingCloseup = ref(false)
const isCloseupMode = ref(false) // 特写模式开关状态
const selectedText = ref('') // 用户选择的文本片段
const selectedParagraphs = ref<number[]>([]) // 选中的段落索引数组
const showRewriteRequirementDialog = ref(false) // 改写要求输入弹窗
const rewriteRequirement = ref('') // 改写要求
const showRewriteResultDialog = ref(false) // 改写结果弹窗
const rewriteResult = ref('') // 改写结果

const editingBackgroundSetting = ref('')
const editingAiWriterSetting = ref('')
const editingNextChapterOverview = ref('')
const selectedBackgroundTemplate = ref<string>('')
const selectedAiWriterTemplate = ref<string>('')

// 人物选择相关状态
const selectedCharacters = ref<string[]>([]) // 选中的人物ID列表
const showCharacterSelector = ref(false)

const novel = computed(() => appStore.currentNovel)
const session = computed(() => appStore.writingSession)
const currentChapter = computed(() => appStore.getCurrentChapter())

// 获取所有章节并按顺序排序
const allChapters = computed(() => {
  if (!novel.value) return []
  return appStore.currentNovelChapters.sort((a, b) => a.order - b.order)
})

// 当前章节的索引
const currentChapterIndex = computed(() => {
  if (!currentChapter.value) return -1
  return allChapters.value.findIndex(c => c.id === currentChapter.value!.id)
})

// 是否有上一章
const hasPreviousChapter = computed(() => currentChapterIndex.value > 0)

// 是否有下一章
const hasNextChapter = computed(() => {
  return currentChapterIndex.value >= 0 && currentChapterIndex.value < allChapters.value.length - 1
})

// 特写功能是否可用（当前章节有内容时）
const canUseCloseup = computed(() => {
  return currentChapter.value && (currentChapter.value.content.trim().length > 0 || session.value.generatedContent.trim().length > 0)
})

// 将生成内容分割成段落
const contentParagraphs = computed(() => {
  if (!session.value.generatedContent) return []
  // 按换行符分割，过滤空段落
  return session.value.generatedContent.split('\n').filter(p => p.trim().length > 0)
})

onMounted(() => {
  // 确保加载数据
  appStore.loadAllData()

  // 如果当前小说不匹配，重新设置
  if (!novel.value || novel.value.id !== props.novelId) {
    const targetNovel = appStore.novels.find(n => n.id === props.novelId)
    if (targetNovel) {
      appStore.setCurrentNovel(targetNovel)
    } else {
      router.push('/')
      return
    }
  }

  // 如果有当前章节ID，开始编辑该章节
  // 注意：loadAllData已经恢复了writingSession，所以startEditingChapter会保留未保存的内容
  if (appStore.writingSession.currentChapterId) {
    appStore.startEditingChapter(appStore.writingSession.currentChapterId)
  }
})

async function sendToAI() {
  if (!appStore.canSendToAI || !novel.value || !currentChapter.value) return

  appStore.setGenerating(true)

  try {
    difyApi.updateConfig(appStore.difyConfig)

    // 构建发送给 Dify 的数据
    const inputs = {
      user_input: session.value.userInput,
      background_setting: novel.value.backgroundSetting,
      ai_writer_setting: novel.value.aiWriterSetting,
      next_chapter_overview: appStore.getCurrentChapterNextOverview(),
      // 使用当前最新内容：包括未保存的生成内容
      current_chapter_content: appStore.getCurrentChapterLatestContent(),
      history_chapters_content: appStore.getHistoryChaptersContent(),
      // 添加选中的人物信息
      characters_info: getSelectedCharactersInfo()
    }

    // 清空之前的内容，准备接收流式数据
    appStore.setGeneratedContent('')

    await difyApi.runWorkflowStreaming(
      {
        inputs,
        user: `novel_${novel.value.id}_chapter_${currentChapter.value.id}`
      },
      // onMessage - 处理流式数据
      (data: any) => {
        if (data.event === 'text_chunk' && data.data?.text) {
          // 逐步追加文本内容
          const currentContent = session.value.generatedContent
          appStore.setGeneratedContent(currentContent + data.data.text)
        } else if (data.event === 'workflow_finished' && data.data?.outputs?.content) {
          // 工作流完成，设置最终内容
          appStore.setGeneratedContent(data.data.outputs.content)
        }
      },
      // onError
      (error: Error) => {
        appStore.setError(error.message)
      },
      // onComplete
      () => {
        // 流式传输完成
        console.log('Streaming completed')
      }
    )

  } catch (error) {
    appStore.setError(error instanceof Error ? error.message : '生成失败')
  } finally {
    appStore.setGenerating(false)
  }
}

function openSettingsDialog() {
  if (!novel.value) return

  editingBackgroundSetting.value = novel.value.backgroundSetting
  editingAiWriterSetting.value = novel.value.aiWriterSetting
  editingNextChapterOverview.value = appStore.getCurrentChapterNextOverview()
  selectedBackgroundTemplate.value = ''
  selectedAiWriterTemplate.value = ''

  showSettingsDialog.value = true
}

function saveSettings() {
  if (!novel.value || !currentChapter.value) return

  // 更新小说设定
  appStore.updateNovel(novel.value.id, {
    backgroundSetting: editingBackgroundSetting.value,
    aiWriterSetting: editingAiWriterSetting.value
  })

  // 更新当前章节的下一章概览
  appStore.updateChapter(currentChapter.value.id, {
    nextChapterOverview: editingNextChapterOverview.value
  })

  showSettingsDialog.value = false
}

function saveChapter() {
  // 保存当前章节内容
  if (session.value.generatedContent) {
    appStore.saveCurrentChapter()
  }

  // 将当前章节的下一章概览填入用户输入框
  const currentNextOverview = appStore.getCurrentChapterNextOverview()
  appStore.setUserInput(currentNextOverview)

  // 弹出对话框让用户输入新的下一章概览，预填当前的下一章概览
  nextChapterOverviewInput.value = currentNextOverview
  showNextChapterDialog.value = true
}

function createNextChapter() {
  if (!currentChapter.value || !nextChapterOverviewInput.value.trim()) return

  // 先更新当前章节的下一章概览
  appStore.updateChapter(currentChapter.value.id, {
    nextChapterOverview: nextChapterOverviewInput.value
  })

  showNextChapterDialog.value = false
}

function selectTemplate(type: 'background' | 'ai_writer') {
  showTemplateSelector.value = type
}

function applyTemplate(templateId: string, type: 'background' | 'ai_writer') {
  const template = appStore.getTemplate(templateId)
  if (template) {
    if (type === 'background') {
      editingBackgroundSetting.value = template.content
      selectedBackgroundTemplate.value = template.name
    } else {
      editingAiWriterSetting.value = template.content
      selectedAiWriterTemplate.value = template.name
    }
  }
  showTemplateSelector.value = null
}

function toggleCloseupMode() {
  if (!canUseCloseup.value) return

  isCloseupMode.value = !isCloseupMode.value

  if (!isCloseupMode.value) {
    // 关闭特写模式，清空选择
    selectedParagraphs.value = []
    selectedText.value = ''
    rewriteRequirement.value = ''
  }
}

// 打开改写要求输入弹窗
function openRewriteRequirementDialog() {
  if (selectedParagraphs.value.length === 0) return
  showRewriteRequirementDialog.value = true
}

// 开始改写
async function startRewrite() {
  if (!rewriteRequirement.value.trim()) return

  showRewriteRequirementDialog.value = false
  showRewriteResultDialog.value = true
  rewriteResult.value = ''
  isGeneratingCloseup.value = true

  try {
    difyApi.updateConfig(appStore.difyConfig)

    const inputs: any = {
      user_input: rewriteRequirement.value,
      background_setting: novel.value!.backgroundSetting,
      ai_writer_setting: novel.value!.aiWriterSetting,
      next_chapter_overview: appStore.getCurrentChapterNextOverview(),
      current_chapter_content: appStore.getCurrentChapterLatestContent(),
      history_chapters_content: appStore.getHistoryChaptersContent(),
      characters_info: getSelectedCharactersInfo(),
      cmd: '特写'
    }

    if (selectedText.value) {
      inputs.choice_content = selectedText.value
    }

    await difyApi.runWorkflowStreaming(
      {
        inputs,
        user: `novel_${novel.value!.id}_chapter_${currentChapter.value!.id}_rewrite`
      },
      (data: any) => {
        if (data.event === 'text_chunk' && data.data?.text) {
          rewriteResult.value += data.data.text
        } else if (data.event === 'workflow_finished' && data.data?.outputs?.content) {
          rewriteResult.value = data.data.outputs.content
        }
      },
      (error: Error) => {
        appStore.setError(error.message)
        showRewriteResultDialog.value = false
      },
      () => {
        console.log('Rewrite streaming completed')
      }
    )
  } catch (error) {
    appStore.setError(error instanceof Error ? error.message : '改写失败')
    showRewriteResultDialog.value = false
  } finally {
    isGeneratingCloseup.value = false
  }
}

// 替换段落
function replaceSelectedParagraphs() {
  if (!selectedText.value || !rewriteResult.value) return

  const replacedContent = session.value.generatedContent.replace(selectedText.value, rewriteResult.value)
  appStore.setGeneratedContent(replacedContent)

  // 清空状态并关闭弹窗
  selectedText.value = ''
  selectedParagraphs.value = []
  rewriteResult.value = ''
  rewriteRequirement.value = ''
  showRewriteResultDialog.value = false
  isCloseupMode.value = false
}

// 重新生成
function regenerateRewrite() {
  showRewriteResultDialog.value = false
  showRewriteRequirementDialog.value = true
}

// 关闭结果弹窗
function closeRewriteResultDialog() {
  showRewriteResultDialog.value = false
}

async function generateCloseup() {
  if (!appStore.canSendToAI || !novel.value || !currentChapter.value || !canUseCloseup.value) return

  isGeneratingCloseup.value = true

  // 立即打开弹窗并清空之前的特写内容
  closeupContent.value = ''
  showCloseupDialog.value = true

  try {
    difyApi.updateConfig(appStore.difyConfig)

    // 构建发送给 Dify 的数据，包含特写指令
    const inputs: any = {
      user_input: session.value.userInput,
      background_setting: novel.value.backgroundSetting,
      ai_writer_setting: novel.value.aiWriterSetting,
      next_chapter_overview: appStore.getCurrentChapterNextOverview(),
      // 使用当前最新内容：包括未保存的生成内容
      current_chapter_content: appStore.getCurrentChapterLatestContent(),
      history_chapters_content: appStore.getHistoryChaptersContent(),
      // 添加选中的人物信息
      characters_info: getSelectedCharactersInfo(),
      cmd: '特写'
    }

    // 如果用户选择了文本片段，添加到参数中
    if (selectedText.value) {
      inputs.choice_content = selectedText.value
    }

    await difyApi.runWorkflowStreaming(
      {
        inputs,
        user: `novel_${novel.value.id}_chapter_${currentChapter.value.id}_closeup`
      },
      // onMessage - 处理流式数据
      (data: any) => {
        if (data.event === 'text_chunk' && data.data?.text) {
          // 逐步追加特写文本内容
          closeupContent.value += data.data.text
        } else if (data.event === 'workflow_finished' && data.data?.outputs?.content) {
          // 工作流完成，设置最终内容
          closeupContent.value = data.data.outputs.content
        }
      },
      // onError
      (error: Error) => {
        appStore.setError(error.message)
        // 生成失败时关闭特写弹窗和模式
        showCloseupDialog.value = false
        isCloseupMode.value = false
      },
      // onComplete
      () => {
        // 流式传输完成
        console.log('Closeup streaming completed')
      }
    )

  } catch (error) {
    appStore.setError(error instanceof Error ? error.message : '特写生成失败')
    // 生成失败时关闭特写弹窗和模式
    showCloseupDialog.value = false
    isCloseupMode.value = false
  } finally {
    isGeneratingCloseup.value = false
  }
}

function closeCloseupDialog() {
  showCloseupDialog.value = false
  // 关闭弹窗后保持特写模式开启状态，不清理特写内容和选择状态
  // 用户需要手动关闭特写开关来退出特写模式
}

function replaceSelectedText() {
  if (!selectedText.value || !closeupContent.value) return

  // 替换生成内容中的文本
  if (session.value.generatedContent) {
    const replacedContent = session.value.generatedContent.replace(selectedText.value, closeupContent.value)
    appStore.setGeneratedContent(replacedContent)
  }

  // 清空选择的文本和特写内容
  selectedText.value = ''
  selectedParagraphs.value = []
  closeupContent.value = ''
  showCloseupDialog.value = false
  isCloseupMode.value = false
}

function handleParagraphClick(index: number) {
  if (!isCloseupMode.value) return

  const selectedIndex = selectedParagraphs.value.indexOf(index)

  if (selectedIndex > -1) {
    // 已选中，取消选择
    selectedParagraphs.value.splice(selectedIndex, 1)
  } else {
    // 未选中，添加选择
    selectedParagraphs.value.push(index)
  }

  // 排序并检查是否连续
  selectedParagraphs.value.sort((a, b) => a - b)

  // 检查是否连续
  if (!isConsecutive(selectedParagraphs.value)) {
    // 如果不连续，只保留当前点击的段落
    selectedParagraphs.value = [index]
  }

  // 更新选中的文本
  updateSelectedText()
}

function isConsecutive(arr: number[]): boolean {
  if (arr.length <= 1) return true

  for (let i = 1; i < arr.length; i++) {
    if (arr[i] !== arr[i - 1] + 1) {
      return false
    }
  }
  return true
}

function updateSelectedText() {
  if (selectedParagraphs.value.length === 0) {
    selectedText.value = ''
    return
  }

  const selectedContent = selectedParagraphs.value
    .map(index => contentParagraphs.value[index])
    .join('\n')

  selectedText.value = selectedContent
}

function handleTextSelection() {
  // 移动端不再使用这个函数
  return
}

function toggleCharacterSelection(characterId: string) {
  const index = selectedCharacters.value.indexOf(characterId)
  if (index > -1) {
    selectedCharacters.value.splice(index, 1)
  } else {
    selectedCharacters.value.push(characterId)
  }
}

function clearCharacterSelection() {
  selectedCharacters.value = []
}

function getSelectedCharactersInfo(): string {
  if (selectedCharacters.value.length === 0) return ''

  const charactersInfo = selectedCharacters.value
    .map(id => appStore.getCharacter(id))
    .filter(char => char !== null)
    .map(char => `${char!.name}: ${char!.description}`)
    .join('\n')

  return charactersInfo
}

function goToPreviousChapter() {
  if (!hasPreviousChapter.value) return

  // 检查是否有未保存的更改
  if (session.value.hasUnsavedChanges) {
    if (!confirm('你有未保存的更改，确定要切换章节吗？更改将会丢失。')) {
      return
    }
    appStore.discardChanges()
  }

  const previousChapter = allChapters.value[currentChapterIndex.value - 1]
  if (previousChapter) {
    appStore.startEditingChapter(previousChapter.id)
  }
}

function goToNextChapter() {
  if (!hasNextChapter.value) return

  // 检查是否有未保存的更改
  if (session.value.hasUnsavedChanges) {
    if (!confirm('你有未保存的更改，确定要切换章节吗？更改将会丢失。')) {
      return
    }
    appStore.discardChanges()
  }

  const nextChapter = allChapters.value[currentChapterIndex.value + 1]
  if (nextChapter) {
    appStore.startEditingChapter(nextChapter.id)
    // 滚动到页面顶部
    window.scrollTo({ top: 0, behavior: 'smooth' })
  }
}

function goBack() {
  // 检查是否有未保存的更改
  if (session.value.hasUnsavedChanges) {
    if (confirm('你有未保存的更改，确定要离开吗？更改将会丢失。')) {
      appStore.discardChanges()
      router.push('/')
    }
  } else {
    router.push('/')
  }
}

function formatDate(timestamp: number) {
  return new Date(timestamp).toLocaleDateString('zh-CN', {
    year: 'numeric',
    month: 'short',
    day: 'numeric'
  })
}
</script>

<template>
  <div v-if="novel" class="writing-view">
    <!-- 头部导航 -->
    <div class="writing-header">
      <div class="header-left">
        <button @click="goBack" class="back-button">
          <span class="back-icon">←</span>
          返回
        </button>
        <div class="chapter-navigation">
          <button @click="goToPreviousChapter" :disabled="!hasPreviousChapter" class="nav-button prev-button" title="上一章">
            ◀ 上一章
          </button>
        </div>
        <div class="novel-info">
          <h2 class="novel-title">{{ novel.title }}</h2>
          <div class="chapter-status">
            <span v-if="currentChapter" class="chapter-info">{{ currentChapter.title }}</span>
            <span v-if="session.hasUnsavedChanges" class="unsaved-indicator">● 未保存</span>
          </div>
        </div>
      </div>

      <div class="header-actions">
        <button v-if="session.hasUnsavedChanges" @click="appStore.discardChanges()" class="discard-button">
          放弃更改
        </button>
        <button @click="openSettingsDialog" class="settings-button">
          <span class="settings-icon">⚙️</span>
          设置
        </button>
      </div>
    </div>

    <!-- 主内容区域 -->
    <div class="writing-content">
      <!-- AI 生成的内容显示区域 -->
      <div class="content-display">
        <div v-if="session.generatedContent" class="generated-content">
          <div class="content-header">
            <h3>AI 生成内容</h3>
            <button @click="saveChapter" class="save-button">
              保存章节
            </button>
          </div>
          <div class="content-text">
            <div
              v-for="(paragraph, index) in contentParagraphs"
              :key="index"
              :class="['paragraph', {
                'selectable': isCloseupMode,
                'selected': selectedParagraphs.includes(index)
              }]"
              @click="handleParagraphClick(index)"
            >
              {{ paragraph }}
            </div>
          </div>
        </div>

        <div v-else class="empty-content">
          <div class="empty-icon">✨</div>
          <h3>等待 AI 创作</h3>
          <p>在下方输入框中描述你想要的内容，然后发送给 AI</p>
        </div>
      </div>

      <!-- 浮动特写开关 -->
      <button
        v-if="canUseCloseup"
        @click="toggleCloseupMode"
        :class="['floating-closeup-toggle', { active: isCloseupMode }]"
        :title="isCloseupMode ? '关闭特写模式' : '开启特写模式'"
      >
        <span class="toggle-icon">{{ isCloseupMode ? '✨' : '👁️' }}</span>
      </button>

      <!-- 浮动改写按钮 -->
      <button
        v-if="isCloseupMode && selectedParagraphs.length > 0"
        @click="openRewriteRequirementDialog"
        class="floating-rewrite-button"
        title="改写选中段落"
      >
        <span class="rewrite-icon">✍️</span>
        <span class="rewrite-text">改写</span>
      </button>

      <!-- 用户输入区域 -->
      <div class="input-section">
        <div class="input-container">
          <textarea
            v-model="session.userInput"
            @input="appStore.setUserInput(session.userInput)"
            placeholder="描述你想要的故事情节、人物对话、场景描述等..."
            rows="4"
            :disabled="session.isGenerating"
          ></textarea>
        </div>

        <div class="input-actions">
          <div class="validation-info">
            <div class="validation-item" :class="{ valid: session.userInput.trim() }">
              用户输入: {{ session.userInput.trim() ? '✓' : '✗' }}
            </div>
            <div class="validation-item" :class="{ valid: novel.backgroundSetting.trim() }">
              背景设定: {{ novel.backgroundSetting.trim() ? '✓' : '✗' }}
            </div>
            <div class="validation-item" :class="{ valid: novel.aiWriterSetting.trim() }">
              AI作家设定: {{ novel.aiWriterSetting.trim() ? '✓' : '✗' }}
            </div>
            <div class="validation-item" :class="{ valid: appStore.getCurrentChapterNextOverview().trim() }">
              下一章概览: {{ appStore.getCurrentChapterNextOverview().trim() ? '✓' : '✗' }}
            </div>
          </div>

          <div class="action-buttons">
            <button
              @click="showCharacterSelector = !showCharacterSelector"
              :class="['character-selector-toggle', { active: showCharacterSelector || selectedCharacters.length > 0 }]"
              :title="selectedCharacters.length > 0 ? `已选择 ${selectedCharacters.length} 个人物` : '选择人物参与创作'"
            >
              <span class="character-icon">👤</span>
              <span class="character-count" v-if="selectedCharacters.length > 0">{{ selectedCharacters.length }}</span>
              <span class="character-text">{{ selectedCharacters.length > 0 ? '已选人物' : '选择人物' }}</span>
            </button>
            <button
              @click="sendToAI"
              :disabled="!appStore.canSendToAI || session.isGenerating"
              class="send-button"
            >
              {{ session.isGenerating ? '生成中...' : '发送给 AI' }}
            </button>
          </div>
        </div>
      </div>
    </div>

    <!-- 人物选择对话框 -->
    <div v-if="showCharacterSelector" class="dialog-overlay" @click="showCharacterSelector = false">
      <div class="dialog character-selector-dialog" @click.stop>
        <div class="dialog-header">
          <h3>选择参与创作的人物</h3>
          <button @click="showCharacterSelector = false" class="close-button">×</button>
        </div>
        <div class="dialog-body">
          <div v-if="appStore.currentNovelCharacters.length === 0" class="empty-characters">
            <div class="empty-icon">👤</div>
            <p>还没有人物，<router-link :to="`/characters/${novel.id}`" class="create-character-link">去创建人物</router-link></p>
          </div>
          <div v-else class="character-selection-list">
            <div
              v-for="character in appStore.currentNovelCharacters"
              :key="character.id"
              @click="toggleCharacterSelection(character.id)"
              :class="['character-selection-item', { selected: selectedCharacters.includes(character.id) }]"
            >
              <div class="character-checkbox">
                <span v-if="selectedCharacters.includes(character.id)" class="check-icon">✓</span>
              </div>
              <div class="character-info">
                <h4 class="character-name">{{ character.name }}</h4>
                <p class="character-description">{{ character.description }}</p>
              </div>
            </div>
          </div>
        </div>
        <div class="dialog-footer">
          <button @click="clearCharacterSelection" class="clear-selection-button" :disabled="selectedCharacters.length === 0">
            清空选择
          </button>
          <button @click="showCharacterSelector = false" class="confirm-selection-button">
            确认选择 {{ selectedCharacters.length > 0 ? `(${selectedCharacters.length})` : '' }}
          </button>
        </div>
      </div>
    </div>

    <!-- 改写要求输入对话框 -->
    <div v-if="showRewriteRequirementDialog" class="dialog-overlay" @click="showRewriteRequirementDialog = false">
      <div class="dialog" @click.stop>
        <div class="dialog-header">
          <h3>输入改写要求</h3>
          <button @click="showRewriteRequirementDialog = false" class="close-button">×</button>
        </div>
        <div class="dialog-body">
          <div class="form-group">
            <label>请描述你的改写要求</label>
            <textarea
              v-model="rewriteRequirement"
              placeholder="例如：增加细节描述、改变语气、加强情感表达等..."
              rows="4"
              maxlength="500"
              autofocus
            ></textarea>
            <div class="help-text">已选择 {{ selectedParagraphs.length }} 个段落</div>
          </div>
        </div>
        <div class="dialog-footer">
          <button @click="showRewriteRequirementDialog = false" class="cancel-button">取消</button>
          <button @click="startRewrite" :disabled="!rewriteRequirement.trim()" class="confirm-button">
            确认改写
          </button>
        </div>
      </div>
    </div>

    <!-- 改写结果展示对话框 -->
    <div v-if="showRewriteResultDialog" class="dialog-overlay" @click.stop>
      <div class="dialog large-dialog rewrite-result-dialog" @click.stop>
        <div class="dialog-header">
          <h3>✨ 改写结果</h3>
        </div>
        <div class="dialog-body">
          <div class="rewrite-result-content">
            {{ rewriteResult || '正在生成中...' }}
          </div>
          <div class="rewrite-note">
            <span class="note-icon">📝</span>
            <span>你可以选择替换原文、重新改写或关闭</span>
          </div>
        </div>
        <div class="dialog-footer">
          <button @click="regenerateRewrite" :disabled="isGeneratingCloseup" class="rewrite-button">
            {{ isGeneratingCloseup ? '生成中...' : '🔄 重写' }}
          </button>
          <button @click="replaceSelectedParagraphs" :disabled="isGeneratingCloseup || !rewriteResult" class="replace-button">
            替换
          </button>
          <button @click="closeRewriteResultDialog" class="close-result-button">
            关闭
          </button>
        </div>
      </div>
    </div>

    <!-- 特写内容展示对话框 -->
    <div v-if="showCloseupDialog" class="dialog-overlay" @click="closeCloseupDialog">
      <div class="dialog large-dialog closeup-dialog" @click.stop>
        <div class="dialog-header">
          <h3>✨ 特写内容</h3>
          <button @click="closeCloseupDialog" class="close-button">×</button>
        </div>
        <div class="dialog-body">
          <div class="closeup-content">
            {{ closeupContent }}
          </div>
          <div v-if="selectedText" class="closeup-note selection-info">
            <span class="note-icon">📝</span>
            <span>你选择了 {{ selectedParagraphs.length }} 个段落，可以使用下方的"替换原文"按钮将其替换为特写内容</span>
          </div>
          <div v-else class="closeup-note">
            <span class="note-icon">💡</span>
            <span>这是基于当前章节内容生成的特写片段。开启特写模式后，点击段落可选择连续的内容进行特写</span>
          </div>
        </div>
        <div class="dialog-footer">
          <button @click="generateCloseup" :disabled="isGeneratingCloseup" class="refresh-closeup-button">
            {{ isGeneratingCloseup ? '重新生成中...' : '🔄 重新生成' }}
          </button>
          <button v-if="selectedText" @click="replaceSelectedText" class="replace-button">
            替换原文
          </button>
          <button @click="closeCloseupDialog" class="close-closeup-button">
            关闭弹窗
          </button>
        </div>
      </div>
    </div>

    <!-- 设置对话框 -->
    <div v-if="showSettingsDialog" class="dialog-overlay" @click="showSettingsDialog = false">
      <div class="dialog large-dialog" @click.stop>
        <div class="dialog-header">
          <h3>创作设置</h3>
          <button @click="showSettingsDialog = false" class="close-button">×</button>
        </div>
        <div class="dialog-body">
          <div class="form-group">
            <div class="form-label-with-action">
              <label>背景设定</label>
              <div class="template-actions">
                <button type="button" @click="selectTemplate('background')" class="template-btn">
                  选择模板
                </button>
              </div>
            </div>
            <div v-if="selectedBackgroundTemplate" class="selected-template">
              已选择模板: {{ selectedBackgroundTemplate }}
            </div>
            <textarea
              v-model="editingBackgroundSetting"
              placeholder="描述小说的世界观、时代背景、主要设定等"
              rows="4"
              maxlength="1000"
            ></textarea>
          </div>

          <div class="form-group">
            <div class="form-label-with-action">
              <label>AI作家设定</label>
              <div class="template-actions">
                <button type="button" @click="selectTemplate('ai_writer')" class="template-btn">
                  选择模板
                </button>
              </div>
            </div>
            <div v-if="selectedAiWriterTemplate" class="selected-template">
              已选择模板: {{ selectedAiWriterTemplate }}
            </div>
            <textarea
              v-model="editingAiWriterSetting"
              placeholder="定义AI作家的风格、偏好、写作特点等"
              rows="4"
              maxlength="1000"
            ></textarea>
          </div>

          <div class="form-group">
            <label>下一章概览</label>
            <textarea
              v-model="editingNextChapterOverview"
              placeholder="描述下一章的故事走向、重要事件等"
              rows="3"
              maxlength="500"
            ></textarea>
          </div>
        </div>
        <div class="dialog-footer">
          <button @click="showSettingsDialog = false" class="cancel-button">取消</button>
          <button @click="saveSettings" class="save-settings-button">保存设置</button>
        </div>
      </div>
    </div>

    <!-- 下一章概览输入对话框 -->
    <div v-if="showNextChapterDialog" class="dialog-overlay">
      <div class="dialog" @click.stop>
        <div class="dialog-header">
          <h3>撰写下一章概览</h3>
        </div>
        <div class="dialog-body">
          <div class="form-group">
            <label>下一章概览</label>
            <textarea
              v-model="nextChapterOverviewInput"
              placeholder="描述下一章的故事走向、重要事件、情节发展等"
              rows="4"
              maxlength="500"
            ></textarea>
            <div class="help-text">这将作为下一章创作的指导，帮助 AI 更好地续写故事</div>
          </div>
        </div>
        <div class="dialog-footer">
          <button @click="createNextChapter" :disabled="!nextChapterOverviewInput.trim()" class="create-chapter-button">
            创建下一章
          </button>
        </div>
      </div>
    </div>

    <!-- 底部导航 -->
    <div class="bottom-navigation">
      <button @click="goToNextChapter" :disabled="!hasNextChapter" class="nav-button next-button" title="下一章">
        下一章 ▶
      </button>
    </div>

    <!-- 模板选择对话框 -->
    <div v-if="showTemplateSelector" class="dialog-overlay" @click="showTemplateSelector = null">
      <div class="dialog template-dialog" @click.stop>
        <div class="dialog-header">
          <h3>选择{{ showTemplateSelector === 'background' ? '背景设定' : 'AI作家设定' }}模板</h3>
          <button @click="showTemplateSelector = null" class="close-button">×</button>
        </div>
        <div class="dialog-body">
          <div
            v-if="(showTemplateSelector === 'background' ? appStore.backgroundTemplates : appStore.aiWriterTemplates).length === 0"
            class="empty-templates"
          >
            <div class="empty-icon">📄</div>
            <p>还没有{{ showTemplateSelector === 'background' ? '背景设定' : 'AI作家设定' }}模板</p>
          </div>
          <div v-else class="template-list">
            <div
              v-for="template in (showTemplateSelector === 'background' ? appStore.backgroundTemplates : appStore.aiWriterTemplates)"
              :key="template.id"
              @click="applyTemplate(template.id, showTemplateSelector)"
              class="template-item"
            >
              <div class="template-header">
                <h4 class="template-name">{{ template.name }}</h4>
                <span class="template-date">{{ formatDate(template.updatedAt) }}</span>
              </div>
              <p v-if="template.description" class="template-description">{{ template.description }}</p>
              <div class="template-preview">{{ template.content.substring(0, 100) }}{{ template.content.length > 100 ? '...' : '' }}</div>
            </div>
          </div>
        </div>
      </div>
    </div>
  </div>
</template>

<style scoped>
.writing-view {
  min-height: calc(100vh - 56px);
  display: flex;
  flex-direction: column;
  background: var(--color-surface-secondary);
}

.writing-header {
  background: var(--color-surface);
  border-bottom: 1px solid #e9ecef;
  padding: 12px 16px;
  display: flex;
  justify-content: space-between;
  align-items: center;
  flex-shrink: 0;
}

.header-left {
  display: flex;
  align-items: center;
  gap: 12px;
}

.back-button {
  display: flex;
  align-items: center;
  gap: 6px;
  background: none;
  border: none;
  color: var(--color-text-secondary);
  font-size: 14px;
  font-weight: 500;
  cursor: pointer;
  padding: 6px 12px;
  border-radius: 6px;
  transition: all 0.2s;
}

.back-button:hover {
  background: var(--color-surface-secondary);
  color: var(--color-text-primary);
}

.back-icon {
  font-size: 16px;
}

.chapter-navigation {
  display: flex;
  gap: 4px;
}

.nav-button {
  background: none;
  border: 1px solid #dee2e6;
  color: var(--color-text-secondary);
  font-size: 14px;
  cursor: pointer;
  padding: 6px 12px;
  border-radius: 6px;
  transition: all 0.2s;
}

.nav-button:hover:not(:disabled) {
  background: var(--color-surface-secondary);
  border-color: var(--color-primary);
  color: var(--color-primary);
}

.nav-button:disabled {
  opacity: 0.3;
  cursor: not-allowed;
}

.novel-info {
  display: flex;
  flex-direction: column;
  gap: 2px;
}

.novel-title {
  margin: 0;
  font-size: 18px;
  font-weight: 600;
  color: var(--color-text-primary);
}

.chapter-status {
  display: flex;
  align-items: center;
  gap: 8px;
}

.chapter-info {
  font-size: 12px;
  color: var(--color-text-secondary);
}

.unsaved-indicator {
  font-size: 12px;
  color: var(--color-danger);
  font-weight: 500;
}

.header-actions {
  display: flex;
  gap: 8px;
}

.discard-button {
  display: flex;
  align-items: center;
  gap: 6px;
  background: #6c757d;
  color: white;
  border: none;
  border-radius: 6px;
  padding: 6px 12px;
  font-size: 14px;
  font-weight: 500;
  cursor: pointer;
  transition: background-color 0.2s;
}

.discard-button:hover {
  background: #5a6268;
}

.settings-button {
  display: flex;
  align-items: center;
  gap: 6px;
  background: #007bff;
  color: white;
  border: none;
  border-radius: 6px;
  padding: 6px 12px;
  font-size: 14px;
  font-weight: 500;
  cursor: pointer;
  transition: background-color 0.2s;
}

.settings-button:hover {
  background: #0056b3;
}

.settings-icon {
  font-size: 14px;
}

.bottom-navigation {
  background: var(--color-surface);
  border-top: 1px solid #e9ecef;
  padding: 12px 16px;
  display: flex;
  justify-content: center;
  align-items: center;
  flex-shrink: 0;
}

.bottom-navigation .nav-button {
  background: var(--color-primary);
  color: white;
  border: none;
  font-weight: 500;
  padding: 12px 20px;
  font-size: 16px;
  width: 100%;
  max-width: 100%;
}

.bottom-navigation .nav-button:hover:not(:disabled) {
  background: var(--color-primary-hover);
  border-color: var(--color-primary-hover);
}

.bottom-navigation .nav-button:disabled {
  background: #dee2e6;
  color: var(--color-text-secondary);
}

.writing-content {
  flex: 1;
  display: flex;
  flex-direction: column;
  gap: 16px;
  padding: 16px;
  min-height: 0;
  position: relative;
}

/* 浮动特写开关按钮 */
.floating-closeup-toggle {
  position: fixed;
  bottom: 120px;
  right: 24px;
  width: 56px;
  height: 56px;
  border-radius: 50%;
  background: var(--color-surface);
  border: 2px solid #dee2e6;
  color: var(--color-text-secondary);
  font-size: 24px;
  cursor: pointer;
  display: flex;
  align-items: center;
  justify-content: center;
  box-shadow: 0 4px 12px rgba(0, 0, 0, 0.15);
  transition: all 0.3s ease;
  z-index: 100;
}

.floating-closeup-toggle:hover {
  transform: translateY(-2px);
  box-shadow: 0 6px 16px rgba(0, 0, 0, 0.2);
  border-color: #17a2b8;
}

.floating-closeup-toggle.active {
  background: linear-gradient(135deg, #17a2b8, #138496);
  border-color: #17a2b8;
  color: white;
}

.floating-closeup-toggle.active:hover {
  background: linear-gradient(135deg, #138496, #117a8b);
}

.floating-closeup-toggle .toggle-icon {
  animation: none;
}

.floating-closeup-toggle.active .toggle-icon {
  animation: sparkle 1.5s ease-in-out infinite;
}

/* 浮动改写按钮 */
.floating-rewrite-button {
  position: fixed;
  bottom: 120px;
  right: 92px;
  height: 56px;
  padding: 0 20px;
  border-radius: 28px;
  background: linear-gradient(135deg, #28a745, #218838);
  border: none;
  color: white;
  font-size: 16px;
  font-weight: 600;
  cursor: pointer;
  display: flex;
  align-items: center;
  gap: 8px;
  box-shadow: 0 4px 12px rgba(40, 167, 69, 0.3);
  transition: all 0.3s ease;
  z-index: 100;
  animation: slideInRight 0.3s ease-out;
}

@keyframes slideInRight {
  from {
    opacity: 0;
    transform: translateX(20px);
  }
  to {
    opacity: 1;
    transform: translateX(0);
  }
}

.floating-rewrite-button:hover {
  transform: translateY(-2px);
  box-shadow: 0 6px 16px rgba(40, 167, 69, 0.4);
  background: linear-gradient(135deg, #218838, #1e7e34);
}

.floating-rewrite-button .rewrite-icon {
  font-size: 20px;
}

.floating-rewrite-button .rewrite-text {
  font-weight: 600;
}

.content-display {
  flex: 1;
  background: var(--color-surface);
  border-radius: 12px;
  box-shadow: 0 1px 3px rgba(0, 0, 0, 0.1);
  min-height: 300px;
  display: flex;
  flex-direction: column;
}

.generated-content {
  height: 100%;
  display: flex;
  flex-direction: column;
}

.content-header {
  display: flex;
  justify-content: space-between;
  align-items: center;
  padding: 16px 20px;
  border-bottom: 1px solid #e9ecef;
}

.content-header h3 {
  margin: 0;
  font-size: 16px;
  font-weight: 600;
  color: var(--color-text-primary);
}

.save-button {
  background: #28a745;
  color: white;
  border: none;
  border-radius: 6px;
  padding: 8px 16px;
  font-size: 14px;
  font-weight: 500;
  cursor: pointer;
  transition: background-color 0.2s;
}

.save-button:hover:not(:disabled) {
  background: #218838;
}

.save-button:disabled {
  background: #dee2e6;
  color: var(--color-text-secondary);
  cursor: not-allowed;
}

.content-text {
  flex: 1;
  padding: 20px;
  font-size: 16px;
  line-height: 1.8;
  color: var(--color-text-primary);
  overflow-y: auto;
}

.paragraph {
  white-space: pre-wrap;
  word-wrap: break-word;
  margin-bottom: 12px;
  padding: 8px;
  border-radius: 6px;
  transition: all 0.2s ease;
}

.paragraph:last-child {
  margin-bottom: 0;
}

.paragraph.selectable {
  cursor: pointer;
  border: 2px solid transparent;
}

.paragraph.selectable:hover {
  background: rgba(23, 162, 184, 0.1);
  border-color: rgba(23, 162, 184, 0.3);
}

.paragraph.selected {
  background: rgba(23, 162, 184, 0.2);
  border-color: #17a2b8;
  box-shadow: 0 2px 8px rgba(23, 162, 184, 0.3);
}

.empty-content {
  flex: 1;
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  padding: 40px;
  text-align: center;
  color: var(--color-text-secondary);
}

.empty-icon {
  font-size: 48px;
  margin-bottom: 16px;
}

.empty-content h3 {
  margin: 0 0 8px 0;
  font-size: 18px;
  font-weight: 600;
}

.empty-content p {
  margin: 0;
  font-size: 14px;
}

.input-section {
  flex-shrink: 0;
  background: var(--color-surface);
  border-radius: 12px;
  padding: 16px;
  box-shadow: 0 1px 3px rgba(0, 0, 0, 0.1);
}

.input-container {
  margin-bottom: 12px;
}

.input-container textarea {
  width: 100%;
  padding: 12px;
  border: 1px solid #dee2e6;
  border-radius: 8px;
  font-size: 14px;
  box-sizing: border-box;
  resize: vertical;
  min-height: 100px;
  transition: border-color 0.2s;
}

.input-container textarea:focus {
  outline: none;
  border-color: var(--color-primary);
  box-shadow: 0 0 0 3px rgba(0, 123, 255, 0.1);
}

.input-container textarea:disabled {
  background: var(--color-surface-secondary);
  color: var(--color-text-secondary);
  cursor: not-allowed;
}

.input-actions {
  display: flex;
  justify-content: space-between;
  align-items: flex-end;
  gap: 16px;
}

.validation-info {
  display: flex;
  flex-wrap: wrap;
  gap: 8px;
  flex: 1;
}

.validation-item {
  font-size: 12px;
  padding: 4px 8px;
  border-radius: 4px;
  background: var(--color-surface-secondary);
  color: var(--color-danger);
  border: 1px solid #f5c6cb;
}

.validation-item.valid {
  background: #d4edda;
  color: #155724;
  border-color: #c3e6cb;
}

.action-buttons {
  display: flex;
  gap: 12px;
  flex-shrink: 0;
}

.action-buttons {
  display: flex;
  gap: 12px;
  flex-shrink: 0;
}

.character-selector-toggle {
  background: var(--color-surface-secondary);
  color: var(--color-text-secondary);
  border: 2px solid #dee2e6;
  border-radius: 8px;
  padding: 12px 16px;
  font-size: 14px;
  font-weight: 600;
  cursor: pointer;
  transition: all 0.3s ease;
  display: flex;
  align-items: center;
  gap: 6px;
  position: relative;
}

.character-selector-toggle:hover:not(:disabled) {
  border-color: var(--color-info);
  color: var(--color-info);
  transform: translateY(-1px);
}

.character-selector-toggle.active {
  background: linear-gradient(135deg, var(--color-info), #138496);
  color: white;
  border-color: var(--color-info);
  box-shadow: 0 4px 8px rgba(23, 162, 184, 0.3);
}

.character-selector-toggle.active:hover:not(:disabled) {
  background: linear-gradient(135deg, #138496, #117a8b);
  transform: translateY(-1px);
  box-shadow: 0 6px 12px rgba(23, 162, 184, 0.4);
}

.character-icon {
  font-size: 16px;
}

.character-count {
  background: rgba(255, 255, 255, 0.9);
  color: var(--color-info);
  border-radius: 50%;
  width: 20px;
  height: 20px;
  display: flex;
  align-items: center;
  justify-content: center;
  font-size: 12px;
  font-weight: 700;
  position: absolute;
  top: -6px;
  right: -6px;
}

.character-selector-toggle.active .character-count {
  background: white;
  color: var(--color-info);
}

.character-text {
  font-weight: 500;
}

.send-button {
  background: #007bff;
  color: white;
  border: none;
  border-radius: 8px;
  padding: 12px 24px;
  font-size: 16px;
  font-weight: 600;
  cursor: pointer;
  transition: all 0.2s;
  flex-shrink: 0;
}

.send-button:hover:not(:disabled) {
  background: #0056b3;
}

.send-button:disabled {
  background: #dee2e6;
  color: var(--color-text-secondary);
  cursor: not-allowed;
}

/* 对话框样式 */
.dialog-overlay {
  position: fixed;
  top: 0;
  left: 0;
  right: 0;
  bottom: 0;
  background: rgba(0, 0, 0, 0.5);
  display: flex;
  align-items: center;
  justify-content: center;
  z-index: 1000;
  padding: 20px;
}

.dialog {
  background: var(--color-surface);
  border-radius: 12px;
  width: 100%;
  max-width: 400px;
  max-height: 90vh;
  overflow: hidden;
  animation: dialogSlideIn 0.2s ease-out;
}

.large-dialog {
  max-width: 600px;
}

@keyframes dialogSlideIn {
  from {
    opacity: 0;
    transform: translateY(-20px);
  }
  to {
    opacity: 1;
    transform: translateY(0);
  }
}

.dialog-header {
  display: flex;
  justify-content: space-between;
  align-items: center;
  padding: 20px;
  border-bottom: 1px solid #e9ecef;
}

.dialog-header h3 {
  margin: 0;
  font-size: 18px;
  font-weight: 600;
  color: var(--color-text-primary);
}

.close-button {
  background: none;
  border: none;
  font-size: 24px;
  color: var(--color-text-secondary);
  cursor: pointer;
  padding: 0;
  width: 32px;
  height: 32px;
  display: flex;
  align-items: center;
  justify-content: center;
  border-radius: 6px;
}

.close-button:hover {
  background: var(--color-surface-secondary);
  color: var(--color-text-primary);
}

.dialog-body {
  padding: 20px;
  max-height: 60vh;
  overflow-y: auto;
}

.form-group {
  margin-bottom: 16px;
}

.form-group:last-child {
  margin-bottom: 0;
}

.form-group label {
  display: block;
  margin-bottom: 8px;
  font-size: 14px;
  font-weight: 500;
  color: var(--color-text-primary);
}

.form-group textarea {
  width: 100%;
  padding: 12px;
  border: 1px solid #dee2e6;
  border-radius: 8px;
  font-size: 14px;
  box-sizing: border-box;
  transition: border-color 0.2s;
  resize: vertical;
  min-height: 80px;
}

.form-group textarea:focus {
  outline: none;
  border-color: var(--color-primary);
  box-shadow: 0 0 0 3px rgba(0, 123, 255, 0.1);
}

.help-text {
  margin-top: 6px;
  font-size: 12px;
  color: var(--color-text-secondary);
  line-height: 1.4;
}

.dialog-footer {
  display: flex;
  gap: 12px;
  padding: 20px;
  border-top: 1px solid var(--color-divider);
  justify-content: flex-end;
}

.cancel-button,
.save-settings-button,
.create-chapter-button {
  padding: 10px 20px;
  border-radius: 8px;
  font-size: 14px;
  font-weight: 500;
  cursor: pointer;
  transition: all 0.2s;
  border: none;
}

.cancel-button {
  background: var(--color-surface-secondary);
  color: var(--color-text-secondary);
}

.cancel-button:hover {
  background: var(--color-hover-background);
  color: var(--color-text-primary);
}

.save-settings-button {
  background: #007bff;
  color: white;
}

.save-settings-button:hover {
  background: #0056b3;
}

.create-chapter-button {
  background: #28a745;
  color: white;
}

.create-chapter-button:hover:not(:disabled) {
  background: #218838;
}

.create-chapter-button:disabled {
  background: #dee2e6;
  color: var(--color-text-secondary);
  cursor: not-allowed;
}

/* 模板相关样式 */
.form-label-with-action {
  display: flex;
  justify-content: space-between;
  align-items: center;
  margin-bottom: 8px;
}

.template-actions {
  display: flex;
  gap: 8px;
}

.template-btn {
  padding: 4px 8px;
  border: 1px solid #dee2e6;
  border-radius: 4px;
  background: var(--color-surface);
  font-size: 12px;
  cursor: pointer;
  transition: all 0.2s;
}

.template-btn:hover:not(:disabled) {
  background: var(--color-hover-background);
  border-color: #adb5bd;
}

.selected-template {
  margin-bottom: 8px;
  padding: 4px 8px;
  background: #e7f3ff;
  border: 1px solid #b3d7ff;
  border-radius: 4px;
  font-size: 12px;
  color: #0066cc;
}

.template-dialog {
  max-width: 600px;
}

.empty-templates {
  text-align: center;
  padding: 40px 20px;
  color: var(--color-text-secondary);
}

.empty-icon {
  font-size: 32px;
  margin-bottom: 12px;
}

.template-list {
  max-height: 400px;
  overflow-y: auto;
}

.template-item {
  padding: 12px;
  border: 1px solid #dee2e6;
  border-radius: 8px;
  margin-bottom: 8px;
  cursor: pointer;
  transition: all 0.2s;
}

.template-item:hover {
  background: var(--color-surface-secondary);
  border-color: var(--color-primary);
}

.template-item:last-child {
  margin-bottom: 0;
}

.template-header {
  display: flex;
  justify-content: space-between;
  align-items: center;
  margin-bottom: 4px;
}

.template-name {
  margin: 0;
  font-size: 14px;
  font-weight: 600;
  color: var(--color-text-primary);
}

.template-date {
  font-size: 11px;
  color: var(--color-text-secondary);
}

.template-description {
  margin: 0 0 8px 0;
  font-size: 12px;
  color: var(--color-text-medium);
  font-style: italic;
}

.template-preview {
  font-size: 12px;
  color: var(--color-text-secondary);
  line-height: 1.4;
}

/* 人物选择对话框样式 */
.character-selector-dialog {
  max-width: 600px;
}

.character-selection-list {
  max-height: 400px;
  overflow-y: auto;
}

.character-selection-item {
  display: flex;
  align-items: flex-start;
  gap: 12px;
  padding: 12px;
  border: 1px solid var(--color-divider);
  border-radius: 8px;
  margin-bottom: 8px;
  cursor: pointer;
  transition: all 0.2s;
}

.character-selection-item:hover {
  background: var(--color-surface-secondary);
  border-color: var(--color-info);
}

.character-selection-item.selected {
  background: #e7f3ff;
  border-color: var(--color-info);
  box-shadow: 0 2px 4px rgba(23, 162, 184, 0.2);
}

.character-selection-item:last-child {
  margin-bottom: 0;
}

.character-checkbox {
  width: 20px;
  height: 20px;
  border: 2px solid #dee2e6;
  border-radius: 4px;
  display: flex;
  align-items: center;
  justify-content: center;
  flex-shrink: 0;
  margin-top: 2px;
  transition: all 0.2s;
}

.character-selection-item.selected .character-checkbox {
  background: var(--color-info);
  border-color: var(--color-info);
}

.check-icon {
  color: white;
  font-size: 12px;
  font-weight: 700;
}

.character-info {
  flex: 1;
  min-width: 0;
}

.character-name {
  margin: 0 0 4px 0;
  font-size: 14px;
  font-weight: 600;
  color: var(--color-text-primary);
}

.character-description {
  margin: 0;
  font-size: 12px;
  color: var(--color-text-medium);
  line-height: 1.4;
}

.empty-characters {
  text-align: center;
  padding: 40px 20px;
  color: var(--color-text-secondary);
}

.empty-characters .empty-icon {
  font-size: 32px;
  margin-bottom: 12px;
}

.create-character-link {
  color: var(--color-info);
  text-decoration: underline;
}

.create-character-link:hover {
  text-decoration: none;
}

.clear-selection-button {
  background: var(--color-surface-secondary);
  color: var(--color-text-secondary);
  border: none;
  border-radius: 8px;
  padding: 10px 20px;
  font-size: 14px;
  font-weight: 500;
  cursor: pointer;
  transition: all 0.2s;
}

.clear-selection-button:hover:not(:disabled) {
  background: var(--color-hover-background);
  color: var(--color-text-primary);
}

.clear-selection-button:disabled {
  opacity: 0.5;
  cursor: not-allowed;
}

.confirm-selection-button {
  background: var(--color-info);
  color: white;
  border: none;
  border-radius: 8px;
  padding: 10px 20px;
  font-size: 14px;
  font-weight: 500;
  cursor: pointer;
  transition: all 0.2s;
}

.confirm-selection-button:hover {
  opacity: 0.9;
}

/* 特写对话框样式 */
.closeup-dialog {
  max-width: 800px;
}

.closeup-content {
  background: var(--color-surface-secondary);
  border-radius: 8px;
  padding: 20px;
  margin-bottom: 16px;
  font-size: 16px;
  line-height: 1.8;
  color: var(--color-text-primary);
  white-space: pre-wrap;
  word-wrap: break-word;
  min-height: 200px;
  max-height: 400px;
  overflow-y: auto;
}

.closeup-note {
  display: flex;
  align-items: center;
  gap: 8px;
  background: #e7f3ff;
  border: 1px solid #b3d7ff;
  border-radius: 6px;
  padding: 8px 12px;
  font-size: 12px;
  color: #0066cc;
}

.note-icon {
  font-size: 14px;
}

.close-closeup-button {
  background: var(--color-primary);
  color: white;
  border: none;
  border-radius: 8px;
  padding: 10px 20px;
  font-size: 14px;
  font-weight: 500;
  cursor: pointer;
  transition: all 0.2s;
}

.close-closeup-button:hover {
  background: var(--color-primary-hover);
}

/* 改写相关弹窗样式 */
.rewrite-result-dialog {
  max-width: 800px;
}

.rewrite-result-content {
  background: var(--color-surface-secondary);
  border-radius: 8px;
  padding: 20px;
  margin-bottom: 16px;
  font-size: 16px;
  line-height: 1.8;
  color: var(--color-text-primary);
  white-space: pre-wrap;
  word-wrap: break-word;
  min-height: 200px;
  max-height: 400px;
  overflow-y: auto;
}

.rewrite-note {
  display: flex;
  align-items: center;
  gap: 8px;
  background: #e7f3ff;
  border: 1px solid #b3d7ff;
  border-radius: 6px;
  padding: 8px 12px;
  font-size: 12px;
  color: #0066cc;
}

.rewrite-button {
  background: #17a2b8;
  color: white;
  border: none;
  border-radius: 8px;
  padding: 10px 20px;
  font-size: 14px;
  font-weight: 500;
  cursor: pointer;
  transition: all 0.2s;
}

.rewrite-button:hover:not(:disabled) {
  background: #138496;
}

.rewrite-button:disabled {
  background: #dee2e6;
  color: var(--color-text-secondary);
  cursor: not-allowed;
}

.replace-button {
  background: #28a745;
  color: white;
  border: none;
  border-radius: 8px;
  padding: 10px 20px;
  font-size: 14px;
  font-weight: 500;
  cursor: pointer;
  transition: all 0.2s;
}

.replace-button:hover:not(:disabled) {
  background: #218838;
}

.replace-button:disabled {
  background: #dee2e6;
  color: var(--color-text-secondary);
  cursor: not-allowed;
}

.close-result-button {
  background: var(--color-primary);
  color: white;
  border: none;
  border-radius: 8px;
  padding: 10px 20px;
  font-size: 14px;
  font-weight: 500;
  cursor: pointer;
  transition: all 0.2s;
}

.close-result-button:hover {
  background: var(--color-primary-hover);
}

.confirm-button {
  background: #28a745;
  color: white;
  border: none;
  border-radius: 8px;
  padding: 10px 20px;
  font-size: 14px;
  font-weight: 500;
  cursor: pointer;
  transition: all 0.2s;
}

.confirm-button:hover:not(:disabled) {
  background: #218838;
}

.confirm-button:disabled {
  background: #dee2e6;
  color: var(--color-text-secondary);
  cursor: not-allowed;
}

@media (max-width: 768px) {
  .writing-content {
    padding: 12px;
  }

  .input-actions {
    flex-direction: column;
    align-items: stretch;
    gap: 12px;
  }

  .validation-info {
    order: 2;
  }

  .action-buttons {
    order: 1;
    flex-direction: column;
  }

  .closeup-toggle,
  .character-selector-toggle,
  .send-button {
    width: 100%;
  }

  .closeup-dialog {
    max-width: 90vw;
  }

  .closeup-content {
    font-size: 14px;
    padding: 16px;
  }

  /* 移动端浮动按钮适配 */
  .floating-closeup-toggle {
    bottom: 80px;
    right: 16px;
    width: 48px;
    height: 48px;
    font-size: 20px;
  }

  .floating-rewrite-button {
    bottom: 80px;
    right: 72px;
    height: 48px;
    padding: 0 16px;
    font-size: 14px;
  }

  .floating-rewrite-button .rewrite-icon {
    font-size: 18px;
  }

  .rewrite-result-dialog {
    max-width: 90vw;
  }

  .rewrite-result-content {
    font-size: 14px;
    padding: 16px;
    min-height: 150px;
  }
}
</style>