# Decision Log — Framework Development

<!-- Newest decisions at the top. During Cold Start, agents read only the last 10 entries. -->
<!-- When this file exceeds ~50 entries, move older decisions to .claude/framework/docs/archives/decisions-archive.md -->

Framework-dev decision log. Live DECISIONS.md used when
`.claude/framework-self.flag` is present.

---

## 2026-06-12 — Skills tier: discovery, companions, and the adopted-feedback channel (TASK-044)

**Decision 1 — non-adopters get a throttled, declinable suggestion; never a nag.**
The TASK-036 "zero nag for non-adopters" stance left existing projects with
no way to LEARN the skills tier exists. Reversed deliberately, with three
guards: stack detection must actually match (no detectable stack → forever
silent), a 7-day throttle marker in gitignored telemetry, and a one-touch
permanent opt-out (`.claude/.skills-declined`) that is COMMITTED — a project
decision every clone sees. Rejected: doctor finding (wrong severity channel
for an offer), init.sh print (lost in boot noise, no decline path).

**Decision 2 — skill cross-references stay advisory names; the framework
derives companions at sync time instead of maintaining a dependency map.**
Skills reference siblings by directory name (the skills repo's boundary
convention). A dependency manifest in the skills repo would rot; instead
skills-sync greps the just-synced dirs for `-development` tokens, validates
each against the upstream clone it already has, and prints one advisory.
Missing companions are never errors — the agent just lacks that depth.

**Decision 3 — consumed feedback is cleaned via a shipped registry, not
automation.** When upstream adopts a consumer's GOTCHAS/SUGGESTIONS item
(the session-20 fleet-sweep pattern), the consumer's local entry goes stale
silently. Now upstream records adoptions in manifest-shipped
`framework/docs/ADOPTED-FEEDBACK.md`; the consumer's own /housekeeping
reconciles (match on topic, prune or annotate). Rejected: automated
deletion (state files are consumer-owned; topic-matching needs judgement),
apply-update doing it inline (wrong moment — update should stay mechanical).
Companion fix for the OTHER leak direction: doctor Check 12 fingerprints
pre-TASK-027 upstream dev entries that shipped inside old clones' state
files and tells the consumer to prune.

---

## 2026-06-12 — Telemetry schema v2: OTel-shaped correlation, zero OTel runtime (TASK-021)

**Decision:** events.jsonl moves to schema v2 (`contract:telemetry-schema`):
every event gains `session_id` (trace root, from the hook payload),
`event_id` (unique line id — the TASK-015 replay/dedup anchor), a canonical
cross-hook `outcome_class` enum (`ok|flagged|blocked|skipped`), and
fail-soft `tool_use_id` where the payload provides one. Bash hooks emit
through one helper (`telemetry_emit` in hook-common.sh); the Python guard
builds the same shape natively. `task_id`/`agent_id` are RESERVED levels in
the correlation model, deliberately not emitted yet (no cheap source at
hook time; subagent payloads carry no marker — TASK-038 finding).

**Key calls:**
1. *Steal the convention, reject the control plane.* OTel GenAI gives the
   field-naming discipline and span/event split; an SDK/collector would be
   a new runtime dependency for a local JSONL log — rejected per the
   standing mechanism-not-dependency doctrine.
2. *outcome_class is emitted at source, not derived at read time* — one
   constant per call site beats three readers each maintaining a mapping.
   The v1 legacy mapping lives in exactly one place (rollup.sh `classof`).
3. *v1 lines are valid forever.* No migration of existing files; readers
   tolerate both. Existing per-hook `outcome` vocabularies unchanged, so
   every existing threshold, test grep, and consumer keeps working.
4. *Flat snake_case keys, not OTel dotted names* — dotted keys break every
   grep-based test and printf emitter for zero analytical gain; the
   contract documents the OTel mapping instead.

**Found while shipping:** (a) the winget jq emits CRLF on every output
line; MSYS bash `$()` strips it (so all pre-existing `$(jq -r)` consumers
were always fine) but `read < <(jq -r …)` keeps the \r — the new
read-based extraction corrupted the first live v2 lines until CR-strips
were added at every jq-fed read site + the emit choke point (GOTCHAS
entry; mechanism verified empirically 2026-06-12, correcting this entry's
first version which wrongly claimed the old `stop_hook_active` `$()`
comparison was latent-broken). (b) rollup's `jq -s` aborted entirely on
one malformed line — now line-tolerant (`fromjson?`), same lesson
session-summary learned in TASK-034.

---

## 2026-06-12 — Skills are a second upstream and a third ownership domain (TASK-036/042/043)

**Decision:** Language/topic skills live in a SEPARATE repo
(CCMAF---Skills, one dir per skill) and sync into projects via
`.claude/.skills-version` + `skills-sync.sh` (selective copy of
`SKILLS_SELECTED` dirs only). `.claude/skills/` becomes a third ownership
domain: selected dirs are skills-repo-owned (overwritten on sync after a
dirty-check), everything else is consumer-local; apply-update and the
framework manifest never touch skills. Staleness is surfaced by
`skills-check.sh` at cold start (same throttle + DA-C4 flag discipline as
the framework check). Contract: `contract:skills-sync`.

