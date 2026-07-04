import { defineStore } from 'pinia'
import { ref } from 'vue'

export const useAppStore = defineStore('app', () => {
  const dataSource = ref('12306') // 12306 | railRe | ctrip
  const sidebarOpen = ref(false)

  function setDataSource(src) {
    dataSource.value = src
  }

  function toggleSidebar() {
    sidebarOpen.value = !sidebarOpen.value
  }

  return { dataSource, sidebarOpen, setDataSource, toggleSidebar }
})
