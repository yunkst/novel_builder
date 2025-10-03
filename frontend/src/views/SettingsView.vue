<script setup lang="ts">
import { ref, onMounted } from 'vue'
import { useAppStore } from '@/stores/app'
import { difyApi } from '@/services/difyApi'
import ThemeToggle from '@/components/ThemeToggle.vue'

const appStore = useAppStore()

const apiBaseUrl = ref('')
const apiKey = ref('')
const historyCharsLimit = ref(20000)
const isSaving = ref(false)
const testResult = ref<string | null>(null)

onMounted(() => {
  apiBaseUrl.value = appStore.difyConfig.apiBaseUrl
  apiKey.value = appStore.difyConfig.apiKey
  historyCharsLimit.value = appStore.settings.historyChaptersMaxChars
})

async function saveSettings() {
  isSaving.value = true
  try {
    appStore.updateDifyConfig({
      apiBaseUrl: apiBaseUrl.value,
      apiKey: apiKey.value
    })

    // 更新 API 服务配置
    difyApi.updateConfig({
      apiBaseUrl: apiBaseUrl.value,
      apiKey: apiKey.value
    })

    testResult.value = '设置已保存'
    setTimeout(() => {
      testResult.value = null
    }, 2000)
  } finally {
    isSaving.value = false
  }
}

async function testConnection() {
  if (!apiKey.value.trim()) {
    testResult.value = '请先输入 API Key'
    return
  }

  isSaving.value = true
  testResult.value = null

  try {
    // 更新临时配置进行测试
    difyApi.updateConfig({
      apiBaseUrl: apiBaseUrl.value,
      apiKey: apiKey.value
    })

    // 发送一个简单的测试请求
    await difyApi.runWorkflow({
      inputs: { test: 'connection' },
      response_mode: 'blocking',
      user: 'test_user'
    })

    testResult.value = '连接成功！'
  } catch (error) {
    testResult.value = `连接失败: ${error instanceof Error ? error.message : '未知错误'}`
  } finally {
    isSaving.value = false
  }
}

function clearData() {
  if (!confirm('确定要清除所有数据吗？此操作不可恢复。')) return

  localStorage.clear()
  appStore.novels.splice(0)
  appStore.chapters.splice(0)
  appStore.templates.splice(0)
  appStore.characters.splice(0)
  appStore.setCurrentNovel(null)
  appStore.resetWritingSession()

  testResult.value = '数据已清除'
  setTimeout(() => {
    testResult.value = null
  }, 2000)
}

function updateHistoryCharsLimit() {
  if (historyCharsLimit.value >= 1000 && historyCharsLimit.value <= 100000) {
    appStore.setHistoryChaptersMaxChars(historyCharsLimit.value)
    testResult.value = '历史章节字数限制已更新'
    setTimeout(() => {
      testResult.value = null
    }, 2000)
  } else {
    testResult.value = '字数限制必须在1000-100000之间'
    setTimeout(() => {
      testResult.value = null
    }, 3000)
  }
}
</script>

<template>
  <div class="settings-view">
    <div class="settings-container">
      <div class="settings-header">
        <h1>设置</h1>
      </div>

      <!-- 主题设置 -->
      <div class="settings-section">
        <h2>外观设置</h2>
        <ThemeToggle />
      </div>

      <!-- 创作设置 -->
      <div class="settings-section">
        <h2>创作设置</h2>
        <div class="form-group">
          <label>历史章节字数限制</label>
          <input
            v-model.number="historyCharsLimit"
            type="number"
            min="1000"
            max="100000"
            step="1000"
            class="form-input"
            @change="updateHistoryCharsLimit"
          />
          <div class="help-text">
            发送给AI的历史章节最大字符数，默认20000字。较大的值会提供更多上下文但增加API成本。
          </div>
        </div>
      </div>

      <!-- Dify API 配置 -->
      <div class="settings-section">
        <h2>Dify API 配置</h2>
        <div class="form-group">
          <label>API 基础地址</label>
          <input
            v-model="apiBaseUrl"
            type="url"
            placeholder="https://api.dify.ai/v1"
            class="form-input"
          />
          <div class="help-text">
            默认使用 Dify 官方 API 地址，如果使用自部署版本请修改此地址
          </div>
        </div>

        <div class="form-group">
          <label>API Key</label>
          <input
            v-model="apiKey"
            type="password"
            placeholder="输入你的 Dify API Key"
            class="form-input"
          />
          <div class="help-text">
            在 Dify 应用设置中可以找到 API Key
          </div>
        </div>

        <div class="button-group">
          <button @click="testConnection" :disabled="isSaving" class="test-button">
            {{ isSaving ? '测试中...' : '测试连接' }}
          </button>
          <button @click="saveSettings" :disabled="isSaving" class="save-button">
            {{ isSaving ? '保存中...' : '保存设置' }}
          </button>
        </div>

        <div v-if="testResult" class="test-result" :class="{ error: testResult.includes('失败') }">
          {{ testResult }}
        </div>
      </div>

      <!-- 使用说明 -->
      <div class="settings-section">
        <h2>使用说明</h2>
        <div class="usage-info">
          <ol>
            <li>
              <strong>获取 API Key:</strong>
              <p>登录 <a href="https://dify.ai" target="_blank">Dify</a>，创建或进入你的应用，在应用设置中找到 API Key。</p>
            </li>
            <li>
              <strong>配置工作流:</strong>
              <p>确保你的 Dify 应用已配置好小说创作相关的工作流，支持文本生成功能。</p>
            </li>
            <li>
              <strong>开始创作:</strong>
              <p>配置完成后，返回首页即可开始创作你的小说。</p>
            </li>
          </ol>
        </div>
      </div>

      <!-- 数据管理 -->
      <div class="settings-section">
        <h2>数据管理</h2>
        <div class="data-info">
          <p>所有数据都保存在浏览器本地存储中，不会上传到服务器。</p>
          <p>当前存储:</p>
          <ul>
            <li>小说数量: {{ appStore.novels.length }}</li>
            <li>章节数量: {{ appStore.chapters.length }}</li>
            <li>模板数量: {{ appStore.templates.length }}</li>
            <li>人物数量: {{ appStore.characters.length }}</li>
          </ul>
        </div>

        <button @click="clearData" class="danger-button">
          清除所有数据
        </button>
      </div>
    </div>
  </div>
