const express = require('express');
const pool    = require('../db');
const bcrypt  = require('bcryptjs');
const { authenticate, requireRole } = require('../middleware/auth');

const router = express.Router();

// Типы документов
router.get('/document-types', authenticate, async (req, res) => {
  const r = await pool.query('SELECT * FROM document_types ORDER BY type_name');
  res.json(r.rows);
});

// Статусы
router.get('/document-statuses', authenticate, async (req, res) => {
  const r = await pool.query('SELECT * FROM document_statuses ORDER BY status_id');
  res.json(r.rows);
});

// Отделы
router.get('/departments', authenticate, async (req, res) => {
  const r = await pool.query('SELECT * FROM departments ORDER BY department_name');
  res.json(r.rows);
});

// Список пользователей (для выбора согласующих)
router.get('/users', authenticate, async (req, res) => {
  const r = await pool.query(
    `SELECT u.user_id, u.full_name, u.position, r.role_name, d.department_name
     FROM users u
     JOIN roles r ON u.role_id = r.role_id
     LEFT JOIN departments d ON u.department_id = d.department_id
     WHERE u.is_active = TRUE
     ORDER BY u.full_name`
  );
  res.json(r.rows);
});

// Все роли (только админ)
router.get('/roles', authenticate, requireRole('admin'), async (req, res) => {
  const r = await pool.query('SELECT * FROM roles ORDER BY role_id');
  res.json(r.rows);
});

// Создание пользователя (только админ)
router.post('/users', authenticate, requireRole('admin'), async (req, res) => {
  const { login, password, full_name, email, role_id, department_id, position } = req.body;
  if (!login || !password || !full_name || !email || !role_id) {
    return res.status(400).json({ error: 'Заполните обязательные поля' });
  }
  try {
    const hash = await bcrypt.hash(password, 10);
    const r = await pool.query(
      `INSERT INTO users (login, password_hash, full_name, email, role_id, department_id, position)
       VALUES ($1, $2, $3, $4, $5, $6, $7)
       RETURNING user_id, login, full_name, email`,
      [login, hash, full_name, email, role_id, department_id || null, position || null]
    );
    res.status(201).json(r.rows[0]);
  } catch (err) {
    console.error(err);
    if (err.code === '23505') {
      return res.status(400).json({ error: 'Логин или email уже заняты' });
    }
    res.status(500).json({ error: 'Ошибка создания пользователя' });
  }
});

// Деактивация пользователя
router.put('/users/:id/toggle', authenticate, requireRole('admin'), async (req, res) => {
  try {
    const r = await pool.query(
      `UPDATE users SET is_active = NOT is_active WHERE user_id = $1 RETURNING is_active`,
      [req.params.id]
    );
    res.json(r.rows[0]);
  } catch (err) {
    res.status(500).json({ error: 'Ошибка' });
  }
});

module.exports = router;
