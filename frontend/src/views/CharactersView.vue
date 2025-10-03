<script setup lang="ts">
import { ref, computed, onMounted } from 'vue'
import { useRouter } from 'vue-router'
import { useAppStore } from '@/stores/app'
import type { Character } from '@/stores/app'

const props = defineProps<{
  novelId: string
}>()

const appStore = useAppStore()
const router = useRouter()

const showCreateDialog = ref(false)
const showEditDialog = ref(false)
const editingCharacter = ref<Character | null>(null)

const newCharacterName = ref('')
const newCharacterDescription = ref('')

const novel = computed(() => appStore.novels.find(n => n.id === props.novelId))
const characters = computed(() => appStore.currentNovelCharacters)

onMounted(() => {
  appStore.loadAllData()

  // 如果当前小说不匹配，重新设置
  if (!novel.value) {
    router.push('/')
    return
  }

  // 设置当前小说
  appStore.setCurrentNovel(novel.value)
})

function openCreateDialog() {
  newCharacterName.value = ''
  newCharacterDescription.value = ''
  showCreateDialog.value = true
}

function createCharacter() {
  if (!newCharacterName.value.trim() || !newCharacterDescription.value.trim()) return

  appStore.createCharacter(props.novelId, newCharacterName.value, newCharacterDescription.value)
  showCreateDialog.value = false
}

function openEditDialog(character: Character) {
  editingCharacter.value = character
  newCharacterName.value = character.name
  newCharacterDescription.value = character.description
  showEditDialog.value = true
}

function updateCharacter() {
  if (!editingCharacter.value || !newCharacterName.value.trim() || !newCharacterDescription.value.trim()) return

  appStore.updateCharacter(editingCharacter.value.id, {
    name: newCharacterName.value,
    description: newCharacterDescription.value
  })
  showEditDialog.value = false
  editingCharacter.value = null
}

function deleteCharacter(character: Character) {
  if (confirm(`确定要删除人物《${character.name}》吗？此操作不可恢复。`)) {
    appStore.deleteCharacter(character.id)
  }
}

