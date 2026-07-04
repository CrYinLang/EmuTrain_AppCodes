<template>
  <div class="links-page">
    <div class="link-card" v-for="link in links" :key="link.title">
      <a :href="link.url" target="_blank" rel="noopener" class="link-item">
        <img v-if="link.icon" :src="link.icon" :alt="link.title" class="link-icon" @error="(e) => e.target.style.display='none'" />
        <Icon v-else name="link" :size="24" color="var(--primary)" />
        <div class="link-info">
          <div class="link-title">{{ link.title }}</div>
          <div class="link-desc">{{ link.desc }}</div>
        </div>
        <Icon name="open_in_new" :size="16" color="var(--text-dim)" />
      </a>
    </div>
  </div>
</template>

<script setup>
import Icon from '../components/Icon.vue'

const links = [
  {
    title: '路路通',
    desc: '列车时刻查询',
    icon: '/assets/icon/llt.png',
    url: 'https://www.114piaowu.com/',
  },
  {
    title: 'RailGo',
    desc: '动车组数据查询',
    icon: '/assets/icon/railgo.png',
    url: 'https://emu.data.railgo.zenglingkun.cn/',
  },
  {
    title: 'Rail.re',
    desc: '列车实时追踪',
    icon: '/assets/icon/railre.png',
    url: 'https://rail.re/',
  },
  {
    title: 'MoeFactory',
    desc: '动车组数据查询',
    icon: '/assets/icon/moefactory.png',
    url: 'https://rail.moefactory.com/',
  },
  {
    title: '中国动车组百科',
    desc: 'china-emu.cn',
    icon: null,
    url: 'https://china-emu.cn/',
  },
]
</script>

<style scoped>
.links-page { display: flex; flex-direction: column; gap: 8px; }
.link-card {
  background: var(--surface);
  border: 1px solid var(--border);
  border-radius: 10px;
  overflow: hidden;
}
.link-item {
  display: flex;
  align-items: center;
  gap: 12px;
  padding: 14px;
  text-decoration: none;
  color: var(--text);
}
.link-item:hover { background: var(--primary-dim); }
.link-icon {
  width: 36px;
  height: 36px;
  border-radius: 8px;
  object-fit: contain;
  flex-shrink: 0;
}
.link-info { flex: 1; min-width: 0; }
.link-title { font-size: 0.95rem; font-weight: 500; }
.link-desc { font-size: 0.78rem; color: var(--text-dim); margin-top: 1px; }
</style>
