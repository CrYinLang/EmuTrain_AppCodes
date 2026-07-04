<template>
  <div class="journey-page">
    <!-- 模式切换 -->
    <div class="mode-tabs">
      <button :class="{ active: mode === 'train' }" @click="mode = 'train'">
        <Icon name="train" :size="16" /> 车次查询
      </button>
      <button :class="{ active: mode === 'station' }" @click="mode = 'station'">
        <Icon name="location_on" :size="16" /> 车站查询
      </button>
    </div>

    <!-- 车次查询模式 -->
    <div v-if="mode === 'train'" class="search-area">
      <div class="row">
        <div class="date-picker" @click="pickDate">
          <Icon name="calendar_today" :size="16" />
          <span>{{ dateText }}</span>
        </div>
        <div class="train-input">
          <select v-model="trainPrefix" class="prefix-sel">
            <option v-for="p in prefixes" :key="p" :value="p">{{ p }}</option>
          </select>
          <input
            v-model="trainNumber"
            placeholder="车次号"
            @keyup.enter="searchTrain"
            inputmode="numeric"
          />
        </div>
        <button class="search-btn" @click="searchTrain" :disabled="loading">
          <Icon name="search" :size="20" />
        </button>
      </div>
    </div>

    <!-- 车站查询模式 -->
    <div v-else class="search-area">
      <div class="row">
        <div class="date-picker" @click="pickDate">
          <Icon name="calendar_today" :size="16" />
          <span>{{ dateText }}</span>
        </div>
      </div>
      <div class="station-row">
        <div class="station-input" @click="selectStation('from')">
          <Icon name="trip_origin" :size="14" color="var(--success)" />
          <span :class="{ placeholder: !fromName }">{{ fromName || '出发站' }}</span>
        </div>
        <button class="swap-btn" @click="swapStations">
          <Icon name="swap_horiz" :size="18" />
        </button>
        <div class="station-input" @click="selectStation('to')">
          <Icon name="location_on" :size="14" color="var(--error)" />
          <span :class="{ placeholder: !toName }">{{ toName || '到达站' }}</span>
        </div>
        <button class="search-btn" @click="searchStation" :disabled="loading">
          <Icon name="search" :size="20" />
        </button>
      </div>

      <!-- 车型筛选 -->
      <div v-if="stationResults.length" class="filter-row">
        <button
          v-for="(active, type) in trainTypeFilters"
          :key="type"
          class="filter-chip"
          :class="{ active }"
          @click="toggleFilter(type)"
        >{{ type }}</button>
      </div>
    </div>

    <!-- 错误 -->
    <div v-if="error" class="error-card">
      <Icon name="error" :size="16" color="var(--error)" />
      <span>{{ error }}</span>
      <button @click="error = ''"><Icon name="close" :size="14" /></button>
    </div>

    <!-- 加载 -->
    <div v-if="loading" class="loading">
      <div class="spinner"></div>
      <span>查询中...</span>
    </div>

    <!-- 车次查询结果 -->
    <div v-if="mode === 'train' && trainResults.length" class="results">
      <div v-for="(train, i) in trainResults" :key="i" class="train-card">
        <div class="train-card-header" @click="toggleTrainDetail(i)">
          <div class="train-info">
            <span class="train-code-tag">{{ trainPrefix + trainNumber }}</span>
            <span class="train-route" v-if="train.from_station || train.station_train_code">
              {{ train.from_station }} → {{ train.to_station }}
            </span>
          </div>
          <Icon :name="expandedTrain === i ? 'expand_less' : 'expand_more'" :size="20" />
        </div>

        <!-- 经停详情 -->
        <div v-if="expandedTrain === i" class="stop-list">
          <div v-if="trainLoading[i]" class="loading-inline">
            <div class="spinner small"></div>
          </div>
          <div v-else-if="trainStops[i] && trainStops[i].length">
            <div v-for="(stop, si) in trainStops[i]" :key="si" class="stop-item">
              <div class="stop-index">{{ si + 1 }}</div>
              <div class="stop-line"></div>
              <div class="stop-info">
                <div class="stop-name">{{ stop.station_name }}</div>
                <div class="stop-times">
                  <span v-if="stop.arrive_time" class="time-arrive">
                    到 {{ stop.arrive_time }}
                  </span>
                  <span v-if="stop.leave_time" class="time-leave">
                    发 {{ stop.leave_time }}
                  </span>
                  <span v-if="stop.stop_duration" class="time-stop">
                    停 {{ stop.stop_duration }}
                  </span>
                  <span v-if="!stop.arrive_time && si === 0" class="time-start">始发</span>
                  <span v-if="!stop.leave_time && si === trainStops[i].length - 1" class="time-end">终到</span>
                </div>
              </div>
            </div>
          </div>
          <div v-else class="empty-stops">暂无经停信息</div>
        </div>
      </div>
    </div>

    <!-- 车站查询结果 -->
    <div v-if="mode === 'station' && stationResults.length" class="results">
      <div class="results-header">
        共 {{ filteredStationResults.length }} 趟列车
      </div>
      <div v-for="(train, i) in filteredStationResults" :key="i" class="station-train-card">
        <div class="stc-header">
          <span class="stc-code">{{ train.trainCode }}</span>
          <span class="stc-type" :class="getTrainTypeClass(train.trainCode)">{{ getTrainTypeName(train.trainCode) }}</span>
          <span class="stc-route">{{ train.from }} → {{ train.to }}</span>
        </div>
        <div class="stc-times">
          <div class="stc-time-item">
            <span class="stc-label">出发</span>
            <span class="stc-value">{{ train.leaveTime || '-' }}</span>
          </div>
          <div class="stc-time-item">
            <span class="stc-label">到达</span>
            <span class="stc-value">{{ train.arriveTime || '-' }}</span>
          </div>
          <div class="stc-time-item" v-if="train.dayAfter">
            <span class="stc-label">次日</span>
            <span class="stc-value">+{{ train.dayAfter }}天</span>
          </div>
        </div>
      </div>
    </div>

    <!-- 空状态 -->
    <div v-if="!loading && !error && searched && !trainResults.length && !stationResults.length" class="empty">
      <Icon name="search_off" :size="40" color="var(--text-dim)" />
      <p>未找到结果</p>
    </div>
  </div>
