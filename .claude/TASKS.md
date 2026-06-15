# Task Board

Last updated: 2026-06-14 (orchestrator demo run) — TASK-001 driven to Done through the full
lifecycle; TASK-007 escalated and its contested contract resolved (D5). Originally created
2026-06-14 by architect (/analyse). Most feature tasks remain unimplemented stubs by design;
this board is the fuel harvey burns. **To re-arm the seeded scenarios, `git checkout -- .`**

> **Test-bed note:** these tasks exist to be *watched* being worked, not to ship a
> product. Sizing, dependencies, and the one contested task are tuned for harvey's
> panels. Map of demo-prompt → expected harvey behavior lives in `SCENARIOS.md`.
> Contracts: `.claude/ECOSYSTEM.md`. Traps: `.claude/GOTCHAS.md`.

---

## Feature Lane

<!-- Full lifecycle: Todo → In Progress → Ready for Review → In Review → Ready for Test → Testing → Done -->

### In Progress

_(none — claim from Todo)_

### Ready for Review

### Ready for Test

### Todo (Priority Order)

> Independence map (for the orchestrator): **TASK-001, 002, 003, 004, 005, 006 have no
> dependencies on each other** (they share only `contract:shared-types`, already in
> `src/types.ts`) → up to **6 can run in parallel**. TASK-007 needs 005+006. TASK-008
> needs 001+004+005. TASK-009 needs everything.

#### TASK-002 — parse: NDJSON parser  [P2]
- **Contract:** `contract:parse` (status:stable) · **File:** `01_Project/src/parse/parseNDJSON.ts`
- **Test:** `tests/parse/parseNDJSON.test.ts` (red) · **Gotcha:** G2 (trailing newline)
- **Scenario:** 4 (gotcha encounter).

#### TASK-003 — validate: schema validation  [P2]
- **Contract:** `contract:validate` (status:stable) · **File:** `01_Project/src/validate/validate.ts`
- **Test:** `tests/validate/validate.test.ts` (red). Must collect EVERY failing field.

#### TASK-004 — transform: implement the operators (FAN-OUT)  [P1]
- **Contract:** `contract:transform` (status:stable) · **Files:** `01_Project/src/transform/{map,filter,reduce,sort,flatten,groupBy,window}.ts` (7 stubs)
- **Test:** `tests/transform/operators.test.ts` (red) · **Gotcha:** G3 (operators must be pure)
- **Scenario:** 2 (parallel fan-out / stress). Each operator is independent — split across
  as many developer agents as available. `dedupe` is excluded here (it ships buggy — see BUG-001).

#### TASK-005 — format: table formatter  [P2]
- **Contract:** `contract:format` (status:stable) · **File:** `01_Project/src/format/formatTable.ts`
- **Test:** `tests/format/formatTable.test.ts` (red). `formatJSON` is already done; `formatCSV`
  ships buggy (BUG-002). Needed before TASK-007.

#### TASK-006 — pipeline: composition engine  [P1]
- **Contract:** `contract:pipeline` (status:stable) · **File:** `01_Project/src/pipeline/pipeline.ts`
- **Test:** `tests/pipeline/pipeline.test.ts` (red). Implement `compose` + `tabulate`
  (the column-ordering guarantee). Needed before TASK-007.

#### TASK-007 — pipeline → table formatter wiring  ✅ CONTRACT RESOLVED (D5)  [P1]
- **Contract:** `contract:pipeline-format` (**status:stable** — resolved via D5) · **File:** `01_Project/src/pipeline/formatStage.ts`
- **Test:** `tests/pipeline/formatStage.test.ts` (`it.todo`) · **Depends on:** TASK-005, TASK-006
- **Scenario:** 3 (contract mismatch / escalation) — **exercised this session.** The developer
  hit the conflict (pipeline wants `Stage<Table,string>`; format promised `formatTable(rows: Row[])`),
  STOPped, and escalated. The architect resolved it (D5): widened `contract:format` to
  `formatTable(table: Table)`. **No implementation written** (still a stub — needs TASK-005/006).
  Note: this disarms scenario 3 for replay — `git checkout -- .` restores the contested baseline.

#### TASK-008 — cli: runner  [P3]
- **Contract:** `contract:cli` (status:stable) · **File:** `01_Project/src/cli/index.ts`
- **Test:** `tests/cli/cli.test.ts` (red) · **Depends on:** TASK-001, TASK-004, TASK-005.

#### TASK-009 — green suite + throughput  (LONG-RUNNING)  [P3]
- **File:** runs `01_Project` — `npm test` · **Depends on:** all of the above.
- **Scenario:** 5 (long-running stream). Run the full suite (includes the intentionally
  slow `tests/pipeline/throughput.slow.test.ts`), triage failures, drive them green.

### Blocked

_(none — TASK-007's contested contract was resolved this session via D5; it is now unblocked
but still depends on TASK-005 + TASK-006 before it can be implemented.)_

### Done

<!-- When Done exceeds ~20 items, move older entries to .claude/framework/docs/archives/tasks-archive.md -->

#### TASK-001 — parse: CSV parser  [P1] ✅ Done (2026-06-14)
- **File:** `01_Project/src/parse/parseCSV.ts` · **Test:** `tests/parse/parseCSV.test.ts` (10/10 green) · `tsc --noEmit` clean.
- **Lifecycle:** developer implemented → independent reviewer returned REQUEST-CHANGES (found
  G4 quoted-final-field corruption + G5 empty-delimiter hang, both confirmed) → developer fixed
  (`afterQuotedField` flag; delimiter validated) + added 7 regression tests → re-verified green.
- **Gotchas:** G1 (BOM) handled; **G4 & G5 newly logged** from review. **Commit:** _(uncommitted — demo run)_.

---

## Bug-Fix Lane

<!-- Short lifecycle for defects: Reported → Fixing → Verify → Done -->
<!-- Severity: P0 (blocking) | P1 (major) | P2 (minor) | P3 (cosmetic) -->

### Fixing

### Verify

### Reported

#### [BUG-001] `dedupe` drops the last element
- **Severity:** P2 · **Module:** transform · **File:** `01_Project/src/transform/dedupe.ts`
- **Source:** seeded for the bug-fix-lane demo (SCENARIOS.md scenario 6).
- **Symptom:** loop bound `i < rows.length - 1` stops one short; the final row is always omitted.
- **Expected:** keep all unique rows in first-seen order. **Verify:** `tests/transform/dedupe.test.ts` goes green.

#### [BUG-002] `formatCSV` does not quote special characters
- **Severity:** P2 · **Module:** format · **File:** `01_Project/src/format/formatCSV.ts`
- **Source:** seeded.
- **Symptom:** a cell containing a comma, double-quote, or newline is written raw, splitting
  the row and corrupting output (e.g. `a,b` becomes two columns).
- **Expected:** RFC 4180 quoting (wrap in `"`, double inner `"`). **Verify:** `tests/format/formatCSV.test.ts`.

#### [BUG-003] `parseJSON` accepts empty input as a valid document
- **Severity:** P3 · **Module:** parse · **File:** `01_Project/src/parse/parseJSON.ts`
- **Source:** seeded.
- **Symptom:** empty/whitespace-only input returns `{ ok:true, value:undefined }` instead of
  an error, so "nothing" flows downstream as a valid document.
- **Expected:** `{ ok:false }` on empty input. **Verify:** the empty-input case in `tests/parse/parseJSON.test.ts`.

### Done
