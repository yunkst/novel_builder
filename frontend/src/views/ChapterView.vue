<script setup lang="ts">
import { ref, computed, onMounted, nextTick, watch } from 'vue'
import { useRouter } from 'vue-router'
import { useAppStore } from '@/stores/app'
import { difyApi } from '@/services/difyApi'

const props = defineProps<{
  novelId: string
  chapterId: string
}>()

const appStore = useAppStore()
const router = useRouter()

const novel = computed(() => appStore.novels.find(n => n.id === props.novelId))
const chapter = computed(() => appStore.chapters.find(c => c.id === props.chapterId))

const isEditing = ref(false)
const chapterTitle = ref('')
const chapterContent = ref('')
const showGenerateDialog = ref(false)
const generatePrompt = ref('')
const isGenerating = ref(false)
const isSaving = ref(false)

const textarea = ref<HTMLTextAreaElement>()

const wordCount = computed(() => {
  return chapterContent.value.length
})

const estimatedReadTime = computed(() => {
  const wordsPerMinute = 300
  const minutes = Math.ceil(wordCount.value / wordsPerMinute)
  return minutes < 1 ? '< 1' : minutes.toString()
})

watch(() => props.chapterId, () => {
  loadChapter()
}, { immediate: true })

onMounted(() => {
  if (!novel.value || !chapter.value) {
    router.push('/')
    return
  }

  appStore.setCurrentNovel(novel.value)
  appStore.setCurrentChapter(chapter.value)
  loadChapter()
})

function loadChapter() {
  if (chapter.value) {
    chapterTitle.value = chapter.value.title
    chapterContent.value = chapter.value.content
  }
}

function startEdit() {
  isEditing.value = true
  nextTick(() => {
    textarea.value?.focus()
  })
}

async function saveChapter() {
  if (!chapter.value) return

  isSaving.value = true
  try {
    appStore.updateChapter(chapter.value.id, {
      title: chapterTitle.value,
      content: chapterContent.value
    })
    isEditing.value = false
  } finally {
    isSaving.value = false
  }
}

function cancelEdit() {
  loadChapter()
  isEditing.value = false
}

function deleteChapter() {
  if (!chapter.value || !novel.value) return
  if (!confirm(`确定要删除章节《${chapter.value.title}》吗？此操作不可恢复。`)) return

  appStore.deleteChapter(chapter.value.id)
  router.push(`/novel/${novel.value.id}`)
}

async function generateContent() {
  if (!novel.value || !chapter.value || !generatePrompt.value.trim()) return

  isGenerating.value = true
  appStore.setLoading(true)

  try {
    difyApi.updateConfig(appStore.difyConfig)

    const response = await difyApi.runWorkflow({
      inputs: {
        novel_title: novel.value.title,
        novel_summary: novel.value.summary || '',
        chapter_title: chapter.value.title,
        current_content: chapterContent.value,
        prompt: generatePrompt.value
      },
      response_mode: 'blocking',
      user: `chapter_${chapter.value.id}`
    })

    if (response.data.outputs?.content) {
      chapterContent.value = response.data.outputs.content
      if (!isEditing.value) {
        startEdit()
      }
    }

    showGenerateDialog.value = false
    generatePrompt.value = ''
  } catch (error) {
    appStore.setError(error instanceof Error ? error.message : '生成失败')
  } finally {
    isGenerating.value = false
    appStore.setLoading(false)
  }
}

function insertAtCursor(text: string) {
  if (!textarea.value) return

  const start = textarea.value.selectionStart
  const end = textarea.value.selectionEnd
  const before = chapterContent.value.substring(0, start)
  const after = chapterContent.value.substring(end)

  chapterContent.value = before + text + after

  nextTick(() => {
    if (textarea.value) {
      const newPosition = start + text.length
      textarea.value.setSelectionRange(newPosition, newPosition)
      textarea.value.focus()
    }
  })
}

function adjustTextareaHeight() {
  if (textarea.value) {
    textarea.value.style.height = 'auto'
    textarea.value.style.height = textarea.value.scrollHeight + 'px'
  }
}

watch(chapterContent, () => {
  nextTick(adjustTextareaHeight)
})

function formatDate(timestamp: number) {
  return new Date(timestamp).toLocaleDateString('zh-CN', {
    year: 'numeric',
    month: 'short',
    day: 'numeric',
    hour: '2-digit',
    minute: '2-digit'
  })
}
</script>

