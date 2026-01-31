#!/usr/bin/env node
/**
 * DreamScape Gateway Service - API Gateway & Proxy
 * DR-328: Experience Pod - Big Pods Architecture  
 * Routes requests between services and provides unified API
 */

const express = require('express');
const { createProxyMiddleware } = require('http-proxy-middleware');
const cors = require('cors');
const rateLimit = require('express-rate-limit');

const app = express();
const PORT = process.env.PORT || 3007;
const SERVICE_NAME = process.env.SERVICE_NAME || 'gateway-service';

// Service URLs - support both pod-based and individual service deployments
const AUTH_SERVICE_URL = process.env.AUTH_SERVICE_URL || 'http://auth-service:3001';
const USER_SERVICE_URL = process.env.USER_SERVICE_URL || 'http://user-service:3002';
const VOYAGE_SERVICE_URL = process.env.VOYAGE_SERVICE_URL || 'http://voyage-service:3003';
const AI_SERVICE_URL = process.env.AI_SERVICE_URL || 'http://ai-service:3004';
const PAYMENT_SERVICE_URL = process.env.PAYMENT_SERVICE_URL || 'http://payment-service:3005';
const PANORAMA_SERVICE_URL = process.env.PANORAMA_SERVICE_URL || 'http://localhost:3006';

// Middleware
app.use(cors({
  origin: [
    'http://localhost',
    'http://localhost:80',
    'http://localhost:8080',
    'http://79.72.27.180',
    'http://79.72.27.180:80',
    'http://84.235.237.183',
    'http://84.235.237.183:80'
  ],
  credentials: true
}));

app.use(express.json({ limit: '10mb' }));
app.use(express.urlencoded({ extended: true, limit: '10mb' }));

// Rate limiting
const limiter = rateLimit({
  windowMs: 15 * 60 * 1000, // 15 minutes
  max: 1000, // limit each IP to 1000 requests per windowMs
  message: {
    success: false,
    error: 'Too many requests from this IP, please try again later.',
    retry_after: '15 minutes'
  }
});
app.use(limiter);

// Request logging
app.use((req, res, next) => {
  console.log(`[${new Date().toISOString()}] ${req.method} ${req.path} - ${req.ip}`);
  next();
});

// Health check endpoint
app.get('/health', (req, res) => {
  res.json({
    status: 'healthy',
    service: SERVICE_NAME,
    version: '1.4.0',
    timestamp: new Date().toISOString(),
    proxies: {
      auth: AUTH_SERVICE_URL,
      user: USER_SERVICE_URL,
      voyage: VOYAGE_SERVICE_URL,
      ai: AI_SERVICE_URL,
      payment: PAYMENT_SERVICE_URL,
      panorama: PANORAMA_SERVICE_URL
    }
  });
});

// API Routes
app.get('/api', (req, res) => {
  res.json({
    service: SERVICE_NAME,
    version: '1.4.0',
    description: 'DreamScape API Gateway - Experience Pod',
    endpoints: {
      health: '/health',
      status: '/status',
      metrics: '/metrics',
      api: {
        auth: '/api/v1/auth/*',
        users: '/api/v1/users/*',
        voyages: '/api/v1/voyages/*',
        ai: '/api/v1/ai/*',
        payment: '/api/v1/payment/*',
        vr: '/api/vr/*'
      }
    },
    timestamp: new Date().toISOString()
  });
});

// API Proxy - mount each service on its own path
// Express strips the mount path, so we need to add it back with pathRewrite
app.use('/api/v1/auth', createProxyMiddleware({
  target: AUTH_SERVICE_URL,
  changeOrigin: true,
  timeout: 30000,
  proxyTimeout: 30000,
  pathRewrite: (path) => '/api/v1/auth' + path,
  onProxyReq: (proxyReq, req, res) => {
    console.log(`[HPM] Auth: ${req.method} ${req.originalUrl} -> ${AUTH_SERVICE_URL}${proxyReq.path}`);
  },
  onProxyRes: (proxyRes, req, res) => {
    console.log(`[HPM] Auth Response: ${proxyRes.statusCode}`);
  },
  onError: (err, req, res) => {
    console.error('[HPM] Auth error:', err.message);
    if (!res.headersSent) {
      res.status(503).json({ success: false, error: 'Auth service unavailable' });
    }
  }
}));

app.use('/api/v1/users', createProxyMiddleware({
  target: USER_SERVICE_URL,
  changeOrigin: true,
  timeout: 30000,
  proxyTimeout: 30000,
  pathRewrite: (path) => '/api/v1/users' + path,
  onError: (err, req, res) => {
    console.error('[HPM] User error:', err.message);
    if (!res.headersSent) {
      res.status(503).json({ success: false, error: 'User service unavailable' });
    }
  }
}));

app.use('/api/v1/voyages', createProxyMiddleware({
  target: VOYAGE_SERVICE_URL,
  changeOrigin: true,
  timeout: 30000,
  proxyTimeout: 30000,
  pathRewrite: (path) => '/api/v1/voyages' + path,
  onError: (err, req, res) => {
    console.error('[HPM] Voyage error:', err.message);
    if (!res.headersSent) {
      res.status(503).json({ success: false, error: 'Voyage service unavailable' });
    }
  }
}));

