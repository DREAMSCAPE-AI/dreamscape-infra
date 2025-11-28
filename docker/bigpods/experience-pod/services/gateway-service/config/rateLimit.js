const FIFTEEN_MINUTES = 15 * 60 * 1000;
const ONE_HOUR = 60 * 60 * 1000;

const toNumber = (value, fallback) => {
  const parsed = Number(value);
  return Number.isFinite(parsed) && parsed > 0 ? parsed : fallback;
};

const config = {
  global: {
    windowMs: toNumber(process.env.RATE_LIMIT_WINDOW_MS, FIFTEEN_MINUTES),
    max: toNumber(process.env.RATE_LIMIT_MAX, 1000),
    limitExceededMessage: 'Too many requests, please try again later.',
    standardHeaders: true,
    legacyHeaders: false,
    skipSuccessfulRequests: false,
    skipFailedRequests: false
  },
  routes: {
    'auth.login': {
      windowMs: toNumber(process.env.RATE_LIMIT_AUTH_LOGIN_WINDOW_MS, FIFTEEN_MINUTES),
      max: toNumber(process.env.RATE_LIMIT_AUTH_LOGIN_MAX, 10),
      limitExceededMessage: 'Too many login attempts, please wait before retrying.'
    },
    'auth.register': {
      windowMs: toNumber(process.env.RATE_LIMIT_AUTH_REGISTER_WINDOW_MS, ONE_HOUR),
      max: toNumber(process.env.RATE_LIMIT_AUTH_REGISTER_MAX, 5),
      limitExceededMessage: 'Too many registration attempts, please try again later.'
    },
    'auth.refresh': {
      windowMs: toNumber(process.env.RATE_LIMIT_AUTH_REFRESH_WINDOW_MS, FIFTEEN_MINUTES),
      max: toNumber(process.env.RATE_LIMIT_AUTH_REFRESH_MAX, 30),
      limitExceededMessage: 'Too many token refresh attempts.'
    },
    'auth.default': {
      max: toNumber(process.env.RATE_LIMIT_AUTH_DEFAULT_MAX, 600)
    },
    'users.default': {
      max: toNumber(process.env.RATE_LIMIT_USERS_DEFAULT_MAX, 800)
    },
    'voyages.default': {
      max: toNumber(process.env.RATE_LIMIT_VOYAGES_DEFAULT_MAX, 400)
    },
    'ai.default': {
      max: toNumber(process.env.RATE_LIMIT_AI_DEFAULT_MAX, 300)
    },
    'vr.default': {
      max: toNumber(process.env.RATE_LIMIT_VR_DEFAULT_MAX, 250),
      windowMs: toNumber(process.env.RATE_LIMIT_VR_WINDOW_MS, ONE_HOUR)
    },
    global: {
      max: toNumber(process.env.RATE_LIMIT_GLOBAL_MAX, 1200),
      windowMs: toNumber(process.env.RATE_LIMIT_GLOBAL_WINDOW_MS, FIFTEEN_MINUTES)
    }
  }
};

module.exports = config;