</template>

<script setup>
import { ref, computed, reactive, onMounted } from 'vue'
import Icon from '../components/Icon.vue'
import { getTrainStops, getStationScreen, searchByStation } from '../api/train'

const mode = ref('train')
const loading = ref(false)
const error = ref('')
const searched = ref(false)
const trainPrefix = ref('G')
const trainNumber = ref('')
const date = ref(new Date().toISOString().slice(0, 10))

const fromName = ref('')
const toName = ref('')
const fromCode = ref('')
const toCode = ref('')

const trainResults = ref([])
const trainStops = reactive({})
const trainLoading = reactive({})
const expandedTrain = ref(null)

const stationResults = ref([])
const trainTypeFilters = reactive({})

const prefixes = ['G', 'D', 'C', 'J', 'K', 'T', 'Z', 'L', '0']

const dateText = computed(() => date.value || '选择日期')

const filteredStationResults = computed(() => {
  let results = stationResults.value
  const activeFilters = Object.entries(trainTypeFilters).filter(([_, v]) => v).map(([k]) => k)
  if (activeFilters.length) {
    results = results.filter(r => {
      const prefix = (r.trainCode || '')[0]
      return activeFilters.includes(prefix)
    })
  }
  return results
})

function pickDate() {
  // 简单的日期选择 - 用 input[type=date]
  const input = document.createElement('input')
  input.type = 'date'
  input.value = date.value
  input.min = new Date(Date.now() - 2 * 86400000).toISOString().slice(0, 10)
  input.max = new Date(Date.now() + 14 * 86400000).toISOString().slice(0, 10)
  input.style.position = 'fixed'
  input.style.opacity = '0'
  document.body.appendChild(input)
  input.showPicker?.()
  input.addEventListener('change', () => {
    if (input.value) date.value = input.value
    document.body.removeChild(input)
  })
  input.addEventListener('blur', () => {
    document.body.removeChild(input)
  })
}