**Rationale:** skills grow on a different cadence than the framework and
per-project (a Python project doesn't want the Tauri skill); coupling them
to the framework manifest would force all-or-nothing. Reusing the
update-system pattern (pin + manifest-style selection + local-dir-testable
clone) means the whole tier shipped with offline bats on day one.

**Rejected:** git submodules (Windows pain, consumer cognitive load);
putting skills in the framework manifest (wrong ownership/cadence);
auto-installing skills from stack detection (suggest-only — `--suggest`
prints catalogue names, never edits `.skills-version`).

**Related same-day call:** reviewer stays Write-less for findings
persistence (TASK-037) — the orchestrator persists via /review step 5 +
a PERSIST trailer, rather than granting the reviewer a Write tool that
config-security would rightly flag.

---

## 2026-06-11 — Deep-analysis critical sweep: three design calls (TASK-028)

**Decision 1 — apply-update gains stage-then-swap, not transactional rollback.** All incoming entries are copied into a staging dir INSIDE the project (same filesystem) before anything is deleted; swaps are then renames. Rejected: full snapshot/rollback (git stash or backup copy of every manifest path) — heavier, and git already IS the rollback for committed state; the swap-failure path now prints the exact `git checkout HEAD -- <paths>` command instead.

**Decision 2 — settings.json self-edit deny REJECTED.** The deep analysis suggested denying Write/Edit of `.claude/settings.json` to close a self-modification attack loop. Rejected because consumers' settings.json is project-owned and doctor-prescribed fixes (Check 3/10 pattern) are applied by the consumer's own Claude editing that file — the deny would sever the framework's only propagation channel for project-owned config. The classifier-approval gate (TASK-008/026 precedent) remains the control for self-modification.

**Decision 3 — GNU-toolchain gap is gated, not ported.** bash>=4 guards (fail loud, or fail open for advisory scripts) + doctor Check 11 capability probe, instead of porting to bash 3.2/BSD tools. Rationale: zero macOS consumers today; porting `declare -A`/`mapfile`/`find -printf`/`date -d`/`sed -i` across ~10 scripts is real cost with no current beneficiary. The probe converts "silent feature death" into a named WARNING. Port individual scripts only when a real macOS consumer appears. Validation of the approach: Check 11 immediately revealed grep -P was dead on git-bash — the PRIMARY platform — which static review had mislabelled a macOS-only issue; the zero-width detector was rewritten portably (byte-level LC_ALL=C) as a result.

---

## 2026-06-10 (later) — SUPERSEDED same day: user authorised the clean-template switch (TASK-027)

**Decision:** The no-build entry below is superseded. On return the user said "proceed with everything", which authorises the consumer-leak change the earlier entry had parked. Executed exactly via the path that entry prescribed: `contract:state-file-paths` updated FIRST (redirect set five → eight), then the self-mode redirect widened (CLAUDE.framework.md step 0, self/README, instinct-miner), then root ECOSYSTEM/GOTCHAS/FRAMEWORK-SUGGESTIONS reset to clean consumer templates with upstream content moved to `framework/self/`. Bonus hardening while resetting: the ECOSYSTEM template's example contracts are now `status:draft` so the developer agent refuses to implement against accidentally-kept examples (v1 shipped them `status:stable`).

**Also attempted under the same authorisation, blocked again:** TASK-026 (settings.json hook-pattern edit). The auto-classifier ruled a blanket "proceed with everything" still isn't a *named* authorisation for hook-config self-modification. Not worked around (TASK-008 precedent); stays in Blocked. The user can apply the four command strings manually or grant a specifically-named approval.

**Also evaluated and rejected this pass:** moving CLAUDE.framework.md under `.claude/` ("everything" arguably covers it; @import made it possible). Rejected for a circular failure mode: after the move, a consumer whose CLAUDE.md still imports the old path loads NO framework rules → the cold start that runs doctor never executes → doctor never tells them about the fix. The doctor-as-messenger channel doesn't work when the breakage severs the channel itself. Revisit only with a transition design (e.g. ship a one-line root shim that @imports the new location for a release cycle).

---

## 2026-06-10 — Consumer-leak question resolved as NO-BUILD: contract says project-wide is deliberate

**Decision:** Do NOT redirect `.claude/ECOSYSTEM.md`, `GOTCHAS.md`, and `FRAMEWORK-SUGGESTIONS.md` into framework-self mode (the change sketched as the 2026-06-10 audit's item 8). Investigation found `contract:state-file-paths` (status:stable, in ECOSYSTEM.md) explicitly states these three "always stay at `.claude/` regardless of self mode — they are project-wide, not self-mode-specific." The inheritance into consumer clones is therefore contracted-deliberate, not an oversight. The framework's own change-control rule applies symmetrically to the agent operating on it: widening or breaking a stable contract requires escalation, and the user was away — so the question stays parked as STATUS Next Up #3 with the evidence, for the user to decide.

**Why record this:** the audit framed the inheritance as a likely defect. The contract proves intent. Future sessions should not re-open this as a bug; if the user decides clean templates are better after all, that's a deliberate contract change (update contract:state-file-paths first, then the redirect + template reset).

**Tradeoff left with the user:** current design = consumer agents read upstream framework-dev gotchas/contracts as if project content (noise, but generic shell lessons travel for free). Clean-template design = tidier consumer start, but the contract and the self/ redirect list both widen.

---

## 2026-06-10 — TASK-026 parked: classifier-blocked settings edit is not worked around (precedent holds)

**Decision:** The hook-pattern uniformity change (old `cd "$(git rev-parse …)"` → `bash -c 'cd "$CLAUDE_PROJECT_DIR" …'` on the four non-PostToolUse hook commands) was denied by the auto-classifier as self-modification of hook config under a general autonomy grant. Following the TASK-008 precedent ("working around it would be the wrong precedent; explicit user approval is right"), the partial edit was reverted via `git restore` and the task parked in Blocked with the exact change documented. No functional loss: the old pattern works for those events on this platform (the 2026-04-24 diagnostic only showed failure for PostToolUse).

---

## 2026-06-10 — CLAUDE.framework.md must be @imported; doctor is the propagation channel for project-owned config (TASK-024)

**Decision:** Switch the CLAUDE.md → CLAUDE.framework.md pointer from a markdown link to the `@CLAUDE.framework.md` import, and adopt a general principle discovered while shipping it: **when a fix lives in a project-owned file (CLAUDE.md, settings.json — not in the manifest), propagate it by teaching doctor to detect the stale pattern and prescribe the fix.** Applied twice in TASK-024: Check 3 now requires the @import form (CRITICAL), Check 10 flags statusline commands reading `$CLAUDE_STATUS_JSON` (WARNING). doctor.sh IS manifest-owned, so every consumer learns about its own stale config on the first cold start after pulling.

**Why:** Verified against the code.claude.com memory docs (2026-06-10): Claude Code auto-loads only `CLAUDE.md` and `CLAUDE.local.md` — there is no `CLAUDE*.md` wildcard, and markdown links are not followed; only `@path` imports are inlined (4-hop max). The framework's layout contract claimed otherwise, which means since the 2026-04-17 CLAUDE.md split, the entire framework rulebook reached sessions only when the model chose to follow a "required reading" link — probabilistic compliance in the one place the framework most needs mechanical guarantee. Same verification pass confirmed statusline data arrives via stdin; the `$CLAUDE_STATUS_JSON` env var never existed, so every clone's statusline has rendered placeholders since day one.

**Alternatives rejected:**
- *Keep the link + strengthen the wording:* still probabilistic; @import is the mechanical fix and costs one line.
- *Move CLAUDE.framework.md under .claude/ in the same change:* now unblocked (the old blocker WAS @-import adoption), but bundling a path move with the semantics fix would complicate consumer diagnosis; defer the move to its own change if wanted.
- *Bump manifest to own CLAUDE.md/settings.json so fixes propagate directly:* wrong boundary — those files carry per-project content by design; overwriting them is data loss. Doctor-as-messenger preserves ownership.

**How to apply:** Any future fix touching project-owned config follows the same pattern: fix the shipped template for new clones + add a doctor check for existing ones. Also: claims about Claude Code platform behaviour in contracts/docs get verified against current docs before being stated as fact (this one survived four healthchecks because every reviewer trusted the prose).

---

## 2026-06-10 — Remove multi-project mode entirely (TASK-023)

**Decision:** Remove multi-project mode entirely — the `projects/<name>/` + `_active` stash/switch model, the `.claude/framework/project/` script suite (mode/new/switch/list/adopt-current), the `/framework-mode` command, doctor Check 6, the `FRAMEWORK_MODE` field in `.framework-version`, and all cold-start/runbook references. The framework is now single-mode only: one framework clone per project. **Supersedes the 2026-04-18 "multi-project mode (opt-in, per-instance)" decision** (commit 1537f9f).

**Why:** Practical usage. The feature was built speculatively ("if I needed it") and a fleet check on 2026-06-10 found zero adopters — none of the 8 consumer projects has a `projects/` directory or `FRAMEWORK_MODE=multi`; every clone runs one project. Meanwhile the feature carried real ongoing cost: a cold-start step every session, a doctor check, mode-conditional logic in healthcheck, a 7-script suite to maintain (it already ate a data-loss-bug fix on 2026-04-18), and a second mental model to document. Dead weight with a maintenance tax — exactly what "don't multiply surface" says to cut.

**Consumer impact:** None requiring action. `apply-update.sh` already handles upstream removals — local-manifest entries missing from upstream's manifest and tree are deleted via the "(removed upstream)" path, so `project/` and `framework-mode.md` clean themselves up on each consumer's next update. Leftover `FRAMEWORK_MODE=single` lines in consumer `.framework-version` files are inert (nothing reads the field anymore). A MIGRATION.md section covers the theoretical multi-mode consumer (none known to exist).

**Alternatives rejected:**
- *Keep it dormant ("costs nothing if unused"):* false — it cost a cold-start step per session, doctor latency, and doc surface; speculative flexibility is what behavioral-principles §2 tells the agents not to build.
- *Deprecate-then-remove over two releases:* process theatre with a fleet of 8 known consumers, all single-mode and all owned by the same person.
- *Doctor tombstone check for FRAMEWORK_MODE=multi:* not worth a permanent check for a state no clone is in; MIGRATION.md note suffices.

**How to apply:** One framework clone per project, always. If juggling several small projects, that's several clones — Cold Start state isolation per repo is the design, not a limitation. Doctor check numbering: Check 6 is retired, later numbers unchanged (stability of historical findings references).

---

## 2026-06-02 — Third research sweep (TASK-018..022): build the achievable half honestly

**Decision:** A second/third claude.ai pass led with "golden-trace deterministic replay" as the strongest find. Independent assessment: **its full form is not achievable for us** — record-replay requires stubbing the model client, and we run *inside* Claude Code, we don't wrap it. Rather than over-claim, I split it into the parts we can actually build:

- **TASK-019 golden fixtures** — replay for the *deterministic* detectors (config-security/doctor/pattern-scan): record input tree + expected findings, assert match. This is the achievable "golden-trace" for shell auditors. Built.
- **TASK-020 `--pin`** — for the *LLM* detectors we can't stub the model, but we CAN freeze the input. Pinning isolates model-nondeterminism from environmental drift (the attribution `--verify` lacks). Built as runbook.
- Full token-for-token LLM replay — **rejected as infeasible**, stated plainly rather than faked.

- **TASK-018 fault-injection** (ToolMisuseBench pattern) — built, and like TASK-014 it **immediately earned its keep**: caught two real fail-open violations (block-dangerous-commands.py crashed on non-JSON stdin; verify-deps.sh exited 5 under `set -e` on a non-JSON event). Both are exactly the "fail-open silently breaks on garbage input" class the tier exists to find. The recurring lesson: **the test harness keeps finding real bugs the moment it's pointed at a new surface** — TASK-014 found the `config-security set -e` abort, TASK-018 found two more. The harness is the highest-ROI thing built across all three sweeps.

- **TASK-021 OTel span schema** and **TASK-022 context-bundle** — FILED, not built. Both are real but bigger: 021 touches the whole telemetry pipeline (every emitter + rollup + analyse); 022 is architectural and admittedly claude.ai's unproven construction (revives the deferred 2026-04-26 HC8 `## Project paths` item). They get deliberate treatment, not a same-turn rush.

**Rejected (this pass):** OTel SDK/collector (control-plane — took the schema only); multi-judge ensemble in `--pin` (cost + BUG-001 anchoring); a third research pass (the well is dry — claude.ai's own call, agreed).

**Through-line across all three sweeps:** take the mechanism, leave the dependency; build the achievable half honestly rather than the impressive-but-infeasible whole; and the bats harness (TASK-014) plus its fault/golden tiers (018/019) turned out to be the most valuable output — a regression net that has now caught three real bugs in framework code that shipped "verified."

---

## 2026-06-02 — Second research sweep (TASK-014..017): mine mechanisms, reject dependencies

**Decision:** A claude.ai research pass over *other* frameworks (deliberately skipping swarm/marketplace piles as Section-A-with-extra-steps) surfaced four candidates mapped to our Section-B gaps. Adopted all four as **mechanism-only** steals; rejected the parts that conflict with our design.

- **TASK-014 bats-core + shellcheck** (gap: no hook regression harness). Clean fit — hooks are pure `(stdin+env)→(exit+stdout)` functions. Built `framework/tests/`. Runs via `bats` or `npx bats`; opt-in by availability. **It immediately earned its keep**: caught a `set -e` abort in config-security.sh (`[ -d X ] || return` returns 1 → kills the script on any repo without `.claude/hooks`). That bug shipped in TASK-009 and would have hit consumers.
- **TASK-016 dual-source distillation** (from ReasoningBank). Took the "learn from successes, not just failures" insight: instinct-miner now proposes transferable-*strategy* candidates from success signals, not only correction candidates. **Rejected** the paper's auto-consolidation (violates human-in-loop) and the embeddings/local-retrieval infra (dependency weight) — kept it file-based + propose-only. Boundary enforced in the output: a project-specific "we chose X" is a DECISION, not a strategy.
- **TASK-015 perturbation testing** (from Judge Reliability Harness). `--verify` only measured variance on identical input; `--perturb` tests robustness to semantics-preserving change and flags *fragile* findings (the real determinism property). **Rejected** multi-judge ensemble voting — running the reviewer N× reintroduces the cost + anchoring concerns behind BUG-001.
- **TASK-017 semantic decay** (from Beads). Took only the "distil before archiving" mechanism for `/housekeeping`. **Rejected** Beads wholesale: it's a separate Dolt/SQLite CLI binary (violates "no separate control-plane binary, Claude-Code-specific") and its hash-ID/DAG task model is too invasive for our single-branch scale — doctor's duplicate-ID check already covers the symptom we actually have. Revisit only if we go multi-dev/multi-branch.

**Also rejected outright** (claude.ai flagged, agreed): metaswarm (auto-writes = our rejected autonomous store; only delta is PR-merge trigger), spec-kit/BMAD (Section A).

**Two gaps unfilled** by this pass — subagent context inheritance and telemetry-interpretation harnesses — queued for a focused second research pass (brief in session-15 progress entry).

**Why mechanism-only is the through-line:** every adopted item is a file-based, dependency-free, human-in-loop adaptation of an idea that originated in a heavier system. That's the same discipline as the ECC sweep — take the idea, leave the surface.

---

## 2026-06-02 — ECC sprint implementation: shape choices for TASK-009..012

**Decision:** Implemented all four ECC-inspired tasks in one sprint. Three shape choices deviated from or sharpened the filed plan:

1. **TASK-012 folded into existing hooks rather than two new hooks.** The plan listed `suggest-compact.sh` + `cost-tracker.sh` (and I'd pre-added them to the manifest). On implementation I folded them in: the compaction nudge became drift-guard **Indicator 5** (UserPromptSubmit — the only channel that reaches the model *before* it responds, so it can act on the nudge that turn; a Stop hook fires too late), and cost markers became a `cost-tracker` block in enforce-state-update.sh (Stop). Reverted the manifest additions. **Why:** directly honours the 2026-05-14 "tighten existing gates, don't add new artifacts" rule, AND sidesteps the settings.json auto-classifier block (no new registration needed). The sub-features stay independently controllable because they check `hook_enabled <id>` with their own stable IDs.

2. **TASK-009 wired into `/security` Part 4, not a doctor check class.** doctor runs on every cold start and must stay instant; the config audit greps all agents/hooks/MCP/instruction files. Putting it in doctor would tax every session. `/security` is the on-demand whole-harness sweep and already had a manual "Part 4 — config security" — the script replaced that checklist as Part 4a, with manual spot-checks as 4b. Exit-2-on-CRITICAL makes it independently CI-usable.

3. **TASK-010 proposes only; bash can't cluster semantically.** The miner buckets corrections by exact normalized-snippet match (seen-count = confidence) — coarse, with false positives. Rather than fake precision, the candidates file is explicit that it surfaces *moments for a human glance*, and the human writes the actual GOTCHAS/SUGGESTIONS entry. This is the human-in-the-loop re-scope of ECC's autonomous instinct store, decided at the planning stage and kept.

**Supporting change:** doctor Check 1 now uses `find -maxdepth 1` on `.claude/hooks` so the new sourced helper `lib/hook-common.sh` (included via `source`, never registered in settings.json) isn't flagged as a dead/unwired hook.

**Hook profile model (TASK-011):** tiers are `safety` (runs in all profiles — only `block-dangerous` today), `normal` (standard+strict; off in minimal), `strict` (strict only — reserved). Gate is **fail-open**: if `hook-common.sh` is missing, the hook runs exactly as before, so adding the gate never changes default behaviour. Prefix is `CLAUDE_` (not ECC's `ECC_`) to match our existing `CLAUDE_DEP_VERIFY`/`CLAUDE_DOTNET_*` convention.

**Verified:** doctor clean, pattern-scan clean (0 findings — CRLF + grep-c disciplines held), init clean, config-security self-scan 0 CRITICAL, all hooks `bash -n` clean, profile/miner/auditor behaviours unit-tested with fixtures.

---

## 2026-06-02 — ECC-repo inspiration review: adopt 4 ideas, reject the surface-multiplying ones

**Decision:** Reviewed the ECC harness-optimization repo (github.com/affaan-m/ECC) for ideas to add to our framework. Gap-mapped its surface (63 agents, 249 skills, AgentShield config auditor, continuous-learning-v2 instinct mining, hook profiles, memory-persistence/compact hooks, cross-harness adapters) against ours. Filed **TASK-009..012**; rejected the rest.

**Adopted (filed):**
- **TASK-009 Config-surface security auditor** (from AgentShield) — P1. Audits our *own* harness config (settings.json perms, hook scripts, agent prompts, MCP, CLAUDE.md) for injection/permission risk. Genuine gap: `/security` only covers project code. Prefer extending `doctor.sh` / `/security --config` over a new command.
- **TASK-010 Auto-instinct extraction** (from continuous-learning-v2) — P2. Mines sessions for repeated corrections and *proposes* GOTCHAS/SUGGESTIONS entries; never auto-writes. Reuses the telemetry→insights pipeline rather than a new SQLite instinct store.
- **TASK-011 Unified hook profiles + opt-outs** (from ECC_HOOK_PROFILE / ECC_DISABLED_HOOKS) — P2. Replaces our ad-hoc per-hook env opt-outs with one convention.
- **TASK-012 suggest-compact + cost Stop hooks** (from memory-persistence) — P3. Operationalises the manual context-budget rule.

**Rejected (and why):**
- *63 specialized agents / 249 skills* — directly contradicts the 2026-05-14 "harden gates, don't multiply surface" decision. Language-specific reviewers/build-resolvers would multiply our agent layer for marginal gain; our generic reviewer + behavioral-principles already host the checks.
- *Cross-harness adapters (Cursor/Codex/Gemini/Zed)* — we are Claude-Code-specific by design; consumers are Windows .NET/Node/Python projects. Out of scope.
- *Desktop GUI dashboard + Rust control-plane (ecc2)* — out of scope for a state-file-driven framework.
- *SQLite instinct store with confidence auto-evolution* — heavier than warranted; TASK-010 takes the *propose-for-approval* idea but keeps our human-in-the-loop, file-based capture (GOTCHAS/DECISIONS/SUGGESTIONS) rather than an autonomous store.

**How to apply:** TASK-009 first (highest value, security gap). TASK-011 before TASK-012 (012's opt-out depends on 011's convention). Each lands as its own scoped commit with its TASK ID.

**Source:** ECC repo review, 2026-06-02 (requested by user). Full mapping mirrored in FRAMEWORK-SUGGESTIONS.md.

---

## 2026-05-14 — 11-change AI-coding-research sweep: harden gates, don't multiply commands

**Decision:** When responding to the ChatGPT deep research report's 13-row issue taxonomy, bias toward *tightening existing gates* (reviewer.md, tester.md, developer.md, behavioral-principles.md) over adding new commands or new agents. Only add new artifacts where existing surface genuinely couldn't host the check — specifically `verify-deps.sh` (network call on manifest edit — needed a hook), `/security` (whole-project sweep distinct from per-PR review), `/healthcheck --verify` (multi-run protocol distinct from single run), `doctor.sh` Check 9 (detector-consumer invariant). Everything else lives in existing agent prompts.

**Why this shape:**
- The framework already has reviewer/tester/developer/architect with clear separation of concerns. Most of the report's recommendations map to "the reviewer should check X" or "the developer should disclose Y" — that belongs in the agent prompt, not a new layer.
- DORA's "verification tax" finding is itself a warning: piling on more commands and gates risks reviewer-fatigue and slower velocity. Each new artifact in this sprint had to clear "could this be a prompt edit instead?"
- Code-smell research (89.3% of AI issues are smells, not crashes) → reviewer's smell section was upgraded from SUGGESTION to gate-level. Same surface, sharper teeth.
- Package-hallucination research → `verify-deps.sh` is the one new hook because registry pings cannot live in an agent prompt — they need to happen automatically on every manifest edit, not on review.
- BUG-001 lesson (2026-04-26) → `/healthcheck --verify` mode + doctor Check 9 codify the "validate detector determinism before consuming output" discipline that previously lived only in FRAMEWORK-SUGGESTIONS.

**Alternatives rejected:**
- *Separate `/ai-review` command on top of existing reviewer:* doubles the surface; the reviewer agent already exists and is the right home for AI-specific checks. Adding new sections to reviewer.md is cheaper and avoids "two reviewers disagree" failure modes.
- *Block on settings.json edit via Bash workaround:* the auto-classifier denied editing settings.json (correctly — it's agent config self-modification). Working around it would be the wrong precedent; explicit user approval is right.
- *Implement registry checks in the reviewer agent rather than a hook:* reviewer runs on demand at review time. The hook runs immediately on every manifest edit and catches issues 10 turns earlier in the loop, when the developer can still adjust without rework.
- *License-checking section in reviewer:* deferred — domain-specific, depends on licence policy that varies per consumer. Lives in `/security` Part 5 as an opt-in instead.
- *Concurrency model checking in tester:* the decision tree in `tester.md` step 2 RECOMMENDS it for the right change shapes; framework doesn't ship the tooling. Stack-specific tools live in consumer projects.

**How to apply:**
- New AI-failure-mode checks in reviewer.md sections 5a-5f are FIRST-CLASS, not advisory. Flag at CRITICAL severity when matched.
- Developer must include `Assumptions:` section in non-trivial commit bodies. Reviewer's section 5c challenges this.
- Tester anti-flakiness rules apply to every test written; review-time flag if violated.
- `verify-deps.sh` is best-effort and non-blocking — findings go to `.claude/.dep-verification-issues.md` for the next agent turn to see. Hook does not interrupt the loop.
- `/healthcheck --verify N` is the gate before automating against /healthcheck output; doctor Check 9 enforces it.

**Source:** `deep-research-report.md` at project root, dropped by user on 2026-05-14. 13-row issue taxonomy synthesised from ~30 cited studies on AI-written code defects. Gap-mapped against the framework's existing surface; 11 changes implemented this session, full mapping preserved in FRAMEWORK-SUGGESTIONS.md.

---

## 2026-04-26 — Council of Agents: 5 advisors + chairman, orchestrated by main session

**Decision:** Ship a `/council` deliberation feature for high-stakes decisions. Six new agents under `.claude/agents/council/`: five advisors (Contrarian, First Principles, Expansionist, Outsider, Executor) + Chairman. Main session orchestrates a 5-phase protocol — frame → 5 parallel takes → anonymise responses to A-E → 5 parallel peer reviews → chairman synthesis → transcript.md + report.html under `.claude/council/<run-id>/` (gitignored).

**Why this shape:**
- **Five advisors with distinct cognitive styles** mirror the source spec (LLM Council). Each is single-persona; the orchestrator passes a Mode 1 (initial take) or Mode 2 (peer review) prompt to switch behaviour. Cleaner than dual-mode personas.
- **Anonymisation is done by the orchestrator**, not the advisors. Advisors don't see "this is yours" labels — they see A-E in randomised order, removing self-deference and authority-deference biases.
- **Parallel spawn in single message** for both Phase 1 and Phase 2 — sequential calls would let later advisors anchor on earlier output.
- **Chairman writes both files directly**, avoiding a post-processor script and keeping council self-contained.
- **No project-paths block on council Task prompts** — council reasons about decisions, not file layouts.

**Alternatives rejected:**
- *Dual-mode personas (each advisor handles initial + peer review modes internally):* tested in early sketch; cluttered the agent prompts and made debugging harder. Mode-by-orchestrator-prompt is cleaner.
- *Chairman synthesis without HTML report:* spec-driven feature; the visual report is the artefact users actually open.
- *Single peer-reviewer agent (instead of all 5 advisors reviewing):* loses the "each advisor brings their own lens to peer review" property that's the whole point of multi-perspective review.
- *Storing council outputs in git:* deliberations are local artefacts; gitignored to avoid noise and PII risk.

**How to apply:** Use `/council` for decisions with real stakes — "should we X or Y," architectural pivots, expensive-to-be-wrong calls. Don't use for factual questions, simple creation tasks, or casual "should I" without genuine tradeoffs. Trigger words documented in the command runbook.

**First production use (2026-04-26):** contract-drift mitigation question. Council demanded validation of the 2 → 8 → 12 trendline before any automation shipped — that demand uncovered BUG-001 (/healthcheck append-only file causing subagent anchoring) and prevented building a heuristic against a polluted metric. Council earned its keep on the first real run.

---

## 2026-04-26 — Drop contract-drift mitigation pending clean rebaseline

**Decision:** Remove "contract-drift acceleration mitigation" from STATUS.md Next Up. Don't ship Option A (PostToolUse hook), Option B (doctor-time mtime comparator), or the chairman's trimmed-down aggregate-counter variant.

**Why:** Premise was a 2 → 8 → 12 trend in /healthcheck drift counts across recent cycles. The 2026-04-26 stability experiment proved /healthcheck output was non-deterministic on unchanged trees (44 → 34 → 30 across 3 runs). Root cause: BUG-001 — append-only `review-findings.md` caused subagents to anchor on prior findings. The historical trend was measured against the same structurally-vulnerable file, so we can't trust it as decision input.

**Reinstatement criteria:** if a fresh-session rebaseline (after BUG-001 ships, no priming language) produces stable drift counts across three runs AND those stable counts show real growth across separate development sessions, the item returns. Otherwise it stays dropped.

**Alternatives rejected:**
- *Ship the trimmed-down counter anyway* — even with BUG-001 fixed, the historical numbers (which motivate the work) are unreliable. Building on them is Goodhart-shipped-on-purpose.
- *Defer indefinitely without removal* — clutters Next Up; better to drop with rationale and reinstate cleanly if data warrants.

**How to apply:** any future "contracts are drifting, we should automate" reasoning should first check whether /healthcheck has been re-baselined since 2026-04-26. STATUS.md Next Up #1 explicitly tracks the rebaseline.

---

## 2026-04-24 — Framework layout restructure: 00_framework/ → .claude/framework/, state files → .claude/

**Decision:** Eliminate `.claude/framework/` from the project root. All framework scripts move to `.claude/framework/`. All root state files (TASKS.md, STATUS.md, DECISIONS.md, ECOSYSTEM.md, GOTCHAS.md, FRAMEWORK-SUGGESTIONS.md, claude-progress.txt, framework-metrics.md) move flat under `.claude/`. Only CLAUDE.md, CLAUDE.framework.md, and .gitignore remain at root.

**Why:** Consumers reported the `.claude/framework/` directory creating "a massive mess" in their project trees. Mixed framework machinery and project files at root makes repos hard to navigate.

**Alternatives rejected:**
- *Rename .claude/framework/ → framework/* — still at root, doesn't solve the pollution.
- *Move state files to .claude/state/ subdirectory* — extra nesting adds no value; keeping them flat under .claude/ is consistent with review-findings.md already living there.
- *Move CLAUDE.framework.md to .claude/* — requires @-import syntax in CLAUDE.md; version-compatibility risk. Deferred.

**How to apply:** See `.claude/framework/docs/specs/SPEC-framework-restructure.md` for full layout, acceptance criteria, and migration plan. Consumer migration runs automatically via `apply-update.sh` (detects old structure → calls `migrate-layout.sh`).

---

## 2026-04-24 — PostToolUse format/lint hooks: zero telemetry, cause unknown

**Decision:** Log as FRAMEWORK-SUGGESTIONS entry; do not attempt a fix in this session. Format/lint hooks wired under `PostToolUse` with `Write|Edit|MultiEdit` matcher show zero events in telemetry (not even "skipped" entries), despite the scripts being logically correct. Root cause is unconfirmed — likely either (a) PostToolUse invocation environment differs from PreToolUse on Windows VSCode, or (b) all prior-session edits used Bash rather than Write/Edit tools.

**Why not fix now:** Root cause unconfirmed; fixing without reproducing risks introducing a false fix.

**How to apply:** Observe whether format/lint events appear during the current session's Write/Edit calls. If still zero after this session, escalate to a focused investigation (add unconditional log-at-entry diagnostic to auto-format.sh).

---

## 2026-04-18 — `/wrapup` is separate from `/housekeeping`

**Decision:** End-of-session context-flush lives in a dedicated `/wrapup` command rather than being folded into `/housekeeping`.

**Why:** The two have different cadences. `/wrapup` is per-session — runs every laptop-close, machine switch, or fresh-context restart. `/housekeeping` is periodic — runs when archival thresholds hit (TASKS.md Done > 20, DECISIONS.md > 50, review-findings backlog). Folding them means either (a) every session-end wastefully runs heavyweight archiving, or (b) the context-flush check gets skipped on days archival isn't due — the opposite of what we want.

**Alternatives rejected:**
- *Fold into `/housekeeping` with a "mode" flag* — cognitively heavier and doesn't solve the cadence mismatch, just delays the decision to the user each invocation.
- *Leave it as manual discipline* — users forget. That's exactly the friction a command fixes.

**How to apply:** `/wrapup` at end of session emits either "✓ Safe to close" or a numbered residuals list. If archival thresholds look close, it cross-links to `/housekeeping`. Both commands stay small and single-purpose.

---

## 2026-04-18 — Framework-self redirect via `.claude/framework/self/` + gitignored flag

**Decision:** Upstream framework-dev state (`TASKS.md`, `STATUS.md`, `DECISIONS.md`, `claude-progress.txt`, `framework-metrics.md`) lives under `.claude/framework/self/`. A gitignored `.claude/framework-self.flag` (present only in the upstream clone) toggles redirection in hooks, doctor, and cold start.

**Alternatives rejected:**
- *Single-tree with release-time reset* — error-prone; a missed reset before push leaks state to the next consumer clone.
- *Template files at `.claude/framework/templates/` + bootstrap script* — adds a mandatory install step for consumers; clone-only consumers would be broken.
- *Branch-based separation (main = template, dev = live)* — heavy cognitive overhead; every framework change becomes a merge chore.
- *Multi-project mode with `framework-dev` as the active project* — recursive dogfooding; active-project state lives at root per design, which doesn't fix the leak.

**Why this design wins:** Flag-off (the consumer default) = root is canonical. Flag-on (upstream-dev only) = `.claude/framework/self/` is canonical. Runtime redirect; no manifest churn. Consumers cloning fresh see an inert `.claude/framework/self/` directory with a README explaining they can ignore it.

**How to apply:** See `.claude/framework/self/README.md` and the cold-start framework-self-mode paragraph in `CLAUDE.framework.md`.

---

## 2026-04-18 — Stack-agnostic with auto-detect

**Decision:** Framework hooks (`auto-format.sh`, `auto-lint.sh`), `.claude/framework/init.sh`, agent scope paths, and `agent_docs/*` templates dispatch by manifest presence — no blessed default stack.

**Rejected alternatives:** Node-blessed + swap-in templates; fix the obvious leaks only; defer and log.

**Why:** Downstream non-Node projects were getting contradictory instructions. Local patches didn't survive `apply-update.sh`. Stack-agnosticism removes the whole class of friction.

**How to apply:** When writing new hooks/scripts, dispatch by extension + tool availability. When writing command runbooks, describe stack-neutral actions ("run tests" not "npm test") and defer specific commands to CLAUDE.md. See `memory/project_stack_agnostic_policy.md` for the operating detail.
