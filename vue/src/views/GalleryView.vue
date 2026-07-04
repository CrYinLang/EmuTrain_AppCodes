<template>
  <div class="gallery-page">
    <!-- Tab 切换 -->
    <div class="gallery-tabs">
      <button
        v-for="(tab, i) in tabs"
        :key="i"
        :class="{ active: currentTab === i }"
        @click="currentTab = i"
      >
        <Icon :name="tab.icon" :size="16" />
        <span>{{ tab.title }}</span>
      </button>
    </div>

    <!-- 列表 -->
    <div class="gallery-list">
      <template v-for="(item, i) in currentList" :key="i">
        <!-- 分区标题 -->
        <div v-if="item.sectionTitle" class="section-header">
          {{ item.sectionTitle }}
        </div>

        <div class="gallery-card">
          <div class="gc-left">
            <img
              :src="'/assets/icon/train/' + getIconModel(item.model, item.number) + '.png'"
              :alt="item.model"
              class="gc-icon"

          </div>
          <div class="gc-body">
            <div class="gc-title">
              <span class="gc-number">{{ item.model }}-{{ item.number }}</span>
            </div>
            <div class="gc-info">
              <div v-for="(val, key) in item.infoItems" :key="key" class="gc-info-row">
                <span class="gc-label">{{ key }}</span>
                <span class="gc-value">{{ val }}</span>
              </div>
            </div>
          </div>
        </div>
      </template>
    </div>

    <div class="gallery-link">
      <a href="https://china-emu.cn/Trains/ALL/" target="_blank" rel="noopener">
        <Icon name="open_in_new" :size="14" /> 查看完整图鉴
      </a>
    </div>
  </div>
</template>

<script setup>
import { ref, computed } from 'vue'
import Icon from '../components/Icon.vue'

const currentTab = ref(0)

const tabs = [
  { title: '热门车型', icon: 'star' },
  { title: '检测列车', icon: 'search' },
  { title: '其他车型', icon: 'directions_railway' },
  { title: '特殊涂装', icon: 'palette' },
]

