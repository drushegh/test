# Decision Log

<!-- Newest decisions at the top. During Cold Start, agents read only the last 10 entries. -->
<!-- When this file exceeds ~50 entries, move older decisions to .claude/framework/docs/archives/decisions-archive.md -->

## 2026-06-14 — D4: `parseJSON` and `formatJSON` ship as correct reference impls
**Decision:** Of all module functions, exactly two are implemented correctly at baseline
(`parseJSON` happy path, `formatJSON`); everything else is a stub or a seeded bug.
**Rationale:** gives the pipeline one working end-to-end path and guarantees the test
suite has at least some green among the red — so "run the full suite" (scenario 5) shows
a realistic mixed signal, and the slow throughput test can run on real working code.

## 2026-06-14 — D3: seeded bugs live in IMPLEMENTED code, across three modules
**Decision:** BUG-001 (`dedupe`, transform), BUG-002 (`formatCSV`, format), BUG-003
(`parseJSON`, parse) ship as working-but-wrong implementations with failing tests that
pin the correct behavior. They are deliberately spread across three modules.
**Rationale:** the bug-fix lane (scenario 6) needs real buggy code to fix, not stubs.
Spreading them across modules makes the bug-fix topology in harvey more interesting and
keeps `dedupe` out of the TASK-004 fan-out (so the two lanes stay visually distinct).

## 2026-06-14 — D2: `contract:pipeline-format` is deliberately CONTESTED (status:draft)
**Decision:** The pipeline's terminal formatter stage is typed `Stage<Table, string>`
(needs `Table.columns`), but `contract:format` promises only `formatTable(rows: Row[])`.
The integration contract is marked `status:draft` so the developer agent refuses to
implement it and must escalate.
**Rationale:** scenario 3 requires a genuine STOP-and-escalate. A type-level conflict
between two *stable* contracts — resolvable only by widening one (an architect decision) —
is the most realistic trigger and exercises harvey's routing/escalation + contracts panel.
The conflict is documented in `src/pipeline/formatStage.ts` and `contract:pipeline-format`.

## 2026-06-14 — D1: stack = TypeScript + Node + Vitest; product = `datakit` data-transform toolkit
**Decision:** Build a typed data-transform toolkit (parse / validate / transform / format /
pipeline / cli) on TS + Vitest, deterministic and dependency-free (no network, no auth, no
external services). The product is a **test bed for harvey** (a multi-agent supervisor), not
a shipped product; its domain is kept ORTHOGONAL to harvey's own (no agents/panes/topics
concepts) to avoid confusing the demo.
**Rationale:** per the project brief. Vitest gives fast feedback and per-file test
granularity (clean fan-out); pure logic guarantees repeatable demos (same prompt → same
observable behavior); ~6 independent modules let 4–6 agents work in parallel without
collisions. Recorded so future sessions don't "fix" the intentional incompleteness.
