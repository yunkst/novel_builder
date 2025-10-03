<script setup lang="ts">
import { ref, computed, onMounted } from 'vue'
import { useRouter } from 'vue-router'
import { useAppStore } from '@/stores/app'
import { difyApi } from '@/services/difyApi'

const props = defineProps<{
  id: string
}>()

const appStore = useAppStore()
const router = useRouter()

const novel = computed(() => appStore.novels.find(n => n.id === props.id))
const chapters = computed(() => appStore.currentNovelChapters)

const showNewChapterDialog = ref(false)
const newChapterTitle = ref('')
const showEditDialog = ref(false)
const editTitle = ref('')
const editSummary = ref('')

const showGenerateDialog = ref(false)
const generatePrompt = ref('')
const generateType = ref<'chapter' | 'content'>('chapter')
const isGenerating = ref(false)

onMounted(() => {
  if (novel.value) {
    appStore.setCurrentNovel(novel.value)
  } else {
    router.push('/')
  }
})

function createNewChapter() {
  if (!newChapterTitle.value.trim() || !novel.value) return

  const chapter = appStore.createChapter(novel.value.id, newChapterTitle.value)
  showNewChapterDialog.value = false
  newChapterTitle.value = ''
  router.push(`/novel/${novel.value.id}/chapter/${chapter.id}`)
}

function openChapter(chapterId: string) {
  router.push(`/novel/${props.id}/chapter/${chapterId}`)
}

function openEditDialog() {
  if (!novel.value) return
  editTitle.value = novel.value.title
  editSummary.value = novel.value.summary || ''
  showEditDialog.value = true
}

function saveNovelInfo() {
  if (!novel.value || !editTitle.value.trim()) return

  appStore.updateNovel(novel.value.id, {
    title: editTitle.value,
    summary: editSummary.value
  })
  showEditDialog.value = false
}

function deleteNovel() {
  if (!novel.value) return
  if (!confirm(`确定要删除小说《${novel.value.title}》吗？此操作不可恢复。`)) return

  appStore.deleteNovel(novel.value.id)
  router.push('/')
}

