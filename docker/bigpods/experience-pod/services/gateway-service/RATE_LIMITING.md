# DreamScape Gateway – Rate Limiting Middleware

Ticket **INFRA-011.1** introduces a configurable Express middleware that protects each API surface with tailored quotas and exposes `RateLimit-*` headers that comply with the [RFC 9333](https://www.rfc-editor.org/rfc/rfc9333) recommendations.

## How it works

- `config/rateLimit.js` centralises every throttle window and reads optional environment overrides (for example `RATE_LIMIT_AUTH_LOGIN_MAX`, `RATE_LIMIT_VR_WINDOW_MS`, etc.).
- `middleware/rateLimiter.js` builds memoized instances of `express-rate-limit`, adds structured JSON responses, emits `Retry-After`/`RateLimit-Policy` headers, and logs the offending IP + route via `onLimitReached`.
- `server.js` now injects the middleware before each proxy binding (login/register/refresh, auth defaults, users, voyages, AI, VR) while keeping a global bucket for health/metadata endpoints.

## Configuration matrix

| Key | Default window | Default max | Env override |
| --- | --- | --- | --- |
| `global` | 15 min | 1000 req | `RATE_LIMIT_WINDOW_MS`, `RATE_LIMIT_MAX` |
| `auth.login` | 15 min | 10 req | `RATE_LIMIT_AUTH_LOGIN_WINDOW_MS`, `RATE_LIMIT_AUTH_LOGIN_MAX` |
| `auth.register` | 60 min | 5 req | `RATE_LIMIT_AUTH_REGISTER_WINDOW_MS`, `RATE_LIMIT_AUTH_REGISTER_MAX` |
| `auth.refresh` | 15 min | 30 req | `RATE_LIMIT_AUTH_REFRESH_WINDOW_MS`, `RATE_LIMIT_AUTH_REFRESH_MAX` |
| `auth.default` | 15 min | 600 req | `RATE_LIMIT_AUTH_DEFAULT_MAX` |
| `users.default` | 15 min | 800 req | `RATE_LIMIT_USERS_DEFAULT_MAX` |
| `voyages.default` | 15 min | 400 req | `RATE_LIMIT_VOYAGES_DEFAULT_MAX` |
| `ai.default` | 15 min | 300 req | `RATE_LIMIT_AI_DEFAULT_MAX` |
| `vr.default` | 60 min | 250 req | `RATE_LIMIT_VR_WINDOW_MS`, `RATE_LIMIT_VR_DEFAULT_MAX` |

## Testing strategy

`npm test` now runs Jest + Supertest suites that cover:

1. Configuration loading & env overrides (`__tests__/rateLimitConfig.test.js`).
2. Integration behaviour with mocked proxies (`__tests__/gateway.rate-limit.test.js`) to assert route-specific blocking, JSON payloads, and header propagation.

These tests are also wired into `dreamscape-tests` via the upcoming integration step for the gateway pod. Run them locally before shipping container images.
