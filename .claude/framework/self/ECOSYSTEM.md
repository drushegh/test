# Project Ecosystem — Source of Truth (Framework Development)

Framework-dev contracts. Live ECOSYSTEM.md used when `.claude/framework-self.flag`
is present (moved here from `.claude/ECOSYSTEM.md` 2026-06-10, TASK-027 — the root
copy is now the clean consumer template).

<!-- Contracts are the shared interface agreements between agents. -->
<!-- Every task in TASKS.md references its relevant contract by ID (e.g., "Contract: contract:framework-layout"). -->
<!-- When this file exceeds ~300 lines, split into per-module files in .claude/framework/agent_docs/contracts/ -->

<!-- CONTRACT FORMAT:
     Each contract has two parts:
     1. Prose description: human-readable context, business rules, edge cases
     2. Machine-readable spec: fenced code block with a stable ID anchor

     Anchor format:    contract:IDENTIFIER status:draft|stable
     (placed in an HTML comment before the fenced block)

     - status:draft  = design in progress, NOT ready for implementation
     - status:stable = reviewed and confirmed, safe to implement against

     Reference from TASKS.md:  "Contract: contract:IDENTIFIER"
     The developer agent will REFUSE to implement against draft contracts.

     The machine-readable block is the ENFORCEABLE spec. The prose is context.
     If they conflict, update both, but the code block is what agents validate against.
-->

---

## Framework Layout Contract

The canonical directory layout after the 2026-04-24 restructure. Any implementation of
TASK-001 must produce exactly this on-disk shape. Agents must not reference any path outside
this layout unless it is explicitly listed as "unchanged" or "user-added".

Root contains only three framework-owned items: `CLAUDE.md`, `CLAUDE.framework.md`, `.gitignore`.
Everything else lives under `.claude/`. Project code lives under `01_Project/` (unchanged).

`CLAUDE.framework.md` is pulled into session context by an `@CLAUDE.framework.md` import
in `CLAUDE.md` — Claude Code auto-loads only `CLAUDE.md`/`CLAUDE.local.md`, never other
`CLAUDE*.md` names, and does not follow plain markdown links (verified against the
code.claude.com memory docs, 2026-06-10). The file stays at root for now; moving it under
`.claude/` would only require updating the import path.

