import { defineStore } from 'pinia'
import api from '../api'

// Роли с правом согласования документов
const APPROVER_ROLES = ['director', 'chief_accountant', 'lawyer']

export const useAuthStore = defineStore('auth', {
  state: () => ({
    user:  JSON.parse(localStorage.getItem('user') || 'null'),
    token: localStorage.getItem('token') || null
  }),
  getters: {
    isAuthenticated: (state) => !!state.token,
    role:            (state) => state.user ? state.user.role : null,
    isAdmin:         (state) => state.user && state.user.role === 'admin',
    isManager:       (state) => state.user && APPROVER_ROLES.includes(state.user.role),
    isClerk:         (state) => state.user && state.user.role === 'clerk',
    isEmployee:      (state) => state.user && state.user.role === 'employee'
  },
  actions: {
    async login(login, password) {
      const r = await api.post('/auth/login', { login, password })
      this.token = r.data.token
      this.user  = r.data.user
      localStorage.setItem('token', this.token)
      localStorage.setItem('user',  JSON.stringify(this.user))
      return r.data
    },
    logout() {
      this.token = null
      this.user  = null
      localStorage.removeItem('token')
      localStorage.removeItem('user')
    }
  }
})
