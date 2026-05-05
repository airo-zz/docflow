<template>
  <div class="container">
    <h2 class="mb-4">Новый документ</h2>

    <div v-if="error" class="alert alert-error">{{ error }}</div>
    <div v-if="success" class="alert alert-success">Документ успешно создан</div>

    <div class="card">
      <form @submit.prevent="submit">
        <div class="form-group">
          <label>Тема документа *</label>
          <input v-model="form.title" class="input" required maxlength="255" />
        </div>

        <div class="grid-2">
          <div class="form-group">
            <label>Тип документа *</label>
            <select v-model="form.type_id" class="select" required>
              <option value="">— выберите тип —</option>
              <option v-for="t in types" :key="t.type_id" :value="t.type_id">{{ t.type_name }}</option>
            </select>
          </div>
          <div class="form-group">
            <label>Отдел</label>
            <select v-model="form.department_id" class="select">
              <option value="">— не указан —</option>
              <option v-for="d in departments" :key="d.department_id" :value="d.department_id">{{ d.department_name }}</option>
            </select>
          </div>
        </div>

        <div class="form-group">
          <label>Срок исполнения</label>
          <input v-model="form.deadline" type="date" class="input" />
        </div>

        <div class="form-group">
          <label>Содержание</label>
          <textarea v-model="form.content" class="textarea" rows="6"></textarea>
        </div>

        <div class="form-group">
          <label>Маршрут согласования (порядок: 1, 2, 3...)</label>
          <div v-for="(a, i) in form.approvers" :key="i" class="flex mb-2">
            <span style="width: 30px;">{{ i + 1 }}.</span>
            <select v-model="form.approvers[i]" class="select" style="flex: 1;">
              <option value="">— выберите согласующего —</option>
              <option v-for="u in users" :key="u.user_id" :value="u.user_id">
                {{ u.full_name }} ({{ u.position }})
              </option>
            </select>
            <button type="button" class="btn btn-secondary" @click="removeApprover(i)">Удалить</button>
          </div>
          <button type="button" class="btn btn-secondary" @click="addApprover">+ Добавить согласующего</button>
        </div>

        <div class="flex">
          <button type="submit" class="btn btn-primary" :disabled="loading">
            {{ loading ? 'Создание...' : 'Создать документ' }}
          </button>
          <button type="button" class="btn btn-secondary" @click="$router.push('/documents')">Отмена</button>
        </div>
      </form>
    </div>
  </div>
</template>

<script setup>
import { ref, onMounted } from 'vue'
import { useRouter } from 'vue-router'
import api from '../api'

const router = useRouter()

const types = ref([])
const departments = ref([])
const users = ref([])

const form = ref({
  title: '',
  type_id: '',
  department_id: '',
  deadline: '',
  content: '',
  approvers: []
})

const loading = ref(false)
const error   = ref('')
const success = ref(false)

onMounted(async () => {
  const [t, d, u] = await Promise.all([
    api.get('/dictionaries/document-types'),
    api.get('/dictionaries/departments'),
    api.get('/dictionaries/users')
  ])
  types.value       = t.data
  departments.value = d.data
  users.value       = u.data.filter(x => ['director', 'chief_accountant', 'lawyer', 'admin'].includes(x.role_name))
})

function addApprover() {
  form.value.approvers.push('')
}
function removeApprover(i) {
  form.value.approvers.splice(i, 1)
}

async function submit() {
  error.value = ''
  loading.value = true
  try {
    const payload = {
      title:         form.value.title,
      content:       form.value.content,
      type_id:       form.value.type_id,
      department_id: form.value.department_id || null,
      deadline:      form.value.deadline      || null,
      approvers:     form.value.approvers.filter(x => !!x)
    }
    await api.post('/documents', payload)
    success.value = true
    setTimeout(() => router.push('/documents'), 1000)
  } catch (e) {
    error.value = e.response?.data?.error || 'Ошибка создания документа'
  } finally {
    loading.value = false
  }
}
</script>
