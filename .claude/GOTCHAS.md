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
- **Encountered:** 0 (seeded) · **Tied to:** TASK-001 (`parseCSV`)
- **Problem:** Files exported from Excel/Windows often begin with a UTF-8 BOM (`U+FEFF`).
  If not stripped, the first header cell becomes `"﻿id"` instead of `"id"`, so every
  lookup on the first column silently returns `undefined`. The failure is invisible in
  casual output — it only shows when you key into the first column.
- **Fix:** strip a leading `﻿` before parsing the header row.
- **First seen:** 2026-06-14 (seeded by /analyse).

### G2 — NDJSON trailing newline produces a phantom empty record
- **Encountered:** 0 (seeded) · **Tied to:** TASK-002 (`parseNDJSON`)
- **Problem:** Well-formed NDJSON files end with a trailing `\n`. Naively splitting on
  `"\n"` yields a final empty string; `JSON.parse("")` throws, so either the parser errors
  on valid input or emits a spurious element. Both are wrong.
- **Fix:** skip empty/whitespace-only lines (do not emit, do not error).
- **First seen:** 2026-06-14 (seeded by /analyse).

## Technology — transform

### G3 — `Array.prototype.sort`/`.reverse`/`.splice` mutate in place
- **Encountered:** 0 (seeded) · **Tied to:** TASK-004 (`sort`), BUG-001 (`dedupe`)
- **Problem:** `transform` operators are contractually PURE. Calling `rows.sort(...)`
  mutates the caller's array. In a pipeline where several operators read the same source
  array, an in-place sort corrupts the inputs of the others — a non-local, hard-to-trace
  bug that only appears under composition.
- **Fix:** copy first — `[...rows].sort(...)` — or build a new array. Never mutate inputs.
- **First seen:** 2026-06-14 (seeded by /analyse).
