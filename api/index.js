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

  router.get('/', async (req, res) => {
    try {
      const [rows] = await pool.query(`SELECT * FROM ${tableName}`);
      res.json(rows);
    } catch (error) {
      res.status(500).json({ error: error.message });
    }
  });

  router.get('/:id', async (req, res) => {
    try {
      const [rows] = await pool.query(`SELECT * FROM ${tableName} WHERE id = ?`, [req.params.id]);
      if (rows.length === 0) return res.status(404).json({ error: 'Not found' });
      res.json(rows[0]);
    } catch (error) {
      res.status(500).json({ error: error.message });
    }
  });

  router.post('/', async (req, res) => {
    try {
      const [result] = await pool.query(`INSERT INTO ${tableName} SET ?`, [req.body]);
      const [rows] = await pool.query(`SELECT * FROM ${tableName} WHERE id = ?`, [req.body.id || result.insertId]);
      res.status(201).json(rows[0]);
    } catch (error) {
      res.status(500).json({ error: error.message });
    }
  });

  router.put('/:id', async (req, res) => {
    try {
      await pool.query(`UPDATE ${tableName} SET ? WHERE id = ?`, [req.body, req.params.id]);
      const [rows] = await pool.query(`SELECT * FROM ${tableName} WHERE id = ?`, [req.params.id]);
      res.json(rows[0]);
    } catch (error) {
      res.status(500).json({ error: error.message });
    }
  });

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

async function safeQuery(sql, params = []) {
  try {
    const [rows] = await pool.query(sql, params);
    return rows;
  } catch (error) {
    if (error.code === 'ER_NO_SUCH_TABLE') {
      return [];
    }
    throw error;
  }
}

