-- =====================================================================
-- Примеры запросов и отчётов
-- (отчёты, агрегации и фильтры — для каждой роли)
-- =====================================================================

-- =========================
-- БАЗОВЫЕ CRUD-ЗАПРОСЫ
-- =========================

-- SELECT: список всех документов с расшифровкой связанных таблиц
SELECT
    d.document_id,
    d.reg_number,
    d.title,
    dt.type_name      AS type,
    ds.status_name    AS status,
    u.full_name       AS author,
    dep.department_name AS department,
    d.created_at,
    d.deadline
FROM documents d
JOIN document_types    dt  ON d.type_id       = dt.type_id
JOIN document_statuses ds  ON d.status_id     = ds.status_id
JOIN users             u   ON d.author_id     = u.user_id
LEFT JOIN departments  dep ON d.department_id = dep.department_id
ORDER BY d.created_at DESC;

-- INSERT: создание документа
INSERT INTO documents (title, content, type_id, status_id, author_id, department_id, deadline)
VALUES ('Тестовый документ', 'Содержание...', 1, 1, 1, 1, '2026-12-31');

-- UPDATE: смена статуса документа
UPDATE documents
SET status_id = (SELECT status_id FROM document_statuses WHERE status_code = 'APPROVED')
WHERE document_id = 1;

-- DELETE: удаление документа
DELETE FROM documents WHERE document_id = 999;

-- =========================
-- ОТЧЁТЫ ДЛЯ АДМИНИСТРАТОРА
-- =========================

-- ОТЧЁТ 1 (admin): Активность пользователей за период
SELECT
    u.full_name,
    r.role_name,
    COUNT(d.document_id)             AS total_docs,
    COUNT(DISTINCT d.type_id)        AS distinct_types,
    MAX(d.created_at)                AS last_activity
FROM users u
JOIN roles r ON u.role_id = r.role_id
LEFT JOIN documents d ON u.user_id = d.author_id
    AND d.created_at BETWEEN '2026-01-01' AND '2026-12-31'
GROUP BY u.user_id, u.full_name, r.role_name
ORDER BY total_docs DESC;

-- ОТЧЁТ 2 (admin): Распределение документов по типам и статусам
SELECT
    dt.type_name,
    ds.status_name,
    COUNT(*)                                            AS qty,
    ROUND(AVG(EXTRACT(EPOCH FROM (CURRENT_TIMESTAMP - d.created_at))/86400)::NUMERIC, 1) AS avg_age_days
FROM documents d
JOIN document_types    dt ON d.type_id   = dt.type_id
JOIN document_statuses ds ON d.status_id = ds.status_id
GROUP BY dt.type_name, ds.status_name
ORDER BY dt.type_name, ds.status_name;

-- ОТЧЁТ 3 (admin): Журнал действий за последние N дней (с фильтром)
SELECT
    h.action_time,
    u.full_name      AS who,
    h.action,
    d.reg_number,
    h.old_value,
    h.new_value
FROM document_history h
LEFT JOIN users     u ON h.user_id     = u.user_id
JOIN documents      d ON h.document_id = d.document_id
WHERE h.action_time >= CURRENT_TIMESTAMP - INTERVAL '30 days'
ORDER BY h.action_time DESC;

-- =========================
-- ОТЧЁТЫ ДЛЯ РУКОВОДИТЕЛЯ
-- =========================

-- ОТЧЁТ 1 (manager): Документы, ожидающие согласования у пользователя
SELECT
    d.reg_number,
    d.title,
    dt.type_name,
    u_author.full_name  AS author,
    dr.step_order,
    d.deadline,
    d.created_at
FROM document_routes dr
JOIN documents      d        ON dr.document_id = d.document_id
JOIN document_types dt       ON d.type_id      = dt.type_id
JOIN users          u_author ON d.author_id    = u_author.user_id
WHERE dr.approver_id = :user_id
  AND dr.decision    = 'pending'
ORDER BY d.deadline NULLS LAST;

-- ОТЧЁТ 2 (manager): Просроченные документы по отделам
SELECT
    dep.department_name,
    COUNT(*)                                                         AS overdue_count,
    ROUND(AVG(CURRENT_DATE - d.deadline)::NUMERIC, 1)                AS avg_days_overdue