<!-- contract:framework-layout status:stable -->
```text
PROJECT_ROOT/
  CLAUDE.md                            # Claude Code required — never move
  CLAUDE.framework.md                  # Claude Code auto-loaded — never move
  .gitignore                           # git required — never move
  01_Project/                          # project code — never move
  .claude/
    # ── Claude Code native (unchanged from pre-restructure) ──────────
    settings.json
    agents/
      framework/
        architect.md
        developer.md
        reviewer.md
        tester.md
      council/                         # /council advisors + chairman
        chairman.md
        contrarian.md
        executor.md
        expansionist.md
        first-principles.md
        outsider.md
    commands/
      analyse.md
      build.md
      council.md
      fleet.md
      healthcheck.md
      housekeeping.md
      plan.md
      review.md
      security.md
      test.md
      wrapup.md
    hooks/
      auto-format.sh
      auto-lint.sh
      block-dangerous-commands.py
      enforce-state-update.sh
      filter-test-output.sh
      framework-drift-guard.sh
      post-edit-dispatch.sh            # TASK-035 — single PostToolUse entry; runs format/lint/verify-deps
      statusline.sh
      verify-deps.sh
      lib/
        hook-common.sh                 # sourced helper, never registered directly
    council/                           # /council run artefacts (gitignored)
    skills/                            # SHARED: skills-repo-synced dirs (skills-sync.sh,
                                       # selected via .skills-version) + consumer-added
                                       # local skills. NEVER touched by apply-update.sh.
    telemetry/
      events.jsonl
      .hook-metrics
      .last-healthcheck
      .last-analysed                   # insights throttle stamp
      .review-scrape-state             # scrape-review-findings.sh cursor
    # ── Framework machinery (was 00_framework/) ──────────────────────
    framework/
      agent_docs/
        architecture.md
        behavioral-principles.md
        building.md
        code-conventions.md
        testing.md
      audit/
        config-security.sh
        pattern-scan.sh
        README.md
      doctor/
        doctor.sh
        README.md
      fleet/
        fleet-status.sh                # TASK-042 — read-only consumer status sweep
      docs/
        requirements/
        specs/
        archives/
        plans/
      healthcheck.conf.template
      init.sh
      insights/
        analyse.sh
        instinct-miner.sh              # mined by /wrapup → .claude/.instinct-candidates.md
        push-state.sh                  # TASK-040 — computed push state for /wrapup
        report.sh
        rollup.sh
        scrape-review-findings.sh
        session-summary.sh             # TASK-034 — /wrapup session-efficacy read-back
        thresholds.conf
        update-metrics.sh
        README.md
      self/                            # framework-dev state; framework-self mode only
        TASKS.md
        STATUS.md
        DECISIONS.md
        ECOSYSTEM.md
        GOTCHAS.md
        FRAMEWORK-SUGGESTIONS.md
        claude-progress.txt
        framework-metrics.md
        README.md
      tests/                           # bats + shellcheck self-tests (see tests/README.md)
      update/
        apply-update.sh
        check-updates.sh
        framework-manifest.txt
        init-framework-version.sh
        migrate-layout.sh              # NEW — consumer migration script
        skills-sync.sh                 # TASK-036 — selective skills-repo sync
        MIGRATION.md
        README.md
    # ── State files (was project root) ───────────────────────────────
    TASKS.md
    STATUS.md
    DECISIONS.md
    ECOSYSTEM.md
    GOTCHAS.md
    FRAMEWORK-SUGGESTIONS.md
    claude-progress.txt
    framework-metrics.md
    test-findings.md                   # tester working file (consumer-owned)
    review-findings.md                 # TRANSIENT — exists only mid-healthcheck/review
    review-findings/                   # gitignored archive; review-findings.md rotates here
    # ── Framework config ─────────────────────────────────────────────
    claude-code-dev-framework.md       # framework guide (update-managed)
    .framework-version                 # was ROOT/.framework-version
    .skills-version                    # OPTIONAL, project-owned — skills-repo pin +
                                       # per-project skill selection (TASK-036)
    framework-self.flag                # gitignored; presence = self mode
    # ── Temp flags (generated by scripts, not committed) ─────────────
    .framework-update-available.md
    .framework-insight-alert.md
    .framework-doctor-findings.md
```

---

## State File Paths Contract

Canonical paths for all state files after restructure. Every hook, command, agent definition,
and script that reads or writes a state file MUST use these paths. Using root-relative bare
names (e.g., `TASKS.md` without the `.claude/` prefix) is a contract violation.

**framework-self mode exception:** When `.claude/framework-self.flag` exists (upstream
framework dev only), the eight self-mode state files redirect to `.claude/framework/self/`.
The redirect is the responsibility of individual scripts — see the machine-readable block.
(History: until 2026-06-10 only five files redirected and ECOSYSTEM/GOTCHAS/
FRAMEWORK-SUGGESTIONS were declared "project-wide". TASK-027 widened the set on user
decision so consumer clones start with clean templates instead of inheriting upstream
framework-dev content at live paths.)

