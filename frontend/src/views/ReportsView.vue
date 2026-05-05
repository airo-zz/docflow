<template>
  <div class="container">
    <h2 class="mb-4">Отчёты</h2>

    <div class="tabs">
      <div v-for="t in availableTabs" :key="t.id"
           :class="['tab', { active: activeTab === t.id }]"
           @click="setTab(t.id)">{{ t.label }}</div>
    </div>

    <div class="card" v-if="activeReport">
      <div class="card-title">{{ activeReport.label }}</div>
      <div v-if="activeReport.filters" class="toolbar">
        <template v-for="f in activeReport.filters" :key="f.name">
          <input v-if="f.type === 'date'" v-model="filterValues[f.name]" type="date" class="input" :placeholder="f.label" />
          <input v-else-if="f.type === 'number'" v-model="filterValues[f.name]" type="number" class="input" :placeholder="f.label" />
        </template>
        <button class="btn btn-primary" @click="loadReport">Применить фильтр</button>
      </div>

      <table v-if="data.length">
        <thead>
          <tr>
            <th v-for="col in activeReport.columns" :key="col.key">{{ col.label }}</th>
          </tr>
        </thead>
        <tbody>
          <tr v-for="(row, i) in data" :key="i">
            <td v-for="col in activeReport.columns" :key="col.key">{{ formatCell(row[col.key], col) }}</td>
          </tr>
        </tbody>
      </table>
      <div v-else class="muted">Данных нет</div>
    </div>
  </div>
</template>

<script setup>
import { ref, computed, onMounted, watch } from 'vue'
import { useAuthStore } from '../stores/auth'
import api from '../api'

const auth = useAuthStore()

