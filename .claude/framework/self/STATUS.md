# Project Status — Framework Development

Last updated: 2026-06-12 (session 21 — TASK-021 schema v2 + TASK-044 skills tier hardening: 29-skill catalogue audited+committed+pushed, non-adopter discovery, companion advisory, full suggest map, ADOPTED-FEEDBACK registry, doctor Check 12, both READMEs. Suite 141/141)

Framework-dev status. Live STATUS.md used when
`.claude/framework-self.flag` is present.

## Current Sprint Goal

Second research-driven sweep (TASK-014..017), from a claude.ai pass over
*other* agent frameworks (bats-core, ReasoningBank, Judge-Reliability-Harness,
Beads) against our Section-B gaps: (014) bats-core + shellcheck hook
regression harness in `framework/tests/` — caught a real `set -e` bug in
config-security.sh; (016) instinct-miner now also captures *successes* as
transferable-strategy candidates (dual-source distillation, propose-only);
(015) `/healthcheck --verify --perturb` flags fragile findings that flip
under cosmetic input change; (017) `/housekeeping` distils completed tasks
forward before archiving (semantic decay). Mechanisms only — rejected Beads'
separate-binary/DAG model and ReasoningBank's auto-consolidation.

First sweep (TASK-009..013): ECC-inspired — config-security auditor, hook
profiles, compaction/cost markers, instinct miner, reviewer noise control +
prompt-injection principle. Committed in 211e56b.

## Third research pass — done; two items filed for deliberate work

The focused second/third claude.ai pass returned. Its standout (golden-trace
deterministic replay) is only partly achievable for us — we don't own Claude
Code's model client, so the LLM half can't be stubbed; the achievable parts
landed as TASK-019 (golden fixtures for deterministic detectors) and TASK-020
(`--pin` input freezing for attribution). Fault-injection landed as TASK-018.
Two bigger items FILED (not built — deliberate work):
- **TASK-021** — OTel-style span schema for telemetry (pipeline-wide; metrics gap).
- **TASK-022** — subagent context-bundle assembler (architect pass; revives the
  deferred HC8 `## Project paths` item).
