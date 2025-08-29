#!/usr/bin/env node
/**
 * DreamScape Panorama Service - VR Content Management
 * DR-328: Experience Pod - Big Pods Architecture
 * Handles VR content serving, streaming and optimization
 */

const express = require('express');
const path = require('path');
const fs = require('fs').promises;
const cors = require('cors');

const app = express();
const PORT = process.env.PORT || 3006;
const SERVICE_NAME = process.env.SERVICE_NAME || 'panorama-service';
const VR_CONTENT_PATH = process.env.VR_CONTENT_PATH || '/usr/share/nginx/html/vr';

// Middleware
app.use(cors());
app.use(express.json({ limit: '50mb' }));
app.use(express.urlencoded({ extended: true, limit: '50mb' }));

// Request logging
app.use((req, res, next) => {
  console.log(`[${new Date().toISOString()}] ${req.method} ${req.path}`);
  next();
});

// Health check endpoint
app.get('/health', (req, res) => {
  res.json({
    status: 'healthy',
    service: SERVICE_NAME,
    version: '1.2.0',
    timestamp: new Date().toISOString(),
    vr_content_path: VR_CONTENT_PATH
  });
});

// VR catalog endpoint
app.get('/api/vr/catalog', async (req, res) => {
  try {
    const catalogPath = path.join(VR_CONTENT_PATH, 'vr-catalog.json');
    const catalogData = await fs.readFile(catalogPath, 'utf8');
    const catalog = JSON.parse(catalogData);
    
    res.json({
      success: true,
      data: catalog,
      timestamp: new Date().toISOString()
    });
  } catch (error) {
    console.error('Failed to load VR catalog:', error.message);
    res.status(500).json({
      success: false,
      error: 'Failed to load VR catalog',
      message: error.message
    });
  }
});

// VR content metadata endpoint
app.get('/api/vr/metadata/:filename', async (req, res) => {
  try {
    const { filename } = req.params;
    const metadataPath = path.join('/var/cache/nginx/vr', `${filename}.json`);
    
    const metadataData = await fs.readFile(metadataPath, 'utf8');
    const metadata = JSON.parse(metadataData);
    
    res.json({
      success: true,
      data: metadata,
      timestamp: new Date().toISOString()
    });
  } catch (error) {
    console.error(`Failed to load metadata for ${req.params.filename}:`, error.message);
    res.status(404).json({
      success: false,
      error: 'Metadata not found',
      message: error.message
    });
  }
});

// VR content upload endpoint (placeholder)
app.post('/api/vr/upload', (req, res) => {
  res.json({
    success: false,
    message: 'VR content upload not implemented yet',
    timestamp: new Date().toISOString()
  });
});

// Status endpoint
app.get('/status', (req, res) => {
  res.json({
    service: SERVICE_NAME,
    status: 'running',
    uptime: process.uptime(),
    memory: process.memoryUsage(),
    version: '1.2.0',
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

// Error handling middleware
app.use((error, req, res, next) => {
  console.error('Panorama Service Error:', error);
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
    timestamp: new Date().toISOString()
  });
});

// Graceful shutdown handling
process.on('SIGTERM', () => {
  console.log('📡 Panorama Service received SIGTERM, shutting down gracefully...');
  server.close(() => {
    console.log('📡 Panorama Service stopped');
    process.exit(0);
  });
});

process.on('SIGINT', () => {
  console.log('📡 Panorama Service received SIGINT, shutting down gracefully...');
  server.close(() => {
    console.log('📡 Panorama Service stopped');
    process.exit(0);
  });
});

// Start server
const server = app.listen(PORT, '0.0.0.0', () => {
  console.log(`🌟 DreamScape Panorama Service started`);
  console.log(`📡 Service: ${SERVICE_NAME}`);
  console.log(`🔗 Port: ${PORT}`);
  console.log(`📁 VR Content Path: ${VR_CONTENT_PATH}`);
  console.log(`🕐 Started at: ${new Date().toISOString()}`);
  console.log(`📋 Health check: http://localhost:${PORT}/health`);
});

server.on('error', (error) => {
  console.error('📡 Panorama Service failed to start:', error);
  process.exit(1);
});