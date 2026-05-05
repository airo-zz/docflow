-- =====================================================================
-- Хранимые процедуры, функции и триггеры
-- =====================================================================

-- ---------------------------------------------------------------------
-- ФУНКЦИЯ 1. Автоматическое присвоение регистрационного номера
-- ---------------------------------------------------------------------
CREATE OR REPLACE FUNCTION generate_reg_number(p_type_id INTEGER)
RETURNS VARCHAR AS $$
DECLARE
    v_code      VARCHAR(10);
    v_count     INTEGER;
    v_year      INTEGER;
    v_reg_num   VARCHAR(50);
BEGIN
    SELECT type_code INTO v_code FROM document_types WHERE type_id = p_type_id;

    v_year := EXTRACT(YEAR FROM CURRENT_DATE);

    SELECT COUNT(*) + 1 INTO v_count
    FROM documents d
    JOIN document_types dt ON d.type_id = dt.type_id
    WHERE dt.type_code = v_code
      AND EXTRACT(YEAR FROM d.created_at) = v_year;

    v_reg_num := v_code || '-' || LPAD(v_count::TEXT, 4, '0') || '/' || v_year;
    RETURN v_reg_num;
END;
$$ LANGUAGE plpgsql;

-- ---------------------------------------------------------------------
-- ТРИГГЕР 1. Автоматическая регистрация документа при вставке
-- ---------------------------------------------------------------------
CREATE OR REPLACE FUNCTION trg_assign_reg_number()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.reg_number IS NULL THEN
        NEW.reg_number := generate_reg_number(NEW.type_id);
        NEW.registered_at := CURRENT_TIMESTAMP;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER documents_before_insert
BEFORE INSERT ON documents
FOR EACH ROW
EXECUTE FUNCTION trg_assign_reg_number();

-- ---------------------------------------------------------------------
-- ТРИГГЕР 2. Запись в журнал при создании документа
-- ---------------------------------------------------------------------
CREATE OR REPLACE FUNCTION trg_log_create()
RETURNS TRIGGER AS $$
BEGIN
    INSERT INTO document_history (document_id, user_id, action, new_value)
    VALUES (NEW.document_id, NEW.author_id, 'CREATE', NEW.title);
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER documents_after_insert
AFTER INSERT ON documents
FOR EACH ROW
EXECUTE FUNCTION trg_log_create();

-- ---------------------------------------------------------------------
-- ТРИГГЕР 3. Запись в журнал при изменении статуса документа
-- ---------------------------------------------------------------------
CREATE OR REPLACE FUNCTION trg_log_status_change()
RETURNS TRIGGER AS $$
DECLARE
    v_old_status VARCHAR(50);
    v_new_status VARCHAR(50);
BEGIN
    IF OLD.status_id <> NEW.status_id THEN
        SELECT status_name INTO v_old_status FROM document_statuses WHERE status_id = OLD.status_id;
        SELECT status_name INTO v_new_status FROM document_statuses WHERE status_id = NEW.status_id;

        INSERT INTO document_history (document_id, user_id, action, old_value, new_value)
        VALUES (NEW.document_id, NEW.author_id, 'STATUS_CHANGE', v_old_status, v_new_status);
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER documents_after_update
AFTER UPDATE ON documents
FOR EACH ROW
EXECUTE FUNCTION trg_log_status_change();

-- ---------------------------------------------------------------------
-- ПРОЦЕДУРА 1. Создание документа с маршрутом согласования
-- ---------------------------------------------------------------------
CREATE OR REPLACE PROCEDURE create_document_with_route(
    p_title         VARCHAR,
    p_content       TEXT,
    p_type_id       INTEGER,
    p_author_id     INTEGER,
    p_department_id INTEGER,
    p_deadline      DATE,
    p_approvers     INTEGER[]
)
LANGUAGE plpgsql AS $$
DECLARE
    v_doc_id     INTEGER;
    v_status_id  INTEGER;
    v_approver   INTEGER;
    v_step       INTEGER := 1;
