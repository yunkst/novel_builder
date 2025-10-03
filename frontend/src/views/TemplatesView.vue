<script setup lang="ts">
import { ref, computed } from 'vue'
import { useRouter } from 'vue-router'
import { useAppStore } from '@/stores/app'
import type { Template } from '@/stores/app'

const appStore = useAppStore()
const router = useRouter()

const activeTab = ref<'background' | 'ai_writer'>('background')
const showCreateDialog = ref(false)
const showEditDialog = ref(false)
const editingTemplate = ref<Template | null>(null)

const newTemplateName = ref('')
const newTemplateDescription = ref('')
const newTemplateContent = ref('')

const backgroundTemplates = computed(() => appStore.backgroundTemplates)
const aiWriterTemplates = computed(() => appStore.aiWriterTemplates)

const currentTemplates = computed(() => {
  return activeTab.value === 'background' ? backgroundTemplates.value : aiWriterTemplates.value
})

function openCreateDialog() {
  newTemplateName.value = ''
  newTemplateDescription.value = ''
  newTemplateContent.value = ''
  showCreateDialog.value = true
}

function createTemplate() {
  if (!newTemplateName.value.trim() || !newTemplateContent.value.trim()) return

  appStore.createTemplate(
    newTemplateName.value,
    activeTab.value,
    newTemplateContent.value,
    newTemplateDescription.value
  )

  showCreateDialog.value = false
}

function openEditDialog(template: Template) {
  editingTemplate.value = template
  newTemplateName.value = template.name
  newTemplateDescription.value = template.description || ''
  newTemplateContent.value = template.content
  showEditDialog.value = true
}

function updateTemplate() {
  if (!editingTemplate.value || !newTemplateName.value.trim() || !newTemplateContent.value.trim()) return

  appStore.updateTemplate(editingTemplate.value.id, {
    name: newTemplateName.value,
    description: newTemplateDescription.value,
    content: newTemplateContent.value
  })

  showEditDialog.value = false
  editingTemplate.value = null
}

function deleteTemplate(templateId: string) {
  const template = appStore.templates.find(t => t.id === templateId)
  if (template && confirm(`确定要删除模板《${template.name}》吗？此操作不可恢复。`)) {
    appStore.deleteTemplate(templateId)
  }
}

