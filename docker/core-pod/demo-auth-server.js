import express from 'express';
const app = express();
const PORT = process.env.PORT || 3001;

app.use(express.json());

app.get('/health', (req, res) => {
  res.json({ 
    service: 'auth-service', 
    status: 'healthy', 
    timestamp: new Date().toISOString(),
    pod: 'core-pod',
    architecture: 'big-pod'
  });
});

app.get('/', (req, res) => {
  res.json({ 
    message: 'DreamScape Auth Service - Core Pod',
    version: '1.0.0',
    endpoints: ['/health', '/api/v1/auth', '/api/v1/auth/login', '/api/v1/auth/register']
  });
});

// Route pour NGINX proxy
app.get('/api/v1/auth', (req, res) => {
  res.json({
    service: 'auth-service',
    message: 'Authentication API - Big Pod Architecture',
    endpoints: {
      login: 'POST /api/v1/auth/login',
      register: 'POST /api/v1/auth/register',
      health: 'GET /health'
    },
    timestamp: new Date().toISOString()
  });
});

app.post('/api/v1/auth/login', (req, res) => {
  res.json({ 
    token: 'demo-jwt-token-bigpod-' + Date.now(), 
    user: 'demo-user',
    message: 'Demo login successful - Big Pod Architecture',
    architecture: 'localhost-communication-5ms'
  });
});

app.post('/api/v1/auth/register', (req, res) => {
  res.json({ 
    user: 'new-user-' + Date.now(),
    message: 'Demo registration successful - Big Pod',
    architecture: 'core-pod'
  });
});

app.listen(PORT, '0.0.0.0', () => {
  console.log(`🔐 Auth Service running on port ${PORT} (Core Pod)`);
});