// Описание всех отчётов по ролям
const allReports = {
  admin: [
    {
      id: 'user-activity', label: 'Активность пользователей',
      url: '/reports/admin/user-activity',
      filters: [
        { name: 'date_from', label: 'С', type: 'date' },
        { name: 'date_to',   label: 'По', type: 'date' }
      ],
      columns: [
        { key: 'full_name',     label: 'Пользователь' },
        { key: 'role_name',     label: 'Роль' },
        { key: 'total_docs',    label: 'Документов' },
        { key: 'distinct_types',label: 'Типов' },
        { key: 'last_activity', label: 'Последняя активность', format: 'datetime' }
      ]
    },
    {
      id: 'types-statuses', label: 'Документы по типам и статусам',
      url: '/reports/admin/types-statuses',
      columns: [
        { key: 'type_name',   label: 'Тип' },
        { key: 'status_name', label: 'Статус' },
        { key: 'qty',         label: 'Количество' }
      ]
    },
    {
      id: 'audit', label: 'Журнал действий',
      url: '/reports/admin/audit',
      filters: [{ name: 'days', label: 'За (дней)', type: 'number' }],
      columns: [
        { key: 'action_time', label: 'Время', format: 'datetime' },
        { key: 'who',         label: 'Кто' },
        { key: 'action',      label: 'Действие' },
        { key: 'reg_number',  label: 'Документ' },
        { key: 'old_value',   label: 'Было' },
        { key: 'new_value',   label: 'Стало' }
      ]
    }
  ],
  manager: [
    {
      id: 'pending', label: 'На моём согласовании',
      url: '/reports/manager/pending',
      columns: [
        { key: 'reg_number', label: '№' },
        { key: 'title',      label: 'Тема' },
        { key: 'type_name',  label: 'Тип' },
        { key: 'author',     label: 'Автор' },
        { key: 'step_order', label: 'Шаг' },
        { key: 'deadline',   label: 'Срок', format: 'date' }
      ]
    },
    {
      id: 'overdue', label: 'Просроченные документы',
      url: '/reports/manager/overdue',
      columns: [
        { key: 'department_name',  label: 'Отдел' },
        { key: 'overdue_count',    label: 'Кол-во просрочек' },
        { key: 'avg_days_overdue', label: 'Средняя просрочка (дней)' }
      ]
    },
    {
      id: 'team', label: 'Сводка по моему отделу',
      url: '/reports/manager/team',
      columns: [
        { key: 'full_name',  label: 'Сотрудник' },
        { key: 'position',   label: 'Должность' },
        { key: 'total_docs', label: 'Всего' },
        { key: 'approved',   label: 'Утверждено' },
        { key: 'rejected',   label: 'Отклонено' },
        { key: 'in_review',  label: 'На согласовании' }
      ]
    }
  ],
  clerk: [
    {
      id: 'registration', label: 'Регистрация по дням',
      url: '/reports/clerk/registration',
      columns: [
        { key: 'reg_date',         label: 'Дата', format: 'date' },
        { key: 'docs_registered',  label: 'Документов' },
        { key: 'unique_authors',   label: 'Авторов' }
      ]
    },
    {
      id: 'by-type', label: 'Документы по типам',
      url: '/reports/clerk/by-type',
      filters: [
        { name: 'date_from', label: 'С', type: 'date' },
        { name: 'date_to',   label: 'По', type: 'date' }
      ],
      columns: [
        { key: 'type_name', label: 'Тип' },
        { key: 'type_code', label: 'Код' },
        { key: 'qty',       label: 'Количество' },
        { key: 'first_doc', label: 'Первый', format: 'date' },
        { key: 'last_doc',  label: 'Последний', format: 'date' }
      ]
    },
    {
      id: 'no-route', label: 'Без маршрута согласования',
      url: '/reports/clerk/no-route',
      columns: [
        { key: 'reg_number', label: '№' },
        { key: 'title',      label: 'Тема' },
        { key: 'type_name',  label: 'Тип' },
        { key: 'author',     label: 'Автор' },
        { key: 'created_at', label: 'Дата', format: 'date' }
      ]
    }
  ],
  employee: [
    {
      id: 'by-status', label: 'Мои документы по статусам',
      url: '/reports/employee/by-status',
      columns: [
        { key: 'status_name', label: 'Статус' },
        { key: 'qty',         label: 'Количество' }
      ]
    },
    {
      id: 'in-progress', label: 'Мои документы в работе',
      url: '/reports/employee/in-progress',
      columns: [
        { key: 'reg_number',     label: '№' },
        { key: 'title',          label: 'Тема' },
        { key: 'status_name',    label: 'Статус' },
        { key: 'approved_steps', label: 'Согласовано' },
        { key: 'total_steps',    label: 'Всего шагов' },
        { key: 'created_at',     label: 'Создан', format: 'date' }
      ]
    },
    {
      id: 'history', label: 'История моих документов',
      url: '/reports/employee/history',
      columns: [
        { key: 'action_time',   label: 'Время', format: 'datetime' },
        { key: 'reg_number',    label: 'Документ' },
        { key: 'action',        label: 'Действие' },
        { key: 'old_value',     label: 'Было' },
        { key: 'new_value',     label: 'Стало' },
        { key: 'performed_by',  label: 'Кем' }
      ]
    }
  ]
}

const role = auth.role
const availableTabs = computed(() => (allReports[role] || []).map(r => ({ id: r.id, label: r.label })))
const activeTab = ref(availableTabs.value[0]?.id || '')
const activeReport = computed(() => (allReports[role] || []).find(r => r.id === activeTab.value))

const data = ref([])
const filterValues = ref({})

async function loadReport() {
  if (!activeReport.value) return
  const params = {}
  Object.keys(filterValues.value).forEach(k => {
    if (filterValues.value[k]) params[k] = filterValues.value[k]
  })
  try {
    const r = await api.get(activeReport.value.url, { params })
    data.value = r.data
  } catch (e) {
    data.value = []
  }
}

function setTab(id) {
  activeTab.value = id
  filterValues.value = {}
  loadReport()
}

function formatCell(val, col) {
  if (val === null || val === undefined) return '—'
  if (col.format === 'date')     return new Date(val).toLocaleDateString('ru-RU')
  if (col.format === 'datetime') return new Date(val).toLocaleString('ru-RU')
  return val
}

onMounted(loadReport)
watch(activeTab, loadReport)
</script>
