const express = require('express');
const cors    = require('cors');
require('dotenv').config();

const app = express();

app.use(cors());
app.use(express.json({ limit: '5mb' }));

// Маршруты
app.use('/api/auth',         require('./routes/auth'));
app.use('/api/documents',    require('./routes/documents'));
app.use('/api/dictionaries', require('./routes/dictionaries'));
app.use('/api/reports',      require('./routes/reports'));

// Корневой маршрут
app.get('/', (req, res) => {
  res.json({ name: 'DocFlow API', version: '1.0.0', status: 'running' });
});

// Глобальный обработчик ошибок
app.use((err, req, res, next) => {
  console.error(err);
  res.status(500).json({ error: 'Внутренняя ошибка сервера' });
});

const PORT = process.env.PORT || 3000;
app.listen(PORT, () => {
  console.log(`[Server] Запущен на порту ${PORT}`);
});