// 从 Flutter gallery_page.dart 完整复制
const galleryData = {
  0: [
    { model: 'CR450AF', number: '0201', infoItems: { '生产厂家': '中车青岛四方', '备注': '450级别动车组', '类型': '实验-实验中' } },
    { model: 'CR450BF', number: '0501', infoItems: { '生产厂家': '长春轨道客车', '备注': '450级别动车组', '类型': '实验-实验中' } },
    { model: 'CR400AF-J', number: '2808', infoItems: { '代管路局': '济南铁路局', '生产厂家': '中车青岛四方', '备注': '复兴号350级别高速综合检测列车', '类型': '检测-上线' } },
  ],
  1: [
    { model: 'CR400BF-J', number: '0001', infoItems: { '代管路局': '沈阳铁路局', '生产厂家': '长春轨道客车', '备注': '复兴号350级别高速综合检测列车', '类型': '检测-上线' } },
    { model: 'CR400AF-J', number: '0002', infoItems: { '代管路局': '武汉铁路局', '生产厂家': '中车青岛四方', '备注': '复兴号350级别高速综合检测列车', '类型': '检测-上线' } },
    { model: 'CR400BF-J', number: '0003', infoItems: { '代管路局': '北京铁路局', '生产厂家': '中车长客股份', '备注': '复兴号350级别高速综合检测列车', '类型': '检测-上线' } },
    { model: 'CR400AF-J', number: '2808', infoItems: { '代管路局': '济南铁路局', '生产厂家': '中车青岛四方', '备注': '复兴号350级别高速综合检测列车', '类型': '检测-上线' } },
    { model: 'CRH380AJ', number: '0201', infoItems: { '代管路局': '广州铁路局', '生产厂家': '南车青岛四方', '备注': '和谐号380级别高速综合检测列车', '类型': '检测-上线' } },
    { model: 'CRH380AJ', number: '0202', infoItems: { '代管路局': '武汉铁路局', '生产厂家': '南车青岛四方', '备注': '和谐号380级别高速综合检测列车', '类型': '检测-上线' } },
    { model: 'CRH380AJ', number: '0203', infoItems: { '代管路局': '武汉铁路局', '生产厂家': '南车青岛四方', '备注': '和谐号380级别高速综合检测列车', '类型': '检测-上线' } },
    { model: 'CRH380AJ', number: '2808', infoItems: { '代管路局': '成都铁路局', '生产厂家': '中车青岛四方', '备注': '和谐号高速综合检测列车,公务车（软卧车），原车组号CRH380A-2808', '类型': '检测-上线' } },
    { model: 'CRH380AJ', number: '2818', infoItems: { '代管路局': '北京铁路局', '生产厂家': '中车青岛四方', '备注': '和谐号高速综合检测列车，原车号CRH380A-2818', '类型': '检测-上线' } },
    { model: 'CRH380AM', number: '0204', infoItems: { '代管路局': '广州铁路局', '生产厂家': '南车青岛四方', '备注': '和谐号更高速度综合检测列车', '类型': '检测-上线' } },
    { model: 'CRH2J', number: '0205', infoItems: { '代管路局': '广州铁路局', '生产厂家': '南车青岛四方', '备注': '和谐号250级别高速综合检测列车', '类型': '检测-上线' } },
    { model: 'CRH380BJ', number: '0301', infoItems: { '代管路局': '北京铁路局', '生产厂家': '唐山轨道客车', '备注': '和谐号350级别高速综合检测列车', '类型': '检测-上线' } },
    { model: 'CRH5J', number: '0501', infoItems: { '代管路局': '兰州铁路局', '生产厂家': '长春轨道客车', '备注': '和谐号250级别 0号高速综合检测列车', '类型': '检测-上线' } },
    { model: 'CRH380BJ-A', number: '0504', infoItems: { '代管路局': '沈阳铁路局', '生产厂家': '长春轨道客车', '备注': '和谐号350级别高速综合检测列车，CRH380CL头型', '类型': '检测-上线' } },
    { model: 'CRH2A', number: '2010', infoItems: { '代管路局': '北京铁路局', '生产厂家': '中车青岛四方', '备注': '和谐号250级别综合检测车', '类型': '检测-上线' } },
    { model: 'CRH2C', number: '2061', infoItems: { '代管路局': '上海铁路局', '生产厂家': '南车青岛四方', '备注': '和谐号350级别综合检测列车', '类型': '检测-上线' } },
    { model: 'CRH2C', number: '2068', infoItems: { '代管路局': '上海铁路局', '生产厂家': '南车青岛四方', '备注': '和谐号380级别综合检测列车', '类型': '检测-上线' } },
    { model: 'CRH2C', number: '2150', infoItems: { '代管路局': '上海铁路局', '生产厂家': '南车青岛四方', '备注': '和谐号350级别高速综合检测列车，CRH380A新头型实验列车', '类型': '检测-上线' } },
  ],
  2: [
    { model: 'CRH380AN', number: '0206', infoItems: { '配属路局': '成都铁路局', '配属动车所': '成都东', '生产厂家': '南车青岛四方', '备注': '永磁电机实验动车组' } },
    { model: 'CR400AF', number: '0207', infoItems: { '配属路局': '北京铁路局', '配属动车所': '北京西', '生产厂家': '南车青岛四方', '备注': '350km/h中国标准动车组样车' } },
    { model: 'CR400BF', number: '0507', infoItems: { '配属路局': '广州铁路局', '配属动车所': '广州南', '生产厂家': '长春轨道客车', '备注': '350km/h中国标准动车组样车，白眉，橡胶风挡' } },
    { model: 'CR400BF', number: '5033', infoItems: { '配属路局': '北京铁路局', '配属动车所': '大厂', '生产厂家': '中车长客股份', '备注': '你懂的' } },
    { model: 'CR400AF-C', number: '2214', infoItems: { '配属路局': '北京铁路局', '配属动车所': '雄安', '生产厂家': '南车青岛四方', '备注': '真正意义上的智能动车，具有自动驾驶功能，仅一列' } },
    { model: 'CRH2A', number: '2460', infoItems: { '配属路局': '昆明铁路局', '配属动车所': '昆明南', '生产厂家': '南车青岛四方', '备注': 'CRH2G新头型实验动车组' } },
    { model: 'CRH380AL', number: '2541', infoItems: { '配属路局': '南昌铁路局', '配属动车所': '厦门北', '生产厂家': '中车青岛四方', '备注': '冲高动车组,最快可达486.1KM,曾编组号CRH380A-2541L' } },
    { model: 'CRH2A', number: '4020', infoItems: { '配属路局': '成都铁路局', '配属动车所': '成都东', '生产厂家': '南车青岛四方', '备注': '2022年6月4日发生事故，头车及7车出轨受损，现已改造为货运动车组。前两节车厢无窗户', '类型': '货运-上线' } },
  ],
  3: [
    { model: 'CR400BF-Z', number: '0524', infoItems: { '配属路局': '上海铁路局', '配属动车所': '杭州西', '生产厂家': '长春轨道客车', '备注': '杭州亚运涂装' } },
    { model: 'CR400BF-C', number: '5162', infoItems: { '配属路局': '北京铁路局', '配属动车所': '北京北', '生产厂家': '长春轨道客车', '备注': '冬奥涂装' } },
  ],
}

