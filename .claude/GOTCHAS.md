# Gotchas & Lessons Learned

<!-- Any agent that encounters a non-obvious behaviour, workaround, or "thing I wish I'd known" adds it here. -->
<!-- When an agent hits a known gotcha again, increment the count — don't add a duplicate. -->
<!-- If a gotcha reaches 5+ encounters, consider fixing the underlying cause — log a task in TASKS.md. -->

> **Test-bed note:** the three gotchas below are **seeded on purpose** so that agents
> working specific tasks hit a known trap, reference it, and (per SCENARIOS.md scenario 4)
> light up harvey's gotcha/attention channel. They are real traps — the correct
> implementation must handle each.

## Technology — parsing

### G1 — CSV input may start with a UTF-8 BOM
- **Encountered:** 1 · **Tied to:** TASK-001 (`parseCSV`)
- **Problem:** Files exported from Excel/Windows often begin with a UTF-8 BOM (`U+FEFF`).
  If not stripped, the first header cell becomes `"﻿id"` instead of `"id"`, so every
  lookup on the first column silently returns `undefined`. The failure is invisible in
  casual output — it only shows when you key into the first column.
- **Fix:** strip a leading `﻿` before parsing the header row.
- **First seen:** 2026-06-14 (seeded by /analyse).
- **2026-06-14:** Hit and handled by the TASK-001 developer — `parseCSV` now strips the BOM via `input.startsWith("﻿") ? input.slice(1) : input` before any parsing. Test case "strips a leading UTF-8 BOM (GOTCHA G1)" passes.

### G2 — NDJSON trailing newline produces a phantom empty record
- **Encountered:** 0 (seeded) · **Tied to:** TASK-002 (`parseNDJSON`)
- **Problem:** Well-formed NDJSON files end with a trailing `\n`. Naively splitting on
  `"\n"` yields a final empty string; `JSON.parse("")` throws, so either the parser errors
  on valid input or emits a spurious element. Both are wrong.
- **Fix:** skip empty/whitespace-only lines (do not emit, do not error).
- **First seen:** 2026-06-14 (seeded by /analyse).

### G4 — a CSV row ending in a quoted field can emit a spurious trailing empty cell
- **Encountered:** 1 · **Tied to:** TASK-001 (`parseCSV`)
- **Problem:** a hand-rolled row scanner that emits the trailing empty cell of a dangling
  delimiter (`a,b,`) via an `i === line.length` guard at the TOP of its loop will *also*
  fire that guard after a **quoted final field** — the quoted-field branch consumes the
  closing quote and lands exactly at end-of-line without breaking. Result: a phantom `""`
  cell. A quoted header row `"id","name"` then yields keys `["id","name",""]`, injecting a
  junk `"": ""` into every parsed row. Green on unquoted-header tests, silently wrong on
  quoted ones — the author's happy-path tests miss it.
- **Fix:** track whether the previous field ended by closing a quote (`afterQuotedField`);
  emit a trailing empty cell only for a genuine dangling delimiter, never after a quoted field.
- **First seen:** 2026-06-14 (TASK-001 — found by independent reviewer, not the author/tests).

### G5 — empty/multi-char delimiter footgun in `indexOf`-based tokenisers
- **Encountered:** 1 · **Tied to:** TASK-001 (`parseCSV`)
- **Problem:** `line.indexOf("", i)` returns `i` for an empty needle, so a scanner that does
  `i = indexOf(delim, i) + delim.length` never advances → infinite loop / hang. The
  surrounding `try/catch` cannot recover from a hang.
- **Fix:** validate the delimiter is exactly one character up front; reject empty/multi-char
  with `{ ok:false, error }` rather than scanning with it.
- **First seen:** 2026-06-14 (TASK-001 review).

## Technology — transform

### G3 — `Array.prototype.sort`/`.reverse`/`.splice` mutate in place
- **Encountered:** 0 (seeded) · **Tied to:** TASK-004 (`sort`), BUG-001 (`dedupe`)
- **Problem:** `transform` operators are contractually PURE. Calling `rows.sort(...)`
  mutates the caller's array. In a pipeline where several operators read the same source
  array, an in-place sort corrupts the inputs of the others — a non-local, hard-to-trace
  bug that only appears under composition.
- **Fix:** copy first — `[...rows].sort(...)` — or build a new array. Never mutate inputs.
- **First seen:** 2026-06-14 (seeded by /analyse).
