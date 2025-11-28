#!/usr/bin/env node
/**
 * DreamScape Gateway Service - API Gateway & Proxy
 * DR-328: Experience Pod - Big Pods Architecture  
 * Routes requests between services and provides unified API
 */

const express = require('express');
const { createProxyMiddleware } = require('http-proxy-middleware');
const cors = require('cors');
const { routeLimiter } = require('./middleware/rateLimiter');

const app = express();
const PORT = process.env.PORT || 3007;
const SERVICE_NAME = process.env.SERVICE_NAME || 'gateway-service';
const CORE_POD_URL = process.env.CORE_POD_URL || 'http://core-pod:3000';
const BUSINESS_POD_URL = process.env.BUSINESS_POD_URL || 'http://business-pod:3001';
const PROXY_TIMEOUT_MS = Number(process.env.PROXY_TIMEOUT_MS) || 30000;
let server;

// Middleware
app.use(cors({
  origin: ['http://localhost', 'http://localhost:80', 'http://localhost:8080'],
  credentials: true
}));

app.use(express.json({ limit: '10mb' }));
app.use(express.urlencoded({ extended: true, limit: '10mb' }));

// Global rate limiting middleware
app.use(routeLimiter('global'));

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
    version: '1.2.0',
    timestamp: new Date().toISOString(),
    proxies: {
      core_pod: CORE_POD_URL,
      business_pod: BUSINESS_POD_URL
    }
  });
});

// API Routes
app.get('/api', (req, res) => {
  res.json({
    service: SERVICE_NAME,
    version: '1.2.0',
    description: 'DreamScape API Gateway - Experience Pod',
    endpoints: {
      health: '/health',
      status: '/status',
      metrics: '/metrics',
      api: {
        auth: '/api/auth/*',
        users: '/api/users/*',
        voyages: '/api/voyages/*',
        ai: '/api/ai/*',
        vr: '/api/vr/*'
      }
    },
    timestamp: new Date().toISOString()
  });
});

const createProxy = (label, target, unavailableMessage, customTimeoutMs) => createProxyMiddleware({
  target,
  changeOrigin: true,
  timeout: customTimeoutMs || PROXY_TIMEOUT_MS,
  proxyTimeout: customTimeoutMs || PROXY_TIMEOUT_MS,
  onError: (err, req, res) => {
    console.error(`${label} proxy error:`, err.message);
    res.status(503).json({
      success: false,
      error: `${label} unavailable`,
      message: unavailableMessage
    });
  }
});

const registerProxyRoute = ({ path, methods, limiterKey, proxyMiddleware }) => {
  const normalizedMethods = Array.isArray(methods) ? methods : [];

  if (normalizedMethods.length) {
    normalizedMethods.forEach((method) => {
      const methodName = method.toLowerCase();
      if (typeof app[methodName] !== 'function') {
        throw new Error(`Unsupported HTTP method "${method}" for ${path}`);
      }

      app[methodName](path, routeLimiter(limiterKey), proxyMiddleware);
    });
    return;
  }

  app.use(path, routeLimiter(limiterKey), proxyMiddleware);
};

const corePodProxy = createProxy(
  'Core Pod',
  CORE_POD_URL,
  'Authentication or user services are temporarily unavailable'
);

const businessPodProxy = createProxy(
  'Business Pod',
  BUSINESS_POD_URL,
  'Experience services are temporarily unavailable',
  60000
);

const panoramaProxy = createProxy(
  'VR Service',
  process.env.PANORAMA_SERVICE_URL || 'http://localhost:3006',
  'VR content service is temporarily unavailable'
);

// Core Pod proxy (Auth, Users)
registerProxyRoute({
  path: '/api/auth/login',
  methods: ['post'],
  limiterKey: 'auth.login',
  proxyMiddleware: corePodProxy
});

registerProxyRoute({
  path: '/api/auth/register',
  methods: ['post'],
  limiterKey: 'auth.register',
  proxyMiddleware: corePodProxy
});

registerProxyRoute({
  path: '/api/auth/refresh',
  methods: ['post'],
  limiterKey: 'auth.refresh',
  proxyMiddleware: corePodProxy
});

registerProxyRoute({
  path: '/api/auth',
  limiterKey: 'auth.default',
  proxyMiddleware: corePodProxy
});

registerProxyRoute({
  path: '/api/users',
  limiterKey: 'users.default',
  proxyMiddleware: corePodProxy
});

// Business Pod proxy (Voyages, AI)
registerProxyRoute({
  path: '/api/voyages',
  limiterKey: 'voyages.default',
  proxyMiddleware: businessPodProxy
});

registerProxyRoute({
  path: '/api/ai',
  limiterKey: 'ai.default',
  proxyMiddleware: businessPodProxy
});

// Local VR API (handled by panorama service)
registerProxyRoute({
  path: '/api/vr',
  limiterKey: 'vr.default',
  proxyMiddleware: panoramaProxy
});

// Status endpoint
app.get('/status', (req, res) => {
  res.json({
    service: SERVICE_NAME,
    status: 'running',
    uptime: process.uptime(),
    memory: process.memoryUsage(),
    version: '1.2.0',
    configuration: {
      core_pod_url: CORE_POD_URL,
      business_pod_url: BUSINESS_POD_URL,
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
        version: '1.2.0'
      },
      panorama: {
        name: 'panorama-service',
        url: 'http://localhost:3006',
        status: 'unknown'
      },
      core_pod: {
        name: 'core-pod',
        url: CORE_POD_URL,
        status: 'unknown'
      },
      business_pod: {
        name: 'business-pod', 
        url: BUSINESS_POD_URL,
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

const startServer = () => {
  if (server) {
    return server;
  }

  server = app.listen(PORT, '0.0.0.0', () => {
    console.log(`?YOY DreamScape Gateway Service started`);
    console.log(`?Ys? Service: ${SERVICE_NAME}`);
    console.log(`?Y"- Port: ${PORT}`);
    console.log(`?YZ? Core Pod: ${CORE_POD_URL}`);
    console.log(`?Y'? Business Pod: ${BUSINESS_POD_URL}`);
    console.log(`?Y? Started at: ${new Date().toISOString()}`);
    console.log(`?Y"< Health check: http://localhost:${PORT}/health`);
  });

  server.on('error', (error) => {
    console.error('?Ys? Gateway Service failed to start:', error);
    process.exit(1);
  });

  return server;
};

const shutdown = (signal) => {
  console.log(`?Ys? Gateway Service received ${signal}, shutting down gracefully...`);
  if (!server) {
    process.exit(0);
    return;
  }

  server.close(() => {
    console.log('?Ys? Gateway Service stopped');
    process.exit(0);
  });
};

process.on('SIGTERM', () => shutdown('SIGTERM'));
process.on('SIGINT', () => shutdown('SIGINT'));

if (require.main === module) {
  startServer();
}

module.exports = { app, startServer };
