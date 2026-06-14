# SCENARIOS.md — harvey demo playbook for the `datakit` test bed

This is the operating manual for demoing **harvey** against this repo. Each scenario is a
prompt you give harvey's orchestrator, paired with the **exact behavior to watch** across
harvey's panels. The codebase (`01_Project/`, a typed data-transform toolkit) is
deliberately incomplete and seeded so that each prompt produces a **repeatable** observable
stream — same prompt → same behavior.

**Before you start:**
- `cd 01_Project && npm install` (deps are declared but not installed; needed so agents can run `npm test`).
- Point harvey at the repo root. The role agents are defined in `.claude/agents/`.
- Contracts live in `.claude/ECOSYSTEM.md`; backlog in `.claude/TASKS.md`; traps in `.claude/GOTCHAS.md`.
- **Repeatability:** each scenario is independent and assumes the clean baseline. To re-run,
  reset the working tree (`git stash` or `git checkout -- 01_Project`) so stubs/bugs return.

## Quick map

| # | Demo prompt | Drives | Primary harvey surfaces to watch |
|---|-------------|--------|----------------------------------|
| 1 | "Implement the CSV parser per its contract." | TASK-001 | Lifecycle pane sequence; handoff messages; contracts panel; signature ring charges |
| 2 | "Implement all 8 transform operators; they're independent." | TASK-004 | Many concurrent panes; topology fan-out; packets on edges; token/cost climbs |
| 3 | "Wire the pipeline to the table formatter." | TASK-007 | **STOP + escalation**; traffic-board escalation msg; attention channel; contested contract highlighted |
| 4 | "Make the NDJSON parser handle trailing newlines." | TASK-002 | Agent references seeded gotcha G2; gotcha/attention panel updates live |
| 5 | "Run the full test suite and fix any failures." | TASK-009 | One pane streams for many seconds; ring stays charging; PTY survives view switch/resize |
| 6 | "Fix BUG-001 (dedupe drops last element)." | BUG-001 | Short bug-fix lane (Reported→Fixing→Verify→Done); quick idle→busy→idle; tester verifies |

---

## Scenario 1 — Lifecycle baseline
**Prompt:** `Implement the CSV parser per its contract.`
**Backlog:** TASK-001 · **Contract:** `contract:parse` · **Gotcha:** G1 (BOM) · **Test:** `tests/parse/parseCSV.test.ts`

**Watch for:**
- The **orchestrator → architect → developer → tester → reviewer** panes light in
  sequence — the full lifecycle, one role at a time.
- **Handoff messages** appear on the traffic board at each role transition.
- The **CSV contract** (`contract:parse`) shows up in the contracts panel as the developer
  reads it.
- The orchestrator **signature ring charges** while busy, returns to idle when the task
  reaches Done.
- (Bonus) the developer likely references **gotcha G1** (strip the BOM) — watch the attention channel.

**Why it's deterministic:** single task, single file, stable contract, one obvious test to satisfy.

---

## Scenario 2 — Parallel fan-out (stress)
**Prompt:** `Implement all 8 transform operators; they're independent.`
**Backlog:** TASK-004 · **Contract:** `contract:transform` · **Gotcha:** G3 (purity) · **Test:** `tests/transform/operators.test.ts`

**Watch for:**
- **Many concurrent developer panes** — the operators (`map, filter, reduce, sort, flatten,
  groupBy, window`) are fully independent, so the orchestrator can fan out widely.
- The **topology graph fans out**: many edges active at once, **simultaneous packets**
  flowing orchestrator→developers.
- The **active-group accent follows your clicks** as you move between panes.
- **Token/cost climbs fast** — this is the heavy-parallel burst.
- Note: `dedupe` is intentionally NOT part of this task (it ships buggy — scenario 6), so
  the fan-out stays clean.

**Why it's deterministic:** 7 independent stubs, each with one pinned test; no shared state.

---

## Scenario 3 — Contract mismatch / escalation
**Prompt:** `Wire the pipeline to the table formatter.`
**Backlog:** TASK-007 (BLOCKED) · **Contract:** `contract:pipeline-format` (**status:draft — CONTESTED**) · **File:** `src/pipeline/formatStage.ts`