<!-- contract:state-file-paths status:stable -->
```shell
# Normal mode (framework-self.flag absent — all consumers)
TASKS_MD=.claude/TASKS.md
STATUS_MD=.claude/STATUS.md
DECISIONS_MD=.claude/DECISIONS.md
ECOSYSTEM_MD=.claude/ECOSYSTEM.md
GOTCHAS_MD=.claude/GOTCHAS.md
FRAMEWORK_SUGGESTIONS_MD=.claude/FRAMEWORK-SUGGESTIONS.md
PROGRESS_TXT=.claude/claude-progress.txt
METRICS_MD=.claude/framework-metrics.md
REVIEW_FINDINGS_MD=.claude/review-findings.md
FRAMEWORK_VERSION=.claude/.framework-version

# framework-self mode (upstream dev only — .claude/framework-self.flag present)
# These EIGHT paths redirect; the rest stay the same as normal mode.
TASKS_MD=.claude/framework/self/TASKS.md
STATUS_MD=.claude/framework/self/STATUS.md
DECISIONS_MD=.claude/framework/self/DECISIONS.md
ECOSYSTEM_MD=.claude/framework/self/ECOSYSTEM.md
GOTCHAS_MD=.claude/framework/self/GOTCHAS.md
FRAMEWORK_SUGGESTIONS_MD=.claude/framework/self/FRAMEWORK-SUGGESTIONS.md
PROGRESS_TXT=.claude/framework/self/claude-progress.txt
METRICS_MD=.claude/framework/self/framework-metrics.md

# Shell helper pattern (copy into any script that needs the redirect):
STATE_ROOT=".claude"
if [ -f ".claude/framework-self.flag" ]; then
  STATE_ROOT=".claude/framework/self"
fi
# Then use: "$STATE_ROOT/TASKS.md", "$STATE_ROOT/GOTCHAS.md", etc.
# Root copies of the eight redirected files stay as clean consumer templates;
# review-findings.md and .framework-version never redirect.
# NOTE: review-findings.md is TRANSIENT, not a persistent state file — it is
# rotated to .claude/review-findings/<ISO>.md (gitignored dir) at the start of
# every /healthcheck run and may not exist between runs. Scripts must tolerate
# its absence.
```

---

## Migration Behaviour Contract

Specifies the interface and behaviour of `migrate-layout.sh`. This script is the
single responsibility point for the one-time consumer migration from the old layout
(`00_framework/` at root) to the new layout (`.claude/framework/`). `apply-update.sh`
calls it as a pre-flight step; it must be idempotent and safe to run repeatedly.

<!-- contract:migration-behavior status:stable -->
```shell
# migrate-layout.sh — interface contract

# DETECTION (old layout present if either condition is true):
OLD_LAYOUT=false
[ -d "00_framework" ] && OLD_LAYOUT=true
[ -f "TASKS.md" ]     && OLD_LAYOUT=true   # bare state file at root

# IDEMPOTENCY: if neither condition is true, print a one-line notice and exit 0.

# ON OLD LAYOUT DETECTED — execute in this order:
#   Step 1: git mv 00_framework/ .claude/framework/
#           If .claude/framework/ pre-exists (e.g., script manually placed
#           there), merge subdirs individually via per-entry git mv + cleanup.
#   Step 2: for each root state file that exists, git mv to .claude/:
#             TASKS.md, STATUS.md, DECISIONS.md, ECOSYSTEM.md, GOTCHAS.md,
#             FRAMEWORK-SUGGESTIONS.md, claude-progress.txt,
#             framework-metrics.md, review-findings.md
#   Step 3: move framework config files to .claude/:
#             .framework-version          → .claude/.framework-version
#             claude-code-dev-framework.md → .claude/claude-code-dev-framework.md
#   Step 4: update .gitignore (idempotent) — rewrite temp flag paths and
#           the `.claude/framework/self/README.md` comment to new layout
#   Step 5: sed update CLAUDE.md — replace 00_framework/ references
#           (CLAUDE.md is consumer-owned but may have pointers)
#   Step 6: sed update CLAUDE.framework.md — fallback if consumer hasn't
#           pulled the new upstream yet (apply-update overwrites later)
#   Step 7: git commit -m "chore: framework layout migration — 00_framework/ → .claude/framework/"
#   Step 8: bash .claude/framework/doctor/doctor.sh
#           Count CRITICAL findings from .claude/.framework-doctor-findings.md
#           (doctor output format: "- **CRITICAL** — [check] msg").
#           Exit 1 if any CRITICAL findings; print them prominently.
#           WARN/INFO findings: print but continue (exit 0).

# EXIT CODES:
#   0 = already migrated (no-op) OR migration succeeded with no CRITICAL findings
#   1 = migration succeeded but doctor found CRITICAL issues (user must fix before proceeding)
#   2 = git error during mv or commit (migration did not complete)

# INVARIANTS (must hold after successful migration):
#   - 00_framework/ does not exist: ! test -d 00_framework
#   - TASKS.md does not exist at root: ! test -f TASKS.md
#   - .claude/framework/ exists: test -d .claude/framework
#   - .claude/TASKS.md exists: test -f .claude/TASKS.md
#   - .claude/.framework-version exists: test -f .claude/.framework-version
```

