-- =====================================================================
-- Демонстрационные запросы для защиты курсовой работы
-- DocFlow — система корпоративного документооборота
-- Запускать в psql: psql -U postgres -d docflow -f database/05_demo_queries.sql
-- Или открыть в pgAdmin / TablePlus и выполнять по одному блоку
-- =====================================================================

\c docflow

-- =====================================================================
-- ЗАПРОС 1: SELECT — выборка с JOIN по нескольким таблицам
-- Показывает все документы с расшифровкой типа, статуса, автора, отдела
-- =====================================================================

SELECT
    d.document_id,
    d.reg_number                AS "Рег. номер",
    d.title                     AS "Заголовок",
    dt.type_name                AS "Тип",
    ds.status_name              AS "Статус",
    u.full_name                 AS "Автор",
    dep.department_name         AS "Отдел",
    d.created_at::DATE          AS "Дата создания",
    d.deadline                  AS "Срок"
FROM documents d
JOIN document_types    dt  ON d.type_id       = dt.type_id
JOIN document_statuses ds  ON d.status_id     = ds.status_id
JOIN users             u   ON d.author_id     = u.user_id
LEFT JOIN departments  dep ON d.department_id = dep.department_id
ORDER BY d.created_at DESC;


-- =====================================================================
-- ЗАПРОС 2: INSERT — добавление нового документа
-- Регистрационный номер присвоится автоматически триггером
-- =====================================================================

INSERT INTO documents (title, content, type_id, status_id, author_id, department_id, deadline)
VALUES (
    'Приказ о проведении инвентаризации',
    'В соответствии с планом провести инвентаризацию основных средств отдела.',
    1,              -- type_id = 1 (Приказ)
    1,              -- status_id = 1 (Черновик)
    2,              -- author_id = 2 (Иванов И.И.)
    1,              -- department_id = 1 (Администрация)
    '2026-07-01'
)
RETURNING document_id, reg_number, registered_at;  -- покажет присвоенный номер


-- =====================================================================
-- ЗАПРОС 3: UPDATE — изменение данных (смена статуса)
-- Подзапрос ищет нужный status_id по коду, чтобы не хардкодить число
-- =====================================================================

UPDATE documents
SET status_id = (
    SELECT status_id
    FROM document_statuses
    WHERE status_code = 'APPROVED'
)
WHERE document_id = 10
RETURNING document_id, reg_number, status_id;  -- подтверждение изменения


-- =====================================================================
-- ЗАПРОС 4: DELETE — удаление записи
-- CASCADE автоматически удалит маршрут и историю этого документа
-- =====================================================================

-- Сначала посмотрим, что удалим
SELECT d.document_id, d.reg_number, d.title,
       COUNT(dr.route_id)  AS маршрутов,
       COUNT(dh.history_id) AS записей_в_журнале
FROM documents d
LEFT JOIN document_routes  dr ON d.document_id = dr.document_id
LEFT JOIN document_history dh ON d.document_id = dh.document_id
WHERE d.document_id = 10
GROUP BY d.document_id, d.reg_number, d.title;

-- Затем удаляем
DELETE FROM documents WHERE document_id = 10;


-- =====================================================================
-- ЗАПРОС 5: GROUP BY — агрегация данных
-- Количество документов по каждому типу и статусу + средний возраст
-- =====================================================================

SELECT
    dt.type_name                                              AS "Тип",
    ds.status_name                                            AS "Статус",
    COUNT(*)                                                  AS "Количество",
    MIN(d.created_at::DATE)                                   AS "Самый старый",
    MAX(d.created_at::DATE)                                   AS "Самый новый",
    ROUND(
        AVG(EXTRACT(EPOCH FROM (CURRENT_TIMESTAMP - d.created_at)) / 86400)::NUMERIC,
        1
    )                                                         AS "Ср. возраст (дней)"
FROM documents d
JOIN document_types    dt ON d.type_id   = dt.type_id
JOIN document_statuses ds ON d.status_id = ds.status_id
GROUP BY dt.type_name, ds.status_name
ORDER BY "Количество" DESC;


-- =====================================================================
-- ЗАПРОС 6: Подзапрос (вложенный SELECT)
-- Находит пользователей, у которых есть документы на согласовании,
-- и показывает сводку по каждому: всего / утверждено / отклонено / на согласовании
-- =====================================================================

SELECT
    u.full_name                  AS "Сотрудник",
    r.role_name                  AS "Роль",
    stats.total_docs             AS "Всего документов",
    stats.approved               AS "Утверждено",
    stats.rejected               AS "Отклонено",
    stats.in_review              AS "На согласовании"
FROM users u
JOIN roles r ON u.role_id = r.role_id
JOIN (
    -- Подзапрос: считаем документы каждого автора по статусам
    SELECT
        d.author_id,
        COUNT(*)                                                         AS total_docs,
        SUM(CASE WHEN ds.status_code = 'APPROVED'   THEN 1 ELSE 0 END) AS approved,
        SUM(CASE WHEN ds.status_code = 'REJECTED'   THEN 1 ELSE 0 END) AS rejected,
        SUM(CASE WHEN ds.status_code = 'IN_REVIEW'  THEN 1 ELSE 0 END) AS in_review
    FROM documents d
    JOIN document_statuses ds ON d.status_id = ds.status_id
    GROUP BY d.author_id
) AS stats ON u.user_id = stats.author_id
ORDER BY stats.total_docs DESC;


-- =====================================================================
-- БОНУС: вызов хранимой процедуры и функции
-- =====================================================================

-- Архивировать документы старше 30 дней
CALL archive_old_documents(30);

-- Количество документов конкретного пользователя
SELECT get_user_document_count(2) AS "Документов у Иванова";

-- Маршрут согласования документа (с прогрессом)
SELECT
    d.reg_number,
    u.full_name    AS "Согласующий",
    dr.step_order  AS "Шаг",
    dr.decision    AS "Решение",
    dr.comment     AS "Комментарий",
    dr.decided_at  AS "Дата решения"
FROM document_routes dr
JOIN documents d ON dr.document_id = d.document_id
JOIN users     u ON dr.approver_id = u.user_id
WHERE d.document_id = 2
ORDER BY dr.step_order;

-- Журнал действий (аудит) — последние 10 записей
SELECT
    h.action_time::TIMESTAMP(0)  AS "Время",
    u.full_name                  AS "Кто",
    h.action                     AS "Действие",
    d.reg_number                 AS "Документ",
    h.old_value                  AS "Было",
    h.new_value                  AS "Стало"
FROM document_history h
LEFT JOIN users    u ON h.user_id     = u.user_id
JOIN      documents d ON h.document_id = d.document_id
ORDER BY h.action_time DESC
LIMIT 10;