function goBack() {
  router.push(`/chapters/${props.novelId}`)
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
  <div v-if="novel" class="characters-view">
    <!-- 头部导航 -->
    <div class="characters-header">
      <div class="header-left">
        <button @click="goBack" class="back-button">
          <span class="back-icon">←</span>
          返回章节
        </button>
        <div class="novel-info">
          <h2 class="novel-title">{{ novel.title }}</h2>
          <div class="characters-count">共 {{ characters.length }} 个人物</div>
        </div>
      </div>

      <div class="header-actions">
        <button @click="openCreateDialog" class="new-character-button">
          <span class="plus-icon">+</span>
          新建人物
        </button>
      </div>
    </div>

    <!-- 主内容区域 -->
    <div class="characters-content">
      <!-- 人物列表 -->
      <div v-if="characters.length === 0" class="empty-characters">
        <div class="empty-icon">👤</div>
        <h3>还没有人物</h3>
        <p>点击新建人物按钮开始创建你的小说人物</p>
      </div>

      <div v-else class="characters-list">
        <div
          v-for="character in characters"
          :key="character.id"
          class="character-card"
        >
          <div class="character-content">
            <div class="character-header">
              <h3 class="character-name">{{ character.name }}</h3>
              <span class="character-date">{{ formatDate(character.updatedAt) }}</span>
            </div>
            <p class="character-description">{{ character.description }}</p>
          </div>
          <div class="character-actions">
            <button @click="openEditDialog(character)" class="action-btn edit">
              编辑
            </button>
            <button @click="deleteCharacter(character)" class="action-btn danger">
              删除
            </button>
          </div>
        </div>
      </div>
    </div>

    <!-- 新建人物对话框 -->
    <div v-if="showCreateDialog" class="dialog-overlay" @click="showCreateDialog = false">
      <div class="dialog" @click.stop>
        <div class="dialog-header">
          <h3>新建人物</h3>
          <button @click="showCreateDialog = false" class="close-button">×</button>
        </div>
        <div class="dialog-body">
          <div class="form-group">
            <label>人物姓名 *</label>
            <input
              v-model="newCharacterName"
              type="text"
              placeholder="输入人物姓名"
              maxlength="50"
            />
          </div>
          <div class="form-group">
            <label>人物简介 *</label>
            <textarea
              v-model="newCharacterDescription"
              placeholder="描述人物的外貌、性格、背景等"
              rows="4"
              maxlength="500"
            ></textarea>
            <div class="help-text">描述人物的外貌特征、性格特点、背景故事等</div>
          </div>
        </div>
        <div class="dialog-footer">
          <button @click="showCreateDialog = false" class="cancel-button">取消</button>
          <button
            @click="createCharacter"
            :disabled="!newCharacterName.trim() || !newCharacterDescription.trim()"
            class="create-button"
          >
            创建人物
          </button>
        </div>
      </div>
    </div>

    <!-- 编辑人物对话框 -->
    <div v-if="showEditDialog" class="dialog-overlay" @click="showEditDialog = false">
      <div class="dialog" @click.stop>
        <div class="dialog-header">
          <h3>编辑人物</h3>
          <button @click="showEditDialog = false" class="close-button">×</button>
        </div>
        <div class="dialog-body">
          <div class="form-group">
            <label>人物姓名 *</label>
            <input
              v-model="newCharacterName"
              type="text"
              placeholder="输入人物姓名"
              maxlength="50"
            />
          </div>
          <div class="form-group">
            <label>人物简介 *</label>
            <textarea
              v-model="newCharacterDescription"
              placeholder="描述人物的外貌、性格、背景等"
              rows="4"
              maxlength="500"
            ></textarea>
            <div class="help-text">描述人物的外貌特征、性格特点、背景故事等</div>
          </div>
        </div>
        <div class="dialog-footer">
          <button @click="showEditDialog = false" class="cancel-button">取消</button>
          <button
            @click="updateCharacter"
            :disabled="!newCharacterName.trim() || !newCharacterDescription.trim()"
            class="save-button"
          >
            保存修改
          </button>
        </div>
      </div>
    </div>
  </div>
</template>

<style scoped>
.characters-view {
  min-height: calc(100vh - 56px);
  display: flex;
  flex-direction: column;
  background: var(--color-surface-secondary);
}

.characters-header {
  background: var(--color-surface);
  border-bottom: 1px solid var(--color-divider);
  padding: 16px 20px;
  display: flex;
  justify-content: space-between;
  align-items: center;
  flex-shrink: 0;
}

.header-left {
  display: flex;
  align-items: center;
  gap: 16px;
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
  background: var(--color-hover-background);
  color: var(--color-text-primary);
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
  color: var(--color-text-primary);
}

.characters-count {
  font-size: 12px;
  color: var(--color-text-secondary);
}

.header-actions {
  display: flex;
  gap: 8px;
}

.new-character-button {
  display: flex;
  align-items: center;
  gap: 6px;
  background: var(--color-primary);
  color: white;
  border: none;
  border-radius: 8px;
  padding: 8px 16px;
  font-size: 14px;
  font-weight: 500;
  cursor: pointer;
  transition: background-color 0.2s;
}

.new-character-button:hover {
  background: var(--color-primary-hover);
}

.plus-icon {
  font-size: 18px;
  line-height: 1;
}

.characters-content {
  flex: 1;
  padding: 16px;
  overflow-y: auto;
}

.empty-characters {
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

.empty-characters h3 {
  margin: 0 0 8px 0;
  font-size: 18px;
  font-weight: 600;
}

.empty-characters p {
  margin: 0;
  font-size: 14px;
}

.characters-list {
  display: flex;
  flex-direction: column;
  gap: 12px;
}

.character-card {
  background: var(--color-surface);
  border-radius: 12px;
  padding: 16px;
  box-shadow: 0 1px 3px rgba(0, 0, 0, 0.1);
  transition: all 0.2s;
  display: flex;
  align-items: flex-start;
  gap: 16px;
}

.character-card:hover {
  box-shadow: 0 2px 8px rgba(0, 0, 0, 0.15);
}

.character-content {
  flex: 1;
  min-width: 0;
}

.character-header {
  display: flex;
  justify-content: space-between;
  align-items: flex-start;
  margin-bottom: 8px;
}

.character-name {
  margin: 0;
  font-size: 16px;
  font-weight: 600;
  color: var(--color-text-primary);
}

.character-date {
  font-size: 12px;
  color: var(--color-text-secondary);
  white-space: nowrap;
}

.character-description {
  margin: 0;
  font-size: 14px;
  color: var(--color-text-medium);
  line-height: 1.5;
}

.character-actions {
  display: flex;
  flex-direction: column;
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
  white-space: nowrap;
}

.action-btn.edit {
  background: var(--color-info);
  color: white;
}

.action-btn.edit:hover {
  opacity: 0.9;
}

.action-btn.danger {
  background: var(--color-danger);
  color: white;
}

.action-btn.danger:hover {
  background: var(--color-danger-hover);
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
  max-width: 500px;
  max-height: 90vh;
  overflow: hidden;
  animation: dialogSlideIn 0.2s ease-out;
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
  border-bottom: 1px solid var(--color-divider);
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
  background: var(--color-hover-background);
  color: var(--color-text-primary);
}

.dialog-body {
  padding: 20px;
  max-height: 60vh;
  overflow-y: auto;
}

.form-group {
  margin-bottom: 20px;
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

.form-group input,
.form-group textarea {
  width: 100%;
  padding: 12px;
  border: 1px solid var(--color-input-border);
  border-radius: 8px;
  font-size: 14px;
  box-sizing: border-box;
  transition: border-color 0.2s;
  background: var(--color-input-background);
  color: var(--color-text-primary);
}

.form-group input:focus,
.form-group textarea:focus {
  outline: none;
  border-color: var(--color-input-focus);
  box-shadow: 0 0 0 3px rgba(0, 123, 255, 0.1);
}

.form-group textarea {
  resize: vertical;
  min-height: 80px;
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
.create-button,
.save-button {
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

.create-button,
.save-button {
  background: var(--color-primary);
  color: white;
}

.create-button:hover:not(:disabled),
.save-button:hover:not(:disabled) {
  background: var(--color-primary-hover);
}

.create-button:disabled,
.save-button:disabled {
  background: var(--color-border);
  color: var(--color-text-muted);
  cursor: not-allowed;
}

@media (max-width: 768px) {
  .characters-content {
    padding: 12px;
  }

  .character-card {
    flex-direction: column;
    align-items: stretch;
    gap: 12px;
  }

  .character-actions {
    flex-direction: row;
    justify-content: flex-end;
  }
}
</style>