**Watch for:**
- The developer reads both contracts, discovers the conflict, and **STOPs** instead of coding:
  the pipeline expects `Stage<Table, string>` (needs `Table.columns`), but `contract:format`
  promises only `formatTable(rows: Row[])` — no column ordering.
- An **escalation message** to the architect appears on the traffic board (routing/escalation).
- The **attention channel raises it** as a blocker.
- The **contracts panel highlights the contested contract** (`pipeline-format`, draft).
- The architect responds with a decision (widen `format` to accept `Table`, or relax the
  pipeline) — watch the handoff back.

**Why it's deterministic:** the conflict is a hard type-level contradiction between two
stable contracts; any developer agent following the Agent Rules must escalate rather than widen.

---

## Scenario 4 — Gotcha encounter
**Prompt:** `Make the NDJSON parser handle trailing newlines.`
**Backlog:** TASK-002 · **Contract:** `contract:parse` · **Gotcha:** G2 (trailing newline) · **Test:** `tests/parse/parseNDJSON.test.ts`

**Watch for:**
- The agent **references seeded gotcha G2** (trailing-newline → phantom empty record) while
  working — the gotcha/attention panel updates live.
- If the agent discovers an additional trap (e.g. blank interior lines), **a newly-found
  gotcha gets logged** to `.claude/GOTCHAS.md` — watch the panel append it.

**Why it's deterministic:** the test explicitly includes the trailing-newline case; the
gotcha is pre-seeded and tied to this exact task.

---

## Scenario 5 — Long-running stream
**Prompt:** `Run the full test suite and fix any failures.`
**Backlog:** TASK-009 · **Slow test:** `tests/pipeline/throughput.slow.test.ts`

**Watch for:**
- A pane **streams `npm test` output over many seconds** — the throughput test is
  intentionally slow (deterministic CPU work, no sleeps).
- The orchestrator **signature ring stays charging** for the duration (contrast with the
  quick bug-fix in scenario 6).
- **PTY robustness:** switch views and resize the window mid-run — the streaming pane must
  survive and re-flow correctly.
- The suite shows a **realistic mixed signal**: `parseJSON`/`formatJSON` tests pass, the
  rest are red (the backlog) — so "fix any failures" has genuine, bounded work.

**Why it's deterministic:** fixed dataset + fixed iteration count in the slow test; the set
of red/green tests is fixed by the seeded baseline.

---

## Scenario 6 — Bug-fix lane
**Prompt:** `Fix BUG-001 (dedupe drops last element).`
**Backlog:** BUG-001 (Bug-Fix Lane) · **File:** `src/transform/dedupe.ts` · **Test:** `tests/transform/dedupe.test.ts`

**Watch for:**
- The **short bug-fix lifecycle** — `Reported → Fixing → Verify → Done` — visibly distinct
  from the longer feature lane (no architect design step).
- A **quick idle → busy → idle** on the signature ring (contrast with scenario 5's long charge).
- The **tester verifies** the fix by running `tests/transform/dedupe.test.ts` green.
- (Bonus) BUG-002 (`formatCSV` quoting) and BUG-003 (`parseJSON` empty input) are also
  seeded — swap them in for back-to-back quick-lane demos.

**Why it's deterministic:** the bug is a fixed off-by-one with a test that pins the correct
behavior; the fix is small and unambiguous.

---

## Notes on seeded friction (so nobody "fixes" the test bed by accident)

- **Intentional incompleteness:** most `src/` functions throw `NotImplementedError`. That is
  the backlog — do not pre-implement them outside a scenario.
- **Contested contract:** `contract:pipeline-format` is `status:draft` on purpose. Do not
  quietly mark it stable; that disarms scenario 3.
- **Seeded bugs:** BUG-001/002/003 are working-but-wrong on purpose, each pinned by a failing
  test. Do not fix them outside scenario 6.
- See `.claude/DECISIONS.md` (D1–D4) for why each of these exists.