---

## Skills Sync Contract

A SECOND upstream, independent of the framework upstream: a skills repo
(one directory per skill, each containing `SKILL.md` + optional reference
files) from which a project selectively syncs language/topic skills into
`.claude/skills/`. Ownership is per-directory: dirs named in
`SKILLS_SELECTED` belong to the skills repo (overwritten on sync, after a
dirty-check); all other dirs under `.claude/skills/` are consumer-local
and invisible to the sync. Neither apply-update.sh nor the framework
manifest ever touches `.claude/skills/`.

<!-- contract:skills-sync status:stable -->
```shell
# .claude/.skills-version — project-owned pin + selection (sourceable shell)
SKILLS_UPSTREAM_URL=git@github.com:drushegh/CCMAF---Skills.git  # or any git-clonable URL/path
SKILLS_UPSTREAM_BRANCH=main
SKILLS_PINNED_SHA=<full sha of last synced upstream HEAD>
SKILLS_SELECTED="python rust"        # space-separated skill dir names to sync
SKILLS_LAST_CHECKED=<ISO ts>         # written by skills-check.sh; throttle bookkeeping (optional)
SKILLS_CHECK_INTERVAL_HOURS=24       # optional; default 24

# skills-check.sh — interface contract (mirrors check-updates.sh)
#   - No .skills-version → NON-ADOPTER DISCOVERY (TASK-044), then exit 0:
#       * .claude/.skills-declined exists → silent (permanent project-level
#         opt-out; the marker is COMMITTED, not gitignored — a project
#         decision every clone should see).
#       * .claude/.skills-suggestion.md already exists → silent (pending
#         notification, same DA-C4 discipline as the update flags).
#       * throttle: .claude/telemetry/.last-skills-suggest mtime within
#         SKILLS_SUGGEST_INTERVAL_DAYS (default 7) → silent.
#       * else run the skills-sync.sh --suggest stack detection; if any
#         skills match, write .claude/.skills-suggestion.md (gitignored)
#         listing suggested names + setup template + decline instructions,
#         touch the throttle marker. Cold start surfaces the flag via
#         AskUserQuestion: set up now / not now (delete flag; re-suggested
#         after the interval) / never (create .claude/.skills-declined).
#   - Opted in (file present): throttle on SKILLS_LAST_CHECKED +
#     SKILLS_CHECK_INTERVAL_HOURS.
#   - ls-remote SKILLS_PINNED_SHA vs upstream branch HEAD:
#       behind → write .claude/.skills-update-available.md (lists
#         SKILLS_SELECTED + the `skills-sync.sh` command); exit 0.
#       up-to-date → clear any stale flag; exit 0.
#   - DA-C4: flags NOT removed up front — survive a throttled run and a
#     network failure; cleared only by a live up-to-date check (update
#     flag) or explicit user action (suggestion flag).
#   - EXIT CODES: 0 checked/throttled/up-to-date/not-opted-in (incl.
#     discovery) | 2 malformed .skills-version | 3 network/ls-remote
#     failure (flag left intact).

# skills-sync.sh — interface contract
#   - No .skills-version → print a fill-in template + exit 2 (that IS the init path).
#   - Clone upstream (branch) to temp dir; local directory paths are valid upstreams.
#   - For each name in SKILLS_SELECTED:
#       * upstream lacks <name>/        → warn, skip (exit stays 0)
#       * local .claude/skills/<name>/ has uncommitted changes:
#           tracked dir → git status --porcelain scoped to the dir ("XY PATH" —
#             consume the space, BUG-002); any line = dirty
#           entirely-untracked dir (previous sync not yet committed) → allowed
#             ONLY if byte-identical to incoming (idempotent re-run); else dirty
#                                       → refuse THAT skill, report, continue others, exit 1 at end
#       * else rm -rf + copy upstream <name>/ → .claude/skills/<name>/
#   - Dirs NOT in SKILLS_SELECTED are never read, written, or deleted.
#   - On ≥1 successful copy: rewrite SKILLS_PINNED_SHA to upstream HEAD.
#   - COMPANION ADVISORY (TASK-044): after ≥1 successful copy, scan the
#     synced skill dirs for `<name>-development` tokens that name a REAL
#     dir in the upstream clone but are not in SKILLS_SELECTED; print one
#     advisory line listing them. Skills cross-reference siblings by name
#     (the skills repo's documented boundary convention) — a missing
#     companion is never an error, just less depth. Advisory only.
#   - --suggest: detect stack manifests and print skill suggestions ONLY.
#     Suggested names track the upstream catalogue's REAL dir names
#     (<stack>-development; pasteable into SKILLS_SELECTED):
#     pyproject/requirements* → python-development; *.csproj →
#     dotnet-development; tauri.conf.json → tauri-development
#     rust-development; Cargo.toml → rust-development; package.json →
#     typescript-development (+react dep → react-development
#     frontend-development; +electron dep → electron-development;
#     +three dep → threejs-development);
#     build.gradle*/settings.gradle* → android-development;
#     *.xcodeproj/Package.swift → ios-development;
#     *.sh outside .claude/ → bash-development; *.ps1/*.psm1 →
#     powershell-development; project.godot → godot-development;
#     ProjectSettings/ProjectVersion.txt → unity-development;
#     *.uproject → unreal-engine-development; azure.yaml/*.bicep →
#     azure-development; .github/workflows/ or azure-pipelines.yml →
#     devops-development; *.pbip/*.tmdl → power-bi-development;
#     *.mcs.yml → copilot-studio-development; *.pcfproj →
#     dynamics-365-development.
#     Cross-cutting skills (secure-development,
#     accessibility-development) are mentioned as always-relevant, not
#     stack-detected. Never installs, never edits .skills-version.
# EXIT CODES: 0 synced/nothing-to-do | 1 ≥1 skill refused (dirty) | 2 setup
#   issue (no .skills-version, malformed) | 3 network/clone failure
```

