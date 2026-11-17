# Authentication, authorisation and rate limiting

API-surface patterns. Identity-provider configuration and token validation
internals live in `identity-development` (Entra ID specifics in
`azure-development`); the threat model lives in `secure-development`;
this covers how the API *presents* auth and protects itself.

## Authentication schemes

| Scheme | Use when |
|---|---|
| **OAuth2 / OIDC bearer (JWT)** | Default for user- and app-delegated access. `Authorization: Bearer <token>`; validate issuer, audience, expiry, signature. Scopes/roles carry permissions. On Microsoft/Azure stacks the IdP is typically Entra ID |
| **API keys** | Server-to-server or simple partner access. `X-API-Key: <key>` (a header, never the URL). Lower assurance — scope tightly, rotate, rate-limit per key |
| **mTLS** | High-assurance service-to-service / regulated integrations |

**JWKS caching after key rotation:** remote-JWKS helpers cache keys and rate-limit
refetches. In `jose`, `createRemoteJWKSet` refetches on an unknown `kid` only once
`cooldownDuration` (default 30 s) has passed since the last successful fetch, and
caches for `cacheMaxAge` (default 10 min). Right after an IdP rotates keys — or in a
test that mints a token with a fresh key — expect up to 30 s of `401`s; tests should
inject a local JWKS rather than wait, and incident runbooks should mention the delay.

Prefer short-lived bearer tokens with refresh over long-lived static
credentials. Never put tokens or keys in query strings — they end up in logs,
history and caches.

## 401 vs 403 — get this right

- `401 Unauthorized` — **who are you?** No/invalid/expired credentials. Include
  a `WWW-Authenticate` header.
- `403 Forbidden` — **I know you, you can't do this.** Authenticated but the
  token lacks the required scope/role.
- Returning `404` to hide a resource's existence from unauthorised callers is a
  valid choice, but make it deliberate and consistent.

## Authorisation

- Enforce **least-privilege scopes/roles** per operation; check on the server
  every time — never trust the client to hide a button.
- Scope tokens to the narrowest set needed; separate read and write scopes.
- For resource ownership, verify the caller may act on *this* instance, not
  just that they hold the right scope.

## Rate limiting

Protect availability and signal limits to clients.

```http
HTTP/1.1 429 Too Many Requests
Retry-After: 60
RateLimit-Policy: "default";q=1000;w=60
RateLimit: "default";r=0;t=60
```

- Return `429` with `Retry-After` when limiting.
- Surface budget on normal responses. The IETF `RateLimit`/`RateLimit-Policy`
  header fields (draft-ietf-httpapi-ratelimit-headers, still an Internet-Draft)
  use Structured Fields: a named policy with `q` (quota) and `w` (window, s) in
  `RateLimit-Policy`, and `r` (remaining) and `t` (seconds until reset) in
  `RateLimit`. Older drafts' `limit=, remaining=, reset=` syntax is obsolete.
  `X-RateLimit-Limit` / `-Remaining` / `-Reset` remain the widely-deployed
  de-facto form — pick one and document it.
- Limit per principal/API key (and optionally per IP); choose an algorithm
  (token bucket / sliding window) suited to burst tolerance.
- Distinguish throttling (`429`, retryable) from quota exhaustion (often `403`
  with a clear `problem+json` type).

## CORS (browser clients)

Only relevant for browser-based callers. Be explicit, not permissive:

- Allow specific origins, not `*`, when `Access-Control-Allow-Credentials` is
  true (the two are incompatible by spec).
- Allow only the methods and headers actually used.
- Handle the `OPTIONS` preflight; cache it with `Access-Control-Max-Age`.
- CORS is **not** a security control — it constrains browsers, not servers.
  Authn/authz still apply to every request.

## Transport and hygiene

- TLS only; redirect/refuse plaintext. HSTS at the edge.
- No secrets/PII in URLs; minimise sensitive data in responses (no over-
  exposure of fields).
- Validate and bound all input (sizes, types, enums) — injection and input
  handling taxonomy → `secure-development`.