const currentList = computed(() => galleryData[currentTab.value] || [])

// 图标模型映射（与后端 icon_mapping.py 一致）
function getIconModel(model, number) {
  const m = model.trim()
  const digits = number.replace(/[^0-9]/g, '')
  const num = digits ? parseInt(digits) : null

  // 带后缀的特殊车型直接匹配
  if (m === 'CR400BF-J') {
    if (num === 1) return 'CR400BF-J-0001'
    if (num === 3) return 'CR400BF-J-0003'
    return 'CR400BF-J-0001'
  }
  if (m === 'CR400AF-J') return 'CR400AF-J'
  if (m === 'CR400BF-C') {
    if (num === 5162) return 'CR400BF-C-5162'
    return 'CR400BF-C'
  }
  if (m === 'CR400BF-G') {
    if (num === 51) return 'CR400BF-G-0051'
    return 'CR400BF'
  }
  if (m === 'CR400BF-S') return 'CR400BF-S'
  if (m === 'CR400BF-Z') {
    if (num === 524) return 'CR400BF-Z-0524'
    return 'CR400BF-Z'
  }
  if (m === 'CRH380AJ') return 'CRH380AJ'
  if (m === 'CRH380BJ') return 'CRH380BJ'
  if (m === 'CRH380BJ-A') return 'CRH380BJ-A'
  if (m === 'CRH380AM') return 'CRH380AM'
  if (m === 'CRH5J') return 'CRH5J'
  if (m === 'CRH2J') return 'CRH2J'

  if (m === 'CRH6A' && num && ((num >= 401 && num <= 408) || (num >= 602 && num <= 610) || num === 420 || num === 421)) return 'CRH6-2'
  if (m === 'CRH3A-A' && num && num >= 511 && num <= 521) return 'CRH3A-A-GKCJ'
  if (m === 'CRH3A-A' && num && num >= 524 && num <= 528) return 'CRH3A-A-ZKCJ'
  if (m === 'CRH1B' && num && num >= 1076 && num <= 1080) return 'CRH1E'
  if (m === 'CRH1E' && num && num >= 1229 && num <= 1233) return 'CRH1A-A'
  if (m === 'CRH6F' && num && num >= 409 && num <= 413) return 'CRH6F'
  if (m === 'CRH6F' && num && num >= 430 && num <= 435) return 'CRH6F'
  if (m === 'CRH6F' && num && num === 4512) return 'CRH6-2'
  if (m === 'CRH6F' && num && num === 1) return 'CRH6-2'
  if (m === 'CRH6F-A' && num && num >= 445 && num <= 450) return 'CRH6F'
  if (m === 'CRH6F-A') return 'CRH6A'
  if (m.includes('CRH6F')) return 'CRH6A'
  if (m === 'CRH2A' && num === 2460) return 'CRH2A-2460'
  if (m === 'CR400BF' && num === 31) return 'CR400BF-0031'
  if (m === 'CR400BF' && num === 5162) return 'CR400BF-C-5162'
  if (m === 'CR400BF' && num && num >= 5154 && num <= 5161) return 'CR400BF-C'
  if (m === 'CR400BF' && num === 5051) return 'CR400BF-G-0051'
  if (m === 'CR400BF' && num === 5001) return 'CR400BF-J-0001'
  if (m === 'CR400BF' && num === 5003) return 'CR400BF-J-0003'
  if (m === 'CR400BF' && num && num >= 5052 && num <= 5058) return 'CR400BF-S'
  if (m === 'CR400BF' && num === 5524) return 'CR400BF-Z-0524'
  if (m === 'CR400BF' && num && num >= 5501 && num <= 5523) return 'CR400BF-Z'
  if (m === 'CR400AF' && num && num >= 2029 && num <= 2032) return 'CR400AF-J'
  if (m === 'CR400AF' && num && num >= 2033 && num <= 2042) return 'CR400AF-SZE'
  if (m === 'CRH380A' && num && num >= 2569 && num <= 2590) return 'CRH380AM'
  if (m === 'CRH380A' && num && num >= 2637 && num <= 2640) return 'CRH380AD'
  if (m === 'CRH380A' && num && num >= 2641 && num <= 2646) return 'CRH380AJ'
  if (m === 'CRH380A' && num && num >= 251 && num <= 259) return 'CRH380AD'
  if (m === 'CRH380B' && num && num >= 3569 && num <= 3578) return 'CRH380BJ'
  if (m === 'CRH380B' && num && num >= 5717 && num <= 5726) return 'CRH380BJ-A'
  if (m === 'CRH1B') return 'CRH1A'
  if (m === 'CRH3A' && num && (num === 302 || num === 502)) return 'CRH3A-YC'
  if (m === 'CRH380AL' || m === 'CRH380AN') return 'CRH380A'
  if (m === 'CRH2B' && num && ((num >= 2466 && num <= 2472) || (num >= 4096 && num <= 4105))) return 'CRH2A'
  if (m === 'CRH2B') return 'CRH2BE'
  if (m === 'CRH5G' && num && num >= 5218 && num <= 5229) return 'CRH5G'
  if (m === 'CRH5G') return 'CRH5A'
  if (m === 'CR200JD') return 'CR200JC'
  if (m === 'CRH2E' && num && (num === 2461 || num === 2462)) return 'CRH2E-NG'
  if (m === 'CRH2G') return 'CRH2E-NG'
  if (m === 'CRH2E') return 'CRH2BE'
  if (m === 'CRH380BL' || m === 'CRH380BG') return 'CRH380B'
  if (m === 'CRH2C' && num === 2150) return 'CRH380A'
  if (m === 'CRH6A-A' || m === 'CRH6A-AZ') return 'CRH6A'
  if (['CR400AF-Z', 'CR400AF-AZ', 'CR400AF-BZ', 'CR400AF-S', 'CR400AF-AS', 'CR400AF-BS', 'CR400AF-AE', 'CR400AF-C'].includes(m)) return 'CR400AF-SZE'
  if (['CR400BF-S', 'CR400BF-AS', 'CR400BF-BS', 'CR400BF-GS'].includes(m)) return 'CR400BF-S'
  if (['CR400BF-Z', 'CR400BF-AZ', 'CR400BF-BZ', 'CR400BF-GZ'].includes(m)) return 'CR400BF-Z'
  if (['CR400AF-A', 'CR400AF-B', 'CR400AF-G'].includes(m)) return 'CR400AF'
  if (['CR400BF-A', 'CR400BF-B', 'CR400BF-G'].includes(m)) return 'CR400BF'
  if (m === 'CR400BF-G' && num === 51) return 'CR400BF-0031'
  return m
}
</script>

