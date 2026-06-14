# URL Shortener — Design Document

> Illustrative sample content for monitoring/demo purposes. Not a production spec.

## 1. Problem Statement

Users need to convert long, unwieldy URLs into short, shareable links that
redirect to the original destination. The service must mint a compact unique
code per submitted URL, resolve that code back to the original URL on access
with low latency, and track basic usage (hit counts). It should deduplicate
identical URLs to avoid wasting the keyspace, support optional custom aliases,
and remain horizontally scalable since reads (redirects) vastly outnumber
writes (link creation).

## 2. API Contract

### `POST /api/links` — create a short link

Request:

```json
{
  "url": "https://example.com/some/very/long/path?ref=123",
  "customAlias": "my-link"      // optional; 3-32 chars, [a-zA-Z0-9_-]
}
```

Response `201 Created`:

```json
{
  "code": "my-link",
  "shortUrl": "https://sho.rt/my-link",
  "originalUrl": "https://example.com/some/very/long/path?ref=123",
  "createdAt": "2026-06-14T10:00:00Z"
}
```

Errors: `400` invalid URL, `409` alias already taken.

### `GET /{code}` — resolve and redirect

Response `301 Moved Permanently` with `Location: <originalUrl>`.
Returns `404` if the code is unknown.

### `GET /api/links/{code}/stats` — usage stats

Response `200 OK`:

```json
{
  "code": "my-link",
  "originalUrl": "https://example.com/some/very/long/path?ref=123",
  "hits": 482,
  "createdAt": "2026-06-14T10:00:00Z",
  "lastAccessedAt": "2026-06-14T18:42:11Z"
}
```

## 3. Data Model

`links` table:

| Column            | Type         | Notes                                  |
|-------------------|--------------|----------------------------------------|
| `code`            | varchar(32)  | Primary key; short code or alias       |
| `original_url`    | text         | Destination URL                        |
| `url_hash`        | char(64)     | SHA-256 of normalized URL; unique idx  |
| `hits`            | bigint       | Default 0                              |
| `created_at`      | timestamptz  | Default now()                          |
| `last_accessed_at`| timestamptz  | Nullable                               |

Indexes: PK on `code`, unique index on `url_hash` (dedup), optional index on
`created_at` for housekeeping.

## 4. Key Design Decisions

**D1 — Base62 counter encoding for codes.**
Mint codes by base62-encoding a monotonic counter (or Snowflake-style ID)
rather than random strings. Rationale: collision-free without retry loops,
compact (7 base62 chars cover ~3.5 trillion links), and naturally ordered.
Rejected: random codes (require collision checks); UUIDs (too long to share).

**D2 — Dedup via `url_hash` unique index.**
Normalize and hash each submitted URL; on conflict, return the existing code.
Rationale: prevents keyspace bloat and gives stable links for repeat
submissions. Cost is one extra index; acceptable given write volume is low.

**D3 — `301` redirect with edge caching.**
Use `301 Moved Permanently` so browsers and CDNs cache the redirect,
offloading the resolve path. Rationale: reads dominate, and caching cuts
origin load dramatically. Tradeoff: hit counts undercount cached redirects —
acceptable for coarse analytics; switch to `302` if exact counts are required.

**D4 — Async hit-count updates.**
Increment `hits` and `last_accessed_at` off the critical redirect path (queue
or fire-and-forget) so resolution stays fast. Rationale: redirect latency is
the user-facing metric; analytics can tolerate eventual consistency.