function goBack() {
  router.push('/')
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
  <div class="templates-view">
    <!-- 头部导航 -->
    <div class="templates-header">
      <div class="header-left">
        <button @click="goBack" class="back-button">
          <span class="back-icon">←</span>
          返回
        </button>
        <div class="page-info">
          <h2 class="page-title">模板管理</h2>
          <span class="templates-count">{{ currentTemplates.length }} 个模板</span>
        </div>
      </div>

      <div class="header-actions">
        <button @click="openCreateDialog" class="new-template-button">
          <span class="plus-icon">+</span>
          新建模板
        </button>
      </div>
    </div>

    <!-- 标签页 -->
    <div class="tabs-container">
      <div class="tabs">
        <button
          @click="activeTab = 'background'"
          :class="['tab', { active: activeTab === 'background' }]"
        >
          背景设定模板
        </button>
        <button
          @click="activeTab = 'ai_writer'"
          :class="['tab', { active: activeTab === 'ai_writer' }]"
        >
          AI作家设定模板
        </button>
      </div>
    </div>

    <!-- 模板列表 -->
    <div class="templates-content">
      <div v-if="currentTemplates.length === 0" class="empty-templates">
        <div class="empty-icon">📄</div>
        <h3>还没有{{ activeTab === 'background' ? '背景设定' : 'AI作家设定' }}模板</h3>
        <p>点击新建模板开始创建第一个模板</p>
        <button @click="openCreateDialog" class="create-first-template-button">
          创建第一个模板
        </button>
      </div>

      <div v-else class="templates-list">
        <div
          v-for="template in currentTemplates"
          :key="template.id"
          class="template-card"
        >
          <div class="template-content">
            <div class="template-header">
              <h3 class="template-title">{{ template.name }}</h3>
              <span class="template-type">{{ activeTab === 'background' ? '背景设定' : 'AI作家设定' }}</span>
            </div>

            <div v-if="template.description" class="template-description">
              {{ template.description }}
            </div>

            <div class="template-preview">
              {{ template.content.substring(0, 200) }}{{ template.content.length > 200 ? '...' : '' }}
            </div>

            <div class="template-meta">
              <span class="template-length">{{ template.content.length }} 字</span>
              <span class="template-date">{{ formatDate(template.updatedAt) }}</span>
            </div>
          </div>

          <div class="template-actions">
            <button @click="openEditDialog(template)" class="action-btn primary">
              编辑
            </button>
            <button @click="deleteTemplate(template.id)" class="action-btn danger">
              删除
            </button>
          </div>
        </div>
      </div>
    </div>

    <!-- 创建模板对话框 -->
    <div v-if="showCreateDialog" class="dialog-overlay" @click="showCreateDialog = false">
      <div class="dialog large-dialog" @click.stop>
        <div class="dialog-header">
          <h3>创建{{ activeTab === 'background' ? '背景设定' : 'AI作家设定' }}模板</h3>
          <button @click="showCreateDialog = false" class="close-button">×</button>
        </div>
        <div class="dialog-body">
          <div class="form-group">
            <label>模板名称 *</label>
            <input
              v-model="newTemplateName"
              type="text"
              placeholder="输入模板名称"
              maxlength="50"
            />
          </div>

          <div class="form-group">
            <label>模板描述（可选）</label>
            <textarea
              v-model="newTemplateDescription"
              placeholder="描述模板的用途和特点"
              rows="2"
              maxlength="200"
            ></textarea>
          </div>

          <div class="form-group">
            <label>模板内容 *</label>
            <textarea
              v-model="newTemplateContent"
              :placeholder="activeTab === 'background' ? '描述小说的世界观、时代背景、主要设定等' : '定义AI作家的风格、偏好、写作特点等'"
              rows="6"
              maxlength="1000"
            ></textarea>
          </div>
        </div>
        <div class="dialog-footer">
          <button @click="showCreateDialog = false" class="cancel-button">取消</button>
          <button
            @click="createTemplate"
            :disabled="!newTemplateName.trim() || !newTemplateContent.trim()"
            class="create-button"
          >
            创建模板
          </button>
        </div>
      </div>
    </div>

    <!-- 编辑模板对话框 -->
    <div v-if="showEditDialog" class="dialog-overlay" @click="showEditDialog = false">
      <div class="dialog large-dialog" @click.stop>
        <div class="dialog-header">
          <h3>编辑{{ activeTab === 'background' ? '背景设定' : 'AI作家设定' }}模板</h3>
          <button @click="showEditDialog = false" class="close-button">×</button>
        </div>
        <div class="dialog-body">
          <div class="form-group">
            <label>模板名称 *</label>
            <input
              v-model="newTemplateName"
              type="text"
              placeholder="输入模板名称"
              maxlength="50"
            />
          </div>

          <div class="form-group">
            <label>模板描述（可选）</label>
            <textarea
              v-model="newTemplateDescription"
              placeholder="描述模板的用途和特点"
              rows="2"
              maxlength="200"
            ></textarea>
          </div>

          <div class="form-group">
            <label>模板内容 *</label>
            <textarea
              v-model="newTemplateContent"
              :placeholder="activeTab === 'background' ? '描述小说的世界观、时代背景、主要设定等' : '定义AI作家的风格、偏好、写作特点等'"
              rows="6"
              maxlength="1000"
            ></textarea>
          </div>
        </div>
        <div class="dialog-footer">
          <button @click="showEditDialog = false" class="cancel-button">取消</button>
          <button
            @click="updateTemplate"
            :disabled="!newTemplateName.trim() || !newTemplateContent.trim()"
            class="save-button"
          >
            保存更改
          </button>
        </div>
      </div>
    </div>
  </div>
</template>

<style scoped>
.templates-view {
  min-height: calc(100vh - 56px);
  display: flex;
  flex-direction: column;
  background: var(--color-surface-secondary);
}

.templates-header {
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

.page-info {
  display: flex;
  flex-direction: column;
  gap: 2px;
}

.page-title {
  margin: 0;
  font-size: 18px;
  font-weight: 600;
  color: #333;
}

.templates-count {
  font-size: 12px;
  color: var(--color-text-secondary);
}

.header-actions {
  display: flex;
  gap: 8px;
}

.new-template-button {
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

.new-template-button:hover {
  background: #0056b3;
}

.plus-icon {
  font-size: 16px;
  line-height: 1;
}

.tabs-container {
  background: var(--color-surface);
  border-bottom: 1px solid #e9ecef;
  flex-shrink: 0;
}

.tabs {
  display: flex;
  padding: 0 16px;
}

.tab {
  background: none;
  border: none;
  padding: 12px 16px;
  font-size: 14px;
  font-weight: 500;
  color: var(--color-text-secondary);
  cursor: pointer;
  border-bottom: 2px solid transparent;
  transition: all 0.2s;
}

.tab:hover {
  color: #333;
}

.tab.active {
  color: #007bff;
  border-bottom-color: #007bff;
}

.templates-content {
  flex: 1;
  padding: 16px;
  overflow-y: auto;
}

.empty-templates {
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

.empty-templates h3 {
  margin: 0 0 8px 0;
  font-size: 18px;
  font-weight: 600;
}

.empty-templates p {
  margin: 0 0 20px 0;
  font-size: 14px;
}

.create-first-template-button {
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

.create-first-template-button:hover {
  background: #0056b3;
}

.templates-list {
  display: flex;
  flex-direction: column;
  gap: 12px;
}

.template-card {
  background: var(--color-surface);
  border-radius: 12px;
  padding: 16px;
  box-shadow: 0 1px 3px rgba(0, 0, 0, 0.1);
  display: flex;
  align-items: flex-start;
  gap: 16px;
  transition: all 0.2s;
}

.template-card:hover {
  box-shadow: 0 2px 8px rgba(0, 0, 0, 0.15);
}

.template-content {
  flex: 1;
  min-width: 0;
}

.template-header {
  display: flex;
  justify-content: space-between;
  align-items: center;
  margin-bottom: 8px;
}

.template-title {
  margin: 0;
  font-size: 16px;
  font-weight: 600;
  color: #333;
}

.template-type {
  font-size: 12px;
  color: var(--color-text-secondary);
  background: var(--color-surface-secondary);
  padding: 2px 8px;
  border-radius: 4px;
}

.template-description {
  margin-bottom: 8px;
  font-size: 14px;
  color: var(--color-text-medium);
  font-style: italic;
}

.template-preview {
  margin-bottom: 8px;
  font-size: 14px;
  color: var(--color-text-medium);
  line-height: 1.5;
}

.template-meta {
  display: flex;
  gap: 12px;
  font-size: 12px;
  color: var(--color-text-secondary);
}

.template-actions {
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
  min-width: 60px;
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
  min-height: 80px;
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

.create-button:disabled,
.save-button:disabled {
  background: #dee2e6;
  color: var(--color-text-secondary);
  cursor: not-allowed;
}

@media (max-width: 768px) {
  .templates-content {
    padding: 12px;
  }

  .template-card {
    flex-direction: column;
    align-items: stretch;
    gap: 12px;
  }

  .template-actions {
    flex-direction: row;
    justify-content: flex-end;
  }

  .templates-header {
    padding: 12px;
  }

  .header-left {
    gap: 8px;
  }

  .tabs {
    padding: 0 12px;
  }
}
</style>