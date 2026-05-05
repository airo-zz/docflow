<template>
  <div>
    <header v-if="auth.isAuthenticated" class="header">
      <div class="header-inner">
        <div class="flex">
          <router-link to="/" class="header-logo">DocFlow</router-link>
        </div>
        <nav class="header-nav">
          <router-link to="/">Главная</router-link>
          <router-link to="/documents">Документы</router-link>
          <router-link to="/reports">Отчёты</router-link>
          <router-link v-if="auth.isAdmin" to="/users">Пользователи</router-link>
          <div class="header-user">
            <span>{{ auth.user.full_name }} ({{ roleLabel }})</span>
            <button class="btn btn-secondary" @click="logout">Выход</button>
          </div>
        </nav>
      </div>
    </header>

    <main>
      <router-view />
    </main>
  </div>
</template>

<script setup>
import { computed } from 'vue'
import { useRouter } from 'vue-router'
import { useAuthStore } from './stores/auth'

const auth = useAuthStore()
const router = useRouter()

const roleLabels = {
  admin:    'Администратор',
  manager:  'Руководитель',
  clerk:    'Делопроизводитель',
  employee: 'Сотрудник'
}
const roleLabel = computed(() => roleLabels[auth.role] || auth.role)

function logout() {
  auth.logout()
  router.push('/login')
}
</script>
