import api from './index'

// 车组搜索
export function searchEmu({ input, type = 'trainId', page = 1, pageSize = 20 }) {
  return api.get('/emu/search', { params: { input, type, page, page_size: pageSize } })
}

// 车次经停查询
export function getTrainStops({ trainNumber, date, source = 'ctrip' }) {
  return api.get('/train/stops', { params: { trainNumber, date, source } })
}

// 车站搜索
export function searchStation({ keyword, limit = 20 }) {
  return api.get('/station/search', { params: { keyword, limit } })
}

// 车站大屏
export function getStationScreen({ stationCode, stationName, date, direction = 0, page = 1 }) {
  return api.get('/station/screen', { params: { stationCode, stationName, date, direction, page } })
}

// 按车站查车次
export function searchByStation({ fromStation, toStation, date, source = 'railRe' }) {
  return api.get('/train/search-by-station', { params: { fromStation, toStation, date, source } })
}

// 车组交路查询
export function getEmuRoute({ emuNo, source = 'railRe' }) {
  return api.get('/emu/route', { params: { emu_no: emuNo, source } })
}

// 客车搜索
export function searchCoach({ input, type = 'number', page = 1 }) {
  return api.get('/coach/search', { params: { input, type, page } })
}

// 机车搜索
export function searchLoco({ input, type = 'number', page = 1 }) {
  return api.get('/loco/search', { params: { input, type, page } })
}

// 健康检查
export function healthCheck() {
  return api.get('/health')
}

// 获取路局列表
export function getBureaus() {
  return api.get('/emu/bureaus')
}

// 获取动车所列表
export function getDepots() {
  return api.get('/emu/depots')
}

// 获取车型列表
export function getTypes() {
  return api.get('/emu/types')
}