app.use('/api/v1/ai', createProxyMiddleware({
  target: AI_SERVICE_URL,
  changeOrigin: true,
  timeout: 60000,
  proxyTimeout: 60000,
  pathRewrite: (path) => '/api/v1/ai' + path,
  onError: (err, req, res) => {
    console.error('[HPM] AI error:', err.message);
    if (!res.headersSent) {
      res.status(503).json({ success: false, error: 'AI service unavailable' });
    }
  }
}));

app.use('/api/v1/payment', createProxyMiddleware({
  target: PAYMENT_SERVICE_URL,
  changeOrigin: true,
  timeout: 30000,
  proxyTimeout: 30000,
  pathRewrite: (path) => '/api/v1/payment' + path,
  onError: (err, req, res) => {
    console.error('[HPM] Payment error:', err.message);
    if (!res.headersSent) {
      res.status(503).json({ success: false, error: 'Payment service unavailable' });
    }
  }
}));

app.use('/api/vr', createProxyMiddleware({
  target: PANORAMA_SERVICE_URL,
  changeOrigin: true,
  timeout: 30000,
  proxyTimeout: 30000,
  pathRewrite: (path) => '/api/vr' + path,
  onError: (err, req, res) => {
    console.error('[HPM] VR error:', err.message);
    if (!res.headersSent) {
      res.status(503).json({ success: false, error: 'VR service unavailable' });
    }
  }
}));

// Status endpoint
app.get('/status', (req, res) => {
  res.json({
    service: SERVICE_NAME,
    status: 'running',
    uptime: process.uptime(),
    memory: process.memoryUsage(),
    version: '1.3.0',
    configuration: {
      auth_service_url: AUTH_SERVICE_URL,
      user_service_url: USER_SERVICE_URL,
      voyage_service_url: VOYAGE_SERVICE_URL,
      ai_service_url: AI_SERVICE_URL,
      payment_service_url: PAYMENT_SERVICE_URL,
      panorama_service_url: PANORAMA_SERVICE_URL,
      port: PORT
    },
    timestamp: new Date().toISOString()
  });
});

// Metrics endpoint
app.get('/metrics', (req, res) => {
  const memUsage = process.memoryUsage();
  res.json({
    service: SERVICE_NAME,
    metrics: {
      memory: {
        rss: memUsage.rss,
        heapTotal: memUsage.heapTotal,
        heapUsed: memUsage.heapUsed,
        external: memUsage.external
      },
      uptime: process.uptime(),
      timestamp: new Date().toISOString()
    }
  });
});

// Service discovery endpoint
app.get('/api/services', (req, res) => {
  res.json({
    success: true,
    services: {
      gateway: {
        name: SERVICE_NAME,
        url: `http://localhost:${PORT}`,
        status: 'running',
        version: '1.3.0'
      },
      auth: {
        name: 'auth-service',
        url: AUTH_SERVICE_URL,
        status: 'unknown'
      },
      user: {
        name: 'user-service',
        url: USER_SERVICE_URL,
        status: 'unknown'
      },
      voyage: {
        name: 'voyage-service',
        url: VOYAGE_SERVICE_URL,
        status: 'unknown'
      },
      ai: {
        name: 'ai-service',
        url: AI_SERVICE_URL,
        status: 'unknown'
      },
      payment: {
        name: 'payment-service',
        url: PAYMENT_SERVICE_URL,
        status: 'unknown'
      },
      panorama: {
        name: 'panorama-service',
        url: PANORAMA_SERVICE_URL,
        status: 'unknown'
      }
    },
    timestamp: new Date().toISOString()
  });
});

// Error handling middleware
app.use((error, req, res, next) => {
  console.error('Gateway Service Error:', error);
  res.status(500).json({
    success: false,
    error: 'Internal server error',
    message: error.message,
    timestamp: new Date().toISOString()
  });
});

// 404 handler
app.use('*', (req, res) => {
  res.status(404).json({
    success: false,
    error: 'Endpoint not found',
    path: req.originalUrl,
    available_endpoints: ['/health', '/status', '/metrics', '/api'],
    timestamp: new Date().toISOString()
  });
});

// Graceful shutdown handling
process.on('SIGTERM', () => {
  console.log('🚀 Gateway Service received SIGTERM, shutting down gracefully...');
  server.close(() => {
    console.log('🚀 Gateway Service stopped');
    process.exit(0);
  });
});

process.on('SIGINT', () => {
  console.log('🚀 Gateway Service received SIGINT, shutting down gracefully...');
  server.close(() => {
    console.log('🚀 Gateway Service stopped');
    process.exit(0);
  });
});

// Start server
const server = app.listen(PORT, '0.0.0.0', () => {
  console.log(`🌟 DreamScape Gateway Service started`);
  console.log(`🚀 Service: ${SERVICE_NAME}`);
  console.log(`🔗 Port: ${PORT}`);
  console.log(`🎯 Auth: ${AUTH_SERVICE_URL}`);
  console.log(`👤 User: ${USER_SERVICE_URL}`);
  console.log(`✈️  Voyage: ${VOYAGE_SERVICE_URL}`);
  console.log(`🤖 AI: ${AI_SERVICE_URL}`);
  console.log(`💳 Payment: ${PAYMENT_SERVICE_URL}`);
  console.log(`🌐 Panorama: ${PANORAMA_SERVICE_URL}`);
  console.log(`🕐 Started at: ${new Date().toISOString()}`);
  console.log(`📋 Health check: http://localhost:${PORT}/health`);
});

server.on('error', (error) => {
  console.error('🚀 Gateway Service failed to start:', error);
  process.exit(1);
});