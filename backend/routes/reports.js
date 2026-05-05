const express = require('express');
const pool    = require('../db');
const { authenticate, requireRole, APPROVER_ROLES } = require('../middleware/auth');

const router = express.Router();

// ========================
// ОТЧЁТЫ ДЛЯ АДМИНИСТРАТОРА
// ========================

// Активность пользователей
router.get('/admin/user-activity', authenticate, requireRole('admin'), async (req, res) => {
  const { date_from, date_to } = req.query;
  try {
    const r = await pool.query(
      `SELECT u.full_name, r.role_name,
              COUNT(d.document_id)             AS total_docs,
              COUNT(DISTINCT d.type_id)        AS distinct_types,
              MAX(d.created_at)                AS last_activity
       FROM users u
       JOIN roles r ON u.role_id = r.role_id
       LEFT JOIN documents d ON u.user_id = d.author_id
            AND ($1::date IS NULL OR d.created_at >= $1::date)
            AND ($2::date IS NULL OR d.created_at <= $2::date)
       GROUP BY u.user_id, u.full_name, r.role_name
       ORDER BY total_docs DESC`,
      [date_from || null, date_to || null]
    );
    res.json(r.rows);
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: 'Ошибка отчёта' });
  }
});

// Распределение документов по типам и статусам
router.get('/admin/types-statuses', authenticate, requireRole('admin'), async (req, res) => {
  try {
    const r = await pool.query(
      `SELECT dt.type_name, ds.status_name, COUNT(*) AS qty
       FROM documents d
       JOIN document_types    dt ON d.type_id   = dt.type_id
       JOIN document_statuses ds ON d.status_id = ds.status_id
       GROUP BY dt.type_name, ds.status_name
       ORDER BY dt.type_name, ds.status_name`
    );
    res.json(r.rows);
  } catch (err) {
    res.status(500).json({ error: 'Ошибка отчёта' });
  }
});

// Журнал действий
router.get('/admin/audit', authenticate, requireRole('admin'), async (req, res) => {
  const { days } = req.query;
  try {
    const r = await pool.query(
      `SELECT h.action_time, u.full_name AS who, h.action,
              d.reg_number, h.old_value, h.new_value
       FROM document_history h
       LEFT JOIN users u ON h.user_id = u.user_id
       JOIN documents d ON h.document_id = d.document_id
       WHERE h.action_time >= CURRENT_TIMESTAMP - ($1 || ' days')::INTERVAL
       ORDER BY h.action_time DESC
       LIMIT 200`,
      [days || 30]
    );
    res.json(r.rows);
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: 'Ошибка отчёта' });
  }
});

// ========================
// ОТЧЁТЫ ДЛЯ РУКОВОДИТЕЛЯ
// ========================

// Документы на согласовании у текущего пользователя
router.get('/manager/pending', authenticate, requireRole(...APPROVER_ROLES, 'admin'), async (req, res) => {
  try {
    const r = await pool.query(
      `SELECT d.reg_number, d.title, dt.type_name,
              u.full_name AS author, dr.step_order, d.deadline, d.created_at,
              dr.route_id
       FROM document_routes dr
       JOIN documents      d  ON dr.document_id = d.document_id
       JOIN document_types dt ON d.type_id      = dt.type_id
       JOIN users          u  ON d.author_id    = u.user_id
       WHERE dr.approver_id = $1 AND dr.decision = 'pending'
       ORDER BY d.deadline NULLS LAST`,
      [req.user.id]
    );
    res.json(r.rows);
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: 'Ошибка отчёта' });
  }
});

// Просроченные документы
router.get('/manager/overdue', authenticate, requireRole(...APPROVER_ROLES, 'admin'), async (req, res) => {
  try {
    const r = await pool.query(
      `SELECT dep.department_name,
              COUNT(*)                                          AS overdue_count,
              ROUND(AVG(CURRENT_DATE - d.deadline)::NUMERIC, 1) AS avg_days_overdue
       FROM documents d
       JOIN departments       dep ON d.department_id = dep.department_id
       JOIN document_statuses ds  ON d.status_id     = ds.status_id
       WHERE d.deadline < CURRENT_DATE
         AND ds.status_code IN ('DRAFT', 'IN_REVIEW')
       GROUP BY dep.department_name
       ORDER BY overdue_count DESC`
    );
    res.json(r.rows);
  } catch (err) {
    res.status(500).json({ error: 'Ошибка отчёта' });
  }
});

// Сводка по сотрудникам отдела руководителя
router.get('/manager/team', authenticate, requireRole(...APPROVER_ROLES, 'admin'), async (req, res) => {
  try {
    // Берём отдел руководителя
    const dept = await pool.query(`SELECT department_id FROM users WHERE user_id = $1`, [req.user.id]);
    const dept_id = dept.rows[0].department_id;

    const r = await pool.query(
      `SELECT u.full_name, u.position,
              COUNT(d.document_id)                                            AS total_docs,
              SUM(CASE WHEN ds.status_code = 'APPROVED'  THEN 1 ELSE 0 END)   AS approved,
              SUM(CASE WHEN ds.status_code = 'REJECTED'  THEN 1 ELSE 0 END)   AS rejected,
              SUM(CASE WHEN ds.status_code = 'IN_REVIEW' THEN 1 ELSE 0 END)   AS in_review
       FROM users u
       LEFT JOIN documents          d  ON u.user_id   = d.author_id
       LEFT JOIN document_statuses  ds ON d.status_id = ds.status_id
       WHERE u.department_id = $1
       GROUP BY u.user_id, u.full_name, u.position
       ORDER BY total_docs DESC`,
      [dept_id]
    );
    res.json(r.rows);
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: 'Ошибка отчёта' });
  }
});