async function generateContent() {
  if (!novel.value || !generatePrompt.value.trim()) return

  isGenerating.value = true
  appStore.setLoading(true)

  try {
    difyApi.updateConfig(appStore.difyConfig)

    const response = await difyApi.runWorkflow({
      inputs: {
        novel_title: novel.value.title,
        novel_summary: novel.value.summary || '',
        prompt: generatePrompt.value,
        type: generateType.value
      },
      response_mode: 'blocking',
      user: `novel_${novel.value.id}`
    })

    if (response.data.outputs?.content) {
      if (generateType.value === 'chapter') {
        // 创建新章节
        const chapter = appStore.createChapter(
          novel.value.id,
          response.data.outputs.title || `第${chapters.value.length + 1}章`
        )
        appStore.updateChapter(chapter.id, {
          content: response.data.outputs.content
        })
        router.push(`/novel/${novel.value.id}/chapter/${chapter.id}`)
      } else {
        // 更新小说内容
        appStore.updateNovel(novel.value.id, {
          content: response.data.outputs.content
        })
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
  <div v-if="novel" class="novel-view">
    <div class="novel-header">
      <div class="back-nav">
        <router-link to="/" class="back-button">
          <span class="back-icon">←</span>
          返回
        </router-link>
      </div>

      <div class="novel-info">
        <h1 class="novel-title">{{ novel.title }}</h1>
        <p v-if="novel.summary" class="novel-summary">{{ novel.summary }}</p>
        <div class="novel-meta">
          <span>创建于 {{ formatDate(novel.createdAt) }}</span>
          <span v-if="novel.updatedAt !== novel.createdAt">
            · 更新于 {{ formatDate(novel.updatedAt) }}
          </span>
          <span>· {{ chapters.length }} 章节</span>
        </div>
      </div>

      <div class="novel-actions">
        <button @click="openEditDialog" class="action-button edit-button">
          <span class="action-icon">✏️</span>
          编辑
        </button>
        <button @click="showGenerateDialog = true" class="action-button generate-button" :disabled="!appStore.isConfigured">
          <span class="action-icon">🤖</span>
          AI生成
        </button>
        <button @click="deleteNovel" class="action-button delete-button">
          <span class="action-icon">🗑️</span>
          删除
        </button>
      </div>
    </div>

    <!-- 章节列表 -->
    <div class="chapters-section">
      <div class="section-header">
        <h2>章节列表</h2>
        <button @click="showNewChapterDialog = true" class="new-chapter-button">
          <span class="plus-icon">+</span>
          新建章节
        </button>
      </div>

      <div v-if="chapters.length === 0" class="empty-chapters">
        <div class="empty-icon">📝</div>
        <h3>还没有章节</h3>
        <p>点击新建章节开始写作</p>
      </div>

      <div v-else class="chapters-list">
        <div
          v-for="chapter in chapters"
          :key="chapter.id"
          @click="openChapter(chapter.id)"
          class="chapter-card"
        >
          <div class="chapter-content">
            <h3 class="chapter-title">{{ chapter.title }}</h3>
            <div class="chapter-meta">
              <span>第 {{ chapter.order }} 章</span>
              <span>· {{ formatDate(chapter.updatedAt) }}</span>
              <span v-if="chapter.content">· {{ Math.ceil(chapter.content.length / 500) }} 千字</span>
            </div>
          </div>
          <div class="chapter-arrow">→</div>
        </div>
      </div>
    </div>

    <!-- 新建章节对话框 -->
    <div v-if="showNewChapterDialog" class="dialog-overlay" @click="showNewChapterDialog = false">
      <div class="dialog" @click.stop>
        <div class="dialog-header">
          <h3>新建章节</h3>
          <button @click="showNewChapterDialog = false" class="close-button">×</button>
        </div>
        <div class="dialog-body">
          <div class="form-group">
            <label>章节标题</label>
            <input
              v-model="newChapterTitle"
              type="text"
              placeholder="输入章节标题"
              maxlength="100"
              @keyup.enter="createNewChapter"
            />
          </div>
        </div>
        <div class="dialog-footer">
          <button @click="showNewChapterDialog = false" class="cancel-button">取消</button>
          <button @click="createNewChapter" :disabled="!newChapterTitle.trim()" class="create-button">创建</button>
        </div>
      </div>
    </div>

    <!-- 编辑小说对话框 -->
    <div v-if="showEditDialog" class="dialog-overlay" @click="showEditDialog = false">
      <div class="dialog" @click.stop>
        <div class="dialog-header">
          <h3>编辑小说信息</h3>
          <button @click="showEditDialog = false" class="close-button">×</button>
        </div>
        <div class="dialog-body">
          <div class="form-group">
            <label>标题</label>
            <input
              v-model="editTitle"
              type="text"
              placeholder="输入小说标题"
              maxlength="50"
            />
          </div>
          <div class="form-group">
            <label>简介</label>
            <textarea
              v-model="editSummary"
              placeholder="输入小说简介"
              rows="4"
              maxlength="300"
            ></textarea>
          </div>
        </div>
        <div class="dialog-footer">
          <button @click="showEditDialog = false" class="cancel-button">取消</button>
          <button @click="saveNovelInfo" :disabled="!editTitle.trim()" class="save-button">保存</button>
        </div>
      </div>
    </div>

    <!-- AI生成对话框 -->
    <div v-if="showGenerateDialog" class="dialog-overlay" @click="showGenerateDialog = false">
      <div class="dialog large-dialog" @click.stop>
        <div class="dialog-header">
          <h3>AI 内容生成</h3>
          <button @click="showGenerateDialog = false" class="close-button">×</button>
        </div>
        <div class="dialog-body">
          <div class="form-group">
            <label>生成类型</label>
            <div class="radio-group">
              <label class="radio-option">
                <input type="radio" v-model="generateType" value="chapter" />
                <span>生成新章节</span>
              </label>
              <label class="radio-option">
                <input type="radio" v-model="generateType" value="content" />
                <span>生成小说大纲</span>
              </label>
            </div>
          </div>
          <div class="form-group">
            <label>创作提示</label>
            <textarea
              v-model="generatePrompt"
              placeholder="描述你想要的内容，比如：情节发展、人物关系、场景描述等"
              rows="5"
              maxlength="500"
            ></textarea>
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
.novel-view {
  min-height: calc(100vh - 56px);
  padding: 16px;
  background: var(--color-surface-secondary);
}

.novel-header {
  background: var(--color-surface);
  border-radius: 12px;
  padding: 20px;
  margin-bottom: 20px;
  box-shadow: 0 1px 3px rgba(0, 0, 0, 0.1);
}

.back-nav {
  margin-bottom: 16px;
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

.novel-info {
  margin-bottom: 20px;
}

.novel-title {
  margin: 0 0 8px 0;
  font-size: 24px;
  font-weight: 600;
  color: #333;
  line-height: 1.3;
}

.novel-summary {
  margin: 0 0 12px 0;
  font-size: 16px;
  color: var(--color-text-secondary);
  line-height: 1.5;
}

.novel-meta {
  font-size: 14px;
  color: var(--color-text-secondary);
}

.novel-actions {
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

.chapters-section {
  background: var(--color-surface);
  border-radius: 12px;
  overflow: hidden;
  box-shadow: 0 1px 3px rgba(0, 0, 0, 0.1);
}

.section-header {
  display: flex;
  justify-content: space-between;
  align-items: center;
  padding: 20px;
  border-bottom: 1px solid #e9ecef;
}

.section-header h2 {
  margin: 0;
  font-size: 20px;
  font-weight: 600;
  color: #333;
}

.new-chapter-button {
  display: flex;
  align-items: center;
  gap: 6px;
  background: #007bff;
  color: white;
  border: none;
  border-radius: 8px;
  padding: 8px 16px;
  font-size: 14px;
  font-weight: 500;
  cursor: pointer;
  transition: background-color 0.2s;
}

.new-chapter-button:hover {
  background: #0056b3;
}

.plus-icon {
  font-size: 18px;
  line-height: 1;
}

.empty-chapters {
  text-align: center;
  padding: 60px 20px;
  color: var(--color-text-secondary);
}

.empty-icon {
  font-size: 48px;
  margin-bottom: 16px;
}

.empty-chapters h3 {
  margin: 0 0 8px 0;
  font-size: 18px;
  font-weight: 600;
}

.empty-chapters p {
  margin: 0;
  font-size: 14px;
}

.chapters-list {
  divide-y: 1px solid #e9ecef;
}

.chapter-card {
  display: flex;
  align-items: center;
  padding: 16px 20px;
  cursor: pointer;
  transition: background-color 0.2s;
  border-bottom: 1px solid #e9ecef;
}

.chapter-card:hover {
  background: var(--color-surface-secondary);
}

.chapter-card:last-child {
  border-bottom: none;
}

.chapter-content {
  flex: 1;
  min-width: 0;
}

.chapter-title {
  margin: 0 0 6px 0;
  font-size: 16px;
  font-weight: 600;
  color: #333;
  line-height: 1.4;
}

.chapter-meta {
  font-size: 14px;
  color: var(--color-text-secondary);
}

.chapter-arrow {
  font-size: 16px;
  color: #dee2e6;
  margin-left: 12px;
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
  margin-bottom: 6px;
  font-size: 14px;
  font-weight: 500;
  color: #333;
}

.form-group input,
.form-group textarea {
  width: 100%;
  padding: 12px;
  border: 1px solid #dee2e6;
  border-radius: 8px;
  font-size: 14px;
  box-sizing: border-box;
  transition: border-color 0.2s;
}

.form-group input:focus,
.form-group textarea:focus {
  outline: none;
  border-color: #007bff;
  box-shadow: 0 0 0 3px rgba(0, 123, 255, 0.1);
}

.form-group textarea {
  resize: vertical;
  min-height: 60px;
}

.radio-group {
  display: flex;
  gap: 16px;
}

.radio-option {
  display: flex;
  align-items: center;
  gap: 6px;
  cursor: pointer;
  font-size: 14px;
}

.radio-option input[type="radio"] {
  width: auto;
  margin: 0;
}

.dialog-footer {
  display: flex;
  gap: 12px;
  padding: 20px;
  border-top: 1px solid var(--color-divider);
  justify-content: flex-end;
}

.cancel-button,
.create-button,
.save-button,
.generate-submit-button {
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
  color: #333;
}

.create-button,
.save-button {
  background: #007bff;
  color: white;
}

.create-button:hover:not(:disabled),
.save-button:hover:not(:disabled) {
  background: #0056b3;
}

.generate-submit-button {
  background: #28a745;
  color: white;
}

.generate-submit-button:hover:not(:disabled) {
  background: #218838;
}

.create-button:disabled,
.save-button:disabled,
.generate-submit-button:disabled {
  background: #dee2e6;
  color: var(--color-text-secondary);
  cursor: not-allowed;
}

@media (max-width: 768px) {
  .novel-view {
    padding: 12px;
  }

  .novel-header {
    padding: 16px;
  }

  .novel-actions {
    gap: 6px;
  }

  .action-button {
    padding: 6px 12px;
    font-size: 13px;
  }

  .radio-group {
    flex-direction: column;
    gap: 12px;
  }
}
</style>