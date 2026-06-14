# Project Status

Last updated: 2026-06-14 (architect /analyse — datakit harvey test bed designed, scaffolded, and verified)

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
| architect | /analyse: spec, contracts, backlog, gotchas, decisions, scenarios, scaffold | — | 2026-06-14 | Done |

## Recently Completed

| Task | Completed By | When | Commit |
| ---- | ------------ | ---- | ------ |
| /analyse → full test-bed deliverable set (SPEC, ECOSYSTEM contracts, TASKS, GOTCHAS, DECISIONS, SCENARIOS, scaffold) | architect | 2026-06-14 | (uncommitted) |
| Scaffold verified: npm install + tsc clean + vitest run (6 pass / 25 fail / 1 todo, ~3.6s) | architect | 2026-06-14 | (uncommitted) |
| Framework setup verified + skills tier opt-in (all 38 skills) | orchestrator | 2026-06-14 | 0441154 (branch) |

## Blockers

- **TASK-007** is intentionally BLOCKED on the contested `contract:pipeline-format`
  (an architect decision) — this is by design (scenario 3), not a real impediment.

## Current Test Status

- `01_Project`: Vitest **6 passing / 25 failing / 1 todo** (13 files). This red-heavy split
  IS the backlog — failures are unimplemented stubs (`NotImplementedError`) + 3 seeded bugs.
- Passing (working references): `parseJSON` (valid/malformed), `formatJSON`, `formatCSV`
  (basic, no special chars), `throughput.slow` (intentionally ~seconds).
- Typecheck: `tsc --noEmit` clean. `npm install` done locally (node_modules gitignored).
- Last run: 2026-06-14, duration ~3.6s.

## Known Issues (SEEDED ON PURPOSE — do not "fix" outside a scenario)

- BUG-001 (P2): `dedupe` drops the last element — bug-fix lane / scenario 6.
- BUG-002 (P2): `formatCSV` doesn't quote special characters — bug-fix lane.
- BUG-003 (P3): `parseJSON` accepts empty input as valid — bug-fix lane.
- `contract:pipeline-format` is `status:draft`/contested on purpose — scenario 3.

## Next Up

1. (Optional) commit the test-bed analysis output (currently uncommitted on branch `setup/framework-and-skills`).
2. Point harvey at the repo and run the scenarios in `SCENARIOS.md` (start with scenario 1).
3. Per scenario: `git checkout -- 01_Project` between runs to restore the seeded baseline.