async function searchTrain() {
  const num = trainNumber.value.trim()
  if (!num) { error.value = '请输入车次号'; return }
  if (!date.value) { error.value = '请选择日期'; return }

  loading.value = true
  error.value = ''
  searched.value = true
  trainResults.value = []
  expandedTrain.value = null

  try {
    const fullCode = trainPrefix.value + num
    const data = await getTrainStops({ trainNumber: fullCode, date: date.value, source: 'ctrip' })
    if (data && data.length) {
      trainResults.value = [{ from_station: '', to_station: '', station_train_code: fullCode }]
      trainStops[0] = data
      expandedTrain.value = 0
    } else {
      // 尝试12306
      const data2 = await getTrainStops({ trainNumber: fullCode, date: date.value, source: '12306' })
      if (data2 && data2.length) {
        trainResults.value = [{ from_station: '', to_station: '', station_train_code: fullCode }]
        trainStops[0] = data2
        expandedTrain.value = 0
      } else {
        error.value = `未找到车次 ${fullCode} 的经停信息`
      }
    }
  } catch (e) {
    error.value = '查询失败: ' + (e.message || e)
  } finally {
    loading.value = false
  }
}

async function searchStation() {
  if (!fromCode.value && !toCode.value) {
    error.value = '请选择出发站或到达站'
    return
  }
  if (!date.value) { error.value = '请选择日期'; return }

  loading.value = true
  error.value = ''
  searched.value = true
  stationResults.value = []

  try {
    // 优先用 station-to-station 搜索
    if (fromCode.value && toCode.value) {
      const data = await searchByStation({
        fromStation: fromCode.value,
        toStation: toCode.value,
        date: date.value,
      })
      stationResults.value = data || []
    } else {
      // 只选了一个站，用车站大屏
      const data = await getStationScreen({
        stationCode: fromCode.value || toCode.value,
        date: date.value,
        direction: fromCode.value ? 1 : 2,
      })
      stationResults.value = data.data || []
    }

    // 构建车型筛选
    const types = {}
    for (const t of stationResults.value) {
      const prefix = (t.trainCode || '')[0]
      if (prefix) types[prefix] = types[prefix] ?? false
    }
    Object.assign(trainTypeFilters, types)

    if (!stationResults.value.length) {
      error.value = '未找到列车信息'
    }
  } catch (e) {
    error.value = '查询失败: ' + (e.message || e)
  } finally {
    loading.value = false
  }
}

async function toggleTrainDetail(index) {
  if (expandedTrain.value === index) {
    expandedTrain.value = null
    return
  }
  expandedTrain.value = index

  if (trainStops[index]) return

  trainLoading[index] = true
  try {
    const train = trainResults.value[index]
    const code = train.station_train_code || (trainPrefix.value + trainNumber.value)
    const data = await getTrainStops({ trainNumber: code, date: date.value, source: 'ctrip' })
    trainStops[index] = data || []
  } catch {
    trainStops[index] = []
  } finally {
    trainLoading[index] = false
  }
}

function toggleFilter(type) {
  trainTypeFilters[type] = !trainTypeFilters[type]
}

function swapStations() {
  const tmpName = fromName.value
  const tmpCode = fromCode.value
  fromName.value = toName.value
  fromCode.value = toCode.value
  toName.value = tmpName
  toCode.value = tmpCode
}

function selectStation(which) {
  // 简单的车站选择 - 用 prompt
  const name = prompt(which === 'from' ? '输入出发站名（如 北京）' : '输入到达站名（如 上海）')
  if (name) {
    // 查找车站编码
    fetch(`/api/station/search?keyword=${encodeURIComponent(name)}&limit=1`)
      .then(r => r.json())
      .then(data => {
        if (data.length) {
          if (which === 'from') {
            fromName.value = data[0].name
            fromCode.value = data[0].telecode
          } else {
            toName.value = data[0].name
            toCode.value = data[0].telecode
          }
        } else {
          error.value = `未找到车站 "${name}"`
        }
      })
      .catch(() => { error.value = '车站查询失败' })
  }
}

function getTrainTypeName(code) {
  const prefix = (code || '')[0]
  const map = { C: '城际', D: '动车', G: '高速', K: '快速', T: '特快', Z: '直达', Y: '旅游', L: '临客', S: '市域' }
  return map[prefix] || '普客'
}

