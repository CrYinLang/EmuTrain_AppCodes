<template>
  <div class="search-page">
    <!-- 搜索栏 -->
    <div class="search-header">
      <div class="search-bar">
        <button class="search-btn" @click="doSearch" :disabled="loading">
          <Icon name="search" :size="22" />
        </button>
        <input
          v-model="query"
          :placeholder="placeholder"
          @keyup.enter="doSearch"
        />
      </div>

      <!-- 搜索类型芯片 -->
      <div class="type-chips">
        <button
          v-for="t in searchTypes"
          :key="t.value"
          class="type-chip"
          :class="{ active: searchType === t.value }"
          @click="switchType(t.value)"
        >
          {{ t.label }}
        </button>
      </div>

      <!-- 快捷芯片（动态获取） -->
      <div v-if="showQuickChips" class="quick-section">
        <p class="qs-title">{{ quickTitle }}</p>
        <div class="qs-chips">
          <button
            v-for="item in quickItems"
            :key="item"
            class="qs-chip"
            @click="query = item; doSearch()"
          >{{ item }}</button>
        </div>
      </div>
    </div>

    <!-- 错误 -->
    <div v-if="error" class="error-card">
      <span>{{ error }}</span>
      <button @click="error = ''">×</button>
    </div>

    <!-- 加载 -->
    <div v-if="loading" class="loading">
      <div class="spinner"></div>
    </div>

    <!-- 结果 -->
    <div v-if="results.length" class="results">
      <div class="results-count">
        共 {{ totalCount }} 条结果
        <span v-if="totalPages > 1"> · {{ currentPage }}/{{ totalPages }} 页</span>
      </div>

      <div v-for="(item, i) in results" :key="i" class="result-card" @click="onCardClick(item)">
        <div class="rc-header">
          <img
            v-if="item.iconPath"
            :src="'/assets/' + item.iconPath"
            class="rc-icon"
          />
          <div v-else class="rc-icon-placeholder">
            <Icon name="train" :size="20" />
          </div>
          <div class="rc-title">
            <span class="rc-number">{{ item.model }}-{{ item.number }}</span>
          </div>
          <img
            v-if="item.bureauIconPath"
            :src="'/assets/' + item.bureauIconPath"
            class="rc-bureau-icon"
          />
        </div>

        <div class="rc-details">
          <div v-if="item.bureauFullName && !isPaginated" class="rc-row">
            <span class="rc-label">配属路局</span>
            <span>{{ item.bureauFullName }}</span>
          </div>
          <div v-if="item.depot" class="rc-row">
            <span class="rc-label">配属动车所</span>
            <span>{{ item.depot }}</span>
          </div>
          <div v-if="item.manufacturer" class="rc-row">
            <span class="rc-label">生产厂家</span>
            <span>{{ item.manufacturer }}</span>
          </div>
          <div v-if="item.remarks" class="rc-row">
            <span class="rc-label">备注</span>
            <span class="rc-remarks">{{ item.remarks }}</span>
          </div>
        </div>

        <div v-if="item.routeInfo" class="rc-route">
          <div v-for="(line, li) in item.routeInfo.split('\n')" :key="li">{{ line }}</div>
        </div>

        <div class="rc-footer">
          <span class="rc-time">{{ item.queryTime }}</span>
        </div>
      </div>

      <!-- 分页 -->
      <div v-if="totalPages > 1" class="pagination">
        <button :disabled="currentPage <= 1" @click="goPage(currentPage - 1)">上一页</button>
        <span>{{ currentPage }} / {{ totalPages }}</span>
        <button :disabled="currentPage >= totalPages" @click="goPage(currentPage + 1)">下一页</button>
      </div>

    </div>

    <!-- 空 -->
    <div v-else-if="searched && !loading && !error" class="empty">
      <Icon name="search_off" :size="40" color="var(--text-dim)" />
      <p>未找到匹配结果</p>
    </div>
  </div>
</template>

<script setup>
import { ref, computed, onMounted } from 'vue'
import Icon from '../components/Icon.vue'
import { searchEmu, getBureaus, getDepots, getTypes } from '../api/train'