// Report data fetchers using MySQL
const REPORT_QUERIES = {
  sales_summary: async () => {
    const [schools] = await safeQuery('SELECT COUNT(*) AS count FROM schools');
    const [users] = await safeQuery('SELECT COUNT(*) AS count FROM users');
    const [orders] = await safeQuery('SELECT COUNT(*) AS count FROM orders');
    const [orderStats] = await safeQuery(`SELECT status, COUNT(*) AS count, SUM(CAST(checkout_amount AS DECIMAL(12,2))) AS total_amount FROM orders GROUP BY status`);
    const [pipelineSummary] = await safeQuery(`SELECT sale_status, COUNT(*) AS count, SUM(CAST(expected_value AS DECIMAL(12,2))) AS total_value FROM school_sales GROUP BY sale_status ORDER BY total_value DESC`);
    const [revenueWon] = await safeQuery(`SELECT SUM(CAST(expected_value AS DECIMAL(12,2))) AS won_value FROM school_sales WHERE sale_status = 'won'`);
    const [topProducts] = await safeQuery(`SELECT product_name, SUM(quantity) AS total_qty, SUM(CAST(line_total AS DECIMAL(12,2))) AS total_value FROM order_items GROUP BY product_name ORDER BY total_value DESC LIMIT 10`);
    return {
      total_schools: (schools && schools[0]?.count) || 0,
      total_users: (users && users[0]?.count) || 0,
      total_orders: (orders && orders[0]?.count) || 0,
      order_status_breakdown: orderStats || [],
      pipeline_summary: pipelineSummary || [],
      won_revenue: (revenueWon && revenueWon[0]?.won_value) || 0,
      top_products: topProducts || []
    };
  },

  pipeline_analysis: async () => {
    const [byStage] = await safeQuery(`SELECT sale_status, COUNT(*) AS opportunities, SUM(CAST(expected_value AS DECIMAL(12,2))) AS total_value, AVG(probability) AS avg_probability, SUM(CAST(weighted_forecast AS DECIMAL(12,2))) AS weighted_forecast FROM school_sales GROUP BY sale_status ORDER BY weighted_forecast DESC`);
    const [byAgent] = await safeQuery(`SELECT u.full_name, u.role, COUNT(s.id) AS opportunities, SUM(CAST(s.expected_value AS DECIMAL(12,2))) AS total_value, SUM(CAST(s.weighted_forecast AS DECIMAL(12,2))) AS weighted_forecast FROM school_sales s JOIN users u ON s.agent_id = u.id GROUP BY s.agent_id, u.full_name, u.role ORDER BY total_value DESC`);
    const [staleOpps] = await safeQuery(`SELECT s.id, u.full_name, sch.name AS school_name, s.sale_status, s.next_action, s.next_action_date, s.stage_sla_due_at, s.risk_level FROM school_sales s JOIN users u ON s.agent_id = u.id JOIN schools sch ON s.school_id = sch.id WHERE s.sale_status NOT IN ('won', 'lost', 'dormant') AND (s.next_action_date < CURDATE() OR s.stage_sla_due_at < NOW()) ORDER BY s.risk_level DESC, s.stage_sla_due_at ASC LIMIT 50`);
    return { by_stage: byStage || [], by_agent: byAgent || [], stale_opportunities: staleOpps || [] };
  },

  agent_performance: async () => {
    const [agents] = await safeQuery(`SELECT u.id, u.full_name, u.role, u.region, COUNT(DISTINCT t.id) AS total_tasks, SUM(t.status = 'closed') AS completed_tasks, COUNT(DISTINCT rp.id) AS total_routes, SUM(rp.status = 'completed') AS completed_routes, COUNT(DISTINCT sv.id) AS total_visits FROM users u LEFT JOIN tasks t ON t.assigned_to = u.id LEFT JOIN route_plans rp ON rp.assigned_to = u.id LEFT JOIN school_visits sv ON sv.agent_id = u.id WHERE u.role IN (4, 5) GROUP BY u.id, u.full_name, u.role, u.region ORDER BY completed_tasks DESC`);
    const [topSchools] = await safeQuery(`SELECT u.full_name, sch.name AS school_name, COUNT(*) AS visits FROM school_visits sv JOIN users u ON sv.agent_id = u.id JOIN schools sch ON sv.school_id = sch.id GROUP BY sv.agent_id, sch.id, u.full_name, sch.name ORDER BY visits DESC LIMIT 20`);
    return { agents: agents || [], most_visited_schools: topSchools || [] };
  },

  regional_summary: async () => {
    const [byRegion] = await safeQuery(`SELECT r.region, r.sub_region, COUNT(DISTINCT u.id) AS user_count, COUNT(DISTINCT sch.id) AS school_count, COUNT(DISTINCT s.id) AS opportunity_count, COALESCE(SUM(CAST(s.expected_value AS DECIMAL(12,2))), 0) AS pipeline_value, COALESCE(SUM(CASE WHEN s.sale_status = 'won' THEN CAST(s.expected_value AS DECIMAL(12,2)) ELSE 0 END), 0) AS won_value FROM regions r LEFT JOIN users u ON u.region_id = r.id LEFT JOIN schools sch ON sch.region_id = r.id LEFT JOIN school_sales s ON s.region_id = r.id GROUP BY r.id, r.region, r.sub_region ORDER BY pipeline_value DESC`);
    return { by_region: byRegion || [] };
  },

  event_summary: async () => {
    const [events] = await safeQuery(`SELECT e.id, e.name, e.event_type, e.region, e.start_at, e.end_at, e.expected_attendance, e.budget, e.status, COUNT(DISTINCT ea.agent_id) AS assigned_agents, COUNT(DISTINCT ec.id) AS checkins, COUNT(DISTINCT el.id) AS leads, COUNT(DISTINCT es.id) AS samples, COALESCE(SUM(CAST(ee.amount AS DECIMAL(12,2))), 0) AS total_expenses FROM events e LEFT JOIN event_assignments ea ON ea.event_id = e.id LEFT JOIN event_checkins ec ON ec.event_id = e.id LEFT JOIN event_leads el ON el.event_id = e.id LEFT JOIN event_samples es ON es.event_id = e.id LEFT JOIN event_expenses ee ON ee.event_id = e.id GROUP BY e.id ORDER BY e.start_at DESC`);
    return { events: events || [] };
  },

  sample_roi: async () => {
    const [roi] = await safeQuery(`SELECT u.full_name, u.role, COUNT(DISTINCT ssd.id) AS samples_given, COUNT(DISTINCT ssd.school_id) AS schools_reached, COALESCE(SUM(CASE WHEN o.status IN ('approved', 'paid', 'completed') THEN CAST(o.checkout_amount AS DECIMAL(12,2)) ELSE 0 END), 0) AS revenue_earned, COALESCE(SUM(CASE WHEN ss.sale_status = 'won' THEN CAST(ss.expected_value AS DECIMAL(12,2)) ELSE 0 END), 0) AS won_value FROM users u LEFT JOIN school_sample_distributions ssd ON ssd.agent_id = u.id LEFT JOIN orders o ON o.agent_id = u.id LEFT JOIN school_sales ss ON ss.agent_id = u.id WHERE u.role IN (4, 5) GROUP BY u.id, u.full_name, u.role ORDER BY revenue_earned DESC`);
    return { roi: roi || [] };
  },

  targets_analysis: async () => {
    const [targets] = await safeQuery(`SELECT t.scope, t.target_type, t.target_period, r.region, r.sub_region, u.full_name AS assigned_to_name, t.target_data FROM targets t LEFT JOIN regions r ON r.id = t.region_id LEFT JOIN users u ON u.id = t.assigned_to ORDER BY t.scope, t.target_type, t.target_period`);
    return { targets: targets || [] };
  }
};

