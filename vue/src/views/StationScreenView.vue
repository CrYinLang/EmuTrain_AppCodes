<template>
  <div class="station-page">
    <!-- 选择车站 -->
    <div class="station-bar">
      <button class="station-select" @click="selectStation">
        <Icon name="location_on" :size="16" color="var(--primary)" />
        <span>{{ stationName }}</span>
        <Icon name="arrow_drop_down" :size="16" />
      </button>
      <div class="direction-tabs">
        <button :class="{ active: direction === 0 }" @click="changeDirection(0)">全部</button>
        <button :class="{ active: direction === 1 }" @click="changeDirection(1)">出发</button>
        <button :class="{ active: direction === 2 }" @click="changeDirection(2)">到达</button>
      </div>
    </div>

    <!-- 加载 -->
    <div v-if="loading" class="loading">
      <div class="spinner"></div>
      <span>加载中...</span>
    </div>

    <!-- 列表 -->
    <div v-if="trains.length" class="train-list">
      <div v-for="(t, i) in trains" :key="i" class="train-row">
        <div class="tr-code">{{ t.trainCode }}</div>
        <div class="tr-route">
          <span class="tr-from">{{ t.from }}</span>
          <Icon name="arrow_forward" :size="12" color="var(--text-dim)" />
          <span class="tr-to">{{ t.to }}</span>
        </div>
        <div class="tr-times">
          <span v-if="t.arriveTime" class="tr-arrive">{{ t.arriveTime }}</span>
          <span v-if="t.leaveTime" class="tr-leave">{{ t.leaveTime }}</span>
        </div>
      </div>

      <!-- 分页 -->
      <div v-if="totalPages > 1" class="pagination">
        <button :disabled="page <= 1" @click="goPage(page - 1)">
          <Icon name="chevron_left" :size="18" />
        </button>
        <span>{{ page }} / {{ totalPages }}</span>
        <button :disabled="page >= totalPages" @click="goPage(page + 1)">
          <Icon name="chevron_right" :size="18" />
        </button>
      </div>
    </div>

    <div v-else-if="!loading && searched" class="empty">
      <Icon name="tv" :size="40" color="var(--text-dim)" />
      <p>暂无数据</p>
    </div>

    <div v-else-if="!loading && !searched" class="empty">
      <Icon name="tv" :size="40" color="var(--text-dim)" />
      <p>请选择车站查看实时信息</p>
    </div>
  </div>
</template>

<script setup>
import { ref } from 'vue'
import Icon from '../components/Icon.vue'
import { getStationScreen } from '../api/train'

const stationName = ref('选择车站')
const stationCode = ref('')
const direction = ref(0)
const loading = ref(false)
const searched = ref(false)
const trains = ref([])
const page = ref(1)
const totalPages = ref(1)

function selectStation() {
  const name = prompt('输入车站名（如 北京）')
  if (!name) return
  fetch(`/api/station/search?keyword=${encodeURIComponent(name)}&limit=1`)
    .then(r => r.json())
    .then(data => {
      if (data.length) {
        stationName.value = data[0].name
        stationCode.value = data[0].telecode
        loadData()
      } else {
        alert('未找到车站')
      }
    })
}

function changeDirection(d) {
  direction.value = d
  page.value = 1
  if (stationCode.value) loadData()
}

function goPage(p) {
  page.value = p
  loadData()
}

async function loadData() {
  if (!stationCode.value) return
  loading.value = true
  searched.value = true
  try {
    const data = await getStationScreen({
      stationCode: stationCode.value,
      stationName: stationName.value,
      date: new Date().toISOString().slice(0, 10),
      direction: direction.value,
      page: page.value,
    })
    trains.value = data.data || []
    totalPages.value = data.totalPages || 1
  } catch (e) {
    trains.value = []
  } finally {
    loading.value = false
  }
}
</script>

<style scoped>
.station-page { display: flex; flex-direction: column; gap: 10px; }

.station-bar {
  background: var(--surface);
  border: 1px solid var(--border);
  border-radius: 10px;
  padding: 10px 12px;
  display: flex;
  flex-direction: column;
  gap: 8px;
}
.station-select {
  display: flex;
  align-items: center;
  gap: 6px;
  background: var(--bg);
  border: 1px solid var(--border);
  border-radius: 8px;
  padding: 10px 12px;
  color: var(--text);
  font-size: 0.95rem;
  cursor: pointer;
}
.direction-tabs {
  display: flex;
  gap: 0;
  border: 1px solid var(--border);
  border-radius: 8px;
  overflow: hidden;
}
.direction-tabs button {
  flex: 1;
  padding: 7px;
  background: none;
  border: none;
  color: var(--text-dim);
  font-size: 0.82rem;
  cursor: pointer;
}
.direction-tabs button.active {
  background: var(--primary-dim);
  color: var(--primary);
  font-weight: 600;
}

.loading {
  display: flex; align-items: center; justify-content: center; gap: 8px;
  padding: 30px; color: var(--text-dim);
}
.spinner {
  width: 20px; height: 20px;
  border: 2px solid var(--border); border-top-color: var(--primary);
  border-radius: 50%; animation: spin 0.8s linear infinite;
}
@keyframes spin { to { transform: rotate(360deg); } }

.train-list { display: flex; flex-direction: column; gap: 0; }
.train-row {
  display: flex;
  align-items: center;
  gap: 10px;
  padding: 10px 14px;
  background: var(--surface);
  border: 1px solid var(--border);
  border-radius: 0;
  border-bottom: none;
  font-size: 0.85rem;
}
.train-row:first-child { border-radius: 10px 10px 0 0; }
.train-row:last-child { border-bottom: 1px solid var(--border); border-radius: 0 0 10px 10px; }
.train-row:only-child { border-radius: 10px; border-bottom: 1px solid var(--border); }

.tr-code {
  font-weight: 600;
  min-width: 60px;
  color: var(--primary);
}
.tr-route {
  flex: 1;
  display: flex;
  align-items: center;
  gap: 6px;
  min-width: 0;
  overflow: hidden;
}
.tr-from, .tr-to {
  white-space: nowrap;
  overflow: hidden;
  text-overflow: ellipsis;
}
.tr-times {
  display: flex;
  gap: 8px;
  font-size: 0.82rem;
  flex-shrink: 0;
}
.tr-arrive { color: var(--success); }
.tr-leave { color: var(--primary); }

.pagination {
  display: flex; align-items: center; justify-content: center; gap: 14px;
  padding: 14px; font-size: 0.85rem;
}
.pagination button {
  padding: 6px 10px; border: 1px solid var(--border); border-radius: 6px;
  background: none; color: var(--text); cursor: pointer; display: flex; align-items: center;
}
.pagination button:disabled { opacity: 0.4; cursor: not-allowed; }

.empty {
  display: flex; flex-direction: column; align-items: center; gap: 10px;
  color: var(--text-dim); padding: 50px 0;
}
</style>
