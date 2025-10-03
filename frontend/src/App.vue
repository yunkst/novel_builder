<script setup lang="ts">
import { onMounted } from 'vue'
import { useAppStore } from '@/stores/app'

const appStore = useAppStore()

onMounted(() => {
  appStore.loadAllData()
})
</script>

<template>
  <div id="app">
    <nav style="background: var(--color-surface); box-shadow: 0 1px 3px var(--shadow-light); border-bottom: 1px solid var(--color-border);">
      <div style="max-width: 28rem; margin: 0 auto; padding: 0 1rem;">
        <div style="display: flex; justify-content: space-between; align-items: center; height: 3.5rem;">
          <router-link to="/" style="font-size: 1.25rem; font-weight: 700; color: var(--color-text-primary); text-decoration: none;">
            小说创作
          </router-link>
          <router-link to="/settings" style="color: var(--color-text-secondary); text-decoration: none;">
            设置
          </router-link>
        </div>
      </div>
    </nav>

    <main style="max-width: 28rem; margin: 0 auto;">
      <router-view />
    </main>

    <!-- 错误提示 -->
    <div v-if="appStore.error" style="position: fixed; top: 4rem; left: 50%; transform: translateX(-50%); z-index: 50;">
      <div style="background: var(--color-validation-invalid); border: 1px solid var(--color-validation-invalid-border); color: var(--color-validation-invalid-text); padding: 12px 16px; border-radius: 6px; box-shadow: 0 4px 6px var(--shadow-light);">
        <div style="display: flex; align-items: center; justify-content: space-between;">
          <span>{{ appStore.error }}</span>
          <button @click="appStore.clearError()" style="margin-left: 8px; background: none; border: none; color: var(--color-validation-invalid-text); cursor: pointer; font-size: 18px;">
            ×
          </button>
        </div>
      </div>
    </div>

  </div>
</template>

<style>
* {
  margin: 0;
  padding: 0;
  box-sizing: border-box;
}

body {
  font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', 'PingFang SC', 'Hiragino Sans GB', 'Microsoft YaHei', 'Helvetica Neue', Helvetica, Arial, sans-serif;
  line-height: 1.6;
  color: #333;
  background: var(--color-surface-secondary);
}

#app {
  font-family: inherit;
}

/* 基础样式重置 */
a {
  color: inherit;
  text-decoration: none;
}

button {
  font-family: inherit;
}

input, textarea {
  font-family: inherit;
}

/* 工具类 */
.min-h-screen { min-height: 100vh; }
.bg-gray-50 { background-color: var(--color-surface-secondary); }
.bg-white { background-color: var(--color-surface); }
.shadow-sm { box-shadow: 0 1px 2px 0 rgba(0, 0, 0, 0.05); }
.border-b { border-bottom: 1px solid #e9ecef; }
.max-w-md { max-width: 28rem; }
.mx-auto { margin-left: auto; margin-right: auto; }
.px-4 { padding-left: 1rem; padding-right: 1rem; }
.flex { display: flex; }
.justify-between { justify-content: space-between; }
.items-center { align-items: center; }
.h-14 { height: 3.5rem; }
.text-xl { font-size: 1.25rem; }
.font-bold { font-weight: 700; }
.text-gray-900 { color: var(--color-text-primary); }
.text-gray-600 { color: var(--color-text-secondary); }
.hover\:text-gray-900:hover { color: var(--color-text-primary); }
.w-6 { width: 1.5rem; }
.h-6 { height: 1.5rem; }
.fixed { position: fixed; }
.top-16 { top: 4rem; }
.left-1\/2 { left: 50%; }
.transform { transform: translateX(-50%); }
.z-50 { z-index: 50; }
.bg-red-100 { background-color: var(--color-validation-invalid); }
.border { border: 1px solid; }
.border-red-400 { border-color: var(--color-validation-invalid-border); }
.text-red-700 { color: var(--color-validation-invalid-text); }
.rounded { border-radius: 0.375rem; }
.shadow-lg { box-shadow: 0 10px 15px -3px rgba(0, 0, 0, 0.1); }
.ml-2 { margin-left: 0.5rem; }
.text-red-500 { color: #dc3545; }
.hover\:text-red-700:hover { color: #a71e2a; }
.w-4 { width: 1rem; }
.h-4 { height: 1rem; }
.inset-0 { top: 0; right: 0; bottom: 0; left: 0; }
.bg-black { background-color: black; }
.bg-opacity-50 { background-color: rgba(0, 0, 0, 0.5); }
.justify-center { justify-content: center; }
.rounded-lg { border-radius: 0.5rem; }
.p-6 { padding: 1.5rem; }
.space-x-3 > * + * { margin-left: 0.75rem; }
.animate-spin { animation: spin 1s linear infinite; }
.rounded-full { border-radius: 50%; }
.border-b-2 { border-bottom-width: 2px; }
.border-blue-500 { border-color: #007bff; }
.text-gray-700 { color: #495057; }

@keyframes spin {
  to { transform: rotate(360deg); }
}
</style>
