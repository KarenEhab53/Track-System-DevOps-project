const express = require('express');
const cors = require('cors');
const client = require('prom-client');
const { pool, initSchema } = require('./db');

const app = express();
const PORT = process.env.PORT || 8000;

app.use(cors());
app.use(express.json());

// --- Prometheus metrics ---
// Exposed on /metrics so Prometheus (running in the monitoring namespace on
// EKS) can scrape backend pod resource + custom app metrics.
const register = new client.Registry();
client.collectDefaultMetrics({ register });

const httpRequestDuration = new client.Histogram({
  name: 'http_request_duration_seconds',
  help: 'Duration of HTTP requests in seconds',
  labelNames: ['method', 'route', 'status_code'],
});
register.registerMetric(httpRequestDuration);

app.use((req, res, next) => {
  const end = httpRequestDuration.startTimer();
  res.on('finish', () => {
    end({ method: req.method, route: req.path, status_code: res.statusCode });
  });
  next();
});

app.get('/metrics', async (req, res) => {
  res.set('Content-Type', register.contentType);
  res.end(await register.metrics());
});

// --- Health check (used by k8s readiness/liveness probes and ALB target group) ---
app.get('/health', (req, res) => {
  res.status(200).json({ status: 'ok', service: 'track-system-backend' });
});

// --- Leave request API ---
app.get('/api/leave-requests', async (req, res) => {
  try {
    const result = await pool.query(
      'SELECT * FROM leave_requests ORDER BY created_at DESC LIMIT 100'
    );
    res.json(result.rows);
  } catch (err) {
    console.error('Failed to fetch leave requests', err);
    res.status(500).json({ error: 'internal_error' });
  }
});

app.post('/api/leave-requests', async (req, res) => {
  const { employee_name, leave_type, start_date, end_date } = req.body || {};
  if (!employee_name || !leave_type || !start_date || !end_date) {
    return res.status(400).json({ error: 'missing_required_fields' });
  }
  try {
    const result = await pool.query(
      `INSERT INTO leave_requests (employee_name, leave_type, start_date, end_date)
       VALUES ($1, $2, $3, $4) RETURNING *`,
      [employee_name, leave_type, start_date, end_date]
    );
    res.status(201).json(result.rows[0]);
  } catch (err) {
    console.error('Failed to create leave request', err);
    res.status(500).json({ error: 'internal_error' });
  }
});

async function start() {
  try {
    await initSchema();
  } catch (err) {
    console.error('Schema init failed (DB may not be ready yet):', err.message);
  }
  app.listen(PORT, () => {
    console.log(`track-system-backend listening on port ${PORT}`);
  });
}

start();

module.exports = app;