const query = ref('')
const searchType = ref('trainId')
const loading = ref(false)
const error = ref('')
const searched = ref(false)
const results = ref([])
const currentPage = ref(1)
const totalPages = ref(1)
const totalCount = ref(0)

// 动态快捷数据
const bureauList = ref([])
const depotList = ref([])
const typeList = ref([])

const searchTypes = [
  { value: 'trainId', label: '车号' },
  { value: 'bureau', label: '路局' },
  { value: 'carType', label: '车型' },
  { value: 'depot', label: '动车所' },
]

const isPaginated = computed(() => ['bureau', 'carType', 'depot'].includes(searchType.value))

const placeholder = computed(() => {
  const map = {
    trainId: '输入车组号查询，如 3001',
    bureau: '输入路局名称，如 上海',
    carType: '输入车型代号，如 CR400AF',
    depot: '输入动车所名称，如 北京南',
  }
  return map[searchType.value] || '输入查询内容'
})

// 快捷芯片
const showQuickChips = computed(() => {
  if (results.value.length) return false
  if (searchType.value === 'bureau' && bureauList.value.length) return true
  if (searchType.value === 'carType' && typeList.value.length) return true
  if (searchType.value === 'depot' && depotList.value.length) return true
  return false
})

const quickTitle = computed(() => {
  const map = { bureau: '常用路局', carType: '常见车型', depot: '常见动车所' }
  return map[searchType.value] || ''
})

const quickItems = computed(() => {
  if (searchType.value === 'bureau') return bureauList.value
  if (searchType.value === 'carType') return typeList.value
  if (searchType.value === 'depot') return depotList.value
  return []
})

// 加载快捷数据
onMounted(async () => {
  try {
    const [b, d, t] = await Promise.all([getBureaus(), getDepots(), getTypes()])
    bureauList.value = b || []
    depotList.value = d || []
    typeList.value = t || []
  } catch {}
})

function switchType(type) {
  // 切换类型时不清除结果，只切换显示
  searchType.value = type
}

async function doSearch() {
  const q = query.value.trim()
  if (!q) return

  // 自动判断搜索类型
  let type = searchType.value
  if (type === 'trainId') {
    const looksLikeModel = /^[A-Za-z]/.test(q) || q.includes('-')
    if (looksLikeModel) type = 'carType'
  }

  loading.value = true
  error.value = ''
  searched.value = true
  results.value = []

  try {
    let data = await searchEmu({ input: q, type, page: currentPage.value })

    // 车号无结果且含字母，自动用车型再搜
    if ((!data.results || !data.results.length) && type === 'trainId' && /[a-zA-Z]/.test(q)) {
      data = await searchEmu({ input: q, type: 'carType', page: currentPage.value })
    }

    results.value = data.results || []
    totalCount.value = data.total || 0
    totalPages.value = data.totalPages || 0
    currentPage.value = data.page || 1
  } catch (e) {
    error.value = '查询失败: ' + (e.message || e)
    results.value = []
  } finally {
    loading.value = false
  }
}

function goPage(page) {
  currentPage.value = page
  doSearch()
}

function onCardClick(item) {
  const code = item.trainCodeForJourney || item.number
  if (code) window.open(`https://rail.re/#${code}`, '_blank')
}
</script>

<style scoped>
.search-page {
  display: flex;
  flex-direction: column;
  height: 100%;
}

.search-header {
  background: var(--surface);
  padding: 12px 16px 8px;
  border-bottom: 1px solid var(--border);
  position: sticky;
  top: 0;
  z-index: 10;
}

.search-bar {
  display: flex;
  align-items: center;
  background: var(--bg);
  border: 1px solid var(--border);
  border-radius: 28px;
  padding: 0 16px;
  height: 48px;
}
.search-btn {
  background: none; border: none; color: var(--text-dim);
  padding: 4px; display: flex; align-items: center; cursor: pointer;
}
.search-bar input {
  flex: 1; border: none; background: transparent; color: var(--text);
  font-size: 0.95rem; outline: none; padding: 0 12px; min-width: 0;
}
.search-bar input::placeholder { color: var(--text-dim); }