<template>
  <div v-if="novel && chapter" class="chapter-view">
    <div class="chapter-header">
      <div class="back-nav">
        <router-link :to="`/novel/${novel.id}`" class="back-button">
          <span class="back-icon">←</span>
          {{ novel.title }}
        </router-link>
      </div>

      <div class="chapter-info">
        <div class="chapter-title-section">
          <input
            v-if="isEditing"
            v-model="chapterTitle"
            class="chapter-title-input"
            placeholder="章节标题"
            maxlength="100"
          />
          <h1 v-else class="chapter-title">{{ chapter.title }}</h1>
        </div>

        <div class="chapter-meta">
          <span>第 {{ chapter.order }} 章</span>
          <span>· {{ wordCount }} 字</span>
          <span>· 约 {{ estimatedReadTime }} 分钟阅读</span>
          <span v-if="chapter.updatedAt">· {{ formatDate(chapter.updatedAt) }}</span>
        </div>
      </div>

      <div class="chapter-actions">
        <template v-if="isEditing">
          <button @click="saveChapter" :disabled="isSaving" class="action-button save-button">
            {{ isSaving ? '保存中...' : '保存' }}
          </button>
          <button @click="cancelEdit" class="action-button cancel-button">
            取消
          </button>
        </template>
        <template v-else>
          <button @click="startEdit" class="action-button edit-button">
            <span class="action-icon">✏️</span>
            编辑
          </button>
          <button @click="showGenerateDialog = true" class="action-button generate-button" :disabled="!appStore.isConfigured">
            <span class="action-icon">🤖</span>
            AI续写
          </button>
          <button @click="deleteChapter" class="action-button delete-button">
            <span class="action-icon">🗑️</span>
            删除
          </button>
        </template>
      </div>
    </div>

    <!-- 内容区域 -->
    <div class="chapter-content-section">
      <div v-if="isEditing" class="editor-container">
        <div class="editor-toolbar">
          <div class="toolbar-left">
            <span class="word-counter">{{ wordCount }} 字</span>
          </div>
          <div class="toolbar-right">
            <button @click="insertAtCursor('【')" class="toolbar-button">【】</button>
            <button @click="insertAtCursor('「')" class="toolbar-button">「」</button>
            <button @click="insertAtCursor('（')" class="toolbar-button">（）</button>
          </div>
        </div>

        <textarea
          ref="textarea"
          v-model="chapterContent"
          class="content-editor"
          placeholder="开始写作..."
          @input="adjustTextareaHeight"
        ></textarea>
      </div>

      <div v-else class="content-viewer">
        <div v-if="!chapter.content" class="empty-content">
          <div class="empty-icon">📝</div>
          <h3>还没有内容</h3>
          <p>点击编辑开始写作，或使用 AI 生成内容</p>
        </div>
        <div v-else class="content-text">
          {{ chapter.content }}
        </div>
      </div>
    </div>

    <!-- AI 生成对话框 -->
    <div v-if="showGenerateDialog" class="dialog-overlay" @click="showGenerateDialog = false">
      <div class="dialog large-dialog" @click.stop>
        <div class="dialog-header">
          <h3>AI 内容生成</h3>
          <button @click="showGenerateDialog = false" class="close-button">×</button>
        </div>
        <div class="dialog-body">
          <div class="form-group">
            <label>创作提示</label>
            <textarea
              v-model="generatePrompt"
              placeholder="描述你想要的内容，比如：
• 故事情节发展方向
• 人物对话和互动
• 场景描述要求
• 情感表达重点
等等..."
              rows="6"
              maxlength="500"
            ></textarea>
            <div class="help-text">
              AI 会根据小说标题、简介和当前章节内容来生成相关内容
            </div>
          </div>
        </div>
        <div class="dialog-footer">
          <button @click="showGenerateDialog = false" class="cancel-button">取消</button>
          <button @click="generateContent" :disabled="!generatePrompt.trim() || isGenerating" class="generate-submit-button">
            {{ isGenerating ? '生成中...' : '开始生成' }}
          </button>
        </div>
      </div>
    </div>
  </div>
</template>

<style scoped>
.chapter-view {
  min-height: calc(100vh - 56px);
  display: flex;
  flex-direction: column;
  background: var(--color-surface-secondary);
}

.chapter-header {
  background: var(--color-surface);
  border-bottom: 1px solid #e9ecef;
  padding: 16px;
  flex-shrink: 0;
}

.back-nav {
  margin-bottom: 12px;
}

.back-button {
  display: inline-flex;
  align-items: center;
  gap: 6px;
  color: var(--color-text-secondary);
  text-decoration: none;
  font-size: 14px;
  font-weight: 500;
  transition: color 0.2s;
}

.back-button:hover {
  color: #333;
}

.back-icon {
  font-size: 16px;
}

.chapter-info {
  margin-bottom: 16px;
}

.chapter-title-section {
  margin-bottom: 8px;
}

.chapter-title {
  margin: 0;
  font-size: 24px;
  font-weight: 600;
  color: #333;
  line-height: 1.3;
}

