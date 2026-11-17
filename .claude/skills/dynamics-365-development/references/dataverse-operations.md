# Dataverse Operations

Distilled from Microsoft's official dataverse-skills plugin — the rules
that keep agents on-rails when querying and shaping Dataverse.

## Tool Hierarchy

**MCP tools (if connected) → official SDK → raw Web API — in that
order.** Improvised raw HTTP for operations the SDK supports is the #1
off-rails failure. Raw Web API is legitimately needed only for the gaps:
forms, views, global option sets, N:N `$ref`/`$expand`, `$apply`
aggregation, and unbound actions.

Auth is always the documented pattern (`pac auth create`, environment
service-principal config) — never parsed token caches, hand-rolled MSAL
flows, or hardcoded tokens.

## Casing — the 400-error generator

| Context | Casing |
|---|---|
| `$select`, `$filter`, `$orderby` | lowercase logical names (`contoso_name`) |
| `$expand`, `@odata.bind` | **case-sensitive Schema/Navigation names** (`contoso_AccountId@odata.bind`) |

`/* wrong */ "contoso_accountid@odata.bind"` silently 400s. When unsure,
check `$metadata` — don't guess.

## Querying

```http
GET [org]/api/data/v9.2/accounts?$select=name,creditlimit
    &$filter=statecode eq 0 and contains(name,'contoso')
    &$orderby=name&$top=50
```

- Always `$select` — unselected queries drag every column and memo over
  the wire (and through API limits).
- Aggregation: single-table → `$apply` server-side; never pull all
  records to aggregate client-side.
- Paging via `@odata.nextLink` / `Prefer: odata.maxpagesize` — iterate,
  don't `$top=5000` and hope.
- FetchXML remains first-class (views, reports, complex link-entity
  queries); OData for app code; pick one per query, not hybrids.
- Lookups format as `_<name>_value` in results; expand for related
  columns rather than N+1 retrieves. The `_x_value` property (and its
  formatted-value/lookup-logical-name annotations) only comes back when it
  is in `$select` — a missing key means "not selected", not "null".
  Null-filter on it: `$filter=_contoso_accountid_value eq null`.
- **URL-encode string literals in `$filter`.** `&`, `#`, `+`, `%`, `/`,
  `?` and non-ASCII characters in a value break the query (400, or worse a
  silent "not found" that makes a find-or-create script create a
  duplicate). Percent-encode the value and double embedded single quotes
  (`'O''Brien'`). Every lookup-by-name helper needs this; test it with a
  name like `R&D + Ops #2`.
- **Choice values are integers** (`100000000`, or the publisher's option
  value prefix + index), not labels. Type choice columns and field names
  from the deployed schema (`$metadata`, `EntityDefinitions`), never from
  contract prose or a design doc.
- Sweeping `EntityDefinitions` by publisher prefix also returns N:N
  intersect tables. Add `IsIntersect` to `$select` and filter on it.

## Lookups (write side)

| Goal | Do | Not |
|---|---|---|
| Set a lookup | `"contoso_AccountId@odata.bind": "/accounts(<guid>)"` (navigation-property casing) | `"_contoso_accountid_value": "<guid>"` — read-only, 400s |
| Clear a lookup | `DELETE .../contoso_projects(<id>)/contoso_AccountId/$ref`, or PATCH `{"contoso_AccountId": null}` (no annotation) | PATCH `"contoso_AccountId@odata.bind": null` — Learn shows it, but it has been seen not to clear (verify) |
| Find the nav-property name | `RelationshipDefinitions` (`ReferencingEntityNavigationPropertyName`) or `$metadata` | guessing from the column's logical name |

An omitted lookup is a silent no-op, not an error. In-memory test
doubles of the Web API should reject `_*_value` keys on writes, so a
wrong payload fails in tests instead of in the environment.

Autonumber columns: let the platform generate the value — don't send one
in data writes.

## Data Operations

- Bulk writes via the SDK's batch-capable operations (e.g.
  `CreateMultiple`/`UpdateMultiple` family) — not record-at-a-time loops,
  and (from app code) not raw per-record POSTs. *(Inside synchronous
  plug-ins the opposite holds: no batch or bulk request types — issue
  individual requests; see plugins.md, "Transactions".)*
