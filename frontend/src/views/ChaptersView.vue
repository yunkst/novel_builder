<script setup lang="ts">
import { ref, computed, onMounted } from 'vue'
import { useRouter } from 'vue-router'
import { useAppStore } from '@/stores/app'

const props = defineProps<{
  novelId: string
}>()

const appStore = useAppStore()
const router = useRouter()

const novel = computed(() => appStore.currentNovel)
const chapters = computed(() => appStore.currentNovelChapters)

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
})

function editChapter(chapterId: string) {
  // 开始编辑章节，设置临时编辑状态
  appStore.startEditingChapter(chapterId)
  router.push(`/writing/${props.novelId}`)
}

function createNewChapter() {
  if (!novel.value) return

  // 创建新章节
  const newChapter = appStore.createChapter(
    novel.value.id,
    `第${chapters.value.length + 1}章`,
    '描述本章的故事情节和发展'
  )

  // 进入新章节编辑
  appStore.writingSession.currentChapterId = newChapter.id
  router.push(`/writing/${props.novelId}`)
}

function deleteChapter(chapterId: string) {
  const chapter = chapters.value.find(c => c.id === chapterId)
  if (chapter && confirm(`确定要删除《${chapter.title}》吗？此操作不可恢复。`)) {
    appStore.deleteChapter(chapterId)
  }
}

function goBack() {
  router.push('/')
}

