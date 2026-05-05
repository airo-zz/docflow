-- =====================================================================
-- База данных корпоративного документооборота
-- Курсовой проект, дисциплина "Базы данных"
-- Выполнил: Джалалов Э.Р., группа И-1-24
-- СУБД: PostgreSQL 14+
-- =====================================================================

-- Удаление существующей БД (для повторного запуска)
DROP DATABASE IF EXISTS docflow;
CREATE DATABASE docflow
    WITH ENCODING 'UTF8'
    LC_COLLATE = 'C'
    LC_CTYPE = 'C'
    TEMPLATE = template0;

\c docflow;

-- =====================================================================
-- Таблица 1. Роли пользователей
-- =====================================================================
CREATE TABLE roles (
    role_id     SERIAL PRIMARY KEY,
    role_name   VARCHAR(50)  NOT NULL UNIQUE,
    description VARCHAR(255)
);

COMMENT ON TABLE roles IS 'Роли пользователей системы';

-- =====================================================================
-- Таблица 2. Отделы организации
-- =====================================================================
CREATE TABLE departments (
    department_id   SERIAL PRIMARY KEY,
    department_name VARCHAR(150) NOT NULL UNIQUE,
    head_name       VARCHAR(150),
    phone           VARCHAR(20),
    CONSTRAINT chk_phone CHECK (phone IS NULL OR phone ~ '^[+0-9() -]+$')
);

COMMENT ON TABLE departments IS 'Отделы организации';

-- =====================================================================
-- Таблица 3. Пользователи
-- =====================================================================
CREATE TABLE users (
    user_id       SERIAL PRIMARY KEY,
    login         VARCHAR(50)  NOT NULL UNIQUE,
    password_hash VARCHAR(255) NOT NULL,
    full_name     VARCHAR(150) NOT NULL,
    email         VARCHAR(100) NOT NULL UNIQUE,
    role_id       INTEGER      NOT NULL REFERENCES roles(role_id) ON DELETE RESTRICT,
    department_id INTEGER      REFERENCES departments(department_id) ON DELETE SET NULL,
    position      VARCHAR(100),
    is_active     BOOLEAN      NOT NULL DEFAULT TRUE,
    created_at    TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT chk_email CHECK (email ~* '^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$'),
    CONSTRAINT chk_login CHECK (LENGTH(login) >= 3)
);

COMMENT ON TABLE users IS 'Пользователи системы';

-- =====================================================================
-- Таблица 4. Типы документов
-- =====================================================================
CREATE TABLE document_types (
    type_id     SERIAL PRIMARY KEY,
    type_name   VARCHAR(100) NOT NULL UNIQUE,
    type_code   VARCHAR(10)  NOT NULL UNIQUE,
    description VARCHAR(255)
);

COMMENT ON TABLE document_types IS 'Справочник типов документов';

-- =====================================================================
-- Таблица 5. Статусы документов
-- =====================================================================
CREATE TABLE document_statuses (
    status_id   SERIAL PRIMARY KEY,
    status_name VARCHAR(50) NOT NULL UNIQUE,
    status_code VARCHAR(20) NOT NULL UNIQUE
);

COMMENT ON TABLE document_statuses IS 'Возможные статусы документов';

-- =====================================================================
-- Таблица 6. Документы (основная таблица)
-- =====================================================================
CREATE TABLE documents (
    document_id     SERIAL PRIMARY KEY,
    reg_number      VARCHAR(50)  UNIQUE,
    title           VARCHAR(255) NOT NULL,
    content         TEXT,
    type_id         INTEGER      NOT NULL REFERENCES document_types(type_id) ON DELETE RESTRICT,
    status_id       INTEGER      NOT NULL REFERENCES document_statuses(status_id) ON DELETE RESTRICT,
    author_id       INTEGER      NOT NULL REFERENCES users(user_id) ON DELETE RESTRICT,
    department_id   INTEGER      REFERENCES departments(department_id) ON DELETE SET NULL,
    created_at      TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
    registered_at   TIMESTAMP,
    deadline        DATE,
    CONSTRAINT chk_title CHECK (LENGTH(title) >= 3),
    CONSTRAINT chk_deadline CHECK (deadline IS NULL OR deadline >= created_at::DATE)
);

CREATE INDEX idx_documents_author ON documents(author_id);
CREATE INDEX idx_documents_status ON documents(status_id);
CREATE INDEX idx_documents_type ON documents(type_id);
CREATE INDEX idx_documents_created ON documents(created_at);

COMMENT ON TABLE documents IS 'Основная таблица документов';

-- =====================================================================
-- Таблица 7. Маршруты согласования
-- =====================================================================
CREATE TABLE document_routes (
    route_id      SERIAL PRIMARY KEY,
    document_id   INTEGER      NOT NULL REFERENCES documents(document_id) ON DELETE CASCADE,
    approver_id   INTEGER      NOT NULL REFERENCES users(user_id) ON DELETE RESTRICT,
    step_order    INTEGER      NOT NULL,
    decision      VARCHAR(20)  DEFAULT 'pending',
    comment       TEXT,
    decided_at    TIMESTAMP,
    CONSTRAINT chk_decision CHECK (decision IN ('pending', 'approved', 'rejected')),
    CONSTRAINT chk_step CHECK (step_order > 0),
    CONSTRAINT uk_route UNIQUE (document_id, step_order)
);

CREATE INDEX idx_routes_document ON document_routes(document_id);
CREATE INDEX idx_routes_approver ON document_routes(approver_id);

COMMENT ON TABLE document_routes IS 'Маршруты согласования документов';

-- =====================================================================
-- Таблица 8. Журнал действий (аудит)
-- =====================================================================
CREATE TABLE document_history (
    history_id  SERIAL PRIMARY KEY,
    document_id INTEGER      NOT NULL REFERENCES documents(document_id) ON DELETE CASCADE,
    user_id     INTEGER      REFERENCES users(user_id) ON DELETE SET NULL,
    action      VARCHAR(50)  NOT NULL,
    old_value   VARCHAR(255),
    new_value   VARCHAR(255),
    action_time TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_history_document ON document_history(document_id);
CREATE INDEX idx_history_time ON document_history(action_time);

COMMENT ON TABLE document_history IS 'Журнал действий с документами (аудит)';
