# Project Status

Last updated: 2026-06-14 (orchestrator — multi-agent demo run: TASK-001 Done, TASK-007 escalation resolved)

<!-- Do NOT record push/ahead-behind state as prose here — it goes stale
     the moment anything is committed. It is computed on demand:
     `bash .claude/framework/insights/push-state.sh` (/wrapup reports it). -->

## Current Sprint Goal

Stand up `datakit` as a **test bed for harvey** (multi-agent supervisor): a typed, pure,
deliberately-incomplete data-transform toolkit whose backlog drives observable agent
activity. Analysis + scaffold are done; the backlog is intentionally left unimplemented
for harvey to work. See `SCENARIOS.md`.

## Active Work

| Agent | Working On | Task | Started | Status |
| ----- | ---------- | ---- | ------- | ------ |
| _(idle)_ | demo run complete — see Recently Completed | — | 2026-06-14 | Idle |

## Recently Completed

| Task | Completed By | When | Commit |
| ---- | ------------ | ---- | ------ |
| TASK-001 parseCSV — full lifecycle (impl → review REQUEST-CHANGES → fix → 10/10 green) | developer + reviewer (+ tester) | 2026-06-14 | (uncommitted — demo) |
| TASK-007 escalation resolved (D5): widened `contract:format` to accept `Table`; `pipeline-format` → stable | developer (STOP) + architect | 2026-06-14 | (uncommitted — demo) |
| Gotchas G4 (quoted-final-field) + G5 (empty-delimiter hang) logged from review; G1 encounter count 0→1 | reviewer / developer | 2026-06-14 | (uncommitted — demo) |
| /analyse → full test-bed deliverable set (SPEC, ECOSYSTEM contracts, TASKS, GOTCHAS, DECISIONS, SCENARIOS, scaffold) | architect | 2026-06-14 | (uncommitted) |
| Framework setup verified + skills tier opt-in (all 38 skills) | orchestrator | 2026-06-14 | 0441154 (branch) |

## Blockers

- **TASK-007** is intentionally BLOCKED on the contested `contract:pipeline-format`
  (an architect decision) — this is by design (scenario 3), not a real impediment.

## Current Test Status

- `01_Project`: `parseCSV` is now implemented and green — **10/10** in
  `tests/parse/parseCSV.test.ts` (was 3 stub-red). The rest of the suite remains red by
  design (unimplemented stubs + 3 seeded bugs) — that's still the backlog harvey burns.
- Passing references: `parseJSON` (valid/malformed), `formatJSON`, `formatCSV` (basic),
  `throughput.slow` (intentionally ~seconds), **and now `parseCSV` (full)**.
- Typecheck: `tsc --noEmit` clean. `npm install` done locally (node_modules gitignored).
- Last run: 2026-06-14 (parseCSV file: 10 passed).

## Known Issues (SEEDED ON PURPOSE — do not "fix" outside a scenario)

- BUG-001 (P2): `dedupe` drops the last element — bug-fix lane / scenario 6.
- BUG-002 (P2): `formatCSV` doesn't quote special characters — bug-fix lane.
- BUG-003 (P3): `parseJSON` accepts empty input as valid — bug-fix lane.
- `contract:pipeline-format` is `status:draft`/contested on purpose — scenario 3.

## Next Up

1. **Decide whether to keep or revert this demo run.** All changes are uncommitted. To
   re-arm the seeded scenarios (esp. scenario 3's contested contract), run `git checkout -- .`
   — this restores parseCSV to a stub, `contract:pipeline-format` to draft, and the gotcha/
   decision/task edits to baseline.
2. If keeping: commit with task IDs (`feat: parseCSV (TASK-001)`, `docs: resolve pipeline-format contract (TASK-007, D5)`).
3. Otherwise continue pointing harvey at the repo and run other `SCENARIOS.md` prompts
   (scenario 2 fan-out, scenario 6 bug-fix lane). `git checkout -- 01_Project` between runs.
