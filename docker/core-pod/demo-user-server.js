import express from 'express';
const app = express();
const PORT = process.env.PORT || 3002;

app.use(express.json());

app.get('/health', (req, res) => {
  res.json({ 
    service: 'user-service', 
    status: 'healthy', 
    timestamp: new Date().toISOString(),
    pod: 'core-pod',
    architecture: 'big-pod'
  });
});

app.get('/', (req, res) => {
  res.json({ 
    message: 'DreamScape User Service - Core Pod',
    version: '1.0.0',
    endpoints: ['/health', '/api/v1/users', '/api/v1/users/profile', '/api/v1/users/preferences']
  });
});

// Route pour NGINX proxy
app.get('/api/v1/users', (req, res) => {
  res.json({
    service: 'user-service',
    message: 'User Management API - Big Pod Architecture',
    endpoints: {
      profile: 'GET /api/v1/users/profile',
      preferences: 'GET /api/v1/users/preferences',
      health: 'GET /health'
    },
    timestamp: new Date().toISOString(),
    communication: 'localhost-5ms-ultra-fast'
  });
});

app.get('/api/v1/users/profile', (req, res) => {
  res.json({ 
    user: {
      id: 'demo-bigpod-' + Date.now(),
      name: 'Demo User Big Pod',
      email: 'demo@dreamscape-bigpod.com',
      architecture: 'core-pod-localhost'
    },
    message: 'Demo profile retrieved - Big Pod Architecture',
    performance: 'localhost-communication-5ms'
  });
});

app.get('/api/v1/users/preferences', (req, res) => {
  res.json({
    preferences: {
      theme: 'dark',
      language: 'fr',
      notifications: true,
      architecture: 'big-pod-optimized'
    },
    message: 'User preferences - Core Pod',
    timestamp: new Date().toISOString()
  });
});

app.listen(PORT, '0.0.0.0', () => {
  console.log(`👤 User Service running on port ${PORT} (Core Pod)`);
});