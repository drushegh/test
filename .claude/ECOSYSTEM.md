# Project Ecosystem — Source of Truth

<!-- Contracts are the shared interface agreements between agents. -->
<!-- Every task in TASKS.md references its relevant contract by ID (e.g., "Contract: contract:parse"). -->
<!-- When this file exceeds ~300 lines, split into per-module files in .claude/framework/agent_docs/contracts/ -->

<!-- CONTRACT FORMAT:
     Anchor:  contract:IDENTIFIER status:draft|stable   (in an HTML comment before the fenced block)
     - status:draft  = design in progress / contested, NOT ready for implementation.
                       The developer agent will REFUSE to implement against a draft contract.
     - status:stable = reviewed and confirmed, safe to implement against.
     The machine-readable block is the ENFORCEABLE spec; prose is context. If they conflict,
     update both — but the code block is what agents validate against.
-->

> **PROJECT PURPOSE — READ FIRST.** This codebase (`datakit`, a typed data-transform
> toolkit) is a **test bed for harvey**, a live supervisor for multi-agent Claude Code
> workflows. The product is a *vehicle*: the real deliverable is a backlog that, when
> worked by role agents (orchestrator → architect → developer → tester → reviewer),
> emits a rich, repeatable, observable stream of agent activity. Contracts below are
> intentionally designed so that working them exercises harvey's panels — including
> **one deliberately contested contract** (`contract:pipeline-format`) designed to force a
> STOP-and-escalate. (It was escalated and **resolved via D5** this session — now
> `status:stable`; restore the seeded baseline with `git checkout` to re-arm scenario 3.)
> See `SCENARIOS.md` for the demo-prompt → expected-behavior map.

---

## Shared Types

The vocabulary every module shares. Stable — implement against freely.

<!-- contract:shared-types status:stable -->

```typescript
// A single record. Heterogeneous string-keyed cells; values are JSON scalars/containers.
export type Cell = string | number | boolean | null;
export type Row = Record<string, Cell>;

// Discriminated result for fallible operations (parse, validate). No exceptions across
// module boundaries — callers branch on `ok`.
export type Result<T> =
  | { ok: true; value: T }
  | { ok: false; error: string };

// A pipeline stage: a named, PURE, synchronous transform from I to O.
// `name` is what harvey shows on the topology edge; keep it stable and human-readable.
export interface Stage<I, O> {
  readonly name: string;
  run(input: I): O;
}

// A column-ordered table envelope. `columns` fixes display/serialization order across
// heterogeneous rows; `rows` may omit columns (treated as null) or carry extras (ignored
// for ordering). Produced by the pipeline's tabulate step.
export interface Table {
  columns: string[];
  rows: Row[];
}
```

---

## parse/ — string → structured data

Owner: `parse` module. Three independent parsers; each returns `Result` (never throws on
malformed input). Pure, synchronous, no I/O.

- `parseCSV` — RFC 4180-ish. First row is the header. Must **strip a leading UTF-8 BOM**
  (see GOTCHA G1). Quoted fields may contain commas and escaped quotes (`""`).
- `parseJSON` — single JSON document → `unknown`. Empty input is an **error**, not `null`
  (see BUG-003).
- `parseNDJSON` — one JSON value per line. A **trailing newline must not** produce a
  phantom empty record (see GOTCHA G2).

<!-- contract:parse status:stable -->

```typescript
export interface CsvOptions {
  delimiter?: string; // default ","
}

// Header row becomes object keys. All cell values are strings (no type coercion here).
export function parseCSV(input: string, opts?: CsvOptions): Result<Row[]>;

// Parses exactly one JSON document. Empty/whitespace-only input => { ok:false }.
export function parseJSON(input: string): Result<unknown>;

// One JSON value per non-empty line. Trailing newline is ignored, not an empty element.
export function parseNDJSON(input: string): Result<unknown[]>;
```

---

