<template>
  <div class="tools-page">
    <div class="card-list">
      <div class="tool-card" @click="$router.push('/station')">
        <Icon name="tv" :size="28" color="var(--primary)" />
        <div class="tool-info">
          <div class="tool-title">车站大屏</div>
          <div class="tool-desc">查看车站实时信息</div>
        </div>
        <Icon name="chevron_right" :size="20" color="var(--text-dim)" />
      </div>

      <div class="tool-card" @click="$router.push('/gallery')">
        <Icon name="auto_stories" :size="28" color="var(--primary)" />
        <div class="tool-info">
          <div class="tool-title">动车图鉴</div>
          <div class="tool-desc">精选了一批特殊的列车</div>
        </div>
        <Icon name="chevron_right" :size="20" color="var(--text-dim)" />
      </div>

      <div class="tool-card" @click="$router.push('/links')">

        <Icon name="link" :size="28" color="var(--primary)" />
        <div class="tool-info">
          <div class="tool-title">友情链接</div>
          <div class="tool-desc">推荐使用的APP</div>
        </div>
        <Icon name="chevron_right" :size="20" color="var(--text-dim)" />
      </div>
    </div>
  </div>
</template>

<script setup>
import Icon from '../components/Icon.vue'
</script>

<style scoped>
.tools-page {
  padding: 0;
}
.card-list {
  display: flex;
  flex-direction: column;
  gap: 10px;
}
.tool-card {
  display: flex;
  align-items: center;
  gap: 14px;
  background: var(--surface);
  border: 1px solid var(--border);
  border-radius: 12px;
  padding: 16px;
  cursor: pointer;
  transition: border-color 0.15s, transform 0.1s;
}
.tool-card:hover {
  border-color: var(--primary);
}
.tool-card:active {
  transform: scale(0.99);
}
.tool-info {
  flex: 1;
}
.tool-title {
  font-size: 1rem;
  font-weight: 500;
}
.tool-desc {
  font-size: 0.8rem;
  color: var(--text-dim);
  margin-top: 2px;
}
</style>