// Report generation endpoint
app.post('/api/ai/report', async (req, res) => {
  try {
    const { report_type, filters = {}, prompt } = req.body;
    const openRouterKey = process.env.OPENROUTER_API_KEY;

    if (!openRouterKey) {
      return res.status(500).json({ error: 'OpenRouter API key not configured on server' });
    }

    const fetcher = REPORT_QUERIES[report_type];
    if (!fetcher) {
      return res.status(400).json({ error: `Unsupported report type: ${report_type}. Supported: ${Object.keys(REPORT_QUERIES).join(', ')}` });
    }

    let data;
    try {
      data = await fetcher(filters);
    } catch (dbError) {
      console.error('Report data fetch error:', dbError);
      return res.status(500).json({ error: `Failed to fetch report data: ${dbError.message}` });
    }

    const reportContext = JSON.stringify(data, null, 2);
    const systemPrompt = `${DB_SCHEMA_PROMPT}

You are generating a comprehensive report from live DeHeus sales data below.
Analyze the data thoroughly, highlight key insights, trends, anomalies, and actionable recommendations.
Structure the report with clear sections, bullet points, and numbers. Be specific and data-driven.

Live Data:
${reportContext}`;

    const userPrompt = prompt || 'Generate a comprehensive report from the provided data.';

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
          { role: 'user', content: userPrompt }
        ]
      })
    });

    const result = await response.json();
    if (!response.ok) {
      return res.status(response.status).json(result);
    }

    res.json({
      report_type,
      generated_at: new Date().toISOString(),
      data,
      report: result.choices[0]?.message?.content || 'No report generated.'
    });
  } catch (error) {
    console.error('Report generation error:', error);
    res.status(500).json({ error: error.message });
  }
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

// Data helper endpoint - returns raw data for AI consumption or direct use
app.get('/api/ai/data/:table', async (req, res) => {
  try {
    const { table } = req.params;
    const allowedTables = [
      'users', 'schools', 'tasks', 'geofences', 'route_plans',
      'school_sales', 'opportunity_activities', 'orders', 'order_items',
      'school_visits', 'school_follow_ups', 'school_sample_distributions',
      'sample_requests', 'catalog_items', 'events', 'event_assignments',
      'event_checkins', 'event_leads', 'event_samples', 'event_expenses',
      'supervisor_alerts', 'targets', 'regions'
    ];

    if (!allowedTables.includes(table)) {
      return res.status(400).json({ error: `Table not allowed: ${table}` });
    }

    const limit = Math.min(parseInt(req.query.limit || '100', 10), 500);
    const offset = parseInt(req.query.offset || '0', 10);

    const [rows] = await safeQuery(`SELECT * FROM ${table} LIMIT ? OFFSET ?`, [limit, offset]);
    res.json({ table, count: rows.length, data: rows });
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