</template>

<style scoped>
.settings-view {
  min-height: calc(100vh - 56px);
  padding: 16px;
  background: var(--color-surface-secondary);
}

.settings-container {
  max-width: 600px;
  margin: 0 auto;
}

.settings-header {
  margin-bottom: 24px;
}

.settings-header h1 {
  margin: 0;
  font-size: 28px;
  font-weight: 600;
  color: var(--color-text-primary);
}

.settings-section {
  background: var(--color-surface);
  border-radius: 12px;
  padding: 24px;
  margin-bottom: 20px;
  box-shadow: 0 1px 3px var(--shadow-light);
  border: 1px solid var(--color-border);
}

.settings-section h2 {
  margin: 0 0 20px 0;
  font-size: 20px;
  font-weight: 600;
  color: var(--color-text-primary);
  border-bottom: 2px solid var(--color-primary);
  padding-bottom: 8px;
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
  font-size: 16px;
  font-weight: 500;
  color: var(--color-text-primary);
}

.form-input {
  width: 100%;
  padding: 12px 16px;
  border: 2px solid var(--color-input-border);
  border-radius: 8px;
  font-size: 16px;
  box-sizing: border-box;
  transition: border-color 0.2s;
  background: var(--color-input-background);
  color: var(--color-text-primary);
}

.form-input:focus {
  outline: none;
  border-color: var(--color-input-focus);
  box-shadow: 0 0 0 3px rgba(0, 123, 255, 0.1);
}

.help-text {
  margin-top: 6px;
  font-size: 14px;
  color: var(--color-text-secondary);
  line-height: 1.4;
}

.button-group {
  display: flex;
  gap: 12px;
  margin-bottom: 16px;
}

.test-button,
.save-button {
  padding: 12px 24px;
  border-radius: 8px;
  font-size: 16px;
  font-weight: 500;
  cursor: pointer;
  transition: all 0.2s;
  border: none;
}

.test-button {
  background: var(--color-info);
  color: white;
  flex: 1;
}

.test-button:hover:not(:disabled) {
  opacity: 0.9;
}

.save-button {
  background: var(--color-primary);
  color: white;
  flex: 1;
}

.save-button:hover:not(:disabled) {
  background: var(--color-primary-hover);
}

.test-button:disabled,
.save-button:disabled {
  background: var(--color-border);
  color: var(--color-text-muted);
  cursor: not-allowed;
}

.test-result {
  padding: 12px 16px;
  border-radius: 8px;
  font-size: 14px;
  font-weight: 500;
  background: var(--color-validation-valid);
  color: var(--color-validation-valid-text);
  border: 1px solid var(--color-validation-valid-border);
}

.test-result.error {
  background: var(--color-validation-invalid);
  color: var(--color-validation-invalid-text);
  border-color: var(--color-validation-invalid-border);
}

.usage-info ol {
  padding-left: 20px;
}

.usage-info li {
  margin-bottom: 16px;
}

.usage-info li:last-child {
  margin-bottom: 0;
}

.usage-info strong {
  color: var(--color-text-primary);
}

.usage-info p {
  margin: 4px 0 0 0;
  color: var(--color-text-secondary);
  line-height: 1.5;
}

.usage-info a {
  color: var(--color-primary);
  text-decoration: none;
}

.usage-info a:hover {
  text-decoration: underline;
}

.data-info {
  margin-bottom: 20px;
}

.data-info p {
  margin: 0 0 12px 0;
  color: var(--color-text-secondary);
  line-height: 1.5;
}

.data-info ul {
  margin: 8px 0 0 20px;
  color: var(--color-text-secondary);
}

.data-info li {
  margin-bottom: 4px;
}

.danger-button {
  padding: 12px 24px;
  border-radius: 8px;
  font-size: 16px;
  font-weight: 500;
  cursor: pointer;
  transition: all 0.2s;
  border: none;
  background: var(--color-danger);
  color: white;
}

.danger-button:hover {
  background: var(--color-danger-hover);
}

@media (max-width: 768px) {
  .settings-view {
    padding: 12px;
  }

  .settings-section {
    padding: 20px;
  }

  .button-group {
    flex-direction: column;
  }

  .test-button,
  .save-button {
    flex: none;
  }
}
</style>