import { createRouter, createWebHistory } from 'vue-router'
import { useAuthStore } from './stores/auth'

import LoginView      from './views/LoginView.vue'
import DashboardView  from './views/DashboardView.vue'
import DocumentsView  from './views/DocumentsView.vue'
import DocumentView   from './views/DocumentView.vue'
import NewDocumentView from './views/NewDocumentView.vue'
import ReportsView    from './views/ReportsView.vue'
import UsersView      from './views/UsersView.vue'

const routes = [
  { path: '/login',          component: LoginView,       meta: { public: true } },
  { path: '/',               component: DashboardView },
  { path: '/documents',      component: DocumentsView },
  { path: '/documents/new',  component: NewDocumentView },
  { path: '/documents/:id',  component: DocumentView },
  { path: '/reports',        component: ReportsView },
  { path: '/users',          component: UsersView,       meta: { roles: ['admin'] } }
]

const router = createRouter({
  history: createWebHistory(),
  routes
})

router.beforeEach((to, from, next) => {
  const auth = useAuthStore()
  if (!to.meta.public && !auth.isAuthenticated) {
    return next('/login')
  }
  if (to.meta.roles && !to.meta.roles.includes(auth.role)) {
    return next('/')
  }
  if (to.path === '/login' && auth.isAuthenticated) {
    return next('/')
  }
  next()
})

export default router
