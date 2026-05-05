# DocFlow

Курсовой проект по дисциплине «Базы данных».

## Запуск

### 1. База данных

Убедитесь, что PostgreSQL запущен, затем выполните:

```bash
psql -U postgres -f database/01_schema.sql
psql -U postgres -d docflow -f database/02_procedures.sql
psql -U postgres -d docflow -f database/03_seed_data.sql
```

### 2. Переменные окружения

Создайте файл `backend/.env` и укажите пароль от PostgreSQL:

```
DB_PASSWORD=ваш_пароль
```

### 3. Бэкенд

```bash
cd backend
npm install
npm start
```

Сервер запустится на `http://localhost:3000`.

### 4. Фронтенд

```bash
cd frontend
npm install
npm run dev
```

Откройте в браузере: **http://localhost:5173**

## Аккаунты

| Логин     | Пароль   | Роль              |
|-----------|----------|-------------------|
| admin     | admin    | Администратор     |
| ivanov    | ivanov   | Директор          |
| petrova   | petrova  | Главный бухгалтер |
| sidorova  | sidorova | Делопроизводитель |
| morozova  | morozova | Юрист             |
| kuznetsov | pass     | Сотрудник         |
| volkov    | pass     | Сотрудник         |
| orlova    | pass     | Сотрудник         |
