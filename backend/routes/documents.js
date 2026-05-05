const express = require('express');
const pool    = require('../db');
const { authenticate, requireRole, APPROVER_ROLES } = require('../middleware/auth');

const router = express.Router();

// GET /api/documents — список документов (с фильтрами)
router.get('/', authenticate, async (req, res) => {
  const { status, type, search } = req.query;
  const params = [];
  const where  = [];

  // Сотрудник видит только свои; остальные — все
  if (req.user.role === 'employee') {
    params.push(req.user.id);
    where.push(`d.author_id = $${params.length}`);
  }

  if (status) {
    params.push(status);
    where.push(`ds.status_code = $${params.length}`);
  }

  if (type) {
    params.push(type);
    where.push(`dt.type_code = $${params.length}`);
  }

  if (search) {
    params.push(`%${search}%`);
    where.push(`(d.title ILIKE $${params.length} OR d.reg_number ILIKE $${params.length})`);
  }

  const whereSQL = where.length ? 'WHERE ' + where.join(' AND ') : '';

  try {
    const sql = `
      SELECT d.document_id, d.reg_number, d.title, d.created_at, d.deadline,
             dt.type_name, dt.type_code,
             ds.status_name, ds.status_code,
             u.full_name AS author_name,
             dep.department_name
      FROM documents d
      JOIN document_types dt    ON d.type_id      = dt.type_id
      JOIN document_statuses ds ON d.status_id    = ds.status_id
      JOIN users u              ON d.author_id    = u.user_id
      LEFT JOIN departments dep ON d.department_id = dep.department_id
      ${whereSQL}
      ORDER BY d.created_at DESC
    `;
    const result = await pool.query(sql, params);
    res.json(result.rows);
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: 'Ошибка получения документов' });
  }
});

// GET /api/documents/:id — детали документа
router.get('/:id', authenticate, async (req, res) => {
  try {
    const docResult = await pool.query(
      `SELECT d.*, dt.type_name, ds.status_name, ds.status_code,
              u.full_name AS author_name, dep.department_name
       FROM documents d
       JOIN document_types dt    ON d.type_id      = dt.type_id
       JOIN document_statuses ds ON d.status_id    = ds.status_id
       JOIN users u              ON d.author_id    = u.user_id
       LEFT JOIN departments dep ON d.department_id = dep.department_id
       WHERE d.document_id = $1`,
      [req.params.id]
    );

    if (docResult.rows.length === 0) {
      return res.status(404).json({ error: 'Документ не найден' });
    }

    const routes = await pool.query(
      `SELECT dr.*, u.full_name AS approver_name
       FROM document_routes dr
       JOIN users u ON dr.approver_id = u.user_id
       WHERE dr.document_id = $1
       ORDER BY dr.step_order`,
      [req.params.id]
    );

    const history = await pool.query(
      `SELECT h.*, u.full_name AS user_name
       FROM document_history h
       LEFT JOIN users u ON h.user_id = u.user_id
       WHERE h.document_id = $1
       ORDER BY h.action_time DESC`,
      [req.params.id]
    );

    res.json({
      document: docResult.rows[0],
      routes:   routes.rows,
      history:  history.rows
    });
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: 'Ошибка сервера' });
  }
});

// POST /api/documents — создать документ
router.post('/', authenticate, async (req, res) => {
  const { title, content, type_id, department_id, deadline, approvers } = req.body;
  if (!title || !type_id) {
    return res.status(400).json({ error: 'Заполните обязательные поля' });
  }

  try {
    // Используем хранимую процедуру
    await pool.query(
      `CALL create_document_with_route($1, $2, $3, $4, $5, $6, $7)`,
      [
        title,
        content || '',
        type_id,
        req.user.id,
        department_id || null,
        deadline || null,
        approvers && approvers.length ? approvers : null
      ]
    );

    res.status(201).json({ message: 'Документ создан' });
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: 'Ошибка создания документа' });
  }
});

// PUT /api/documents/:id — обновить документ
router.put('/:id', authenticate, async (req, res) => {
  const { title, content, status_id, deadline } = req.body;
  try {
    // Проверка прав: автор или админ
    const own = await pool.query(
      `SELECT author_id FROM documents WHERE document_id = $1`, [req.params.id]
    );
    if (!own.rows.length) return res.status(404).json({ error: 'Документ не найден' });
    if (own.rows[0].author_id !== req.user.id && req.user.role !== 'admin') {
      return res.status(403).json({ error: 'Доступ запрещён' });
    }

    const result = await pool.query(
      `UPDATE documents
       SET title    = COALESCE($1, title),
           content  = COALESCE($2, content),
           status_id= COALESCE($3, status_id),
           deadline = COALESCE($4, deadline)
       WHERE document_id = $5
       RETURNING *`,
      [title, content, status_id, deadline, req.params.id]
    );
    res.json(result.rows[0]);
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: 'Ошибка обновления' });
  }
});

// DELETE /api/documents/:id — только админ
router.delete('/:id', authenticate, requireRole('admin'), async (req, res) => {
  try {
    await pool.query(`DELETE FROM documents WHERE document_id = $1`, [req.params.id]);
    res.json({ message: 'Документ удалён' });
  } catch (err) {
    res.status(500).json({ error: 'Ошибка удаления' });
  }
});

// POST /api/documents/route/:routeId/decision — принять решение по согласованию
router.post('/route/:routeId/decision', authenticate, requireRole(...APPROVER_ROLES, 'admin'), async (req, res) => {
  const { decision, comment } = req.body;
  if (!['approved', 'rejected'].includes(decision)) {
    return res.status(400).json({ error: 'Некорректное решение' });
  }
  try {
    // Проверка, что текущий пользователь — назначенный согласующий
    const check = await pool.query(
      `SELECT approver_id, decision FROM document_routes WHERE route_id = $1`,
      [req.params.routeId]
    );
    if (!check.rows.length) return res.status(404).json({ error: 'Маршрут не найден' });
    if (check.rows[0].approver_id !== req.user.id && req.user.role !== 'admin') {
      return res.status(403).json({ error: 'Вы не являетесь согласующим' });
    }
    if (check.rows[0].decision !== 'pending') {
      return res.status(400).json({ error: 'Решение уже принято' });
    }

    await pool.query(`CALL process_approval($1, $2, $3)`, [req.params.routeId, decision, comment]);
    res.json({ message: 'Решение сохранено' });
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: 'Ошибка сохранения решения' });
  }
});

module.exports = router;