- Respect **service protection limits** (429s with `Retry-After`): honour
  the header, back off, and design imports to stay under entitlement.
- `Upsert` for integration-style idempotent writes keyed on alternate
  keys; define alternate keys for any external-system correlation.
  Creating a key starts an async index build: wait until the key's
  `EntityKeyIndexStatus` is `Active` before relying on it (`Failed` means
  existing rows violate uniqueness).
- Deleting a parent in a default (Referential) relationship **removes the
  link** — children survive with an empty lookup. Choose the cascade
  behaviour deliberately when the relationship is created.

## Metadata

- Tables/columns/relationships created programmatically follow the same
  publisher-prefix discipline (below) and land in an explicit solution —
  use the `MSCRM.SolutionName` header on Web API metadata creates, then
  **verify** (`pac solution list-components`): a typo'd header silently
  dumps components into the Default solution.
- Choice columns: prefer global option sets for reused choice lists.
  Bind a picklist to a global set by MetadataId:
  `"GlobalOptionSet@odata.bind": "/GlobalOptionSetDefinitions(<guid>)"`.
  Learn says the `Name='...'` alternate key works too, but it has
  returned a 500 ("Guid string should only contain hexadecimal
  characters") — resolve the GUID first (verify on your environment).
- Schema changes are forever-ish — renames don't change logical names;
  design names before creating.

### Updating metadata: PUT, never PATCH

Table, column and relationship definitions **cannot be PATCHed** (405).
The documented update is `PUT` of the **entire** retrieved definition with
your changes applied, plus the `MSCRM.MergeLabels: true` header — without
it the default is `false` and every label in other languages is deleted.
Then publish (`PublishXml`). In practice:

1. `GET` the definition (cast to the subtype, e.g.
   `.../Attributes(LogicalName='x')/Microsoft.Dynamics.CRM.StringAttributeMetadata`).
2. Change the properties; `PUT` it back with `MSCRM.MergeLabels: true`.
3. Options of a choice column are a separate message (`UpdateOptionValue`,
   `InsertOptionValue`), not part of the attribute PUT.

- Set table flags such as `IsAuditEnabled` and `ChangeTrackingEnabled` in
  the create `POST` — cheapest place. Changing them later means the full
  PUT (or the maker portal / solution import), not a PATCH.
- Converting an existing text column to autonumber: set `AutoNumberFormat`
  through a full update (SDK `UpdateAttributeRequest` or the maker UI). If
  that fights you, create a fresh autonumber column instead.

### Bursts, publishing and retries

Metadata writes, publishes and solution operations queue behind each
other in the environment. A script that creates many components and calls
"publish all" after each one hits: `0x80071151` (SolutionConcurrencyFailure
— another solution operation running), 429 service-protection throttling,
503 timeouts, and 400s on lookups to a table created seconds ago (metadata
cache lag). Rules:

- **Publish once at the end** (or per table), not per component.
- Retry transient failures (429 honouring `Retry-After`, 503,
  `0x80071151`) with backoff; make every step idempotent
  (find-then-create) so the whole run can simply be re-run.
- When the next call must see a definition you changed seconds ago, send
  `Consistency: Strong` on that request (small cost; don't use it
  everywhere).

### Tokens for scripted Web API calls

`az account get-access-token --resource <org-url>` tokens expire after
roughly an hour. A long migration that caches one token for the process
lifetime starts failing with 401 mid-run. Re-mint on 401 and retry once
(the azure-development skill has the general pattern).

## Publisher Prefix Discipline

Never `new_`. Discovery flow before creating anything:

1. Query existing publishers (exclude Microsoft defaults).
2. Show them and **ask which to use** (or confirm creating one — 2–8
   lowercase chars, meaningful to the org).
3. The prefix is permanent on every component created with it; one
   publisher serves many solutions; never mix prefixes in a solution.

## Environment Safety (restating because it's the big one)

`pac org who` + explicit user confirmation of the target URL before the
first mutating operation of a session. PAC profile state, `.env`
contents, and memory of previous sessions are all unreliable indicators
of *current intent*.
