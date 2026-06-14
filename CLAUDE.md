# Test

<!--
  This file is PROJECT-OWNED. Put project-specific instructions here
  (tech stack, commands, domain rules). Framework-shipped instructions
  (cold start, state file rules, agent rules, etc.) live in
  CLAUDE.framework.md and are updated by .claude/framework/update/.

  IMPORTANT: Claude Code auto-loads ONLY CLAUDE.md and CLAUDE.local.md —
  there is no CLAUDE*.md wildcard, and plain markdown links are NOT
  followed. CLAUDE.framework.md reaches the session context solely via
  the @import on the line below. Do not remove or reword it into a
  link, or every framework rule silently drops out of your sessions.
-->

**Framework instructions (required):** @CLAUDE.framework.md

The imported Cold Start Sequence is authoritative — this file is for *project-specific additions* (tech stack, commands, path mapping, domain rules), NOT a competing cold-start list.

## What

`datakit` — a small, pure, dependency-free TypeScript data-transform toolkit (parse /
validate / transform / format / pipeline / cli). **It is a test bed for *harvey*** (a live
supervisor for multi-agent Claude Code workflows), NOT a product to ship. It is
deliberately incomplete: most functions are stubs and a few are seeded with bugs, so that
agents working the backlog emit a rich, observable stream of activity. See `SCENARIOS.md`.

## Tech Stack

- Language: TypeScript (ES2022, strict)
- Runtime: Node.js, ESM
- Testing: Vitest
- No backend / frontend / database / network / auth — pure in-memory logic only (by design).

## Contract & Decision Layout

- Contracts: monolithic `.claude/ECOSYSTEM.md` (default layout).
- Decisions: monolithic `.claude/DECISIONS.md` (default layout).

## Commands (run from 01_Project/)

    cd 01_Project && npm install          # First-time setup (deps declared, not installed)
    cd 01_Project && npm test             # Run the Vitest suite (mostly red — that's the backlog)
    cd 01_Project && npm run typecheck    # tsc --noEmit
    # (no dev server / build step — this is a library, not an app)

## Project-Specific Notes

- **Do NOT "finish" the implementations or "fix" the seeded bugs/contested contract
  outside a scenario.** The incompleteness IS the deliverable — see `.claude/DECISIONS.md`
  (D1–D4) and the "seeded friction" note at the bottom of `SCENARIOS.md`.
- Stubs throw `NotImplementedError` (greppable). `parseJSON` (happy path) and `formatJSON`
  are the only correct reference impls.
- `contract:pipeline-format` is `status:draft` on purpose (contested) — TASK-007 is meant
  to trigger a STOP-and-escalate, not an implementation.
- Backlog: `.claude/TASKS.md`. Seeded traps: `.claude/GOTCHAS.md`. Demo playbook: `SCENARIOS.md`.
