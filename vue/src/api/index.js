import axios from 'axios'

const api = axios.create({
  baseURL: import.meta.env.VITE_API_BASE || '/api',
  timeout: 15000,
  headers: {
    'Content-Type': 'application/json',
  },
})

// 请求拦截
api.interceptors.response.use(
  (res) => res.data,
  (err) => {
    console.error('[API Error]', err.response?.status, err.message)
    return Promise.reject(err)
  }
)

export default api
