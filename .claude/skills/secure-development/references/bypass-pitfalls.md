# Defences That Look Right But Aren't

A catalogue of plausible-looking controls that were bypassed in real
reviews. Use it when reviewing a validator, a path/URL check, a
"sandbox", or an access-control boundary: each entry names the trap and
the shape of the fix. Generalise — the examples are fictional.

## Deny-list validators (CSS, HTML, URLs, file names)

A deny-list validator for a rich grammar will be bypassed; one
user-supplied CSS-value validator fell seven different ways:

- **Escape-sequence injection** — `\f` (form feed) is a newline in
  CSS, so it can terminate a string the validator thought was closed.
  CSS also accepts hex escapes (`\75rl(` is `url(`).
- **Encoding layers** — base64 `data:` SVG payloads; a percent-decode
  step that *fails open* on malformed input (decode error → value
  passed through unchecked).
- **Unit and number forms** — `1e3px`, `10in`, `calc()` defeat a
  "max 200px" regex; parse the number and unit, then compare.
- **Fallback channels** — `var(--x, <fallback>)`: the fallback is
  arbitrary content and must be validated as well.
- **Unbalanced brackets** — a stray `(` or quote swallows the rest of
  the declaration or rule.

Fix: an **allow-list grammar** (permitted properties, units and
functions), one shared bracket/quote balance check and one shared unit
parser used by every validator, validated `var()` fallbacks, and
fail-closed decoding. Treat "add another deny rule" as a smell.

## Windows paths

- **Mixed-separator UNC** — `\/host/share` and `/\host\share` are UNC
  paths to Windows but pass `starts_with("\\\\")` checks. Resolving a
  UNC path can send the user's NTLM credentials to the remote host.
  Decide from the parsed path, not the string: in Rust, walk
  `Path::components()` and accept only a `Prefix::Disk` prefix
  (reject `UNC`, `VerbatimUNC`, `DeviceNS`, `Verbatim*` unless you
  mean to support them). Other languages: use the platform's path
  parser, then check the root type.
- **BatBadBut** (CVE-2024-24576 and siblings across languages) — on
  Windows, arguments passed to a `.bat`/`.cmd` file are re-parsed by
  `cmd.exe`, so argv-array quoting does not protect you. Never pass
  user-controlled strings as arguments to batch shims (this includes
  `npm.cmd`, `npx.cmd` and similar wrappers); call the real
  executable or pass data via a file or stdin.
- Canonicalise (resolve `..`, symlinks, junctions, 8.3 short names)
  *before* the containment check, and check against the canonical
  root.

## URL and origin checks

- **Loopback regexes** must anchor the host and stop at `[/?#]` after
  the optional port. `^http://localhost:5173` also matches
  `http://localhost:5173@evil.example/` — everything before `@` is
  userinfo and the host is `evil.example`.
- After any regex pre-filter, **re-parse with a real URL parser**
  (WHATWG `URL`, `urllib.parse`, `System.Uri`) and compare `hostname`
  and `port` exactly; reject userinfo outright.
- Compare origins as (scheme, host, port) tuples, never by substring
  or `startsWith`.

## Constant-time comparison

Constant-time helpers usually short-circuit on **length mismatch** (the
Rust `subtle` crate's slice `ct_eq` documents this). That leaks the
length, which is fine for fixed-length MACs and digests but not for
variable-length secrets. Compare fixed-length digests (HMAC the input
first) rather than raw variable-length tokens.

## Sandbox illusions

- `exec(code, {"__builtins__": {}})` in Python is **not a sandbox**:
  `().__class__.__base__.__subclasses__()` walks back to `os` and
  friends. The same goes for `vm` in Node.js (documented as not a
  security mechanism) and regex-based "safe eval". Treat such code as
  trusted-authors-only, or isolate it in a separate process/container
  with no credentials, or use a purpose-built restricted interpreter
  and still assume escapes exist.
- Browser-automation origin allow-lists are not a boundary either:
  Playwright MCP's `--allowed-origins` / `--blocked-origins` are
  documented as "not a security boundary" and do not affect redirects.

## Access-control boundaries

- **Serverless rate limiting** — in-memory, per-instance counters are
  ineffective on serverless/edge platforms (each instance or isolate
  has its own memory and instances come and go). Use a durable shared
  store (database row, KV with care, a platform rate-limit binding) or
  the platform's WAF/rate-limit product.
- **Privileged database clients bypass row-level security** — a route
  that uses a service-role or admin connection (Supabase
  `service_role`, a database owner, a superuser) skips RLS entirely,
  so the app-layer membership check is the *only* boundary. Every such
  route needs an explicit object-level check (IDOR), and RLS policies
  give no protection there.
- **Identity from a client-settable header** — if the server trusts a
  header that front-end JavaScript sets (`X-User-Id`, a token copied
  out of storage), the httpOnly session cookie is decorative. Derive
  identity server-side from the cookie or verified token only; strip
  identity headers at the edge.
- **Query parameters** — clamp and allow-list every search/sort/page
  parameter (numeric bounds, enum sort keys, maximum page size), and
  escape `LIKE`/`ILIKE` wildcards (`%`, `_` and the escape character)
  when user text is meant literally.

## Review heuristic

For every control, ask: *what parser does the attacker's input meet
after mine?* (the CSS engine, `cmd.exe`, the URL resolver, the OS path
API, the database role). If the control does not use that same parser,
or a strict subset of it, assume it can be bypassed.
