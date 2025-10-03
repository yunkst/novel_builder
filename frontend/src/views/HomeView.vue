<script setup lang="ts">
import { ref, computed, onMounted } from 'vue'
import { useRouter } from 'vue-router'
import { useAppStore } from '@/stores/app'

const appStore = useAppStore()
const router = useRouter()

const showNewNovelDialog = ref(false)
const newNovelTitle = ref('')
const newNovelBackground = ref('')
const newNovelAiWriter = ref('')

// 模板选择相关
const showTemplateSelector = ref<'background' | 'ai_writer' | null>(null)
const selectedBackgroundTemplate = ref<string>('')
const selectedAiWriterTemplate = ref<string>('')

// 保存为模板相关
const showSaveTemplateDialog = ref(false)
const saveTemplateType = ref<'background' | 'ai_writer'>('background')
const saveTemplateName = ref('')
const saveTemplateDescription = ref('')
const saveTemplateContent = ref('')

const sortedNovels = computed(() => {
  return [...appStore.novels].sort((a, b) => b.updatedAt - a.updatedAt)
})

onMounted(() => {
  appStore.loadAllData()
})

function openCreateDialog() {
  newNovelTitle.value = ''
  newNovelBackground.value = ''
  newNovelAiWriter.value = ''
  selectedBackgroundTemplate.value = ''
  selectedAiWriterTemplate.value = ''
  showNewNovelDialog.value = true
}

function selectTemplate(type: 'background' | 'ai_writer') {
  showTemplateSelector.value = type
}

function applyTemplate(templateId: string, type: 'background' | 'ai_writer') {
  const template = appStore.getTemplate(templateId)
  if (template) {
    if (type === 'background') {
      newNovelBackground.value = template.content
      selectedBackgroundTemplate.value = template.name
    } else {
      newNovelAiWriter.value = template.content
      selectedAiWriterTemplate.value = template.name
    }
  }
  showTemplateSelector.value = null
}

function openSaveTemplateDialog(type: 'background' | 'ai_writer') {
  saveTemplateType.value = type
  saveTemplateName.value = ''
  saveTemplateDescription.value = ''
  saveTemplateContent.value = type === 'background' ? newNovelBackground.value : newNovelAiWriter.value
  showSaveTemplateDialog.value = true
}

function saveAsTemplate() {
  if (!saveTemplateName.value.trim() || !saveTemplateContent.value.trim()) return

  appStore.createTemplate(
    saveTemplateName.value,
    saveTemplateType.value,
    saveTemplateContent.value,
    saveTemplateDescription.value
  )

  showSaveTemplateDialog.value = false
}

function createNewNovel() {
  if (!newNovelTitle.value.trim() || !newNovelBackground.value.trim() || !newNovelAiWriter.value.trim()) {
    return
  }

  const novel = appStore.createNovel(
    newNovelTitle.value,
    newNovelBackground.value,
    newNovelAiWriter.value
  )

  // 创建第一章
  const firstChapter = appStore.createChapter(novel.id, '第1章', '描述第一章的故事情节和发展')

  showNewNovelDialog.value = false

  // 设置当前小说并进入创作页面
  appStore.setCurrentNovel(novel)
  appStore.writingSession.currentChapterId = firstChapter.id

  router.push(`/writing/${novel.id}`)
}

function openNovel(novelId: string) {
  const novel = appStore.novels.find(n => n.id === novelId)
  if (novel) {
    appStore.setCurrentNovel(novel)
    // 进入章节列表页面，让用户选择要编辑的章节
    router.push(`/chapters/${novel.id}`)
  }
}