---

## Telemetry Schema Contract

Every framework hook emits one JSON object per line to
`.claude/telemetry/events.jsonl` (gitignored, machine-local). Schema v2
(TASK-021) reshapes the flat per-hook records toward an OTel-GenAI-style
span model: the *naming convention and span/event split* are adopted; no
OTel SDK, collector, or any runtime dependency beyond jq/date/bash is.

**Correlation model** — a trace is a session; spans nest beneath it:

    session (trace root)        session_id   — from the hook payload; present on every v2 event
      └─ task                   task_id      — RESERVED, not yet emitted (no cheap source at hook
                                               time; candidate source: drift-guard's TASKS.md parse)
        └─ agent handoff        agent_id     — RESERVED, not yet emitted (hook payloads carry no
                                               subagent marker — TASK-038 finding)
          └─ tool call          tool_use_id  — emitted fail-soft where the payload provides it
                                               (PreToolUse/PostToolUse); correlates a guard decision
                                               with the same call's post-edit effects
    every event                 event_id     — unique per line; the dedup/replay anchor (composes
                                               with TASK-015 golden-trace replay)

<!-- contract:telemetry-schema status:stable -->
```shell
# events.jsonl line shape — schema v2 (one JSON object per line)
#
# {"ts":"2026-06-12T20:00:00Z","schema":2,"event_id":"20260612T200000Z-1234-28461",
#  "session_id":"<uuid>","tool_use_id":"<id-or-absent>",
#  "hook":"drift-guard","outcome":"drift-detected","outcome_class":"flagged",
#  "trigger":"stale-state"}
#
# REQUIRED (v2): ts, schema(=2), event_id, session_id (may be "" when the
#   payload lacks it), hook, outcome, outcome_class
# OPTIONAL low-cardinality indexed: tool_use_id, trigger (drift-guard),
#   ecosystem (verify-deps), missing (stop), tool_uses/transcript_lines
#   (cost-tracker), critical/warning/suggestion (review-scraper)
# RESERVED: task_id, agent_id (correlation model levels, not yet emitted);
#   detail (object — verbose/high-cardinality content goes HERE so readers
#   can drop it; never promote high-cardinality values to top-level keys)
#
# NAMING CONVENTION (the gen_ai.* steal): flat snake_case keys; OTel mapping:
#   session_id ~ trace id | tool_use_id ~ span id | event_id ~ log-record id
#   hook ~ instrumentation scope | outcome ~ scope-specific status
#   outcome_class ~ canonical status code (the low-cardinality cross-hook enum)
#
# outcome_class enum (canonical, exactly four values):
#   ok      — hook ran, nothing noteworthy (clean/passed/allowed/formatted/ran/filtered/session-end)
#   flagged — hook surfaced something non-blocking (drift-detected/findings/scraped)
#   blocked — hook prevented an action (stop blocked / bash-guard blocked)
#   skipped — hook had nothing applicable (skipped/passthrough)
#
# PER-HOOK outcome VOCABULARIES are UNCHANGED from v1 (back-compat):
#   drift-guard: drift-detected|clean    stop: passed|blocked
#   bash-guard:  allowed|blocked         format: formatted|skipped
#   lint: ran|skipped                    test-filter: filtered|passthrough
#   verify-deps: clean|findings          review-scraper: scraped
#   cost-tracker: session-end
#
# BACK-COMPAT RULE: v1 lines (no schema field) remain valid forever; readers
#   MUST tolerate both (derive outcome_class for v1 via the legacy mapping in
#   rollup.sh). No migration of existing events.jsonl files — append-only.
#
# EMITTERS: bash hooks emit via telemetry_emit() in hooks/lib/hook-common.sh
#   (session_id/tool_use_id arrive via CLAUDE_HOOK_SESSION_ID /
#   CLAUDE_HOOK_TOOL_USE_ID, exported by each hook after its payload parse,
#   or by post-edit-dispatch.sh for the dispatched trio). Lib absent →
#   no event (telemetry is best-effort; core hook function never depends on it).
#   block-dangerous-commands.py builds the same shape natively.
#
# READERS: rollup.sh (.hook-metrics gains sessions/schema_mix/by_session),
#   analyse.sh (existing flat thresholds unchanged; + stop-block session
#   concentration), session-summary.sh (windows by session_id, falls back
#   to the cost-tracker-marker heuristic for v1 streams).
```

---

## Module Boundaries & File Ownership

| Module | Owner Role | Files | Notes |
| ------ | ---------- | ----- | ----- |
| Framework machinery | Framework (update-managed) | `.claude/framework/**` | Overwritten by apply-update.sh |
| Claude Code config | Framework (update-managed) | `.claude/agents/`, `.claude/commands/`, `.claude/hooks/`, `.claude/settings.json` | Overwritten by apply-update.sh |
| State files | Consumer (never overwritten) | `.claude/TASKS.md`, `.claude/STATUS.md`, `.claude/DECISIONS.md`, `.claude/ECOSYSTEM.md`, `.claude/GOTCHAS.md`, `.claude/FRAMEWORK-SUGGESTIONS.md`, `.claude/claude-progress.txt`, `.claude/framework-metrics.md`, `.claude/test-findings.md` | Consumer-owned content |
| Review artefacts | Consumer (transient) | `.claude/review-findings.md`, `.claude/review-findings/` | Flat file rotates into the gitignored archive dir each /healthcheck run |
| Skills (synced) | Skills repo (sync-managed) | `.claude/skills/<name>/` for each name in `SKILLS_SELECTED` | THIRD ownership domain (TASK-036): overwritten by `skills-sync.sh` from the skills upstream pinned in `.claude/.skills-version`; dirty-checked before overwrite. NOT in framework-manifest.txt, never touched by apply-update.sh |
| Skills (local) | Consumer (never overwritten) | `.claude/skills/` dirs NOT in `SKILLS_SELECTED` | Consumer-added; invisible to both apply-update.sh and skills-sync.sh |
| Root instructions | Hybrid | `CLAUDE.md` (consumer content), `CLAUDE.framework.md` (framework-owned) | CLAUDE.md is consumer's; CLAUDE.framework.md is update-managed |
| Framework-self state | Upstream only | `.claude/framework/self/**` | gitignored flag gates access; not propagated to consumers |
