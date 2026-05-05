<template>
  <div class="container">
    <div class="flex-between mb-4">
      <h2>Пользователи</h2>
      <button class="btn btn-primary" @click="showCreate = !showCreate">
        {{ showCreate ? 'Скрыть форму' : '+ Создать пользователя' }}
      </button>
    </div>

    <div v-if="error" class="alert alert-error">{{ error }}</div>

    <div v-if="showCreate" class="card">
      <div class="card-title">Новый пользователь</div>
      <form @submit.prevent="createUser">
        <div class="grid-2">
          <div class="form-group">
            <label>Логин *</label>
            <input v-model="form.login" class="input" required />
          </div>
          <div class="form-group">
            <label>Пароль *</label>
            <input v-model="form.password" class="input" type="password" required />
          </div>
          <div class="form-group">
            <label>ФИО *</label>
            <input v-model="form.full_name" class="input" required />
          </div>
          <div class="form-group">
            <label>Email *</label>
            <input v-model="form.email" type="email" class="input" required />
          </div>
          <div class="form-group">
            <label>Роль *</label>
            <select v-model="form.role_id" class="select" required>
              <option value="">— выберите —</option>
              <option v-for="r in roles" :key="r.role_id" :value="r.role_id">{{ r.role_name }}</option>
            </select>
          </div>
          <div class="form-group">
            <label>Отдел</label>
            <select v-model="form.department_id" class="select">
              <option value="">— не указан —</option>
              <option v-for="d in departments" :key="d.department_id" :value="d.department_id">{{ d.department_name }}</option>
            </select>
          </div>
          <div class="form-group">
            <label>Должность</label>
            <input v-model="form.position" class="input" />
          </div>
        </div>
        <button type="submit" class="btn btn-primary">Создать</button>
      </form>
    </div>

    <div class="card">
      <table>
        <thead>
          <tr>
            <th>ID</th>
            <th>Логин</th>
            <th>ФИО</th>
            <th>Email</th>
            <th>Роль</th>
            <th>Отдел</th>
            <th>Должность</th>
          </tr>
        </thead>
        <tbody>
          <tr v-for="u in users" :key="u.user_id">
            <td>{{ u.user_id }}</td>
            <td>—</td>
            <td>{{ u.full_name }}</td>
            <td>—</td>
            <td>{{ u.role_name }}</td>
            <td>{{ u.department_name || '—' }}</td>
            <td>{{ u.position || '—' }}</td>
          </tr>
        </tbody>
      </table>
    </div>
  </div>
</template>

<script setup>
import { ref, onMounted } from 'vue'
import api from '../api'

const users       = ref([])
const roles       = ref([])
const departments = ref([])
const showCreate  = ref(false)
const error       = ref('')

const form = ref({
  login: '', password: '', full_name: '', email: '',
  role_id: '', department_id: '', position: ''
})

onMounted(async () => {
  const [u, r, d] = await Promise.all([
    api.get('/dictionaries/users'),
    api.get('/dictionaries/roles'),
    api.get('/dictionaries/departments')
  ])
  users.value       = u.data
  roles.value       = r.data
  departments.value = d.data
})

async function createUser() {
  error.value = ''
  try {
    await api.post('/dictionaries/users', form.value)
    const u = await api.get('/dictionaries/users')
    users.value = u.data
    form.value = { login: '', password: '', full_name: '', email: '', role_id: '', department_id: '', position: '' }
    showCreate.value = false
  } catch (e) {
    error.value = e.response?.data?.error || 'Ошибка создания'
  }
}
</script>