function getTrainTypeClass(code) {
  const prefix = (code || '')[0]
  return 'type-' + (prefix || 'num').toLowerCase()
}
</script>

<style scoped>
.journey-page {
  display: flex;
  flex-direction: column;
  gap: 0;
}

/* 模式切换 */
.mode-tabs {
  display: flex;
  background: var(--surface);
  border-radius: 10px;
  overflow: hidden;
  margin-bottom: 10px;
  border: 1px solid var(--border);
}
.mode-tabs button {
  flex: 1;
  padding: 10px;
  background: none;
  border: none;
  color: var(--text-dim);
  font-size: 0.85rem;
  display: flex;
  align-items: center;
  justify-content: center;
  gap: 6px;
  cursor: pointer;
  transition: all 0.15s;
}
.mode-tabs button.active {
  background: var(--primary-dim);
  color: var(--primary);
  font-weight: 600;
}

/* 搜索区域 */
.search-area {
  background: var(--surface);
  border: 1px solid var(--border);
  border-radius: 10px;
  padding: 12px;
  margin-bottom: 10px;
}
.row {
  display: flex;
  gap: 8px;
  align-items: center;
}
.date-picker {
  display: flex;
  align-items: center;
  gap: 6px;
  padding: 8px 12px;
  background: var(--bg);
  border: 1px solid var(--border);
  border-radius: 8px;
  cursor: pointer;
  font-size: 0.85rem;
  white-space: nowrap;
}
.train-input {
  flex: 1;
  display: flex;
  background: var(--bg);
  border: 1px solid var(--border);
  border-radius: 8px;
  overflow: hidden;
}
.prefix-sel {
  padding: 8px 8px;
  background: transparent;
  border: none;
  border-right: 1px solid var(--border);
  color: var(--primary);
  font-size: 0.85rem;
  cursor: pointer;
}
.train-input input {
  flex: 1;
  padding: 8px 10px;
  border: none;
  background: transparent;
  color: var(--text);
  font-size: 0.9rem;
  outline: none;
  min-width: 0;
}
.search-btn {
  padding: 8px 14px;
  background: var(--primary);
  border: none;
  border-radius: 8px;
  color: #fff;
  cursor: pointer;
  display: flex;
  align-items: center;
}
.search-btn:disabled {
  opacity: 0.5;
}

/* 车站查询 */
.station-row {
  display: flex;
  gap: 6px;
  align-items: center;
  margin-top: 8px;
}
.station-input {
  flex: 1;
  display: flex;
  align-items: center;
  gap: 6px;
  padding: 10px 12px;
  background: var(--bg);
  border: 1px solid var(--border);
  border-radius: 8px;
  cursor: pointer;
  font-size: 0.9rem;
}
.station-input .placeholder {
  color: var(--text-dim);
}
.swap-btn {
  background: none;
  border: none;
  color: var(--text-dim);
  padding: 4px;
  cursor: pointer;
}

/* 筛选 */
.filter-row {
  display: flex;
  gap: 6px;
  flex-wrap: wrap;
  margin-top: 10px;
}
.filter-chip {
  padding: 4px 10px;
  border: 1px solid var(--border);
  border-radius: 20px;
  background: none;
  color: var(--text-dim);
  font-size: 0.75rem;
  cursor: pointer;
}
.filter-chip.active {
  background: var(--primary);
  border-color: var(--primary);
  color: #fff;
}

/* 错误 */
.error-card {
  margin: 8px 0;
  padding: 10px;
  background: rgba(255,107,107,0.1);
  border: 1px solid rgba(255,107,107,0.3);
  border-radius: 8px;
  color: var(--error);
  display: flex;
  align-items: center;
  gap: 8px;
  font-size: 0.85rem;
}
.error-card span { flex: 1; }
.error-card button {
  background: none;
  border: none;
  color: var(--error);
  cursor: pointer;
  display: flex;
}

.loading {
  display: flex;
  align-items: center;
  justify-content: center;
  gap: 8px;
  padding: 30px;
  color: var(--text-dim);
  font-size: 0.9rem;
}
.spinner {
  width: 20px;
  height: 20px;
  border: 2px solid var(--border);
  border-top-color: var(--primary);
  border-radius: 50%;
  animation: spin 0.8s linear infinite;
}
.spinner.small { width: 16px; height: 16px; }
@keyframes spin { to { transform: rotate(360deg); } }

