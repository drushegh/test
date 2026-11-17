# SQLite and PostgreSQL application gotchas

Traps that come up in application code (ORMs, connection pools,
Supabase/PostgREST clients, embedded SQLite) rather than in DBA work.
SQLite is outside this skill's main two-platform scope, but it is the
engine behind desktop apps, test databases and edge databases such as
Cloudflare D1 (D1 mechanics → `cloudflare-workers-development`), so its
sharp edges are collected here.

## SQLite

### PRAGMAs are per-connection

- `PRAGMA foreign_keys = ON` applies only to the connection that ran it,
  and it is a **no-op inside a transaction**. Putting it in a migration
  file (which most runners wrap in a transaction) does nothing for the
  pooled connections your app uses later — foreign keys stay
  unenforced. Set it in the pool's per-connection initialisation hook
  (`afterCreate`, `on_connect`, connection-string option) and assert it
  in a test (`PRAGMA foreign_keys;` returns `1`).
- `PRAGMA journal_mode = WAL` cannot be changed while a transaction is
  open, so it also fails inside a transactional migration. WAL mode is
  persistent (stored in the database file), so set it once at startup or
  in connection init, outside any transaction. `busy_timeout`,
  `synchronous` and `cache_size` are per-connection like `foreign_keys`.

### Uniqueness and upserts

- **Enforce uniqueness with a `UNIQUE` index, not SELECT-then-INSERT.**
  Check-then-insert races under any concurrency (two requests both see
  "absent" and both insert). Declare the unique index and let the
  database arbitrate.
- Prefer `INSERT ... ON CONFLICT (col) DO NOTHING` (targets one
  constraint) to `INSERT OR IGNORE`, which also silently swallows
  `NOT NULL`, `CHECK` and primary-key violations — real bugs disappear.
- `INSERT ... ON CONFLICT DO UPDATE` **updates the existing row and
  keeps its original primary key/rowid.** Don't use
  `last_insert_rowid()` (or a driver's `lastID`) to find the row after an
  upsert; use `RETURNING id` (SQLite 3.35+) or re-read by the natural
  key you conflicted on.

### Conditional writes

A state gate ("only approve if status is `pending`") belongs **in the
write itself** (`UPDATE ... WHERE id = ? AND status = 'pending'`), with
the affected-row count checked, and the same predicate applied when
reading the result back. A check in application code before the write
is a race; a gate on the write but not on the read-back reports success
for rows another request changed.

### Aggregates and bare columns

SQLite accepts bare (non-aggregated, non-grouped) columns in a `GROUP
BY` query. With exactly one `min()` or `max()` aggregate, the bare
columns come from the row holding that extreme; with any other
aggregate their values are arbitrary. Other engines reject the query.
Don't rely on it in portable code — use a window function
(`ROW_NUMBER() OVER (PARTITION BY ... ORDER BY ... DESC)`) or a join
back to the aggregate.

## PostgreSQL / Supabase

### Case- and accent-insensitive matching

- `ILIKE` is case-insensitive but **not accent-insensitive**: searching
  `Sean` does not match `Seán`, and a slug lookup for a name with a fada
  or umlaut 404s. Options:
  - the `unaccent` extension: `WHERE unaccent(name) ILIKE unaccent($1)`.
    To index it, wrap `unaccent` in an `IMMUTABLE` SQL function (the
    built-in is only `STABLE`) and build an expression index on that
    wrapper;
  - a stored, generated search/slug column computed once (NFD-normalise,
    strip combining marks, lower-case, normalise hyphens and spaces) and
    indexed;
  - a nondeterministic ICU collation for equality comparisons (not
    usable with `LIKE` patterns on older versions — verify for your PG
    version).
- Generate slugs with the same NFD transliteration on the application
  side and in the database, or lookups drift apart.
- Escape `%`, `_` and the escape character in user text passed to
  `LIKE`/`ILIKE` when it is meant literally.

### PostgREST / Supabase JS filters

- There is no `NOT IN (subquery)` through the PostgREST filter API; fetch
  the ids first, use an RPC (SQL function), or a view.
- The list form is a raw PostgREST string:
  `.not('id', 'in', '(id1,id2)')` with bare values inside the
  parentheses — no quotes around UUIDs and no spaces. Build it from
  validated ids only; never interpolate user text into the filter
  string.
- A query made with the service-role key bypasses RLS entirely (see
  `secure-development`, `references/bypass-pitfalls.md`).