## validate/ — runtime schema validation

Owner: `validate` module. A tiny, dependency-free schema validator over `Row`/`unknown`.
Pure, synchronous. Returns every failing field (not just the first).

<!-- contract:validate status:stable -->

```typescript
export type FieldType = "string" | "number" | "boolean" | "null";

export interface FieldSchema {
  type: FieldType;
  required?: boolean; // default true
}

export type Schema = Record<string, FieldSchema>;

export interface ValidationIssue {
  field: string;
  message: string;
}

// ok:true with the typed value, or ok:false with a flat list of issues.
export function validate(value: unknown, schema: Schema): Result<Row> & {
  issues?: ValidationIssue[];
};
```

---

## transform/ — independent operators (FAN-OUT SURFACE)

Owner: `transform` module. Eight **independent** operators, each in its own file. This is
the parallelism surface — they share only `shared-types` and never each other. Every
operator is **pure**: it MUST NOT mutate its input (see GOTCHA G3 — `sort`/`dedupe`).

<!-- contract:transform status:stable -->

```typescript
export function map<I, O>(rows: I[], fn: (row: I, i: number) => O): O[];
export function filter<T>(rows: T[], pred: (row: T, i: number) => boolean): T[];
export function reduce<T, A>(rows: T[], fn: (acc: A, row: T) => A, init: A): A;

// Stable sort by a key selector; ascending. MUST NOT mutate `rows`.
export function sort<T>(rows: T[], key: (row: T) => Cell): T[];

// Remove duplicates by a key selector, keeping the FIRST occurrence and order.
// MUST NOT mutate `rows`. (Buggy reference impl ships for the bug-fix lane — BUG-001.)
export function dedupe<T>(rows: T[], key: (row: T) => Cell): T[];

// Flatten one level of nested arrays.
export function flatten<T>(rows: T[][]): T[];

// Group rows by a key selector into a Map (insertion order of first-seen keys).
export function groupBy<T>(rows: T[], key: (row: T) => string): Map<string, T[]>;

// Fixed-size contiguous windows. Drops a trailing partial window (length < size).
export function window<T>(rows: T[], size: number): T[][];
```

---

## format/ — structured data → string

Owner: `format` module. Three output formatters. Pure, synchronous.

> ✅ **RESOLVED (D5, 2026-06-14).** This module was one half of the formerly-contested
> `contract:pipeline-format`. The conflict — the pipeline needed a caller-supplied column
> order that `formatTable(rows: Row[])` could not receive — is resolved by **widening
> `formatTable` to accept a `Table`**: it uses `table.columns` for header/serialization
> order and `table.rows` for data. `Table` is an already-exported shared type, so this adds
> no new dependency and preserves the pipeline's column-ordering guarantee end-to-end.

<!-- contract:format status:stable -->

```typescript
import type { Table } from "../types";

// Renders a column-ordered table. Header/serialization order comes from `table.columns`;
// data comes from `table.rows`. Rows may omit columns (treated as null) or carry extras
// (ignored for ordering). This is the form the pipeline's terminal stage wires to (D5).
export function formatTable(table: Table): string;

// Pretty JSON (2-space indent).
export function formatJSON(value: unknown): string;

// RFC 4180 CSV. MUST quote fields containing the delimiter, quotes, or newlines
// (buggy reference impl ships for the bug-fix lane — BUG-002).
export function formatCSV(rows: Row[]): string;
```

---

## pipeline/ — typed composition engine

Owner: `pipeline` module. Composes `Stage<I,O>` values left-to-right with type-checked
chaining, plus a `tabulate` stage that produces the column-ordered `Table` envelope.

<!-- contract:pipeline status:stable -->

