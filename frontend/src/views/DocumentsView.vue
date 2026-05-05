<template>
  <div class="container">
    <div class="flex-between mb-4">
      <h2>Документы</h2>
      <router-link to="/documents/new" class="btn btn-primary">+ Создать документ</router-link>
    </div>

    <div class="card">
      <div class="toolbar">
        <input v-model="filters.search" class="input" placeholder="Поиск по теме или номеру..." style="flex:1; min-width:240px;" />
        <select v-model="filters.status" class="select">
          <option value="">Все статусы</option>
          <option v-for="s in statuses" :key="s.status_id" :value="s.status_code">{{ s.status_name }}</option>
        </select>
        <select v-model="filters.type" class="select">
          <option value="">Все типы</option>
          <option v-for="t in types" :key="t.type_id" :value="t.type_code">{{ t.type_name }}</option>
        </select>
        <button class="btn btn-primary" @click="loadDocs">Применить</button>
        <button class="btn btn-secondary" @click="resetFilters">Сбросить</button>
      </div>

      <table>
        <thead>
          <tr>
            <th>№</th>
            <th>Тема</th>
            <th>Тип</th>
            <th>Статус</th>
            <th>Автор</th>
            <th>Создан</th>
            <th>Срок</th>
          </tr>
        </thead>
        <tbody>
          <tr v-for="d in documents" :key="d.document_id" @click="$router.push('/documents/'+d.document_id)" style="cursor:pointer;">
            <td>{{ d.reg_number }}</td>
            <td>{{ d.title }}</td>
            <td>{{ d.type_name }}</td>
            <td><span :class="['badge', statusBadge(d.status_code)]">{{ d.status_name }}</span></td>
            <td>{{ d.author_name }}</td>
            <td>{{ formatDate(d.created_at) }}</td>
            <td>{{ d.deadline ? formatDate(d.deadline) : '—' }}</td>
          </tr>
          <tr v-if="!documents.length">
            <td colspan="7" class="text-center muted">Документов не найдено</td>
          </tr>
        </tbody>
      </table>
    </div>
  </div>
</template>

<script setup>
import { ref, onMounted } from 'vue'
import api from '../api'

const documents = ref([])
const types     = ref([])
const statuses  = ref([])
const filters   = ref({ search: '', status: '', type: '' })

onMounted(async () => {
  const [t, s] = await Promise.all([
    api.get('/dictionaries/document-types'),
    api.get('/dictionaries/document-statuses')
  ])
  types.value    = t.data
  statuses.value = s.data
  await loadDocs()
})

async function loadDocs() {
  const params = {}
  if (filters.value.search) params.search = filters.value.search
  if (filters.value.status) params.status = filters.value.status
  if (filters.value.type)   params.type   = filters.value.type
  const r = await api.get('/documents', { params })
  documents.value = r.data
}

function resetFilters() {
  filters.value = { search: '', status: '', type: '' }
  loadDocs()
}

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
