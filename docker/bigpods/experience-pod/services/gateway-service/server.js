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
const CORE_POD_URL = process.env.CORE_POD_URL || 'http://core-pod:3000';
const BUSINESS_POD_URL = process.env.BUSINESS_POD_URL || 'http://business-pod:3001';

// Middleware
app.use(cors({
  origin: ['http://localhost', 'http://localhost:80', 'http://localhost:8080'],
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

// Core Pod proxy (Auth, Users)
app.use('/api/auth', createProxyMiddleware({
  target: CORE_POD_URL,
  changeOrigin: true,
  timeout: 30000,
  onError: (err, req, res) => {
    console.error('Core Pod proxy error:', err.message);
    res.status(503).json({
      success: false,
      error: 'Core Pod unavailable',
      message: 'Authentication service is temporarily unavailable'
    });
  }
}));

app.use('/api/users', createProxyMiddleware({
  target: CORE_POD_URL,
  changeOrigin: true,
  timeout: 30000,
  onError: (err, req, res) => {
    console.error('Core Pod proxy error:', err.message);
    res.status(503).json({
      success: false,
      error: 'Core Pod unavailable',
      message: 'User service is temporarily unavailable'
    });
  }
}));

// Business Pod proxy (Voyages, AI)
app.use('/api/voyages', createProxyMiddleware({
  target: BUSINESS_POD_URL,
  changeOrigin: true,
  timeout: 30000,
  onError: (err, req, res) => {
    console.error('Business Pod proxy error:', err.message);
    res.status(503).json({
      success: false,
      error: 'Business Pod unavailable',
      message: 'Voyage service is temporarily unavailable'
    });
  }
}));

app.use('/api/ai', createProxyMiddleware({
  target: BUSINESS_POD_URL,
  changeOrigin: true,
  timeout: 60000, // AI requests can take longer
  onError: (err, req, res) => {
    console.error('Business Pod AI proxy error:', err.message);
    res.status(503).json({
      success: false,
      error: 'AI Service unavailable',
      message: 'AI service is temporarily unavailable'
    });
  }
}));

// Local VR API (handled by panorama service)
app.use('/api/vr', createProxyMiddleware({
  target: 'http://localhost:3006',
  changeOrigin: true,
  timeout: 30000,
  onError: (err, req, res) => {
    console.error('Panorama service proxy error:', err.message);
    res.status(503).json({
      success: false,
      error: 'VR Service unavailable',
      message: 'VR content service is temporarily unavailable'
    });
  }
}));

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
  console.log(`🎯 Core Pod: ${CORE_POD_URL}`);
  console.log(`💼 Business Pod: ${BUSINESS_POD_URL}`);
  console.log(`🕐 Started at: ${new Date().toISOString()}`);
  console.log(`📋 Health check: http://localhost:${PORT}/health`);
});

server.on('error', (error) => {
  console.error('🚀 Gateway Service failed to start:', error);
  process.exit(1);
});