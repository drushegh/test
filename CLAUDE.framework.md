# CLAUDE.framework.md — Framework-shipped instructions

This file is FRAMEWORK-OWNED. The update system (.claude/framework/update/)
will overwrite it when a new framework version is pulled. Do not edit
it directly — make project-specific changes in CLAUDE.md instead.

`CLAUDE.md` includes this file via the pointer at its top. Both files
are loaded into the session context on cold start.

---

## Cold Start Sequence (MANDATORY for every new session)

<!-- Steps 5-9 are ordered for prompt-cache optimisation: stable content
     (contracts, decisions) before volatile (tasks, status, progress).
     Steps 0-4 emit session-varying output and sit first for a different
     reason: broken state must surface before any content is read. -->

0. **Framework-self mode (upstream framework dev only)** — If
   `.claude/framework-self.flag` exists, state files (`TASKS.md`,
   `STATUS.md`, `DECISIONS.md`, `ECOSYSTEM.md`, `GOTCHAS.md`,
   `FRAMEWORK-SUGGESTIONS.md`, `claude-progress.txt`,
   `framework-metrics.md`) live under `.claude/framework/self/` rather than
   at root. Root copies stay as clean templates. All later steps in
   this runbook that reference state-file paths resolve to
   `.claude/framework/self/<filename>` when the flag is present. The flag
   is gitignored and created manually in the upstream repo only —
   consumers never see it and read `.claude/` state files as usual.

   Rationale: this lets the upstream framework repository dogfood its
   own framework fully (real task board, real session log, real
   decisions) without that development state leaking into consumer
   clones. The flag is the only per-clone bit that distinguishes
   upstream from a consumer; no manifest or code-path branching.
1. **Framework update check** — Run `bash .claude/framework/update/check-updates.sh`
   (silent if up-to-date). If `.claude/.framework-update-available.md` exists
   afterwards, read it, summarise the new commits to the user via
   AskUserQuestion, and ask whether to update. On *yes*: run
   `bash .claude/framework/update/apply-update.sh` and then RESTART the cold
   start from step 1 (agent definitions may have changed). On *no*:
   delete `.claude/.framework-update-available.md` for this session and continue.

   Then run `bash .claude/framework/update/skills-check.sh` (usually silent).
   Two flags it may raise:
   - `.claude/.skills-update-available.md` (project opted into skills via
     `.claude/.skills-version` and is behind upstream): read it and tell the
     user their selected skills are behind; on their go-ahead run
     `bash .claude/framework/update/skills-sync.sh`, else delete the flag for
     this session.
   - `.claude/.skills-suggestion.md` (project has NOT opted in but its stack
     matches catalogue skills; throttled to once per
     `SKILLS_SUGGEST_INTERVAL_DAYS`): read it and ask via AskUserQuestion:
     *set up skills sync now* (create `.claude/.skills-version` from the
     flag's template, run skills-sync, delete the flag) / *not now* (delete
     the flag; re-suggested after the interval) / *never for this project*
     (create `.claude/.skills-declined`, COMMIT it, delete the flag).
   (Skills are separate from the framework update above — a different
   upstream, different pin.)
2. **Framework insights check** — Run `bash .claude/framework/insights/analyse.sh`
   (silent if nothing to report; throttled by `INSIGHTS_CHECK_INTERVAL_DAYS`).
   If `.claude/.framework-insight-alert.md` exists afterwards, read it, summarise
   the findings to the user via AskUserQuestion with three options:
   *file as `.claude/FRAMEWORK-SUGGESTIONS.md` entry* / *show full report and
   discuss* / *dismiss (delete flag file)*. Findings always represent
   patterns worth considering, not always bugs.
3. **Framework doctor check** — Run `bash .claude/framework/doctor/doctor.sh`
   (silent if clean; no throttle — broken state needs surfacing immediately).
   If `.claude/.framework-doctor-findings.md` exists afterwards, read it. CRITICAL
   findings must be resolved before continuing (broken hooks, missing
   CLAUDE.framework.md include, missing manifest paths will cause silent
   session failures). WARNING findings should be triaged. Surface via
   AskUserQuestion: *fix now* / *file as task* / *dismiss for this session*.
4. **Healthcheck reminder (deep audit)** — Check
   `.claude/telemetry/.last-healthcheck` (ISO timestamp of last successful
   run). If missing OR older than `HEALTHCHECK_REMIND_DAYS` (from
   `.claude/healthcheck.conf` if set, else default 14), ask the user
   via AskUserQuestion: "No healthcheck in N days. Run /healthcheck now?
   (takes 5-15 minutes)". Options: *run now* / *skip — remind in N days*.
   On *run now*: follow the `/healthcheck` command runbook, then touch
   `.claude/telemetry/.last-healthcheck` with the current timestamp when
   it finishes.
   On *skip*: touch `.claude/telemetry/.last-healthcheck` with the current
   timestamp — the nudge waits another full interval. Throttle: only one healthcheck
   prompt per cold start, even if multiple reasons to nudge exist.
5. Read contracts — types, boundaries, interface agreements (stable — high cache hit rate). Default: `.claude/ECOSYSTEM.md` (monolithic); projects using per-file contracts read `contracts/` instead. Project CLAUDE.md specifies which layout applies.
6. Read recent decisions — top 10, newest first (mostly stable). Default: `.claude/DECISIONS.md`; per-file layouts read `decisions/`. Project CLAUDE.md specifies which layout applies.
7. Read `.claude/TASKS.md` → task board with lifecycle statuses (changes each session)
8. Read `.claude/STATUS.md` → current state, who's doing what (changes each session)
9. Read `.claude/claude-progress.txt` → Rolling Summary + last 3 detailed entries (newest first)
10. Run `.claude/framework/init.sh` → start dev server, verify nothing is broken
11. Pick the highest-priority unblocked task from `.claude/TASKS.md`
12. Check `.claude/GOTCHAS.md` → entries relevant to the task area
13. Pre-task check: estimate context cost against the current window, ask user if projected >= 90%

