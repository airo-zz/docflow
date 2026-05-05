<template>
  <div class="container">
    <h2 class="mb-4">Добро пожаловать, {{ auth.user.full_name }}</h2>

    <div class="grid-4 mb-4">
      <div class="stat">
        <div class="stat-value">{{ stats.total }}</div>
        <div class="stat-label">Всего документов</div>
      </div>
      <div class="stat">
        <div class="stat-value">{{ stats.draft }}</div>
        <div class="stat-label">Черновики</div>
      </div>
      <div class="stat">
        <div class="stat-value">{{ stats.in_review }}</div>
        <div class="stat-label">На согласовании</div>
      </div>
      <div class="stat">
        <div class="stat-value">{{ stats.approved }}</div>
        <div class="stat-label">Утверждено</div>
      </div>
    </div>

    <div class="card">
      <div class="card-title">Последние документы</div>
      <table>
        <thead>
          <tr>
            <th>№</th>
            <th>Тема</th>
            <th>Тип</th>
            <th>Статус</th>
            <th>Автор</th>
            <th>Дата</th>
          </tr>
        </thead>
        <tbody>
          <tr v-for="d in recent" :key="d.document_id" @click="$router.push('/documents/'+d.document_id)" style="cursor:pointer;">
            <td>{{ d.reg_number }}</td>
            <td>{{ d.title }}</td>
            <td>{{ d.type_name }}</td>
            <td><span :class="['badge', statusBadge(d.status_code)]">{{ d.status_name }}</span></td>
            <td>{{ d.author_name }}</td>
            <td>{{ formatDate(d.created_at) }}</td>
          </tr>
          <tr v-if="!recent.length">
            <td colspan="6" class="text-center muted">Нет документов</td>
          </tr>
        </tbody>
      </table>
    </div>
  </div>
</template>

<script setup>
import { ref, computed, onMounted } from 'vue'
import { useAuthStore } from '../stores/auth'
import api from '../api'

const auth = useAuthStore()
const documents = ref([])

onMounted(async () => {
  const r = await api.get('/documents')
  documents.value = r.data
})

const stats = computed(() => ({
  total: documents.value.length,
  draft: documents.value.filter(d => d.status_code === 'DRAFT').length,
  in_review: documents.value.filter(d => d.status_code === 'IN_REVIEW').length,
  approved: documents.value.filter(d => d.status_code === 'APPROVED').length
}))

const recent = computed(() => documents.value.slice(0, 8))

function statusBadge(code) {
  return {
    DRAFT: 'badge-draft', IN_REVIEW: 'badge-review', APPROVED: 'badge-approved',
    REJECTED: 'badge-rejected', ARCHIVED: 'badge-archived'
  }[code] || 'badge-draft'
}
function formatDate(d) {
  return new Date(d).toLocaleDateString('ru-RU')
}
</script>