.type-chips {
  display: flex; gap: 8px; margin-top: 12px;
  overflow-x: auto; -webkit-overflow-scrolling: touch;
  scrollbar-width: none;
}
.type-chips::-webkit-scrollbar { display: none; }
.type-chip {
  padding: 6px 16px; border: 1px solid var(--border); border-radius: 20px;
  background: none; color: var(--text-dim); font-size: 0.85rem;
  white-space: nowrap; cursor: pointer; transition: all 0.15s;
}
.type-chip.active {
  background: var(--primary); border-color: var(--primary);
  color: #fff; font-weight: 500;
}

.quick-section { margin-top: 16px; }
.qs-title { font-size: 0.8rem; color: var(--text-dim); margin-bottom: 8px; }
.qs-chips { display: flex; flex-wrap: wrap; gap: 6px; }
.qs-chip {
  padding: 6px 14px; border: 1px solid var(--border); border-radius: 20px;
  background: none; color: var(--text); font-size: 0.82rem; cursor: pointer;
}
.qs-chip:hover { border-color: var(--primary); color: var(--primary); }

.error-card {
  margin: 12px 16px; padding: 12px;
  background: rgba(255,107,107,0.1); border: 1px solid rgba(255,107,107,0.3);
  border-radius: 8px; color: var(--error);
  display: flex; align-items: center; gap: 8px; font-size: 0.85rem;
}
.error-card span { flex: 1; }
.error-card button { background: none; border: none; color: var(--error); font-size: 1.2rem; cursor: pointer; }

.loading { display: flex; justify-content: center; padding: 40px; }
.spinner {
  width: 24px; height: 24px; border: 2px solid var(--border);
  border-top-color: var(--primary); border-radius: 50%;
  animation: spin 0.8s linear infinite;
}
@keyframes spin { to { transform: rotate(360deg); } }

.results { flex: 1; overflow-y: auto; padding: 12px 16px; }
.results-count { font-size: 0.8rem; color: var(--text-dim); margin-bottom: 12px; }

.result-card {
  background: var(--surface); border-radius: 12px; padding: 14px;
  margin-bottom: 12px; cursor: pointer; border: 1px solid var(--border);
  transition: border-color 0.15s;
}
.result-card:hover { border-color: var(--primary); }

.rc-header { display: flex; align-items: center; gap: 10px; margin-bottom: 10px; }
.rc-icon {
  width: 40px; height: 40px; border-radius: 6px; object-fit: contain; flex-shrink: 0;
}
.rc-icon-placeholder {
  width: 40px; height: 40px; border-radius: 6px; background: var(--bg);
  border: 1px solid var(--border); display: flex; align-items: center;
  justify-content: center; color: var(--text-dim); flex-shrink: 0;
}
.rc-title { flex: 1; min-width: 0; }
.rc-number { font-size: 1.1rem; font-weight: 700; }
.rc-bureau-icon {
  width: 28px; height: 28px; border-radius: 4px; object-fit: contain; flex-shrink: 0;
}

.rc-details { display: flex; flex-direction: column; gap: 4px; margin-bottom: 8px; }
.rc-row { display: flex; font-size: 0.85rem; line-height: 1.4; }
.rc-label { color: var(--text-dim); min-width: 70px; flex-shrink: 0; }
.rc-remarks { color: #f0a030; }

.rc-route {
  background: var(--primary-dim); border-radius: 6px; padding: 8px 10px;
  margin-bottom: 8px; font-size: 0.85rem; line-height: 1.6;
}

.rc-footer { display: flex; justify-content: space-between; align-items: center; }
.rc-time { font-size: 0.72rem; color: var(--text-dim); }

.pagination {
  display: flex; align-items: center; justify-content: center;
  gap: 16px; padding: 16px; font-size: 0.9rem;
}
.pagination button {
  padding: 8px 16px; border: 1px solid var(--border); border-radius: 8px;
  background: none; color: var(--text); cursor: pointer;
}
.pagination button:disabled { opacity: 0.4; cursor: not-allowed; }

.empty {
  display: flex; flex-direction: column; align-items: center; gap: 10px;
  color: var(--text-dim); padding: 50px 0;
}
</style>