/* 车次结果卡片 */
.results { display: flex; flex-direction: column; gap: 8px; }
.results-header {
  font-size: 0.8rem;
  color: var(--text-dim);
  padding: 0 2px 4px;
}
.train-card {
  background: var(--surface);
  border: 1px solid var(--border);
  border-radius: 10px;
  overflow: hidden;
}
.train-card-header {
  display: flex;
  align-items: center;
  justify-content: space-between;
  padding: 12px 14px;
  cursor: pointer;
}
.train-info {
  display: flex;
  align-items: center;
  gap: 10px;
}
.train-code-tag {
  background: var(--primary);
  color: #fff;
  padding: 2px 10px;
  border-radius: 4px;
  font-weight: 600;
  font-size: 0.9rem;
}
.train-route {
  font-size: 0.85rem;
  color: var(--text-dim);
}

/* 经停列表 */
.stop-list {
  border-top: 1px solid var(--border);
  padding: 8px 14px;
}
.loading-inline {
  display: flex;
  justify-content: center;
  padding: 16px;
}
.stop-item {
  display: flex;
  gap: 10px;
  position: relative;
  padding: 6px 0;
}
.stop-index {
  width: 22px;
  height: 22px;
  border-radius: 50%;
  background: var(--primary-dim);
  color: var(--primary);
  font-size: 0.7rem;
  font-weight: 600;
  display: flex;
  align-items: center;
  justify-content: center;
  flex-shrink: 0;
}
.stop-line {
  position: absolute;
  left: 10px;
  top: 28px;
  bottom: -6px;
  width: 2px;
  background: var(--border);
}
.stop-item:last-child .stop-line { display: none; }
.stop-info { flex: 1; min-width: 0; }
.stop-name {
  font-size: 0.9rem;
  font-weight: 500;
}
.stop-times {
  display: flex;
  gap: 10px;
  font-size: 0.78rem;
  color: var(--text-dim);
  margin-top: 2px;
}
.time-arrive { color: var(--success); }
.time-leave { color: var(--primary); }
.time-stop { color: var(--text-dim); }
.time-start { color: var(--success); font-weight: 500; }
.time-end { color: var(--error); font-weight: 500; }
.empty-stops {
  text-align: center;
  color: var(--text-dim);
  padding: 16px;
  font-size: 0.85rem;
}

/* 车站查询结果 */
.station-train-card {
  background: var(--surface);
  border: 1px solid var(--border);
  border-radius: 10px;
  padding: 12px 14px;
}
.stc-header {
  display: flex;
  align-items: center;
  gap: 8px;
  margin-bottom: 8px;
}
.stc-code {
  font-weight: 600;
  font-size: 0.95rem;
}
.stc-type {
  font-size: 0.7rem;
  padding: 1px 6px;
  border-radius: 3px;
  font-weight: 500;
}
.type-g { background: rgba(76,175,80,0.15); color: #4caf50; }
.type-d { background: rgba(33,150,243,0.15); color: #2196f3; }
.type-c { background: rgba(255,152,0,0.15); color: #ff9800; }
.type-k { background: rgba(156,39,176,0.15); color: #9c27b0; }
.type-t { background: rgba(0,150,136,0.15); color: #009688; }
.type-z { background: rgba(244,67,54,0.15); color: #f44336; }
.type-num { background: rgba(96,125,139,0.15); color: #607d8b; }
.stc-route {
  font-size: 0.8rem;
  color: var(--text-dim);
  margin-left: auto;
}
.stc-times {
  display: flex;
  gap: 16px;
}
.stc-time-item {
  display: flex;
  flex-direction: column;
  gap: 2px;
}
.stc-label {
  font-size: 0.7rem;
  color: var(--text-dim);
}
.stc-value {
  font-size: 0.9rem;
  font-weight: 500;
}

.empty {
  display: flex;
  flex-direction: column;
  align-items: center;
  gap: 10px;
  color: var(--text-dim);
  padding: 40px 0;
}
</style>