```typescript
import type { Stage, Row, Table } from "../types";

// Type-checked left-to-right composition. Output of stage N must equal input of N+1.
export function compose<A, B>(s1: Stage<A, B>): Stage<A, B>;
export function compose<A, B, C>(s1: Stage<A, B>, s2: Stage<B, C>): Stage<A, C>;
export function compose<A, B, C, D>(
  s1: Stage<A, B>, s2: Stage<B, C>, s3: Stage<C, D>,
): Stage<A, D>;

// Produces a Table with explicit, stable column ordering (union of keys, first-seen order).
// This is the pipeline's column-ordering GUARANTEE.
export function tabulate(columnsHint?: string[]): Stage<Row[], Table>;
```

### ✅ RESOLVED: pipeline → table formatter wiring (D5)

<!-- contract:pipeline-format status:stable -->

```typescript
// RESOLVED 2026-06-14 (DECISIONS.md D5, TASK-007, SCENARIOS.md scenario 3).
//
// The pipeline's terminal formatting stage is TYPED to receive a Table, because the
// pipeline guarantees stable column ordering (via `tabulate`) across heterogeneous rows:
import type { Stage, Table } from "../types";
export type TableFormatStage = Stage<Table, string>;   // pipeline terminal stage

// This stage is backed directly by the (now widened) format contract:
//     formatTable(table: Table): string      // see contract:format
// so it runs as:  { name: "format-table", run: (t: Table) => formatTable(t) }
//
// ┌─ RESOLUTION (Option A) ─────────────────────────────────────────────────────────┐
// │ `contract:format` was WIDENED so `formatTable` accepts a `Table` instead of       │
// │ `Row[]`: header/serialization order from `table.columns`, data from `table.rows`. │
// │   • `Table` is an already-exported shared type → no new dependency.               │
// │   • The pipeline's column-ordering guarantee is preserved END TO END:             │
// │     tabulate → Table (ordered columns) → formatTable(table) → string.             │
// │ Rejected: relaxing contract:pipeline to emit Row[] (drops the ordering guarantee, │
// │ demotes Table to a dead type); and a local adapter passing only table.rows        │
// │ (type-checks but discards columns → breaks the guarantee at runtime).             │
// │                                                                                    │
// │ This was the architect decision the draft status forced via STOP-and-escalate     │
// │ (scenario 3). The contract is now stable — safe to implement against.             │
// └────────────────────────────────────────────────────────────────────────────────┘
```

---

## cli/ — thin runner

Owner: `cli` module. Wires parse → transform → format from argv. No framework, no network.

<!-- contract:cli status:stable -->

```typescript
export interface CliResult {
  exitCode: number;
  stdout: string;
  stderr: string;
}

// Pure function over argv + stdin string (no process side effects — testable).
// e.g. run(["--from","csv","--to","json"], inputText)
export function run(argv: string[], stdin: string): CliResult;
```

---

## Module Boundaries & File Ownership

| Module | Owner Role | Files | Notes |
| ------ | ---------- | ----- | ----- |
| shared-types | architect | `01_Project/src/types.ts` | Foundation; changing it ripples everywhere — touch rarely. |
| parse | developer | `01_Project/src/parse/*` | 3 parsers, independent. Gotchas G1 (CSV BOM), G2 (NDJSON newline). BUG-003 (parseJSON empty). |
| validate | developer | `01_Project/src/validate/*` | Independent of all others. |
| transform | developer | `01_Project/src/transform/*` | 8 operators, fully independent — the fan-out surface. Gotcha G3 (purity). BUG-001 (dedupe). |
| format | developer | `01_Project/src/format/*` | 3 formatters. Half of the formerly-contested `pipeline-format` contract (resolved — D5). BUG-002 (formatCSV escaping). |
| pipeline | architect+developer | `01_Project/src/pipeline/*` | Composition engine. Owns the `pipeline-format` wiring (formerly contested; resolved — D5). |
| cli | developer | `01_Project/src/cli/*` | Thin; depends on parse/transform/format. Build last. |

## Design Tokens

(n/a — no UI in this product.)
