<template>
  <div class="app-shell" :class="'theme-' + settingsStore.theme">
    <header v-if="route.name !== 'Search'" class="app-bar">
      <button v-if="isSubPage" class="back-btn" @click="router.back()">
        <Icon name="arrow_back" :size="22" />
      </button>
      <h1 class="app-bar-title">{{ currentTitle }}</h1>
    </header>

    <main class="app-content" :class="{ 'no-bar': route.name === 'Search' }">
      <router-view />
    </main>

    <nav class="bottom-nav">
      <button
        v-for="tab in tabs"
        :key="tab.name"
        :class="{ active: isActive(tab.name) }"
        @click="router.push(tab.path)"
      >
        <Icon :name="isActive(tab.name) ? tab.iconFill : tab.icon" :size="24" :fill="isActive(tab.name)" />
        <span class="nav-label">{{ tab.label }}</span>
      </button>
    </nav>
  </div>
</template>

<script setup>
import { computed, onMounted } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import Icon from '../components/Icon.vue'
import { useSettingsStore } from '../stores/settings'

const route = useRoute()
const router = useRouter()
const settingsStore = useSettingsStore()

const tabs = [
  { name: 'Home', path: '/', icon: 'train', iconFill: 'train', label: '旅行' },
  { name: 'Search', path: '/search', icon: 'search', iconFill: 'search', label: '搜索' },
  { name: 'Tools', path: '/tools', icon: 'handyman', iconFill: 'handyman', label: '其他' },
  { name: 'Settings', path: '/settings', icon: 'settings', iconFill: 'settings', label: '设置' },
]

const subPages = ['StationScreen', 'Gallery', 'Links']
const isSubPage = computed(() => subPages.includes(route.name))

const titleMap = {
  Home: '车次查询',
  Search: '动车组查询',
  Gallery: '动车图鉴',
  StationScreen: '车站大屏',
  Tools: '其他',
  Settings: '设置',
  Links: '友情链接',
}

const currentTitle = computed(() => titleMap[route.name] || 'EmuTrain')

function isActive(name) {
  return route.name === name
}

onMounted(() => {
  // 启动时加载所有设置
  settingsStore.load()
})
</script>

<style scoped>
.app-shell {
  display: flex;
  flex-direction: column;
  height: 100%;
  overflow: hidden;
}

.app-bar {
  height: 52px;
  min-height: 52px;
  display: flex;
  align-items: center;
  padding: 0 8px 0 4px;
  background: var(--surface);
  border-bottom: 1px solid var(--border);
  flex-shrink: 0;
  gap: 4px;
}
.back-btn {
  background: none; border: none; color: var(--text);
  padding: 8px; border-radius: 50%;
  display: flex; align-items: center; justify-content: center;
}
.back-btn:hover { background: var(--primary-dim); }
.app-bar-title { font-size: 1.05rem; font-weight: 500; margin: 0; }

.app-content {
  flex: 1; overflow-y: auto; overflow-x: hidden;
  padding: 12px; -webkit-overflow-scrolling: touch;
}
.app-content.no-bar { padding: 0; }

.bottom-nav {
  display: flex; height: 64px;
  background: var(--surface); border-top: 1px solid var(--border); flex-shrink: 0;
}
.bottom-nav button {
  flex: 1; display: flex; flex-direction: column;
  align-items: center; justify-content: center; gap: 2px;
  background: none; border: none; color: var(--text-dim);
  cursor: pointer; position: relative; transition: color 0.15s;
}
.bottom-nav button.active { color: var(--primary); }
.bottom-nav button.active::before {
  content: ''; position: absolute; top: 0; left: 20%; right: 20%;
  height: 3px; background: var(--primary); border-radius: 0 0 3px 3px;
}
.nav-label { font-size: 0.68rem; font-weight: 500; }
</style>
