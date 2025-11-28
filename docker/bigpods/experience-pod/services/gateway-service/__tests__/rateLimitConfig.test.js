const loadConfig = () => {
  let configModule;
  jest.isolateModules(() => {
    configModule = require('../config/rateLimit');
  });
  return configModule;
};

describe('rate limit configuration', () => {
  afterEach(() => {
    delete process.env.RATE_LIMIT_AI_DEFAULT_MAX;
  });

  it('exposes route level overrides with sane defaults', () => {
    const config = loadConfig();
    expect(config.global.windowMs).toBeGreaterThan(1000);
    expect(config.routes['auth.login'].max).toBe(10);
    expect(config.routes['auth.register'].windowMs).toBeGreaterThan(config.global.windowMs);
  });

  it('reads environment overrides for specific services', () => {
    process.env.RATE_LIMIT_AI_DEFAULT_MAX = '42';
    const config = loadConfig();
    expect(config.routes['ai.default'].max).toBe(42);
  });
});