function deleteNovel(novelId: string) {
  const novel = appStore.novels.find(n => n.id === novelId)
  if (novel && confirm(`确定要删除小说《${novel.title}》吗？此操作不可恢复。`)) {
    appStore.deleteNovel(novelId)
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
  <div class="home-view">
    <!-- 配置检查 -->
    <div v-if="!appStore.isConfigured" class="config-warning">
      <div class="warning-card">
        <div class="warning-icon">⚠️</div>
        <div>
          <h3>需要配置 Dify API</h3>
          <p>请先在设置中配置 Dify API 密钥和服务地址</p>
          <router-link to="/settings" class="config-link">前往设置</router-link>
        </div>
      </div>
    </div>

    <!-- 小说列表 -->
    <div class="novels-section">
      <div class="section-header">
        <h2>我的小说</h2>
        <div class="header-actions">
          <router-link to="/templates" class="templates-button">
            📄 模板管理
          </router-link>
          <button @click="openCreateDialog" class="new-button">
            <span class="plus-icon">+</span>
            新建小说
          </button>
        </div>
      </div>

      <div v-if="sortedNovels.length === 0" class="empty-state">
        <div class="empty-icon">📚</div>
        <h3>还没有小说</h3>
        <p>点击新建小说按钮开始创作你的第一部小说</p>
      </div>

      <div v-else class="novels-list">
        <div
          v-for="novel in sortedNovels"
          :key="novel.id"
          class="novel-card"
        >
          <div class="novel-content" @click="openNovel(novel.id)">
            <h3 class="novel-title">{{ novel.title }}</h3>
            <p class="novel-background">{{ novel.backgroundSetting.substring(0, 100) }}{{ novel.backgroundSetting.length > 100 ? '...' : '' }}</p>
            <div class="novel-meta">
              <span class="novel-date">{{ formatDate(novel.updatedAt) }}</span>
              <span v-if="appStore.chapters.filter(c => c.novelId === novel.id).length > 0" class="chapter-count">
                {{ appStore.chapters.filter(c => c.novelId === novel.id).length }} 章节
              </span>
            </div>
          </div>
          <div class="novel-actions">
            <button @click="openNovel(novel.id)" class="action-btn primary">
              继续创作
            </button>
            <button @click="deleteNovel(novel.id)" class="action-btn danger">
              删除
            </button>
          </div>
        </div>
      </div>
    </div>

    <!-- 新建小说对话框 -->
    <div v-if="showNewNovelDialog" class="dialog-overlay" @click="showNewNovelDialog = false">
      <div class="dialog" @click.stop>
        <div class="dialog-header">
          <h3>新建小说</h3>
          <button @click="showNewNovelDialog = false" class="close-button">×</button>
        </div>
        <div class="dialog-body">
          <div class="form-group">
            <label>小说标题 *</label>
            <input
              v-model="newNovelTitle"
              type="text"
              placeholder="输入小说标题"
              maxlength="50"
            />
          </div>

          <div class="form-group">
            <div class="form-label-with-action">
              <label>背景设定 *</label>
              <div class="template-actions">
                <button type="button" @click="selectTemplate('background')" class="template-btn">
                  选择模板
                </button>
                <button type="button" @click="openSaveTemplateDialog('background')" :disabled="!newNovelBackground.trim()" class="template-btn save-btn">
                  保存为模板
                </button>
              </div>
            </div>
            <div v-if="selectedBackgroundTemplate" class="selected-template">
              已选择模板: {{ selectedBackgroundTemplate }}
            </div>
            <textarea
              v-model="newNovelBackground"
              placeholder="描述小说的世界观、时代背景、主要设定等"
              rows="4"
              maxlength="1000"
            ></textarea>
            <div class="help-text">描述小说的世界观、时代背景、主要人物关系等</div>
          </div>

          <div class="form-group">
            <div class="form-label-with-action">
              <label>AI作家设定 *</label>
              <div class="template-actions">
                <button type="button" @click="selectTemplate('ai_writer')" class="template-btn">
                  选择模板
                </button>
                <button type="button" @click="openSaveTemplateDialog('ai_writer')" :disabled="!newNovelAiWriter.trim()" class="template-btn save-btn">
                  保存为模板
                </button>
              </div>
            </div>
            <div v-if="selectedAiWriterTemplate" class="selected-template">
              已选择模板: {{ selectedAiWriterTemplate }}
            </div>
            <textarea
              v-model="newNovelAiWriter"
              placeholder="定义AI作家的风格、偏好、写作特点等"
              rows="4"
              maxlength="1000"
            ></textarea>
            <div class="help-text">定义AI的写作风格、文笔特点、擅长的类型等</div>
          </div>
        </div>
        <div class="dialog-footer">
          <button @click="showNewNovelDialog = false" class="cancel-button">取消</button>
          <button
            @click="createNewNovel"
            :disabled="!newNovelTitle.trim() || !newNovelBackground.trim() || !newNovelAiWriter.trim()"
            class="create-button"
          >
            创建小说
          </button>
        </div>
      </div>
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

    <!-- 保存为模板对话框 -->
    <div v-if="showSaveTemplateDialog" class="dialog-overlay" @click="showSaveTemplateDialog = false">
      <div class="dialog" @click.stop>
        <div class="dialog-header">
          <h3>保存为{{ saveTemplateType === 'background' ? '背景设定' : 'AI作家设定' }}模板</h3>
          <button @click="showSaveTemplateDialog = false" class="close-button">×</button>
        </div>
        <div class="dialog-body">
          <div class="form-group">
            <label>模板名称 *</label>
            <input
              v-model="saveTemplateName"
              type="text"
              placeholder="输入模板名称"
              maxlength="50"
            />
          </div>

          <div class="form-group">
            <label>模板描述（可选）</label>
            <textarea
              v-model="saveTemplateDescription"
              placeholder="描述模板的用途和特点"
              rows="2"
              maxlength="200"
            ></textarea>
          </div>

          <div class="form-group">
            <label>模板内容</label>
            <textarea
              v-model="saveTemplateContent"
              rows="4"
              readonly
              class="readonly-textarea"
            ></textarea>
          </div>
        </div>
        <div class="dialog-footer">
          <button @click="showSaveTemplateDialog = false" class="cancel-button">取消</button>
          <button @click="saveAsTemplate" :disabled="!saveTemplateName.trim()" class="save-button">保存模板</button>
        </div>
      </div>
    </div>
  </div>
</template>

<style scoped>
.home-view {
  min-height: calc(100vh - 56px);
  padding: 16px;
  background: var(--color-surface-secondary);
}

.config-warning {
  margin-bottom: 24px;
}

.warning-card {
  background: var(--color-warning-background);
  border: 1px solid var(--color-warning-border);
  border-radius: 8px;
  padding: 16px;
  display: flex;
  align-items: center;
  gap: 12px;
}

.warning-icon {
  font-size: 24px;
}

.warning-card h3 {
  margin: 0 0 4px 0;
  color: var(--color-warning-text);
  font-size: 16px;
  font-weight: 600;
}

.warning-card p {
  margin: 0 0 8px 0;
  color: var(--color-warning-text);
  font-size: 14px;
}

.config-link {
  color: #0066cc;
  text-decoration: none;
  font-weight: 500;
}

.config-link:hover {
  text-decoration: underline;
}

.novels-section {
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
  color: var(--color-text-primary);
}

.header-actions {
  display: flex;
  gap: 12px;
}

.templates-button {
  display: flex;
  align-items: center;
  gap: 6px;
  background: #6c757d;
  color: white;
  text-decoration: none;
  border-radius: 8px;
  padding: 8px 16px;
  font-size: 14px;
  font-weight: 500;
  transition: background-color 0.2s;
}

.templates-button:hover {
  background: #5a6268;
}

.new-button {
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

.new-button:hover {
  background: #0056b3;
}

.plus-icon {
  font-size: 18px;
  line-height: 1;
}

.empty-state {
  text-align: center;
  padding: 60px 20px;
  color: var(--color-text-secondary);
}

.empty-icon {
  font-size: 48px;
  margin-bottom: 16px;
}

.empty-state h3 {
  margin: 0 0 8px 0;
  font-size: 18px;
  font-weight: 600;
}

.empty-state p {
  margin: 0;
  font-size: 14px;
}

.novels-list {
  divide-y: 1px solid #e9ecef;
}

.novel-card {
  display: flex;
  align-items: center;
  padding: 16px 20px;
  border-bottom: 1px solid #e9ecef;
  transition: background-color 0.2s;
}

.novel-card:hover {
  background: var(--color-surface-secondary);
}

.novel-card:last-child {
  border-bottom: none;
}

.novel-content {
  flex: 1;
  min-width: 0;
  cursor: pointer;
}

.novel-title {
  margin: 0 0 6px 0;
  font-size: 18px;
  font-weight: 600;
  color: var(--color-text-primary);
  line-height: 1.4;
}

.novel-background {
  margin: 0 0 8px 0;
  font-size: 14px;
  color: var(--color-text-secondary);
  line-height: 1.4;
}

.novel-meta {
  display: flex;
  gap: 12px;
  font-size: 12px;
  color: var(--color-text-secondary);
}

.novel-actions {
  display: flex;
  gap: 8px;
  margin-left: 12px;
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

.help-text {
  margin-top: 6px;
  font-size: 12px;
  color: var(--color-text-secondary);
  line-height: 1.4;
}

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

.template-btn:disabled {
  background: var(--color-surface-secondary);
  color: var(--color-text-secondary);
  cursor: not-allowed;
}

.template-btn.save-btn {
  background: #28a745;
  color: white;
  border-color: #28a745;
}

.template-btn.save-btn:hover:not(:disabled) {
  background: #218838;
  border-color: #218838;
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
  border-color: #007bff;
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

.readonly-textarea {
  background: var(--color-surface-secondary) !important;
  color: var(--color-text-secondary) !important;
  cursor: not-allowed;
}

.save-button {
  background: #28a745;
  color: white;
}

.save-button:hover:not(:disabled) {
  background: #218838;
}

.save-button:disabled {
  background: #dee2e6;
  color: var(--color-text-secondary);
  cursor: not-allowed;
}

.dialog-footer {
  display: flex;
  gap: 12px;
  padding: 20px;
  border-top: 1px solid var(--color-divider);
  justify-content: flex-end;
}

.cancel-button,
.create-button {
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

.create-button {
  background: #007bff;
  color: white;
}

.create-button:hover:not(:disabled) {
  background: #0056b3;
}

.create-button:disabled {
  background: #dee2e6;
  color: var(--color-text-secondary);
  cursor: not-allowed;
}

@media (max-width: 768px) {
  .home-view {
    padding: 12px;
  }

  .novel-card {
    flex-direction: column;
    align-items: stretch;
    gap: 12px;
  }

  .novel-actions {
    margin-left: 0;
    justify-content: flex-end;
  }
}
</style>