<style scoped>
.gallery-page { display: flex; flex-direction: column; gap: 10px; }

.gallery-tabs {
  display: flex;
  gap: 0;
  background: var(--surface);
  border: 1px solid var(--border);
  border-radius: 10px;
  overflow: hidden;
}
.gallery-tabs button {
  flex: 1;
  padding: 10px 6px;
  background: none;
  border: none;
  color: var(--text-dim);
  font-size: 0.72rem;
  display: flex;
  flex-direction: column;
  align-items: center;
  gap: 3px;
  cursor: pointer;
}
.gallery-tabs button.active {
  background: var(--primary-dim);
  color: var(--primary);
  font-weight: 600;
}

.gallery-list { display: flex; flex-direction: column; gap: 8px; }
.section-header {
  font-size: 0.9rem;
  font-weight: 600;
  color: var(--primary);
  padding: 8px 4px 0;
}
.gallery-card {
  display: flex;
  gap: 12px;
  background: var(--surface);
  border: 1px solid var(--border);
  border-radius: 10px;
  padding: 12px;
}
.gc-left { flex-shrink: 0; }
.gc-icon {
  width: 56px;
  height: 56px;
  border-radius: 8px;
  object-fit: contain;
  background: var(--bg);
  image-rendering: auto;
}
.gc-body { flex: 1; min-width: 0; }
.gc-title {
  display: flex;
  align-items: center;
  gap: 8px;
  margin-bottom: 6px;
}
.gc-number { font-size: 1rem; font-weight: 600; }
.gc-info { display: flex; flex-direction: column; gap: 2px; }
.gc-info-row { display: flex; font-size: 0.78rem; }
.gc-label {
  color: var(--text-dim);
  min-width: 60px;
  flex-shrink: 0;
}
.gc-value { color: var(--text); }

.gallery-link {
  text-align: center;
  padding: 12px;
}
.gallery-link a {
  color: var(--primary);
  font-size: 0.85rem;
  display: inline-flex;
  align-items: center;
  gap: 4px;
}
</style>