FROM documents d
JOIN departments       dep ON d.department_id = dep.department_id
JOIN document_statuses ds  ON d.status_id     = ds.status_id
WHERE d.deadline < CURRENT_DATE
  AND ds.status_code IN ('DRAFT', 'IN_REVIEW')
GROUP BY dep.department_name
ORDER BY overdue_count DESC;

-- ОТЧЁТ 3 (manager): Сводка по сотрудникам отдела
SELECT
    u.full_name,
    u.position,
    COUNT(d.document_id)                                          AS total_docs,
    SUM(CASE WHEN ds.status_code = 'APPROVED' THEN 1 ELSE 0 END)  AS approved,
    SUM(CASE WHEN ds.status_code = 'REJECTED' THEN 1 ELSE 0 END)  AS rejected,
    SUM(CASE WHEN ds.status_code = 'IN_REVIEW' THEN 1 ELSE 0 END) AS in_review
FROM users u
LEFT JOIN documents          d  ON u.user_id   = d.author_id
LEFT JOIN document_statuses  ds ON d.status_id = ds.status_id
WHERE u.department_id = :dept_id
GROUP BY u.user_id, u.full_name, u.position
ORDER BY total_docs DESC;

-- =========================
-- ОТЧЁТЫ ДЛЯ ДЕЛОПРОИЗВОДИТЕЛЯ
-- =========================

-- ОТЧЁТ 1 (clerk): Регистрация документов по дням
SELECT
    DATE(d.registered_at)        AS reg_date,
    COUNT(*)                     AS docs_registered,
    COUNT(DISTINCT d.author_id)  AS unique_authors
FROM documents d
WHERE d.registered_at IS NOT NULL
  AND d.registered_at >= CURRENT_DATE - INTERVAL '30 days'
GROUP BY DATE(d.registered_at)
ORDER BY reg_date DESC;

-- ОТЧЁТ 2 (clerk): Документы по типам с фильтром по периоду
SELECT
    dt.type_name,
    dt.type_code,
    COUNT(*)                                                     AS qty,
    MIN(d.created_at)                                            AS first_doc,
    MAX(d.created_at)                                            AS last_doc
FROM documents d
JOIN document_types dt ON d.type_id = dt.type_id
WHERE d.created_at BETWEEN :date_from AND :date_to
GROUP BY dt.type_name, dt.type_code
ORDER BY qty DESC;

-- ОТЧЁТ 3 (clerk): Документы без маршрута согласования
SELECT
    d.reg_number,
    d.title,
    dt.type_name,
    u.full_name AS author,
    d.created_at
FROM documents d
JOIN document_types dt ON d.type_id    = dt.type_id
JOIN users          u  ON d.author_id  = u.user_id
LEFT JOIN document_routes dr ON d.document_id = dr.document_id
WHERE dr.route_id IS NULL
ORDER BY d.created_at DESC;

-- =========================
-- ОТЧЁТЫ ДЛЯ СОТРУДНИКА
-- =========================

-- ОТЧЁТ 1 (employee): Мои документы по статусам
SELECT
    ds.status_name,
    COUNT(*) AS qty
FROM documents d
JOIN document_statuses ds ON d.status_id = ds.status_id
WHERE d.author_id = :user_id
GROUP BY ds.status_name;

-- ОТЧЁТ 2 (employee): Мои документы на согласовании (с прогрессом)
SELECT
    d.reg_number,
    d.title,
    ds.status_name,
    COUNT(dr.route_id) FILTER (WHERE dr.decision = 'approved') AS approved_steps,
    COUNT(dr.route_id)                                         AS total_steps,
    d.created_at
FROM documents d
JOIN document_statuses ds  ON d.status_id    = ds.status_id
LEFT JOIN document_routes dr ON d.document_id = dr.document_id
WHERE d.author_id   = :user_id
  AND ds.status_code IN ('IN_REVIEW', 'DRAFT')
GROUP BY d.document_id, d.reg_number, d.title, ds.status_name, d.created_at
ORDER BY d.created_at DESC;

-- ОТЧЁТ 3 (employee): История работы с моими документами
SELECT
    h.action_time,
    d.reg_number,
    h.action,
    h.old_value,
    h.new_value,
    u.full_name AS performed_by
FROM document_history h
JOIN documents d ON h.document_id = d.document_id
LEFT JOIN users u ON h.user_id    = u.user_id
WHERE d.author_id = :user_id
ORDER BY h.action_time DESC
LIMIT 50;
