-- тестовые данные для базы документооборота
-- пароли: у админа/руководителей/делопроизводителя совпадают с логином,
-- у обычных сотрудников — pass. Хэши через bcrypt (saltRounds=10).

-- роли
INSERT INTO roles (role_name, description) VALUES
    ('admin',            'Администратор системы — полный доступ'),
    ('director',         'Директор — согласование любых документов'),
    ('chief_accountant', 'Главный бухгалтер — согласование финансовых документов'),
    ('lawyer',           'Юрист — согласование договоров и писем'),
    ('clerk',            'Делопроизводитель — регистрация документов'),
    ('employee',         'Сотрудник — создание документов');

-- отделы
INSERT INTO departments (department_name, head_name, phone) VALUES
    ('Администрация',           'Иванов И.И.', '+7(978)100-10-10'),
    ('Бухгалтерия',             'Петрова А.С.', '+7(978)100-20-20'),
    ('Отдел кадров',            'Сидорова М.В.','+7(978)100-30-30'),
    ('IT-отдел',                'Кузнецов Д.А.','+7(978)100-40-40'),
    ('Юридический отдел',       'Морозова Е.П.','+7(978)100-50-50');

-- типы документов
INSERT INTO document_types (type_name, type_code, description) VALUES
    ('Приказ',                'ПР',  'Распорядительный документ'),
    ('Служебная записка',     'СЗ',  'Внутренний документ'),
    ('Договор',               'ДГ',  'Договор с контрагентом'),
    ('Входящее письмо',       'ВХ',  'Корреспонденция извне'),
    ('Исходящее письмо',      'ИС',  'Корреспонденция вовне'),
    ('Заявление',             'ЗВ',  'Заявление сотрудника');

-- статусы
INSERT INTO document_statuses (status_name, status_code) VALUES
    ('Черновик',              'DRAFT'),
    ('На согласовании',       'IN_REVIEW'),
    ('Утвержден',             'APPROVED'),
    ('Отклонен',              'REJECTED'),
    ('В архиве',              'ARCHIVED');

-- пользователи
-- admin/admin, ivanov/ivanov, petrova/petrova, sidorova/sidorova, morozova/morozova
-- kuznetsov/pass, volkov/pass, orlova/pass
INSERT INTO users (login, password_hash, full_name, email, role_id, department_id, position) VALUES
    ('admin',    '$2b$10$l8O//0gJqXGwgiN3.GA4NuUdwssEGjXfvmr5u.vSSZbaepQczCQ0O', 'Джалалов Эмир Рустемович',  'admin@docflow.local',    1, 4, 'Администратор системы'),
    ('ivanov',   '$2b$10$qkr1C1uUbp.CnEbqeiG1MegpZyVgGwfZbXb8i8vP6uSlGCnqwxF9u', 'Иванов Иван Иванович',      'ivanov@docflow.local',   2, 1, 'Директор'),
    ('petrova',  '$2b$10$OWwVok3iXxjxixq9a/xpgeBwjQZ/3SWSP/vinyQRATIgdH5CCHqdy', 'Петрова Анна Сергеевна',    'petrova@docflow.local',  3, 2, 'Главный бухгалтер'),
    ('sidorova', '$2b$10$tt9Dvyn.kpr1NSpLFbQKUeqQ23q5RmQWpNYbjS2VkoDaugOnKXRAO', 'Сидорова Мария Викторовна', 'sidorova@docflow.local', 5, 3, 'Делопроизводитель'),
    ('morozova', '$2b$10$5sjH3FirSxQGG0gJwaN4duU8rkPPaCZTedaJSb1TsCz1YvvtqnZ36', 'Морозова Елена Павловна',   'morozova@docflow.local', 4, 5, 'Начальник юридического отдела'),
    ('kuznetsov','$2b$10$xSMSpSQG3yk7ZMSDul9ogehscojoVe3MG9Qo/iAxS1MLLOT3p6oJC', 'Кузнецов Дмитрий Алексеевич','kuznetsov@docflow.local',6, 4, 'Программист'),
    ('volkov',   '$2b$10$xSMSpSQG3yk7ZMSDul9ogehscojoVe3MG9Qo/iAxS1MLLOT3p6oJC', 'Волков Сергей Николаевич',  'volkov@docflow.local',   6, 2, 'Бухгалтер'),
    ('orlova',   '$2b$10$xSMSpSQG3yk7ZMSDul9ogehscojoVe3MG9Qo/iAxS1MLLOT3p6oJC', 'Орлова Татьяна Игоревна',   'orlova@docflow.local',   6, 3, 'Специалист по кадрам');

-- тестовые документы
INSERT INTO documents (title, content, type_id, status_id, author_id, department_id, deadline) VALUES
    ('О приёме на работу нового сотрудника',  'В связи с расширением IT-отдела принять на работу программиста с 01.05.2026.',  1, 3, 4, 3, '2026-05-01'),
    ('О закупке оргтехники',                  'Прошу согласовать закупку 5 ноутбуков для IT-отдела на сумму 450 000 руб.',     2, 2, 6, 4, '2026-05-15'),
    ('Договор на поставку канцтоваров',       'Договор с ООО "Канцелярия+" на поставку канцтоваров на 2026 год.',              3, 1, 3, 2, '2026-12-31'),
    ('Заявление на отпуск',                   'Прошу предоставить ежегодный оплачиваемый отпуск с 01.06.2026 по 28.06.2026.',  6, 3, 7, 2, '2026-06-01'),
    ('Об утверждении штатного расписания',    'Утвердить штатное расписание на 2026 год в редакции согласно приложению.',      1, 2, 2, 1, '2026-05-30'),
    ('Запрос документов от ИФНС',             'Входящий запрос от налоговой о предоставлении документов за 2025 год.',         4, 1, 4, 2, '2026-05-20'),
    ('Ответ на претензию',                    'Подготовлен ответ на досудебную претензию от контрагента ООО "Поставщик".',     5, 2, 5, 5, '2026-05-10'),
    ('О премировании сотрудников',            'По итогам квартала премировать сотрудников бухгалтерии.',                       1, 3, 2, 1, '2026-04-30'),
    ('Служебная записка о ремонте',           'Прошу выделить средства на ремонт серверной комнаты.',                          2, 4, 6, 4, '2026-06-15'),
    ('Заявление о переводе',                  'Прошу перевести меня на должность старшего программиста.',                     6, 1, 6, 4, '2026-05-25');

-- маршруты согласования для нескольких документов
INSERT INTO document_routes (document_id, approver_id, step_order, decision, comment, decided_at) VALUES
    (2, 3, 1, 'approved', 'Согласовано',                   CURRENT_TIMESTAMP - INTERVAL '2 days'),
    (2, 2, 2, 'pending',  NULL,                            NULL),
    (3, 5, 1, 'pending',  NULL,                            NULL),
    (5, 3, 1, 'approved', 'Финансово обосновано',          CURRENT_TIMESTAMP - INTERVAL '3 days'),
    (5, 5, 2, 'pending',  NULL,                            NULL),
    (7, 2, 1, 'pending',  NULL,                            NULL),
    (9, 3, 1, 'rejected', 'Бюджет не предусмотрен',        CURRENT_TIMESTAMP - INTERVAL '1 day');