## State File Rules (NON-NEGOTIABLE)

- Update `.claude/TASKS.md` whenever a task status changes (feature lane or bug-fix lane)
- Update `.claude/STATUS.md` at session start (claim work) and end (record results)
- Update `.claude/claude-progress.txt` at session end with summary
- Add significant decisions to `.claude/DECISIONS.md` with rationale
- If you change a contract, update `.claude/ECOSYSTEM.md` FIRST — both prose AND machine-readable blocks
- TASKS.md, STATUS.md, and claude-progress.txt updates are enforced by the
  Stop hook — you cannot end a session without them. DECISIONS.md and
  ECOSYSTEM.md updates are convention-only (no hook can judge whether a
  decision was made) — treat them as equally non-negotiable discipline,
  precisely BECAUSE nothing will catch you skipping them

## Commit Convention (NON-NEGOTIABLE)

- Every commit MUST include the task/bug ID: `type: description (TASK-XXX)` or `(BUG-XXX)`
- A task cannot move to Ready for Review or Done without a linked commit
- Verify with: `git log --oneline --grep="TASK-XXX"`

## Agent Rules

- Architect plans, Developer implements, Tester tests, Reviewer reviews
- The agent that writes code does NOT review it
- If you discover a contract mismatch — STOP and flag it
- Developers may tighten/clarify contracts inline; widening → escalate to Architect
- `.claude/TASKS.md` has two lanes: **Feature** (full lifecycle) and **Bug-fix** (Reported → Fixing → Verify → Done)
- Log bugs with [BUG-XXX] IDs, severity (P0-P3), and source reference

## Code Quality Rules

- **Check before creating:** Read code-conventions.md and check for existing shared helpers first
- **Reuse over duplication:** Only create new abstractions when there is clear duplication
- **Domain language:** Use existing terminology from `.claude/ECOSYSTEM.md` — no new names for existing concepts
- **Machine-readable contracts:** `.claude/ECOSYSTEM.md` contracts must include fenced code blocks
  anchored with `<!-- contract:ID status:stable -->`. Add one when you touch a contract area.
- **Update conventions as you go:** New stable pattern → update code-conventions.md same commit

## Code Navigation

- If a code graph MCP server is configured (check /mcp), use it BEFORE grep/glob
- Prefer targeted searches over full-codebase scans

## Reference Documents (read when relevant)

- Requirements → .claude/framework/docs/requirements/
- Specs → .claude/framework/docs/specs/
- Building → .claude/framework/agent_docs/building.md
- Testing → .claude/framework/agent_docs/testing.md
- Conventions → .claude/framework/agent_docs/code-conventions.md
- Architecture → .claude/framework/agent_docs/architecture.md
- Behavioral principles → .claude/framework/agent_docs/behavioral-principles.md
  (per-turn discipline — think before coding, simplicity, surgical
  changes, goal-driven execution — loaded by each agent on handoff)
- Gotchas → `.claude/GOTCHAS.md` | Framework metrics → `.claude/framework-metrics.md`

## Hook Configuration (consumer-tunable)

Hooks honour two environment variables (resolved by `.claude/hooks/lib/hook-common.sh`):

- `CLAUDE_HOOK_PROFILE=minimal|standard|strict` (default `standard`).
  - **minimal** — only the destructive-command guard (`block-dangerous`) runs. Everything else is silenced. For low-context/local-model setups or quick throwaway work.
  - **standard** — all shipped hooks run. This is the default; behaviour is unchanged from before the profile system existed.
  - **strict** — standard plus any hooks declared at the `strict` tier (reserved for future opt-in extra-strict checks).
- `CLAUDE_DISABLED_HOOKS="format,lint"` — comma/space-separated list of stable hook IDs to turn off regardless of profile. An explicit disable always wins, even for safety-tier hooks.

Stable hook IDs: `block-dangerous` (safety), `enforce-state`, `filter-test-output`, `drift-guard`, `format`, `lint`, `verify-deps`, `suggest-compact`, `cost-tracker`.

Legacy per-hook opt-outs still work and compose with the above: `CLAUDE_DEP_VERIFY=0` (skip dependency registry checks), `CLAUDE_DOTNET_FORMAT=1` / `CLAUDE_DOTNET_LINT=1` (opt into slow .NET tooling), `CLAUDE_SUGGEST_COMPACT_TURNS=N` (compaction-nudge cadence).

## MCP Servers

- Only enable servers you're actively using — check /mcp for token costs
- Prefer CLI tools over MCP when available — lower token overhead

## Framework Feedback

- Log framework improvement ideas in `.claude/FRAMEWORK-SUGGESTIONS.md` (reviewed separately)

## Context Awareness (NON-NEGOTIABLE)

- Before implementation tasks: estimate token cost against the current context window
- If projected >= 90%: STOP and ask user (proceed / prepare for compaction / fresh session)
- If context > 60% with tasks remaining: suggest a fresh session
- When compacting: preserve modified files, task status, current decisions
- Use subagents for research-heavy work (their context is separate)
