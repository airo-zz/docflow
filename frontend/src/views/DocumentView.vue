<template>
  <div class="container" v-if="doc">
    <div class="flex-between mb-4">
      <h2>{{ doc.title }}</h2>
      <button class="btn btn-secondary" @click="$router.push('/documents')">← Назад</button>
    </div>

    <div class="card">
      <div class="grid-2">
        <div>
          <div class="form-group">
            <label>Регистрационный номер</label>
            <div>{{ doc.reg_number }}</div>
          </div>
          <div class="form-group">
            <label>Тип документа</label>
            <div>{{ doc.type_name }}</div>
          </div>
          <div class="form-group">
            <label>Статус</label>
            <span :class="['badge', statusBadge(doc.status_code)]">{{ doc.status_name }}</span>
          </div>
          <div class="form-group">
            <label>Автор</label>
            <div>{{ doc.author_name }}</div>
          </div>
        </div>
        <div>
          <div class="form-group">
            <label>Отдел</label>
            <div>{{ doc.department_name || '—' }}</div>
          </div>
          <div class="form-group">
            <label>Дата создания</label>
            <div>{{ formatDate(doc.created_at) }}</div>
          </div>
          <div class="form-group">
            <label>Срок исполнения</label>
            <div>{{ doc.deadline ? formatDate(doc.deadline) : '—' }}</div>
          </div>
          <div class="form-group">
            <label>Зарегистрирован</label>
            <div>{{ doc.registered_at ? formatDateTime(doc.registered_at) : '—' }}</div>
          </div>
        </div>
      </div>
      <div class="form-group">
        <label>Содержание</label>
        <div style="white-space: pre-wrap; padding: 12px; background: #f9f9f9; border-radius: 4px;">{{ doc.content || '—' }}</div>
      </div>
    </div>

    <div class="card">
      <div class="card-title">Маршрут согласования</div>
      <table v-if="routes.length">
        <thead>
          <tr>
            <th>#</th>
            <th>Согласующий</th>
            <th>Решение</th>
            <th>Комментарий</th>
            <th>Дата</th>
            <th></th>
          </tr>
        </thead>
        <tbody>
          <tr v-for="r in routes" :key="r.route_id">
            <td>{{ r.step_order }}</td>
            <td>{{ r.approver_name }}</td>
            <td>
              <span v-if="r.decision === 'approved'" class="badge badge-approved">Согласовано</span>
              <span v-else-if="r.decision === 'rejected'" class="badge badge-rejected">Отклонено</span>
              <span v-else class="badge badge-review">Ожидает</span>
            </td>
            <td>{{ r.comment || '—' }}</td>
            <td>{{ r.decided_at ? formatDateTime(r.decided_at) : '—' }}</td>
            <td>
              <div v-if="canDecide(r)" class="flex">
                <button class="btn btn-success" @click="decide(r, 'approved')">Согласовать</button>
                <button class="btn btn-danger"  @click="decide(r, 'rejected')">Отклонить</button>
              </div>
            </td>
          </tr>
        </tbody>
      </table>
      <div v-else class="muted">Маршрут согласования не назначен</div>
    </div>

    <div class="card">
      <div class="card-title">Журнал действий</div>
      <table v-if="history.length">
        <thead>
          <tr>
            <th>Дата</th>
            <th>Пользователь</th>
            <th>Действие</th>
            <th>Было</th>
            <th>Стало</th>
          </tr>
        </thead>
        <tbody>
          <tr v-for="h in history" :key="h.history_id">
            <td>{{ formatDateTime(h.action_time) }}</td>
            <td>{{ h.user_name || '—' }}</td>
            <td>{{ actionLabel(h.action) }}</td>
            <td>{{ h.old_value || '—' }}</td>
            <td>{{ h.new_value || '—' }}</td>
          </tr>
        </tbody>
      </table>
      <div v-else class="muted">Журнал пуст</div>
    </div>
  </div>
</template>

<script setup>
import { ref, onMounted } from 'vue'
import { useRoute } from 'vue-router'
import { useAuthStore } from '../stores/auth'
import api from '../api'

const route = useRoute()
const auth  = useAuthStore()

const doc     = ref(null)
const routes  = ref([])
const history = ref([])

async function loadData() {
  const r = await api.get('/documents/' + route.params.id)
  doc.value     = r.data.document
  routes.value  = r.data.routes
  history.value = r.data.history
}

onMounted(loadData)

function canDecide(r) {
  return r.decision === 'pending' &&
         (r.approver_id === auth.user.id || auth.role === 'admin')
}

async function decide(r, decision) {
  const comment = prompt(decision === 'approved' ? 'Комментарий к согласованию (необязательно):' : 'Причина отклонения:') || ''
  try {
    await api.post(`/documents/route/${r.route_id}/decision`, { decision, comment })
    await loadData()
  } catch (e) {
    alert(e.response?.data?.error || 'Ошибка')
  }
}

function statusBadge(code) {
  return {
    DRAFT: 'badge-draft', IN_REVIEW: 'badge-review', APPROVED: 'badge-approved',
    REJECTED: 'badge-rejected', ARCHIVED: 'badge-archived'
  }[code] || 'badge-draft'
}
function actionLabel(a) {
  return { CREATE: 'Создание', STATUS_CHANGE: 'Смена статуса' }[a] || a
}
function formatDate(d) {
  return new Date(d).toLocaleDateString('ru-RU')
}
function formatDateTime(d) {
  return new Date(d).toLocaleString('ru-RU')
}
</script>
