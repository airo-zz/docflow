const jwt = require('jsonwebtoken');
const SECRET = process.env.JWT_SECRET || 'docflow_secret_key';

// Список ролей с правом согласования документов (руководящие роли)
const APPROVER_ROLES = ['director', 'chief_accountant', 'lawyer'];

// Проверка JWT-токена
function authenticate(req, res, next) {
  const header = req.headers.authorization;
  if (!header) return res.status(401).json({ error: 'Не авторизован' });

  const token = header.split(' ')[1];
  if (!token) return res.status(401).json({ error: 'Токен отсутствует' });

  try {
    const payload = jwt.verify(token, SECRET);
    req.user = payload;
    next();
  } catch (e) {
    return res.status(401).json({ error: 'Неверный токен' });
  }
}

// Проверка роли пользователя
function requireRole(...roles) {
  return (req, res, next) => {
    if (!roles.includes(req.user.role)) {
      return res.status(403).json({ error: 'Доступ запрещён' });
    }
    next();
  };
}

module.exports = { authenticate, requireRole, SECRET, APPROVER_ROLES };
