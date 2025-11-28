/**
 * Integration-style tests that verify the rate limiting middleware wiring on the Express app.
 * We mock the proxy layer to avoid external network calls and focus on middleware behaviour.
 */
jest.mock('../config/rateLimit', () => {
  const windowMs = 500;
  return {
    global: {
      windowMs,
      max: 5,
      limitExceededMessage: 'Global limit exceeded',
      standardHeaders: true,
      legacyHeaders: false
    },
    routes: {
      global: {
        windowMs,
        max: 5
      },
      'auth.login': {
        windowMs,
        max: 2,
        limitExceededMessage: 'Login limited'
      },
      'auth.register': {
        windowMs,
        max: 1,
        limitExceededMessage: 'Register limited'
      },
      'auth.refresh': {
        windowMs,
        max: 2
      },
      'auth.default': {
        windowMs,
        max: 4
      },
      'users.default': {
        windowMs,
        max: 4
      },
      'voyages.default': {
        windowMs,
        max: 3
      },
      'ai.default': {
        windowMs,
        max: 3
      },
      'vr.default': {
        windowMs,
        max: 2
      }
    }
  };
});

jest.mock('http-proxy-middleware', () => ({
  createProxyMiddleware: jest.fn(() => (req, res) => {
    res.status(200).json({
      proxied: true,
      path: req.originalUrl,
      method: req.method
    });
  })
}));

const request = require('supertest');
const { resetLimiters } = require('../middleware/rateLimiter');
const { app } = require('../server');

describe('Gateway rate limiting middleware', () => {
  beforeAll(() => {
    process.env.PANORAMA_SERVICE_URL = 'http://panorama-service.test';
  });

  afterEach(() => {
    resetLimiters();
  });

  afterAll(() => {
    delete process.env.PANORAMA_SERVICE_URL;
  });

  it('exposes standard rate limit headers on health endpoint', async () => {
    const response = await request(app).get('/health');
    expect(response.status).toBe(200);
    expect(response.headers['ratelimit-limit']).toBeDefined();
    expect(response.headers['ratelimit-remaining']).toBeDefined();
    expect(response.headers['ratelimit-reset']).toBeDefined();
  });

  it('enforces stricter login limits than the global bucket', async () => {
    const first = await request(app).post('/api/auth/login').send({ email: 'a@a', password: 'pwd' });
    const second = await request(app).post('/api/auth/login').send({ email: 'a@a', password: 'pwd' });
    expect(first.status).toBe(200);
    expect(second.status).toBe(200);

    const blocked = await request(app).post('/api/auth/login').send({ email: 'a@a', password: 'pwd' });
    expect(blocked.status).toBe(429);
    expect(blocked.body).toMatchObject({
      success: false,
      code: 'RATE_LIMIT_EXCEEDED',
      message: 'Login limited',
      route: 'auth.login'
    });
    expect(blocked.headers['retry-after']).toBeDefined();
    expect(blocked.headers['ratelimit-policy']).toContain('2;');
  });

  it('keeps other routes usable when a specific limiter is exhausted', async () => {
    // Exhaust registration limiter (max = 1)
    await request(app).post('/api/auth/register').send({ email: 'a@a', password: 'pwd' });
    const blockedRegister = await request(app).post('/api/auth/register').send({ email: 'a@a', password: 'pwd' });
    expect(blockedRegister.status).toBe(429);

    // Users route should still be available and return proxy payload
    const usersResponse = await request(app).get('/api/users/profile');
    expect(usersResponse.status).toBe(200);
    expect(usersResponse.body).toMatchObject({ proxied: true });
    expect(usersResponse.headers['ratelimit-limit']).toBeDefined();
  });
});
