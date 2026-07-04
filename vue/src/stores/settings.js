import { defineStore } from 'pinia'
import { ref, watch } from 'vue'

export const useSettingsStore = defineStore('settings', () => {
  const dataSource = ref('12306')
  const emuSource = ref('railRe')
  const showBureauIcons = ref(true)
  const showTrainImage = ref(true)
  const theme = ref('dark')

  // 从 localStorage 加载
  function load() {
    const keys = {
      dataSource: '12306',
      emuSource: 'railRe',
      showBureauIcons: true,
      showTrainImage: true,
      theme: 'dark',
    }
    for (const [key, def] of Object.entries(keys)) {
      const val = localStorage.getItem(`emutrain_${key}`)
      if (val !== null) {
        try {
          const parsed = JSON.parse(val)
          if (key === 'dataSource') dataSource.value = parsed
          else if (key === 'emuSource') emuSource.value = parsed
          else if (key === 'showBureauIcons') showBureauIcons.value = parsed
          else if (key === 'showTrainImage') showTrainImage.value = parsed
          else if (key === 'theme') theme.value = parsed
        } catch {
          // ignore
        }
      }
    }
    applyTheme()
  }

  // 保存单个设置
  function save(key) {
    const val = key === 'dataSource' ? dataSource.value
      : key === 'emuSource' ? emuSource.value
      : key === 'showBureauIcons' ? showBureauIcons.value
      : key === 'showTrainImage' ? showTrainImage.value
      : key === 'theme' ? theme.value
      : null
    if (val !== null) {
      localStorage.setItem(`emutrain_${key}`, JSON.stringify(val))
    }
    if (key === 'theme') applyTheme()
  }

  function applyTheme() {
    document.documentElement.setAttribute('data-theme', theme.value)
  }

  // 监听变化自动保存
  watch(dataSource, () => save('dataSource'))
  watch(emuSource, () => save('emuSource'))
  watch(showBureauIcons, () => save('showBureauIcons'))
  watch(showTrainImage, () => save('showTrainImage'))
  watch(theme, () => save('theme'))

  return {
    dataSource, emuSource, showBureauIcons, showTrainImage, theme,
    load, save,
  }
})
