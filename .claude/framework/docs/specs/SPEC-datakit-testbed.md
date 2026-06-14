# SPEC — datakit: a typed data-transform toolkit (harvey test bed)

- **Status:** approved (derived directly from the project brief, 2026-06-14)
- **Author:** architect (/analyse)
- **Related:** `.claude/ECOSYSTEM.md` (contracts), `.claude/TASKS.md` (backlog),
  `.claude/GOTCHAS.md`, `.claude/DECISIONS.md`, `SCENARIOS.md` (demo map)

## 1. Purpose (read this first — the usual spec instinct is inverted)

This project is a **dedicated test bed for harvey**, a live IDE/supervisor for multi-agent
Claude Code workflows. harvey spawns role agents (orchestrator, architect, developer,
tester, reviewer) that edit *this* codebase, and surfaces their thinking, tool calls,
handoffs, routing/escalation, contracts, gotchas, token/cost, and a live topology graph.

**The product is only a vehicle.** The real deliverable is a codebase + backlog that, when
worked by those agents, emits a rich, controlled, *observable* stream of agent activity.
Therefore "good" here does **not** mean a finished, polished product — it means work that
is decomposable, parallelizable, deterministic, and deliberately incomplete in ways that
exercise every harvey panel.

## 2. The product (the vehicle)

`datakit` — a small, pure, dependency-free TypeScript toolkit for transforming tabular/JSON
data. Six modules, each with its own typed contract:

| Module | Responsibility |
| ------ | -------------- |
| `parse/` | CSV, JSON, NDJSON → structured data (`Result`-typed) |
| `validate/` | runtime schema validation of rows |
| `transform/` | 8 independent operators: map, filter, reduce, sort, dedupe, flatten, groupBy, window |
| `format/` | output formatters: table, json, csv |
| `pipeline/` | typed `Stage<I,O>` composition engine + `tabulate` |
| `cli/` | thin runner wiring parse → transform → format |

Stack: **TypeScript + Node + Vitest** (fast feedback, per-file test granularity, no
toolchain/network risk). See DECISIONS D1.

## 3. Design driver — every harvey surface must be exercised

| harvey surface | How the test bed exercises it |
| -------------- | ----------------------------- |
| Concurrent per-agent terminal panes | 6 independent modules + an 8-operator fan-out (TASK-004) → genuinely parallel work |
| Agent thinking + tool calls | real edits, greps, `npm test` runs against red tests |
| Inter-agent handoffs | each feature task runs architect→developer→tester→reviewer (lifecycle) |
| Routing & escalation | **contested** `contract:pipeline-format` forces a developer STOP→architect escalation (TASK-007) |
| Contracts panel | one machine-readable contract per module; one (`pipeline-format`) contested |
| Gotchas / attention | 3 seeded gotchas (G1 BOM, G2 NDJSON newline, G3 purity) tied to specific tasks |
| Signature ring (busy/idle) | quick tasks (bug fixes) + a long-running task (TASK-009) → charge/idle contrast |
| Topology graph w/ packets | fan-out (TASK-004) lights many edges at once |
| Token/cost indicator | parallel fan-out + long suite → bursty heavy work |

## 4. Functional requirements & acceptance criteria

Each criterion traces to the brief. "Done" for a feature task = its contract is implemented,
its (currently red) test goes green, and the lifecycle ran through review + test.

- **FR-1 (parse):** `parseCSV`, `parseJSON`, `parseNDJSON` per `contract:parse`.
  - AC: header→keys; quoted commas preserved; **BOM stripped** (G1); NDJSON **trailing
    newline** ignored (G2); empty JSON input is an error (BUG-003 fix).
- **FR-2 (validate):** `validate(value, schema)` per `contract:validate`.
  - AC: conforming row → ok; non-conforming → ok:false with **every** failing field listed.
- **FR-3 (transform):** 8 operators per `contract:transform`, each independent and **pure**.
  - AC: each operator matches its test; **no operator mutates its input** (G3); `dedupe`
    keeps the last unique element (BUG-001 fix).
- **FR-4 (format):** `formatTable`, `formatJSON`, `formatCSV` per `contract:format`.
  - AC: table columns aligned; JSON 2-space; CSV **quotes special chars** per RFC 4180 (BUG-002 fix).
- **FR-5 (pipeline):** `compose` (type-checked chaining) + `tabulate` per `contract:pipeline`.
  - AC: composition chains types; `tabulate` yields stable first-seen column order.
- **FR-6 (pipeline→format wiring):** governed by **contested** `contract:pipeline-format`.
  - AC: a developer attempting TASK-007 **STOPs and escalates** rather than implementing;
    resolution is an architect decision to widen one contract. (This AC is about *process*,
    not code — it is the escalation demo.)
- **FR-7 (cli):** `run(argv, stdin)` per `contract:cli`, pure over its inputs.
  - AC: `--from csv --to json` round-trips; unknown format → non-zero exit + stderr.

## 5. Non-functional requirements

- **Deterministic:** no randomness, clocks, network, filesystem, or env dependence in
  product code or tests. Same prompt → same observable behavior (brief constraint).
- **Dependency-free product:** only `typescript` + `vitest` as devDependencies; the product
  code imports nothing outside `src/`.
- **Fast feedback, one slow exception:** unit tests are fast; `throughput.slow.test.ts` is
  *intentionally* multi-second (scenario 5) and must stay deterministic and < 30s.
- **Incompleteness is a feature:** stubs throw `NotImplementedError` (greppable). Do **not**
  finish implementations as part of analysis/scaffolding — the backlog IS the deliverable.

## 6. Out of scope (this iteration)

- Any networking, persistence, auth, or external service.
- Real CLI process wiring (argv parsing lib, stdin streaming) — `cli.run` stays pure.
- Performance optimization beyond "the slow test runs a few seconds."
- Streaming/async APIs — everything is synchronous for determinism.
- Polishing the product to completion — explicitly **not** a goal.

## 7. Gap analysis (existing project state)

- **Was present:** throwaway monitoring-demo code (`stringUtils`, `base62`, `urlNormalizer`)
  + illustrative design docs in `02_solution/`. **Removed** during scaffolding (committed
  on the branch, recoverable); they were unrelated to the test-bed design.
- **Now present (this analysis):** module dirs + typed stubs + buggy reference impls + red
  test suites; `package.json`/`tsconfig.json`/`vitest.config.ts`; all `.claude/` contracts,
  backlog, gotchas, decisions; `SCENARIOS.md`.
- **Still needed (the backlog — left for harvey to drive):** every FR above. `npm install`
  in `01_Project/` is required before tests run (deps are declared, not installed).

## 8. Next

`SCENARIOS.md` is the operating manual: it maps each demo prompt to the exact harvey
behavior to watch. A normal project would now run `/plan`; here the plan (contracts +
tasks) is already laid down by this same pass.