Research is concluded — the well of novel, in-philosophy mechanisms is dry
(claude.ai's own call). No further passes planned.

## Active Work

| Agent | Working On | Task | Started | Status |
| ----- | ---------- | ---- | ------- | ------ |
| — | Session 21: TASK-021 + TASK-044 Done. Remaining Todo: TASK-022 (context-bundle architect pass). Consumer moves queued: dogfood skills-sync on a consumer; nudge /fleet-flagged stale projects (their next cold start now also gets the skills suggestion flag) | — | — | Idle |

## Recently Completed

| Task | Completed By | When | Commit |
| ---- | ------------ | ---- | ------ |
| TASK-044: skills tier hardening — 29-skill catalogue audited + committed + pushed; non-adopter discovery (.skills-suggestion.md, declinable); companion advisory; full --suggest map; ADOPTED-FEEDBACK.md registry + /housekeeping reconciliation; doctor Check 12 (leaked dev-state fingerprints); skills README framework contract; framework README refresh | session 21 | 2026-06-12 | be33651 + skills c0a1a1d |
| TASK-021: telemetry schema v2 — contract:telemetry-schema, telemetry_emit helper, 8 emitters on session_id/event_id/outcome_class (+fail-soft tool_use_id), rollup by_session/schema_mix, analyse session-concentration finding, session-summary session-id windowing; CRLF jq gotcha found+fixed live; suite 131/131 | session 21 | 2026-06-12 | 7ece316 |
| TASK-042: /fleet consumer status sweep (read-only); TASK-043: skills-check cold-start staleness notice. Pre-push healthcheck clean (fixed tester/architect RED-LINES gap + stale ECOSYSTEM tree) | this session | 2026-06-12 | e99097f / 60eca69 / 35c5d32 |
| TASK-037..041: fleet-sweep batch — findings persistence, subagent RED-LINES, command-collision notice, computed push-state, council self-preference fix | this session | 2026-06-12 | 296809b..e9db2d7 |
| TASK-036: skills-repo sync — .skills-version + skills-sync.sh selective copy, contract:skills-sync, 11 bats, --suggest wired into init.sh; live smoke vs CCMAF---Skills passed | this session | 2026-06-12 | 32778d7 |
| TASK-035: post-edit dispatcher — git spawns 3→1, ~410ms/edit saved; settings.json collapsed to one PostToolUse entry (named approval); doctor learns indirect hook wiring | this session | 2026-06-12 | 057659d + f302ddd |
| TASK-034: /wrapup "Session efficacy" line — insights/session-summary.sh telemetry read-back, fail-soft, jq isolated for TASK-021 | this session | 2026-06-12 | 57c73b5 |
| TASK-033: instinct-miner precision — 34→0 noise on the observed transcript; schema characterised in script header | this session | 2026-06-12 | 01a3140 |
| TASK-032: update-system bats tier — 25 tests, fully offline via local-dir-upstream fixtures; found+fixed BUG-002 (migrate-layout dirty refusal never fired) | this session | 2026-06-12 | 7851515 |
| TASK-026: settings.json hook-pattern uniformity — all 7 hooks on bash -c + $CLAUDE_PROJECT_DIR (landed after named user authorisation) | this session | 2026-06-10 | e4e80e9 |
| TASK-027: consumer clean templates — ECOSYSTEM/GOTCHAS/SUGGESTIONS joined the self-mode redirect (contract updated first); root templates reset, examples now status:draft | this session | 2026-06-10 | 801111a |
| TASK-025: spec-doc rewritten for v2 — 2,151 → 418 lines, shrink-to-concepts, setup scenarios on the update-system flow, zero stale refs | this session | 2026-06-10 | 5f253d0 |
| TASK-024: audit quick-fix bundle — @CLAUDE.framework.md import (rules were never auto-loaded; doctor Check 3 upgraded), statusline stdin reader + doctor Check 10, test-filter anchor fix, stop_hook_active yield, drift-guard per-session counters + Indicator 3 fix, hygiene sweep | this session | 2026-06-10 | 74cd602 |
| TASK-023: multi-project mode removed — single framework clone per project; supersedes 2026-04-18 multi-project decision; fleet check showed zero adopters | this session | 2026-06-10 | 0a8e36b |
| TASK-018: fault-injection test tier (caught 2 fail-open bugs: block-dangerous crash, verify-deps set -e exit 5) | this session | 2026-06-02 | f624e44 |
| TASK-019: golden-fixture regression for config-security | this session | 2026-06-02 | f624e44 |
| TASK-020: /healthcheck --verify --pin (model-vs-environment attribution) | this session | 2026-06-02 | f624e44 |
| TASK-014: bats-core + shellcheck hook regression harness (caught a config-security set -e bug) | this session | 2026-06-02 | f624e44 |
| TASK-016: instinct-miner success capture (dual-source distillation, propose-only) | this session | 2026-06-02 | f624e44 |
| TASK-015: /healthcheck --verify --perturb (fragile-finding detection) | this session | 2026-06-02 | f624e44 |
| TASK-017: /housekeeping semantic decay (distil before archiving) | this session | 2026-06-02 | f624e44 |
| TASK-013: ECC agent patterns — reviewer noise control + prompt-injection principle | this session | 2026-06-02 | 211e56b |
| TASK-011: unified hook profile + opt-out convention | this session | 2026-06-02 | 211e56b |
| TASK-009: config-surface security auditor (+ /security Part 4) | this session | 2026-06-02 | 211e56b |
| TASK-012: compaction nudge + cost markers (folded into existing hooks) | this session | 2026-06-02 | 211e56b |
| TASK-010: instinct miner (proposes GOTCHAS/SUGGESTIONS, never auto-writes) | this session | 2026-06-02 | 211e56b |
| TASK-008: 11-change AI-coding-research sweep | this session | 2026-05-14 | 6976b91 |
| BUG-001: /healthcheck append-only review-findings.md anchoring fix | this session | 2026-04-26 | 03c13d4 |
| TASK-007: /council command + 6 council agents + smoke test on contract-drift | this session | 2026-04-26 | a1d398b |
| README rewrite to reflect current framework surface | this session | 2026-04-26 | a1d398b |
| /healthcheck: 14 findings identified, all fixed | reviewer + developer session | 2026-04-24 | 3b1084f + pending |
| TASK-001–006: full framework layout restructure + migration tooling + verification | developer/tester session | 2026-04-24 | 9663226 + 8647dd9 |
| /analyse + /plan: framework layout restructure spec + plan + contracts | architect session | 2026-04-24 | (session 7) |
| Downstream healthcheck sweep (10 items) | main session | 2026-04-18 | 31076b9 → d0b8f86 |
| `.claude/framework/self/` redirect migration | main session | 2026-04-18 | 883cc91 |
| apply-update smoke test — `.claude/framework/self/` confirmed not propagated | main session | 2026-04-18 | (verified, no commit) |
| jq install via winget + `~/.bashrc` PATH fix | main session | 2026-04-18 | (system change) |
| End-to-end hook smoke tests (drift-guard + filter-test-output) | main session | 2026-04-18 | (verified, no commit) |
| `pattern-scan.sh` anti-pattern scanner | main session | 2026-04-18 | 0443d3c |
| Downstream patch-6 sweep (agent-layer ECOSYSTEM/DECISIONS generic phrasing) | main session | 2026-04-18 | 94f668d |
| Dogfooding loop closed: downstream retired `framework-patch.sh` + `framework-update.sh` | downstream consumer | 2026-04-18 | (downstream TASK-078 closed) |
| `/wrapup` session-close command | main session | 2026-04-18 | b3c49ea |
| HC8 upstream sweep — 7 items (F12 F13 F25 F4 F28 F5/F14 F33) | main session | 2026-04-18 | 473eac5 + 04361ee + 70f63dc |
| HC8 sweep verified end-to-end in downstream | downstream consumer | 2026-04-18 | c7c8bfd pulled; all 7 items FIXED with file:line evidence; HEALTHCHECK_SOURCE_DIRS live-tested on `02_src/reqtool` |

## Blockers

- None.

## Current Test Status

- Hook regression harness: bats + shellcheck suite at `framework/tests/` (TASK-014, 2026-06-02) with behavioural, fault-injection (TASK-018), golden-fixture (TASK-019), and update-system (TASK-032) tiers. Run via `bash .claude/framework/tests/run-tests.sh`. Latest full run 2026-06-12 (session 21, after TASK-021): 131/131 pass. Tiers now also include skills-sync, skills-check, fleet-status, push-state, session-summary, telemetry-schema-v2.
- `apply-update.sh` end-to-end: verified 2026-04-18 via synthetic consumer (24 paths updated, `.claude/framework/self/` correctly absent).
- Last full `/healthcheck`: 2026-06-11 (3 BROKEN, 1 CRITICAL misalignment, 7 contract gaps, 6 stale items — all fixed same session; see `.claude/review-findings.md`).

## Known Issues

- None currently. (Drift-guard Indicator 3 false-negative fixed in TASK-024; the
  2026-06-10 external audit's remaining items are tracked as TASK-025 and the
  Next Up consumer-leak question below.)

## Next Up

0. **PICK UP HERE — TASK-022 (context-bundle architect pass, incl. AC5)**,
   the last Todo item. ~~TASK-021~~ Done 2026-06-12 (session 21):
   telemetry schema v2 shipped pipeline-wide; `task_id`/`agent_id` are
   reserved correlation levels the TASK-022 design may eventually feed.
   ~~TASK-032..035~~ all Done 2026-06-12 (session 20).
   Still pending user actions: remote `assets` branch deletion (GitHub UI),
   downstream consumer prompt (session-17 progress entry). Unchosen
   brainstorm ideas parked in FRAMEWORK-SUGGESTIONS [2026-06-12].
   TASK-036/042/043 (skills sync + /fleet + skills-check) DONE & PUSHED
   2026-06-12. Skills catalogue LIVE on GitHub (10 skills, 11940f4);
   user adding bash + D365 next via cowork. NEXT consumer move: dogfood
   skills-sync on a consumer (create its .claude/.skills-version,
   SKILLS_SELECTED="python-development") and nudge the stale projects
   /fleet flagged (babynamey + claude-usage-tray PRE-migration;
   harvey + prompt-picker on old pins) to pull.
1. **Rebaseline drift count cleanly post-BUG-001.** Run /healthcheck on reqtool from a FRESH session with no priming language ("stability experiment", "RUN N of M", "insert before existing block" — all forbidden). With the runbook's new Part 0.0 rotation in place, the run starts with no prior findings. If three such rebaseline runs produce stable drift counts, the historical 2→8→12 trend can be re-evaluated. If they vary, the metric is fundamentally noisy and we don't build automation against it. Now also exposable as `/healthcheck --verify 3` per TASK-008.
2. ~~TASK-025 — spec-doc reconciliation~~ **DONE 2026-06-10** (commit 5f253d0): guide rewritten 2,151 → 418 lines, zero stale refs.
3. ~~Consumer-leak policy~~ **RESOLVED 2026-06-10 (TASK-027):** user authorised the clean-template switch; contract updated first, redirect widened to eight files, root copies reset, upstream content moved to `framework/self/`.
4. Consider extracting `state_root()` helper — 3 copies of the flag-check pattern live in separate scripts now; worth consolidating if it grows a 4th caller.
5. ~~Subagent path inheritance (HC8 deferred item)~~ — superseded: tracked as **TASK-022** in Todo (context-bundle assembler; its AC3 explicitly decides supersede-or-compose for the `## Project paths` prepend).
6. ~~Contract-drift acceleration mitigation~~ **DROPPED 2026-04-26.** Original premise (2→8→12 drift trend) measured against the structurally-vulnerable append-only review-findings.md (see BUG-001). Trend can't be trusted without a clean rebaseline (item 1 above). If the rebaseline shows real drift acceleration, this item returns; otherwise it stays dropped.
