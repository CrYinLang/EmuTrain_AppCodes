<template>
  <div class="settings-page">
    <div class="setting-section">
      <div class="section-header">
        <Icon name="search" :size="18" color="var(--primary)" />
        <span class="section-title">搜索</span>
      </div>
      <div class="section-body">
        <div class="setting-item">
          <div class="setting-label">
            <div class="setting-name">数据源选择</div>
            <div class="setting-desc">车次查询使用的数据接口</div>
          </div>
          <select v-model="store.dataSource">
            <option value="12306">12306 官方</option>
            <option value="railRe">Rail.re</option>
            <option value="ctrip">携程</option>
          </select>
        </div>

        <div class="setting-item">
          <div class="setting-label">
            <div class="setting-name">交路查询数据源</div>
            <div class="setting-desc">查询车组当前担当交路</div>
          </div>
          <select v-model="store.emuSource">
            <option value="railRe">Rail.re</option>
            <option value="moeFactory">MoeFactory</option>
            <option value="railGo">RailGo</option>
          </select>
        </div>

        <div class="setting-item">
          <div class="setting-label">
            <div class="setting-name">显示路局图标</div>
            <div class="setting-desc">在搜索结果中显示路局图标</div>
          </div>
          <label class="toggle">
            <input type="checkbox" v-model="store.showBureauIcons" />
            <span class="toggle-slider"></span>
          </label>
        </div>

        <div class="setting-item">
          <div class="setting-label">
            <div class="setting-name">显示车组图片</div>
            <div class="setting-desc">在详情中显示动车组实拍图</div>
          </div>
          <label class="toggle">
            <input type="checkbox" v-model="store.showTrainImage" />
            <span class="toggle-slider"></span>
          </label>
        </div>
      </div>
    </div>

    <div class="setting-section">
      <div class="section-header">
        <Icon name="palette" :size="18" color="var(--primary)" />
        <span class="section-title">显示</span>
      </div>
      <div class="section-body">
        <div class="setting-item">
          <div class="setting-label">
            <div class="setting-name">主题模式</div>
            <div class="setting-desc">选择界面深色或浅色主题</div>
          </div>
          <select v-model="store.theme">
            <option value="dark">深色</option>
            <option value="light">浅色</option>
          </select>
        </div>
      </div>
    </div>

    <div class="setting-section">
      <div class="section-header">
        <Icon name="info" :size="18" color="var(--primary)" />
        <span class="section-title">关于</span>
      </div>
      <div class="section-body">
        <div class="setting-item">
          <div class="setting-label">
            <div class="setting-name">EmuTrain 网页版</div>
            <div class="setting-desc">版本 1.0.0 · Vue 3 + FastAPI</div>
          </div>
        </div>
      </div>
    </div>
  </div>
</template>

<script setup>
import Icon from '../components/Icon.vue'
import { useSettingsStore } from '../stores/settings'

const store = useSettingsStore()
</script>

<style scoped>
.settings-page { display: flex; flex-direction: column; gap: 16px; padding-bottom: 20px; }

.setting-section {
  background: var(--surface); border: 1px solid var(--border);
  border-radius: 12px; overflow: hidden;
}
.section-header {
  display: flex; align-items: center; gap: 10px;
  padding: 14px 16px 8px;
}
.section-title { font-size: 0.95rem; font-weight: 600; color: var(--primary); }
.section-body { padding: 0 16px 14px; }

.setting-item {
  display: flex; align-items: center; justify-content: space-between;
  padding: 12px 0; border-bottom: 1px solid var(--border); gap: 16px;
}
.setting-item:last-child { border-bottom: none; }
.setting-label { flex: 1; }
.setting-name { font-size: 0.95rem; }
.setting-desc { font-size: 0.75rem; color: var(--text-dim); margin-top: 2px; }
.setting-item select {
  padding: 6px 10px; border: 1px solid var(--border); border-radius: 6px;
  background: var(--bg); color: var(--text); font-size: 0.85rem; min-width: 120px;
}

.toggle { position: relative; display: inline-block; width: 44px; height: 24px; flex-shrink: 0; }
.toggle input { opacity: 0; width: 0; height: 0; }
.toggle-slider {
  position: absolute; cursor: pointer; inset: 0;
  background: var(--border); border-radius: 24px; transition: background 0.2s;
}
.toggle-slider::before {
  content: ''; position: absolute; width: 18px; height: 18px;
  left: 3px; bottom: 3px; background: #fff;
  border-radius: 50%; transition: transform 0.2s;
}
.toggle input:checked + .toggle-slider { background: var(--primary); }
.toggle input:checked + .toggle-slider::before { transform: translateX(20px); }
</style>
