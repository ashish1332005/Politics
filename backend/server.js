require('dotenv').config();
const express = require('express');
const cors = require('cors');
const path = require('path');
const connectDB = require('./src/config/db');
const { requestLogger } = require('./src/middleware/activityLogger');
const errorHandler = require('./src/middleware/errorHandler');
const { startMessageWorker } = require('./src/services/messageQueue');
const { restoreWebSessions } = require('./src/services/whatsappWeb');

const app = express();
const configuredOrigins = (process.env.CORS_ORIGIN || '*')
  .split(',')
  .map((origin) => origin.trim())
  .filter(Boolean);
const corsOptions = {
  origin(origin, callback) {
    if (!origin || configuredOrigins.includes('*') || configuredOrigins.includes(origin)) {
      return callback(null, true);
    }
    const error = new Error(`Origin ${origin} is not allowed by CORS.`);
    error.status = 403;
    return callback(error);
  },
  credentials: true,
  methods: ['GET', 'POST', 'PUT', 'PATCH', 'DELETE', 'OPTIONS'],
  allowedHeaders: ['Authorization', 'Content-Type', 'Accept'],
  maxAge: 86400,
};

app.use(cors(corsOptions));
app.options('*', cors(corsOptions));
app.use(express.json({ limit: '10mb' }));
app.use(express.urlencoded({ extended: true }));
app.use('/uploads', express.static(path.join(__dirname, process.env.UPLOAD_PATH || 'uploads')));
app.use('/party-logos', express.static(path.join(__dirname, 'src/public/party-logos')));

app.get('/', (req, res) => res.json({ name: 'Political Booth Management CRM API', status: 'ok' }));
app.use('/api/auth', require('./src/routes/auth'));
app.use('/api/wards', require('./src/routes/wards'));
app.use('/api/areas', require('./src/routes/areas'));
app.use('/api/booths', require('./src/routes/booths'));
app.use('/api/members', requestLogger, require('./src/routes/members'));
app.use('/api/families', requestLogger, require('./src/routes/families'));
app.use('/api/parties', require('./src/routes/parties'));
app.use('/api/import', requestLogger, require('./src/routes/import'));
app.use('/api/import-previews', requestLogger, require('./src/routes/importPreviews'));
app.use('/api/import-reviews', requestLogger, require('./src/routes/importReviews'));
app.use('/api/export', require('./src/routes/export'));
app.use('/api/print', require('./src/routes/print'));
app.use('/api/activity', require('./src/routes/activity'));
app.use('/api/security', requestLogger, require('./src/routes/security'));
app.use('/api/reports', require('./src/routes/reports'));
app.use('/api/political-analytics', require('./src/routes/politicalAnalytics'));
app.use('/api/messages', requestLogger, require('./src/routes/messages'));
app.use('/api/notifications', require('./src/routes/notifications'));
app.use('/api/follow-ups', requestLogger, require('./src/routes/followUps'));
app.use(errorHandler);

const PORT = process.env.PORT || 5000;
const serverTimeoutMs = Number(process.env.UPLOAD_TIMEOUT_MINUTES || 30) * 60 * 1000;

connectDB()
  .then(() => {
    const server = app.listen(PORT, () => console.log(`Political Booth Management CRM API running on ${PORT}`));
    server.requestTimeout = serverTimeoutMs;
    server.headersTimeout = serverTimeoutMs + 5000;
    restoreWebSessions().catch((error) => console.error('WhatsApp restore:', error.message));
    startMessageWorker();
  })
  .catch(() => {
    console.error('API not started because MongoDB is unavailable.');
    process.exit(1);
  });