function goToCharacters() {
  router.push(`/characters/${props.novelId}`)
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

function getWordCount(content: string): number {
  return content.length
}
</script>

<template>
  <div v-if="novel" class="chapters-view">
    <!-- 头部导航 -->
    <div class="chapters-header">
      <div class="header-left">
        <button @click="goBack" class="back-button">
          <span class="back-icon">←</span>
          返回
        </button>
        <div class="novel-info">
          <h2 class="novel-title">{{ novel.title }}</h2>
          <span class="chapters-count">{{ chapters.length }} 章节</span>
        </div>
      </div>

      <div class="header-actions">
        <button @click="goToCharacters" class="characters-button">
          👤 人物
        </button>
        <button @click="createNewChapter" class="new-chapter-button">
          <span class="plus-icon">+</span>
          新章节
        </button>
      </div>
    </div>

    <!-- 章节列表 -->
    <div class="chapters-content">
      <div v-if="chapters.length === 0" class="empty-chapters">
        <div class="empty-icon">📝</div>
        <h3>还没有章节</h3>
        <p>点击新建章节开始创作</p>
        <button @click="createNewChapter" class="create-first-chapter-button">
          创建第一章
        </button>
      </div>

      <div v-else class="chapters-list">
        <div
          v-for="chapter in chapters"
          :key="chapter.id"
          class="chapter-card"
        >
          <div class="chapter-content" @click="editChapter(chapter.id)">
            <div class="chapter-header">
              <h3 class="chapter-title">{{ chapter.title }}</h3>
              <span class="chapter-order">第 {{ chapter.order }} 章</span>
            </div>

            <div class="chapter-preview" v-if="chapter.content">
              {{ chapter.content.substring(0, 120) }}{{ chapter.content.length > 120 ? '...' : '' }}
            </div>
            <div v-else class="chapter-empty">
              <span class="empty-text">空章节</span>
            </div>

            <div class="chapter-meta">
              <span class="chapter-words">{{ getWordCount(chapter.content) }} 字</span>
              <span class="chapter-date">{{ formatDate(chapter.updatedAt) }}</span>
            </div>
          </div>

          <div class="chapter-actions">
            <button @click="editChapter(chapter.id)" class="action-btn primary">
              编辑
            </button>
            <button @click="deleteChapter(chapter.id)" class="action-btn danger">
              删除
            </button>
          </div>
        </div>
      </div>
    </div>
  </div>
</template>

<style scoped>
.chapters-view {
  min-height: calc(100vh - 56px);
  display: flex;
  flex-direction: column;
  background: var(--color-surface-secondary);
}

.chapters-header {
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
  color: #333;
}

.back-icon {
  font-size: 16px;
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
  color: #333;
}

.chapters-count {
  font-size: 12px;
  color: var(--color-text-secondary);
}

.header-actions {
  display: flex;
  gap: 8px;
}

.characters-button {
  display: flex;
  align-items: center;
  gap: 6px;
  background: var(--color-info);
  color: white;
  border: none;
  border-radius: 6px;
  padding: 8px 16px;
  font-size: 14px;
  font-weight: 500;
  cursor: pointer;
  transition: background-color 0.2s;
}

.characters-button:hover {
  opacity: 0.9;
}

.new-chapter-button {
  display: flex;
  align-items: center;
  gap: 6px;
  background: #007bff;
  color: white;
  border: none;
  border-radius: 6px;
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
  font-size: 16px;
  line-height: 1;
}

.chapters-content {
  flex: 1;
  padding: 16px;
  overflow-y: auto;
}

.empty-chapters {
  text-align: center;
  padding: 60px 20px;
  color: var(--color-text-secondary);
  background: var(--color-surface);
  border-radius: 12px;
  box-shadow: 0 1px 3px rgba(0, 0, 0, 0.1);
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
  margin: 0 0 20px 0;
  font-size: 14px;
}

.create-first-chapter-button {
  background: #007bff;
  color: white;
  border: none;
  border-radius: 8px;
  padding: 12px 24px;
  font-size: 16px;
  font-weight: 500;
  cursor: pointer;
  transition: background-color 0.2s;
}

.create-first-chapter-button:hover {
  background: #0056b3;
}

.chapters-list {
  display: flex;
  flex-direction: column;
  gap: 12px;
}

.chapter-card {
  background: var(--color-surface);
  border-radius: 12px;
  padding: 16px;
  box-shadow: 0 1px 3px rgba(0, 0, 0, 0.1);
  display: flex;
  align-items: center;
  gap: 16px;
  transition: all 0.2s;
}

.chapter-card:hover {
  box-shadow: 0 2px 8px rgba(0, 0, 0, 0.15);
}

.chapter-content {
  flex: 1;
  min-width: 0;
  cursor: pointer;
}

.chapter-header {
  display: flex;
  justify-content: space-between;
  align-items: center;
  margin-bottom: 8px;
}

.chapter-title {
  margin: 0;
  font-size: 16px;
  font-weight: 600;
  color: #333;
}

.chapter-order {
  font-size: 12px;
  color: var(--color-text-secondary);
  background: var(--color-surface-secondary);
  padding: 2px 8px;
  border-radius: 4px;
}

.chapter-preview {
  margin-bottom: 8px;
  font-size: 14px;
  color: var(--color-text-medium);
  line-height: 1.5;
}

.chapter-empty {
  margin-bottom: 8px;
  padding: 8px 0;
}

.empty-text {
  font-size: 14px;
  color: var(--color-text-secondary);
  font-style: italic;
}

.chapter-meta {
  display: flex;
  gap: 12px;
  font-size: 12px;
  color: var(--color-text-secondary);
}

.chapter-actions {
  display: flex;
  gap: 8px;
}

.action-btn {
  padding: 6px 12px;
  border: none;
  border-radius: 6px;
  font-size: 12px;
  font-weight: 500;
  cursor: pointer;
  transition: all 0.2s;
}

.action-btn.primary {
  background: #007bff;
  color: white;
}

.action-btn.primary:hover {
  background: #0056b3;
}

.action-btn.danger {
  background: #dc3545;
  color: white;
}

.action-btn.danger:hover {
  background: #c82333;
}

@media (max-width: 768px) {
  .chapters-content {
    padding: 12px;
  }

  .chapter-card {
    flex-direction: column;
    align-items: stretch;
    gap: 12px;
  }

  .chapter-actions {
    justify-content: flex-end;
  }

  .chapters-header {
    padding: 12px;
  }

  .header-left {
    gap: 8px;
  }
}
</style>