BEGIN
    SELECT status_id INTO v_status_id FROM document_statuses WHERE status_code = 'DRAFT';

    INSERT INTO documents (title, content, type_id, status_id, author_id, department_id, deadline)
    VALUES (p_title, p_content, p_type_id, v_status_id, p_author_id, p_department_id, p_deadline)
    RETURNING document_id INTO v_doc_id;

    IF p_approvers IS NOT NULL THEN
        FOREACH v_approver IN ARRAY p_approvers
        LOOP
            INSERT INTO document_routes (document_id, approver_id, step_order)
            VALUES (v_doc_id, v_approver, v_step);
            v_step := v_step + 1;
        END LOOP;
    END IF;
END;
$$;

-- ---------------------------------------------------------------------
-- ПРОЦЕДУРА 2. Принятие решения по документу (согласование/отклонение)
-- ---------------------------------------------------------------------
CREATE OR REPLACE PROCEDURE process_approval(
    p_route_id  INTEGER,
    p_decision  VARCHAR,
    p_comment   TEXT
)
LANGUAGE plpgsql AS $$
DECLARE
    v_doc_id        INTEGER;
    v_pending_count INTEGER;
    v_status_id     INTEGER;
BEGIN
    UPDATE document_routes
    SET decision   = p_decision,
        comment    = p_comment,
        decided_at = CURRENT_TIMESTAMP
    WHERE route_id = p_route_id
    RETURNING document_id INTO v_doc_id;

    IF p_decision = 'rejected' THEN
        SELECT status_id INTO v_status_id FROM document_statuses WHERE status_code = 'REJECTED';
        UPDATE documents SET status_id = v_status_id WHERE document_id = v_doc_id;
        RETURN;
    END IF;

    SELECT COUNT(*) INTO v_pending_count
    FROM document_routes
    WHERE document_id = v_doc_id AND decision = 'pending';

    IF v_pending_count = 0 THEN
        SELECT status_id INTO v_status_id FROM document_statuses WHERE status_code = 'APPROVED';
        UPDATE documents SET status_id = v_status_id WHERE document_id = v_doc_id;
    ELSE
        SELECT status_id INTO v_status_id FROM document_statuses WHERE status_code = 'IN_REVIEW';
        UPDATE documents SET status_id = v_status_id WHERE document_id = v_doc_id;
    END IF;
END;
$$;

-- ---------------------------------------------------------------------
-- ПРОЦЕДУРА 3. Архивация старых документов
-- ---------------------------------------------------------------------
CREATE OR REPLACE PROCEDURE archive_old_documents(p_days INTEGER)
LANGUAGE plpgsql AS $$
DECLARE
    v_archive_id  INTEGER;
    v_approved_id INTEGER;
    v_count       INTEGER;
BEGIN
    SELECT status_id INTO v_archive_id FROM document_statuses WHERE status_code = 'ARCHIVED';
    SELECT status_id INTO v_approved_id FROM document_statuses WHERE status_code = 'APPROVED';

    UPDATE documents
    SET status_id = v_archive_id
    WHERE status_id = v_approved_id
      AND created_at < CURRENT_DATE - p_days;

    GET DIAGNOSTICS v_count = ROW_COUNT;
    RAISE NOTICE 'Заархивировано документов: %', v_count;
END;
$$;

-- ---------------------------------------------------------------------
-- ФУНКЦИЯ 2. Получение количества документов пользователя
-- ---------------------------------------------------------------------
CREATE OR REPLACE FUNCTION get_user_document_count(p_user_id INTEGER)
RETURNS INTEGER AS $$
DECLARE
    v_count INTEGER;
BEGIN
    SELECT COUNT(*) INTO v_count FROM documents WHERE author_id = p_user_id;
    RETURN v_count;
END;
$$ LANGUAGE plpgsql;
