# Consuming third-party APIs, local dev hosts, router traps

The rest of this skill is about APIs you *publish*. This file covers the
other side — integrating with APIs you don't control — plus local-dev
and router traps that cost real debugging time.

## Consuming APIs you don't control

1. **Check the body verdict, not just the status.** Many APIs answer
   `200 OK` with a failure in the body (`{"result": "error", "message":
   ...}`, `{"ok": false}`, `{"errors": [...]}` from GraphQL). `res.ok`
   is necessary, not sufficient: parse the envelope and branch on its
   own success field before trusting `data`.
2. **Normalise at the boundary.** Third-party payloads are often
   loosely typed — optional fields, numbers as strings, `""` vs `null`
   vs missing, one shape for a single item and another for a list.
   Convert them into one *total* internal type (every field present,
   correctly typed, defaults explicit) in a single adapter, and let
   the UI and business logic see only that type. Validate with a
   schema library rather than casting.
3. **Log the shape when a join misses.** When a lookup or join against
   an external API returns zero rows or an unexpected count, emit a
   cheap, always-on warning with the *shape* of what came back: top-
   level keys or block names, row counts per block, and the keys of the
   first row (never values — they may be personal data or secrets).
   Most "it returns nothing" bugs are a renamed field or an extra
   envelope level, and the shape log turns a long investigation into a
   glance.
4. **Don't send parameters you haven't verified.** Some servers
   validate optional parameters strictly — an unknown `sortKey` or
   filter name returns `400` for the whole request instead of being
   ignored. Send only parameters confirmed against the docs or a
   captured response for *that* server version; when in doubt, fetch
   unsorted pages and sort client-side.
5. **Paginate defensively.** Loop until the API signals the end (empty
   page, no `next` link, cursor absent), with a **hard row or page cap**
   so a server that ignores your page parameter cannot spin the loop
   forever. Log when the cap is hit.
6. **Time out, retry selectively, back off.** Every outbound call has a
   timeout; retry only idempotent requests and only on transient
   failures (`429`, `502`–`504`, network errors), honouring
   `Retry-After`, with jittered exponential back-off and a retry
   budget.
7. **Record what you observed.** Keep a captured sample response
   (scrubbed) next to the adapter and a contract test against it, so a
   silent upstream change fails a test instead of a user.

## Local multi-tenant / subdomain development

- Use **`*.localhost`** (for example `tenant-a.localhost:5173`) for
  subdomain-per-tenant work. RFC 6761 reserves `localhost` and its
  subdomains for loopback; current browsers resolve them without DNS.
- Avoid public wildcard-DNS helper domains (names that resolve every
  subdomain to `127.0.0.1` via public DNS): filtered or corporate DNS
  often blocks them, giving `ERR_NAME_NOT_RESOLVED` on some machines
  only.
- Non-browser clients may not special-case `*.localhost` (the OS
  resolver on Windows does not, and curl treats bare `localhost` as
  loopback but subdomain handling varies by version — verify). Use
  `curl --resolve tenant-a.localhost:5173:127.0.0.1 ...` or send an
  explicit `Host:` header to `127.0.0.1`.
- Cookies: a cookie set for one `*.localhost` subdomain is not sent to
  another unless you scope it deliberately; test tenant isolation the
  same way production will see it.

## Router and app-construction traps

- **Hono:** routes must all be registered before the first request is
  matched. Hono's default `SmartRouter` (and `RegExpRouter`) build the
  matcher on first match and then throw `Can not add a route since the
  matcher is already built.` on any later `app.get(...)`. This bites
  tests that share one module-level `app` and add routes per test, and
  code that registers routes lazily. Export a `createApp()` factory
  that builds a fresh app with all routes, and call it per test.
- The general rule for any framework: build the app in a factory (no
  module-level singletons holding mutable state), so tests get
  isolation and route registration has one obvious place.
