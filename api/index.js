const express = require('express');
const cors = require('cors');
const mysql = require('mysql2/promise');
require('dotenv').config();
const { DB_SCHEMA_PROMPT } = require('./schema_context');

const app = express();
const port = process.env.PORT || 3000;

const dbHost = process.env.DB_HOST || process.env.MYSQL_HOST || 'localhost';
const dbUser = process.env.DB_USER || process.env.MYSQL_USER || 'root';
const dbPassword = process.env.DB_PASSWORD || process.env.MYSQL_PASSWORD || '';
const dbName = process.env.DB_NAME || process.env.MYSQL_DATABASE || '';

if (!dbPassword || !dbName) {
  console.warn('Warning: Database credentials not fully configured. Set DB_HOST, DB_USER, DB_PASSWORD, DB_NAME or Railway MySQL variables.');
}

const pool = mysql.createPool({
  host: dbHost,
  user: dbUser,
  password: dbPassword,
  database: dbName,
  waitForConnections: true,
  connectionLimit: 10,
  queueLimit: 0
});

app.use(cors());
app.use(express.json());

// Generic CRUD factory for MySQL
const createRouter = (tableName) => {
  const router = express.Router();

  // GET all
  router.get('/', async (req, res) => {
    try {
      const [rows] = await pool.query(`SELECT * FROM ${tableName}`);
      res.json(rows);
    } catch (error) {
      res.status(500).json({ error: error.message });
    }
  });

  // GET by ID
  router.get('/:id', async (req, res) => {
    try {
      const [rows] = await pool.query(`SELECT * FROM ${tableName} WHERE id = ?`, [req.params.id]);
      if (rows.length === 0) return res.status(404).json({ error: 'Not found' });
      res.json(rows[0]);
    } catch (error) {
      res.status(500).json({ error: error.message });
    }
  });

  // POST new
  router.post('/', async (req, res) => {
    try {
      const [result] = await pool.query(`INSERT INTO ${tableName} SET ?`, [req.body]);
      const [rows] = await pool.query(`SELECT * FROM ${tableName} WHERE id = ?`, [req.body.id || result.insertId]);
      res.status(201).json(rows[0]);
    } catch (error) {
      res.status(500).json({ error: error.message });
    }
  });

  // PUT update
  router.put('/:id', async (req, res) => {
    try {
      await pool.query(`UPDATE ${tableName} SET ? WHERE id = ?`, [req.body, req.params.id]);
      const [rows] = await pool.query(`SELECT * FROM ${tableName} WHERE id = ?`, [req.params.id]);
      res.json(rows[0]);
    } catch (error) {
      res.status(500).json({ error: error.message });
    }
  });

  // DELETE
  router.delete('/:id', async (req, res) => {
    try {
      await pool.query(`DELETE FROM ${tableName} WHERE id = ?`, [req.params.id]);
      res.json({ message: 'Deleted successfully' });
    } catch (error) {
      res.status(500).json({ error: error.message });
    }
  });

  return router;
};

// Health check
app.get('/health', (req, res) => {
  res.json({ status: 'ok', database: 'mysql', timestamp: new Date().toISOString() });
});

// AI Chat proxy - forwards requests to OpenRouter API
app.post('/api/ai/chat', async (req, res) => {
  try {
    const { messages, context } = req.body;
    const openRouterKey = process.env.OPENROUTER_API_KEY;
    
    if (!openRouterKey) {
      return res.status(500).json({ error: 'OpenRouter API key not configured on server' });
    }

    const systemPrompt = context 
      ? `${DB_SCHEMA_PROMPT}\n\nYou are analyzing the following performance data. Answer questions about it accurately using your schema knowledge.\n\nPerformance Context:\n${context}`
      : DB_SCHEMA_PROMPT;

    const response = await fetch('https://openrouter.ai/api/v1/chat/completions', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': `Bearer ${openRouterKey}`,
        'HTTP-Referer': process.env.OPENROUTER_HTTP_REFERER || 'https://deheus.app',
        'X-OpenRouter-Title': process.env.OPENROUTER_APP_TITLE || 'DeHeus Sales App',
      },
      body: JSON.stringify({
        model: process.env.OPENROUTER_MODEL || 'openai/gpt-4o-mini',
        messages: [
          { role: 'system', content: systemPrompt },
          ...messages
        ]
      })
    });

    const data = await response.json();
    if (!response.ok) {
      return res.status(response.status).json(data);
    }
    res.json(data);
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

// Register routes for main tables
const tables = [
  'users',
  'schools',
  'tasks',
  'geofences',
  'route_plans'
];

tables.forEach(table => {
  app.use(`/api/${table}`, createRouter(table));
});

// Root path
app.get('/', (req, res) => {
  res.json({
    message: 'Welcome to DeHeus MySQL API',
    endpoints: tables.map(t => `/api/${t}`)
  });
});

app.listen(port, '0.0.0.0', () => {
  console.log(`Server is running on port ${port}`);
});