.chapter-title-input {
  width: 100%;
  padding: 8px 0;
  border: none;
  border-bottom: 2px solid #007bff;
  font-size: 24px;
  font-weight: 600;
  color: #333;
  background: transparent;
  outline: none;
  line-height: 1.3;
}

.chapter-meta {
  font-size: 14px;
  color: var(--color-text-secondary);
}

.chapter-actions {
  display: flex;
  gap: 8px;
  flex-wrap: wrap;
}

.action-button {
  display: flex;
  align-items: center;
  gap: 6px;
  padding: 8px 16px;
  border: none;
  border-radius: 8px;
  font-size: 14px;
  font-weight: 500;
  cursor: pointer;
  transition: all 0.2s;
}

.edit-button {
  background: var(--color-hover-background);
  color: var(--color-text-medium);
}

.edit-button:hover {
  background: #dee2e6;
}

.generate-button {
  background: #28a745;
  color: white;
}

.generate-button:hover:not(:disabled) {
  background: #218838;
}

.generate-button:disabled {
  background: #dee2e6;
  color: var(--color-text-secondary);
  cursor: not-allowed;
}

.save-button {
  background: #007bff;
  color: white;
}

.save-button:hover:not(:disabled) {
  background: #0056b3;
}

.save-button:disabled {
  background: #dee2e6;
  color: var(--color-text-secondary);
  cursor: not-allowed;
}

.cancel-button {
  background: var(--color-surface-secondary);
  color: var(--color-text-secondary);
}

.cancel-button:hover {
  background: var(--color-hover-background);
  color: #333;
}

.delete-button {
  background: #dc3545;
  color: white;
}

.delete-button:hover {
  background: #c82333;
}

.action-icon {
  font-size: 14px;
}

.chapter-content-section {
  flex: 1;
  display: flex;
  flex-direction: column;
  min-height: 0;
}

.editor-container {
  flex: 1;
  display: flex;
  flex-direction: column;
  background: var(--color-surface);
  margin: 16px;
  border-radius: 12px;
  overflow: hidden;
  box-shadow: 0 1px 3px rgba(0, 0, 0, 0.1);
}

.editor-toolbar {
  display: flex;
  justify-content: space-between;
  align-items: center;
  padding: 12px 16px;
  border-bottom: 1px solid #e9ecef;
  background: var(--color-surface-secondary);
}

.toolbar-left {
  font-size: 14px;
  color: var(--color-text-secondary);
}

.toolbar-right {
  display: flex;
  gap: 8px;
}

.toolbar-button {
  padding: 4px 8px;
  border: 1px solid #dee2e6;
  border-radius: 4px;
  background: var(--color-surface);
  font-size: 12px;
  cursor: pointer;
  transition: all 0.2s;
}

.toolbar-button:hover {
  background: var(--color-hover-background);
}

.content-editor {
  flex: 1;
  padding: 20px;
  border: none;
  outline: none;
  font-size: 16px;
  line-height: 1.8;
  font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', 'PingFang SC', 'Hiragino Sans GB', 'Microsoft YaHei', sans-serif;
  resize: none;
  min-height: 400px;
  overflow-y: auto;
}

.content-viewer {
  flex: 1;
  background: var(--color-surface);
  margin: 16px;
  border-radius: 12px;
  box-shadow: 0 1px 3px rgba(0, 0, 0, 0.1);
  display: flex;
  flex-direction: column;
}

.empty-content {
  flex: 1;
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  padding: 60px 20px;
  color: var(--color-text-secondary);
  text-align: center;
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

.content-text {
  flex: 1;
  padding: 24px;
  font-size: 18px;
  line-height: 2;
  color: #333;
  white-space: pre-wrap;
  word-wrap: break-word;
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
  max-width: 500px;
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
  color: #333;
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
  color: #333;
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
  font-size: 16px;
  font-weight: 500;
  color: #333;
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
  border-color: #007bff;
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

.generate-submit-button {
  padding: 10px 20px;
  border-radius: 8px;
  font-size: 14px;
  font-weight: 500;
  cursor: pointer;
  transition: all 0.2s;
  border: none;
  background: #28a745;
  color: white;
}

.generate-submit-button:hover:not(:disabled) {
  background: #218838;
}

.generate-submit-button:disabled {
  background: #dee2e6;
  color: var(--color-text-secondary);
  cursor: not-allowed;
}

@media (max-width: 768px) {
  .chapter-header {
    padding: 12px;
  }

  .chapter-actions {
    gap: 6px;
  }

  .action-button {
    padding: 6px 12px;
    font-size: 13px;
  }

  .editor-container,
  .content-viewer {
    margin: 12px;
  }

  .content-editor {
    padding: 16px;
    font-size: 15px;
  }

  .content-text {
    padding: 20px;
    font-size: 16px;
    line-height: 1.8;
  }
}
</style>