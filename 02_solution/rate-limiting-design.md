# Rate Limiting — Design Document

> Illustrative sample content for monitoring/demo purposes. Not a production spec.

## 1. Problem Statement

The URL shortener exposes two abusable surfaces. The **create path**
(`POST /api/links`) mints a new code per request; an unthrottled client can
mass-create links to exhaust the base62 keyspace, bloat storage, and drive up
write amplification on the `url_hash` dedup index. The **resolve path**
(`GET /{code}`) is the high-traffic redirect endpoint; a flood here can
saturate origin capacity behind the CDN — a redirect-path DoS — degrading
latency for legitimate users.

Because reads (redirects) vastly outnumber writes, the two paths need
**different limits**: the create path should be tight (creation is rare and
expensive), while the resolve path should be loose enough not to penalize
normal browsing bursts but firm enough to blunt abuse. The mechanism must work
across a horizontally scaled fleet without pinning a client to one instance.

## 2. Proposed Approach

**Token-bucket per client key.** Each client gets a bucket that refills at a
fixed rate up to a burst capacity; each request consumes one token. The client
key is the **API key** when present, otherwise the **client IP** (first
trusted hop from `X-Forwarded-For`). Buckets are namespaced per path class so
the create and resolve limits are independent.

Example limits (tunable per environment):

| Path class                | Sustained rate | Burst capacity |
|---------------------------|----------------|----------------|
| Create (`POST /api/links`)| 10 / minute    | 20 tokens      |
| Resolve (`GET /{code}`)   | 600 / minute   | 1000 tokens    |

The resolve bucket is ~60x looser, reflecting that reads dominate and that
CDN/edge caching already absorbs most repeat redirects (see design doc D3).
The create bucket is deliberately small because each accepted request consumes
keyspace and storage permanently.

## 3. Where State Lives

A token bucket needs shared, atomic counters. With a horizontally scaled fleet,
**in-memory buckets per instance are incorrect**: a client load-balanced across
N instances effectively gets N× its limit, and limits reset on deploy/restart.

State therefore lives in **Redis**, keyed by `rl:{pathClass}:{clientKey}`, with
refill computed via a small atomic Lua script (read tokens + timestamp, refill
by elapsed time, decrement, write back) so concurrent requests don't race.
TTL on each key reclaims idle buckets automatically.

Tradeoff: Redis adds a network hop and a dependency on the hot resolve path.
Mitigations: (a) the check is a single round trip and pipelines cheaply;
(b) resolve traffic is heavily CDN-cached, so only cache misses reach the
limiter; (c) on Redis unavailability the limiter **fails open** (allow the
request, log, and alert) rather than blocking all traffic — availability of
redirects outranks perfect enforcement for a demo-grade service.

## 4. API Behavior

When a bucket is empty, the request is rejected with **`429 Too Many
Requests`** before any business logic runs.

Response body:

```json
{
  "error": "rate_limited",
  "message": "Too many requests. Retry after 12 seconds.",
  "retryAfterSeconds": 12
}
```

Headers on **every** rate-limited path (both 2xx/3xx and 429 responses):

| Header                  | Meaning                                                |
|-------------------------|--------------------------------------------------------|
| `X-RateLimit-Limit`     | Bucket capacity for this path class (e.g. `20`)        |
| `X-RateLimit-Remaining` | Tokens left after this request (e.g. `0`)              |
| `X-RateLimit-Reset`     | Unix epoch seconds when the bucket is fully refilled   |
| `Retry-After`           | (429 only) seconds until at least one token is available|

Note: on the resolve path the 429 is a JSON body rather than a redirect, so
clients and crawlers can distinguish throttling from a missing code (`404`).

## 5. Key Design Decisions

**D5 — Token bucket over fixed/sliding window.**
Use a refilling token bucket keyed per client and path class. Rationale:
absorbs short legitimate bursts (browser prefetch, share-sheet fan-out) while
enforcing a sustained ceiling, and refill is cheap to compute from a single
timestamp. Rejected: fixed-window counters (boundary-burst doubling at window
edges); sliding-window logs (per-request memory grows with traffic — wrong for
the read-dominated resolve path).

**D6 — Redis-backed state, fail-open.**
Store buckets in Redis with an atomic Lua refill-and-decrement; on Redis
outage, allow the request and alert. Rationale: correct enforcement across a
horizontally scaled fleet requires shared state, and for redirects availability
outranks strict enforcement. Rejected: per-instance in-memory buckets (give
N× the limit behind a load balancer and reset on deploy); fail-closed (a Redis
blip would take down all redirects).

**D7 — Client key = API key, falling back to IP.**
Prefer an authenticated API key as the bucket identity; use the trusted client
IP only when no key is present. Rationale: API keys give stable, per-tenant
fairness and survive NAT/shared-IP situations; IP is a reasonable default for
anonymous traffic. Rejected: IP-only (penalizes users behind shared NAT/CGNAT
and is trivially rotated by attackers); global limits (one noisy client would
throttle everyone).
