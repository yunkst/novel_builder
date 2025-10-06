import { createRouter, createWebHistory } from 'vue-router'

const router = createRouter({
  history: createWebHistory(import.meta.env.BASE_URL),
  routes: [
    {
      path: '/',
      name: 'home',
      component: () => import('@/views/HomeView.vue')
    },
    {
      path: '/chapters/:novelId',
      name: 'chapters',
      component: () => import('@/views/ChaptersView.vue'),
      props: true
    },
    {
      path: '/characters/:novelId',
      name: 'characters',
      component: () => import('@/views/CharactersView.vue'),
      props: true
    },
    {
      path: '/writing/:novelId',
      name: 'writing',
      component: () => import('@/views/WritingView.vue'),
      props: true
    },
    {
      path: '/settings',
      name: 'settings',
      component: () => import('@/views/SettingsView.vue')
    },
    {
      path: '/templates',
      name: 'templates',
      component: () => import('@/views/TemplatesView.vue')
    },
    {
      path: '/novel/:id',
      name: 'novel',
      component: () => import('@/views/NovelView.vue'),
      props: true
    }
  ]
})

export default router