// ========================
// ОТЧЁТЫ ДЛЯ ДЕЛОПРОИЗВОДИТЕЛЯ
// ========================

router.get('/clerk/registration', authenticate, requireRole('clerk', 'admin'), async (req, res) => {
  try {
    const r = await pool.query(
      `SELECT DATE(d.registered_at) AS reg_date,
              COUNT(*)              AS docs_registered,
              COUNT(DISTINCT d.author_id) AS unique_authors
       FROM documents d
       WHERE d.registered_at IS NOT NULL
         AND d.registered_at >= CURRENT_DATE - INTERVAL '30 days'
       GROUP BY DATE(d.registered_at)
       ORDER BY reg_date DESC`
    );
    res.json(r.rows);
  } catch (err) {
    res.status(500).json({ error: 'Ошибка отчёта' });
  }
});

router.get('/clerk/by-type', authenticate, requireRole('clerk', 'admin'), async (req, res) => {
  const { date_from, date_to } = req.query;
  try {
    const r = await pool.query(
      `SELECT dt.type_name, dt.type_code,
              COUNT(*) AS qty,
              MIN(d.created_at) AS first_doc,
              MAX(d.created_at) AS last_doc
       FROM documents d
       JOIN document_types dt ON d.type_id = dt.type_id
       WHERE ($1::date IS NULL OR d.created_at >= $1::date)
         AND ($2::date IS NULL OR d.created_at <= $2::date)
       GROUP BY dt.type_name, dt.type_code
       ORDER BY qty DESC`,
      [date_from || null, date_to || null]
    );
    res.json(r.rows);
  } catch (err) {
    res.status(500).json({ error: 'Ошибка отчёта' });
  }
});

router.get('/clerk/no-route', authenticate, requireRole('clerk', 'admin'), async (req, res) => {
  try {
    const r = await pool.query(
      `SELECT d.reg_number, d.title, dt.type_name, u.full_name AS author, d.created_at
       FROM documents d
       JOIN document_types dt ON d.type_id   = dt.type_id
       JOIN users          u  ON d.author_id = u.user_id
       LEFT JOIN document_routes dr ON d.document_id = dr.document_id
       WHERE dr.route_id IS NULL
       ORDER BY d.created_at DESC`
    );
    res.json(r.rows);
  } catch (err) {
    res.status(500).json({ error: 'Ошибка отчёта' });
  }
});

// ========================
// ОТЧЁТЫ ДЛЯ СОТРУДНИКА
// ========================

router.get('/employee/by-status', authenticate, async (req, res) => {
  try {
    const r = await pool.query(
      `SELECT ds.status_name, COUNT(*) AS qty
       FROM documents d
       JOIN document_statuses ds ON d.status_id = ds.status_id
       WHERE d.author_id = $1
       GROUP BY ds.status_name`,
      [req.user.id]
    );
    res.json(r.rows);
  } catch (err) {
    res.status(500).json({ error: 'Ошибка отчёта' });
  }
});

router.get('/employee/in-progress', authenticate, async (req, res) => {
  try {
    const r = await pool.query(
      `SELECT d.reg_number, d.title, ds.status_name,
              COUNT(dr.route_id) FILTER (WHERE dr.decision = 'approved') AS approved_steps,
              COUNT(dr.route_id) AS total_steps,
              d.created_at
       FROM documents d
       JOIN document_statuses ds ON d.status_id = ds.status_id
       LEFT JOIN document_routes dr ON d.document_id = dr.document_id
       WHERE d.author_id = $1 AND ds.status_code IN ('IN_REVIEW','DRAFT')
       GROUP BY d.document_id, d.reg_number, d.title, ds.status_name, d.created_at
       ORDER BY d.created_at DESC`,
      [req.user.id]
    );
    res.json(r.rows);
  } catch (err) {
    res.status(500).json({ error: 'Ошибка отчёта' });
  }
});

router.get('/employee/history', authenticate, async (req, res) => {
  try {
    const r = await pool.query(
      `SELECT h.action_time, d.reg_number, h.action, h.old_value, h.new_value,
              u.full_name AS performed_by
       FROM document_history h
       JOIN documents d ON h.document_id = d.document_id
       LEFT JOIN users u ON h.user_id = u.user_id
       WHERE d.author_id = $1
       ORDER BY h.action_time DESC
       LIMIT 50`,
      [req.user.id]
    );
    res.json(r.rows);
  } catch (err) {
    res.status(500).json({ error: 'Ошибка отчёта' });
  }
});

module.exports = router;
