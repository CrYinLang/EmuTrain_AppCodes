import { createRouter, createWebHistory } from 'vue-router'

const routes = [
  {
    path: '/',
    name: 'Home',
    component: () => import('../views/HomeView.vue'),
  },
  {
    path: '/search',
    name: 'Search',
    component: () => import('../views/SearchView.vue'),
  },
  {
    path: '/tools',
    name: 'Tools',
    component: () => import('../views/ToolsView.vue'),
  },
  {
    path: '/settings',
    name: 'Settings',
    component: () => import('../views/SettingsView.vue'),
  },
  {
    path: '/station',
    name: 'StationScreen',
    component: () => import('../views/StationScreenView.vue'),
  },
  {
    path: '/gallery',
    name: 'Gallery',
    component: () => import('../views/GalleryView.vue'),
  },
  {
    path: '/links',
    name: 'Links',
    component: () => import('../views/LinksView.vue'),
  },
]

const router = createRouter({
  history: createWebHistory(),
  routes,
})

export default router
