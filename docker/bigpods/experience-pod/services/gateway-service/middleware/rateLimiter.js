const rateLimit = require('express-rate-limit');
const rateLimitConfig = require('../config/rateLimit');

const limiterCache = new Map();

const secondsFromMs = (ms) => Math.ceil(ms / 1000);

const buildLimiterOptions = (key = 'global') => {
  const globalConfig = rateLimitConfig.global || {};
  const routeConfig = rateLimitConfig.routes?.[key] || {};

  return {
    ...globalConfig,
    ...routeConfig,
    key
  };
};

const createLimiter = (key) => {
  const options = buildLimiterOptions(key);
  const windowMs = options.windowMs ?? rateLimitConfig.global.windowMs;
  const max = options.max ?? rateLimitConfig.global.max;
  const limitExceededMessage = options.limitExceededMessage || rateLimitConfig.global.limitExceededMessage;
  const standardHeaders = options.standardHeaders ?? true;
  const legacyHeaders = options.legacyHeaders ?? false;
  const skipSuccessfulRequests = options.skipSuccessfulRequests ?? false;
  const skipFailedRequests = options.skipFailedRequests ?? false;
  const keyGenerator = options.keyGenerator || ((req) => `${req.ip}:${req.method}:${req.baseUrl || req.path}`);

  return rateLimit({
    windowMs,
    max,
    standardHeaders,
    legacyHeaders,
    skipSuccessfulRequests,
    skipFailedRequests,
    keyGenerator,
    handler: (req, res) => {
      const retryAfterSeconds = secondsFromMs(windowMs);
      res.setHeader('Retry-After', retryAfterSeconds);
      res.setHeader('RateLimit-Policy', `${max};w=${retryAfterSeconds}`);

      console.warn(`[RateLimit] ${key} exceeded for ${req.ip} ${req.originalUrl}`);

      res.status(429).json({
        success: false,
        code: 'RATE_LIMIT_EXCEEDED',
        message: limitExceededMessage,
        route: key,
        windowMs,
        limit: max,
        retryAfterSeconds
      });
    }
  });
};

const getLimiter = (key = 'global') => {
  if (!limiterCache.has(key)) {
    limiterCache.set(key, createLimiter(key));
  }
  return limiterCache.get(key);
};

const routeLimiter = (key = 'global') => {
  const middleware = (req, res, next) => getLimiter(key)(req, res, next);
  // Instantiate immediately to comply with express-rate-limit v7 recommendation.
  getLimiter(key);
  return middleware;
};

const resetLimiters = () => {
  const keys = Array.from(limiterCache.keys());
  limiterCache.clear();
  keys.forEach((key) => {
    limiterCache.set(key, createLimiter(key));
  });
};

module.exports = {
  routeLimiter,
  resetLimiters,
  buildLimiterOptions
};
