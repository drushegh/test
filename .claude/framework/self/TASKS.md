# Task Board — Framework Development

Last updated: 2026-06-12 (session 20: TASK-032..043 ALL Done + pre-push healthcheck (clean). New: /fleet (042), skills-check (043). Suite 124/124. Todo: TASK-021/022)

Framework-dev task board. This is the live TASKS.md used when
`.claude/framework-self.flag` is present. Root `.claude/TASKS.md` stays as
the empty template for consumers.

---

## Feature Lane

<!-- Full lifecycle for planned work: Todo → In Progress → Ready for Review → In Review → Ready for Test → Testing → Done -->

### In Progress

### Ready for Test

### Todo (Priority Order)

#### TASK-022 — Subagent context-bundle assembler (architect pass) [P2]
**Source:** second research pass (synthesised, not battle-tested) + revives the 2026-04-26 HC8-triage deferred item (STATUS Next Up: main session prepends a `## Project paths` block to subagent prompts).
**Why:** passing the right context slice (paths, active contracts, task ACs, relevant GOTCHAS) to a framework subagent is currently manual/ad-hoc. The mature pattern (incl. Claude Code's own) is **"don't inherit context — read a scoped anchor"**: subagents get fresh context + a canonical anchor + append findings back.

Design (architect, then developer) a **per-task ephemeral context bundle**: at subagent spawn, auto-assemble ONE scoped file from (relevant contracts + relevant GOTCHAS + the task's dependency edges + project paths/config) so the subagent reads a minimal correct anchor instead of re-deriving or being hand-fed.
- AC1: architect produces the design (bundle contents, where it's written, lifecycle/cleanup, how "relevant" is scoped from the claimed task) — explicitly weigh under-context (subagent guesses) vs over-context (token bloat + priming that risks BUG-001 anchoring).
- AC2: define the assembly mechanism in the file-based model (no new agents, no binary).
- AC3: decide the boundary with the existing "skip cold start" subagent instruction and the deferred `## Project paths` prepend — supersede or compose.
- AC4: flagged as a design direction (claude.ai's construction, unproven) — architect validates before any build.
- AC5 (added 2026-06-12, fleet sweep — harvey/harveyTest parallel-subagent state-file races): the design must also cover state-file write serialisation for parallel subagents (who may write STATUS/progress — orchestrator-serialised vs per-subagent return values; harvey's coordinator pattern is prior art).

### Blocked

### Done

#### TASK-044 — Skills tier hardening: discovery, companions, full suggest map, adopted-feedback registry [P2] ✓
**Commit:** be33651 (framework) + c0a1a1d (skills repo) | **Completed:** 2026-06-12
**Source:** user direction 2026-06-12 — "read the skills repo, sanity check, handle cross-references, make the README framework-legible, solve non-adopter discovery + upstream skill updates + consumed-feedback cleanup; push both repos."

- **Skills repo audit (29 skills):** all clean — frontmatter names match dirs, descriptions ≤771 chars (limit 1024), no CRLF, no broken intra-skill reference indexes, all cross-skill references resolve to real catalogue dirs (4 apparent danglers were source attributions/reference filenames). Committed the 19 untracked skills + README + new .gitattributes (LF pin — synced content must not carry CRLF into consumers).
- **Cross-references:** policy decided + documented both sides: boundary pointers are advisory NAMES, not hard links — missing companion = less depth, never breakage. skills-sync now prints a **companion advisory** after sync (greps synced skills for `-development` tokens that exist in the upstream clone but aren't in SKILLS_SELECTED). 2 bats.
- **Non-adopter discovery (contract:skills-sync extended FIRST):** skills-check.sh, when `.skills-version` is absent, runs the --suggest stack detection (throttled via telemetry marker, default 7 days) and raises `.claude/.skills-suggestion.md`; permanent opt-out = committed `.claude/.skills-declined`. Cold-start step 1 wording handles the flag (set up / not now / never). Gitignore wiring upstream + init-framework-version ephemera list (which was ALSO missing the TASK-043 update flag — pre-existing gap fixed). 4 bats.
- **--suggest full map:** bash/powershell (root+scripts/, deliberately NOT .claude/), godot/unity/unreal, azure (azure.yaml/bicep), devops (.github/workflows|azure-pipelines), power-bi (pbip/tmdl), copilot-studio (.mcs.yml), dynamics (pcfproj), three-dep → threejs; cross-cutting secure/accessibility mentioned, never stack-claimed. 2 bats.
- **Skills README framework-legibility:** new "Framework integration (CCMAF)" section = the consumption contract in the skills repo's own words (dir name = identity/selection token, naming convention, SKILL.md mandatory + description <1024, cross-refs advisory, every main commit is a release, LF/no hidden chars because config-security scans synced skills) + add-a-new-skill checklist; line-count claim fixed to match reality (85–180).
- **Consumed-feedback cleanup:** `framework/docs/ADOPTED-FEEDBACK.md` registry (manifest-shipped) seeded with the session-20 fleet-sweep adoptions; /housekeeping gains an "Adopted-feedback reconciliation" step (prune local GOTCHAS/SUGGESTIONS entries upstream has shipped); doctor **Check 12** WARNINGs on pre-TASK-027 leaked upstream framework-dev entries in consumer state files (fingerprint titles; upstream repo unaffected — its dev content lives in self/). 2 bats.
- **Framework README refresh:** skills section added; /fleet + /security rows; doctor "8 invariants" → 12 checks; stale `project/` removed from the structure tree; fleet/tests/ machinery rows; skills + adopted-feedback paragraphs under Updating. Doctor README gained missing rows 11 (pre-existing gap) and 12.

#### TASK-021 — OTel-style span schema for telemetry [P2] ✓
**Commit:** 7ece316 | **Completed:** 2026-06-12
**Source:** second research pass — OpenTelemetry GenAI semantic conventions (schema only, NOT a backend/collector). Contract: `contract:telemetry-schema` (written FIRST, status:stable).

- AC1 ✓ correlation model defined in the contract: session (trace root, `session_id`) → task (`task_id`, RESERVED) → agent handoff (`agent_id`, RESERVED — payloads carry no subagent marker, TASK-038) → tool call (`tool_use_id`, emitted fail-soft on Pre/PostToolUse). `event_id` unique per line. All 8 emitters migrated (format/lint/verify-deps via dispatcher env + standalone path, drift-guard, stop+cost-tracker, bash-guard py, test-filter, review-scraper).
- AC2 ✓ flat snake_case keys with the OTel mapping documented in the contract (dotted names rejected — break every grep/printf for zero gain); per-hook `outcome` vocabularies UNCHANGED; new canonical `outcome_class` enum (ok|flagged|blocked|skipped) emitted at source; `detail` reserved for verbose/droppable content; `schema:2` marker.
- AC3 ✓ rollup gains `sessions`/`schema_mix`/`by_session` (blocked/flagged/stop_blocked/drift_fires per session; v1 legacy class mapping lives only in rollup's `classof`); analyse gains the stop-block session-concentration finding (INSIGHTS_MIN_SESSIONS=5, STOP_BLOCK_SESSION_RATE_HIGH=0.50 in thresholds.conf) + "across S sessions" header; session-summary windows by session_id (mid-session Stop no longer splits the window) with the marker heuristic as v1 fallback — TSV contract unchanged, exactly the TASK-034 migration point.
- AC4 ✓ jq/date/bash only, no new dependency; `event_id` is the TASK-015 replay/dedup anchor.
- **Live-fire bonus:** the hooks ran the new code DURING the implementing session — first v2 lines were corrupt with raw \r. Verified mechanism (bug-sweep follow-up): winget jq emits CRLF on every line; MSYS bash `$()` strips it (pre-existing `$(jq -r)` consumers were always fine) but `read < <(jq -r)` keeps it — the new read-based extraction re-exposed it. CR-strips at every jq-fed read site + telemetry_emit choke point (GOTCHAS). Also fixed: rollup's `jq -s` died on one malformed line → line-tolerant `fromjson?`; verify-deps `get_added_lines` strips \r from CRLF manifests (hardening).
- Tests: +7 bats (5 hooks: session_id/event_id/outcome_class per emitter family, dispatcher propagation, strict-parse CRLF pin; 2 insights: by_session rollup w/ malformed-line tolerance, session-window vs mid-session marker). Suite 131/131; doctor, pattern-scan, config-security clean. Verified live on 3,098 real events (v1+v2 mixed).

#### TASK-042 — /fleet: consumer status sweep across sibling repos [P2] ✓
**Commit:** e99097f | **Completed:** 2026-06-12
- AC1 ✓ `framework/fleet/fleet-status.sh [ROOT]` (default repo parent) tables pinned SHA / layout era / skills opt-in / dirty count per consumer; `--format text|md`. Doctor-count column dropped from the plan and replaced with a read-only design (running consumer doctor would write their flag — violates AC2); upstream-freshness is the opt-in `--check-remote` column instead.
- AC2 ✓ read-only, fail-soft per repo; bats asserts the no-mutation invariant (no doctor flag written into a scanned consumer).
- AC3 ✓ thin `/fleet` command; shipped via manifest (fleet/ dir-mirror + fleet.md file entry).
- AC4 ✓ 7 bats over synthetic siblings (post-layout, PRE-migration, non-framework ignored, dirty count, md format, empty root, read-only).
- Live value confirmed: flagged babynamey + claude-usage-tray PRE-migration, harvey/prompt-picker on older pins.

#### TASK-043 — skills-check.sh: notify when synced skills are behind upstream [P2] ✓
**Commit:** 60eca69 | **Completed:** 2026-06-12
- AC1 ✓ contract:skills-sync extended with SKILLS_LAST_CHECKED + SKILLS_CHECK_INTERVAL_HOURS + the skills-check interface.
- AC2 ✓ `update/skills-check.sh` ls-remote pinned-vs-HEAD → writes `.skills-update-available.md` (lists SKILLS_SELECTED + sync command) / clears on up-to-date / silent when not opted in.
- AC3 ✓ DA-C4: flag survives throttled run + network failure; cleared only by a live up-to-date check.
- AC4 ✓ cold-start wiring (CLAUDE.framework.md step 1, after the framework update check); gitignore covers the flag; rides update/ dir-mirror.
- AC5 ✓ 7 bats (behind/up-to-date/throttle/network-fail/not-opted-in/malformed/last-checked-bump).

#### TASK-037..041 — Fleet-sweep batch: five consumer-reported framework updates [P2/P3] ✓
**Commits:** 296809b / 07660ae / 9557d81 / 2be7ede / e9db2d7 | **Completed:** 2026-06-12
**Source:** 2026-06-12 fleet sweep of 31 GOTCHAS/FRAMEWORK-SUGGESTIONS files across 15 consumer projects; user direction "do all the updates you suggest are needed".

- **TASK-037 (296809b) findings persistence:** tester persists its own date-stamped section to test-findings.md (write-only prepend, BUG-001 guard); reviewer stays Write-less by design — /review step 5 makes orchestrator persistence MANDATORY+FIRST and reviewer output ends with a `PERSIST:` trailer. Design note: deliberately did NOT give reviewer a Write tool (config-security posture).
- **TASK-038 (07660ae) subagent RED-LINES:** behavioral-principles §7 — no commit/push/lifecycle transitions without a by-name grant (`allow_commit`); developer.md points at it; reviewer checklist 6b (orchestrator-path check). PreToolUse-hook variant DEFERRED — hook payloads carry no reliable subagent marker today.
- **TASK-039 (9557d81) command-collision notice:** apply-update compares an about-to-be-overwritten `.claude/commands/*` file against the PINNED upstream version (CRLF-normalised, unshallow-on-demand) — stock-evolving stays silent, customised gets a loud post-update notice + HEAD recovery hint. 2 bats cases (notice + anti-noise control).
- **TASK-040 (2be7ede) computed push-state:** insights/push-state.sh (branch / ahead-behind / uncommitted, read-only, exit 0); /wrapup verdict includes it and forbids hand-written push prose; consumer STATUS template annotated. 2 bats cases.
- **TASK-041 (e9db2d7) council self-preference:** Mode-2 prompts in council.md + all five advisors require privately identifying the likely-own response and excluding it from Strongest (lens criteria preserved); chairman weights blind-spot/missed signals above Strongest votes.
- Also: TASK-022 gained AC5 (parallel-subagent state-file write serialisation — harvey's coordinator pattern as prior art).
**Verified:** suite 110/110, doctor clean, pattern-scan clean, config-security 0 CRITICAL.

#### TASK-036 — Skills-repo sync: per-project language skills from a separate upstream [P2] ✓
**Commit:** 32778d7 | **Completed:** 2026-06-12
**Source:** user direction 2026-06-12; repo `git@github.com:drushegh/CCMAF---Skills.git` (python skill incoming — repo is LICENSE-only today).

- AC5 first ✓ `contract:skills-sync` added to ECOSYSTEM (layout tree, ownership table, machine-readable block) BEFORE code: `.claude/skills/` is the third ownership domain — `SKILLS_SELECTED` dirs are skills-repo-owned (sync-managed), all others consumer-local; apply-update/manifest never touch skills.
- AC1 ✓ `.claude/.skills-version` (URL/branch/pin/selection); missing file → printed setup template + exit 2 (the init path — no extra script surface).
- AC2 ✓ `update/skills-sync.sh` selective clone-and-copy with per-skill dirty rules: tracked → porcelain (BUG-002 space class); entirely-untracked previous sync → byte-identical allowed (idempotent re-run), different refused until committed. Per-skill refusals continue others, exit 1 at end. Rides the existing `update/` dir-mirror — no manifest line needed.
- AC3 ✓ 11 bats cases on local-dir skills-upstream fixtures, incl. the empty-repo skip and traversal-name rejection. Suite 106/106.
- AC4 ✓ `--suggest` (suggest-only), probes root + 01_Project/; wired into init.sh stack-detect gated on `.skills-version` existing (chosen over doctor INFO — no findings-flag interrupt; zero nag for non-adopters).
- AC6 ✓ no submodules; ATTRIBUTION.md recommended in the skills repo, not enforced here.
- Live smoke vs the real repo ✓ (pre-skill): clean clone, graceful skip, pin untouched.
- **Real e2e ✓ (same day, after the user added the skill):** `python-development` (SKILL.md + 9 references) synced into a fresh consumer fixture, pin rewritten to the real SHA (3c42ac7), idempotent re-run clean. The skill was untracked in the user's mirror — committed locally (3c42ac7) so clone could see it; **push left to the user**. Follow-up 8bba528: --suggest now emits the catalogue's REAL dir names (python-development) so suggestions paste into SKILLS_SELECTED verbatim.
- **Remaining:** user pushes the skills repo; dogfood on a consumer project (its own .claude/.skills-version, SKILLS_SELECTED="python-development").

#### TASK-035 — Post-edit hook dispatcher: one PostToolUse entry, one git spawn [P2] ✓
**Commits:** 057659d (AC1-3,5) + f302ddd (AC4) | **Completed:** 2026-06-12
**Source:** 2026-06-12 brainstorm item 6; deep-analysis S4.

- AC1 ✓ `hooks/post-edit-dispatch.sh` reads stdin/jq/normalize/`git rev-parse` ONCE, hands results to the three hooks via `CLAUDE_POSTEDIT_FILE`/`CLAUDE_POSTEDIT_ROOT`. Design choice: precomputed env vars over sourceable-function refactor — the three hooks stay intact standalone scripts (legacy 3-entry registrations keep working bit-for-bit; independently testable), each gaining only an "env present → trust it" branch.
- AC2 ✓ gates untouched — each hook still runs its own `hook_enabled`; pinned by a dispatcher bats case (`CLAUDE_DISABLED_HOOKS=format` → lint still fires).
- AC3 ✓ measured (Windows git-bash, 10-iteration mean, plain .ts edit): git spawns 3 → 1; wall-clock ~1300ms → ~890ms per edit (~32%). Pinned by a PATH-stubbed-git regression asserting ≤2 spawns.
- AC4 ✓ landed on named approval ("Yes — collapse to dispatcher"): settings.json PostToolUse = one dispatcher entry. Knock-on handled: doctor Check 1 taught indirect wiring (dispatcher children aren't "dead code"; true orphans still flagged — pass + control tests). Consumers keep their 3-entry form; the shipped dispatcher + doctor's "unreferenced" WARNING on it is the adoption path.
- AC5 ✓ 5 dispatcher cases + 2 doctor cases; direct-path per-hook tests unchanged. Suite 95/95, doctor clean, config-security 0 CRITICAL.

#### TASK-034 — /wrapup session efficacy line (telemetry read-back) [P2] ✓
**Commit:** 57c73b5 | **Completed:** 2026-06-12
**Source:** 2026-06-12 brainstorm item 5; telemetry was written but never read back.

- AC1 ✓ `insights/session-summary.sh` — read-only, always exit 0; window = events after the last cost-tracker marker (approximation documented in header: a mid-session Stop splits windows; fresh installs have no marker → whole file). Tool-call figure is the PREVIOUS session's (marker only exists at session end) — labelled as such. Parsing is line-tolerant (`fromjson?`): python-emitted events use spaced JSON, which grep-style matching silently misses.
- AC2 ✓ /wrapup final verdict leads with the line; fail-soft on missing jq/events/parse failure + an explicit script-missing fallback in the runbook.
- AC3 ✓ 3 bats cases: window boundary (pre-marker excluded, malformed tolerated, spaced JSON counted), fail-soft, no-marker fallback.
- AC4 ✓ all jq isolated in `mine_window_counts()` → flat TSV contract; TASK-021 migration = that one function. Live run on real telemetry verified.
- Bonus: insights/README rows for session-summary.sh + instinct-miner.sh (pre-existing doc gap).

#### TASK-033 — Instinct-miner precision: mine only genuine human turns [P2] ✓
**Commit:** 01a3140 | **Completed:** 2026-06-12
**Source:** 2026-06-12 brainstorm item 4; observed 2026-06-11 — 34 candidates, ~33 noise.

- AC0 ✓ schema characterised from 5 live transcripts and documented in the script header: user-type entries come as tool results (`toolUseResult`), harness meta turns (`isMeta` — hook feedback + skill/command runbook expansions, THE noise source), subagent sidechains (`isSidechain`), and genuine human turns. `promptSource` rejected as discriminator (version-dependent; 16/26 genuine turns lack it).
- AC1 ✓ three-level filter: entry (toolUseResult/isMeta/isSidechain), text-item (harness-injection tag prefixes `<ide_*`/`<system-reminder`/`<command-*`), line (`<system-reminder>` ranges + fenced ``` blocks stripped).
- AC2 ✓ fixture: 2 corrections buried in six noise classes → exactly the 2 mined; new bats case verifies each class is excluded.
- AC3 ✓ before/after on real transcripts: c90fe100 (the observed blast) 34 → 0, all noise was isMeta expansions; 23b5fe94 15 → 15, all genuinely user-sent (majority = UNFENCED research pastes inside human turns — documented limitation: indistinguishable from typed text without heavier heuristics).
- AC4 ✓ propose-only, format/thresholds untouched.
- Test-hermeticity note: the miner roots itself via `git rev-parse` on CWD — the bats case runs it from inside $REPO (first draft leaked the flag into the real repo; caught and noted in the test).

#### TASK-032 — Update-system test tier: 25 bats tests for apply-update / check-updates / migrate-layout / doctor [P1] ✓
**Commit:** 7851515 | **Completed:** 2026-06-12
**Source:** 2026-06-12 brainstorm item 3; deep-analysis coverage map (the update system destroys files on every consumer yet had ZERO tests).

- AC1 ✓ `update_helpers.bash` builds a synthetic upstream (2 commits on main) + consumer fixtures in $BATS_TEST_TMPDIR; `git clone` of a local directory path stands in for the GitHub remote — fully offline. Fixtures carry the REAL scripts so SCRIPT_DIR-relative root resolution works as shipped.
- AC2 ✓ apply-update (9 tests): file-overwrite, dir-mirror, upstream-removal, dirty refusal x3, DA-M5 warning + local-manifest fallback, DA-C3 staging-failure tree-intact, pin/LAST_CHECKED rewrite, missing-version exit 2. Staging failure simulated via PATH-shadowed `cp` (not the planned unwritable-dir pre-create — the staging path embeds the script's $$ so it can't be predicted, and chmod-based unwritability is a no-op on Windows git-bash; the cp stub fails the same phase-1 code path deterministically on all platforms).
- AC3 ✓ check-updates (5 tests): throttle proven side-effect-free via unreachable URL; DA-C4 flag survival (throttled run AND network failure); cleared only on live up-to-date; flag content (both short SHAs, commit subjects, To-apply section).
- AC4 ✓ migrate-layout (6 tests): both detection triggers, full invariants (moves + CLAUDE.md/.gitignore rewrites + commit), idempotent re-run, .env.local NOT swept (DA-H5).
- AC5 ✓ doctor (5 tests): clean-tree silence + each CRITICAL class (missing hook, link-style pointer, manifest gap, empty version field).
- AC6 ✓ offline, hermetic (git status clean of fixture leakage), run-tests.sh 84/84.
- **Found BUG-002 while writing AC4:** migrate-layout's dirty-tree refusal never fired (see Bug-Fix lane). Fixed same commit; regression test verified to fail against the unfixed script.

#### TASK-031 — DA round remainder: 12 MEDIUM + 4 LOW findings fixed [P2] ✓
**Commit:** 28c184a | **Completed:** 2026-06-12
**Source:** review-findings.md Deep Framework Analysis; user authorisation "proceed with the rest of the fixes".

- M1 healthcheck runbook (renumber/Part-5/--verify wording), M2 housekeeping archive paths, M3 command stubs → CLAUDE.framework.md steps 0-9, M4 statusline uniform registration, M5 apply-update upstream-manifest warning, M6 init-framework-version full ephemera gitignore, M7 instinct-miner ambiguity refusal, M8 bats pinned 1.13.0, M9 scanners cover skills/, M11 dead .last-security touch removed, M12 drift-guard conf extraction instead of source (injection canary verified), M13 blocked-command echo truncated
- L1 cache comment, L2 four wording/context fixes (incl. healthcheck Part 1.3 now passes detected shape), L3 gitignore asymmetry note, L5 verify-deps blocklist extension
- Deferred: L4 (historical commit msg), L6 (consumer-name sweep → go-public checklist). M10 landed with TASK-029.
**Verified:** 59/59 bats, doctor clean, pattern-scan clean, config-security baseline unchanged, settings.json valid.

#### TASK-030 — README images render in private repo: in-main .github/assets/ [P3] ✓
**Commit:** a898171 | **Completed:** 2026-06-11
**Source:** user report — clicking README images gave 404. Root cause: private repo; raw.githubusercontent cross-branch URLs only render publicly; GitHub serves RELATIVE in-repo paths authenticated.

- 6 webp moved from the orphan assets branch into .github/assets/ on main (byte-identical); README rewritten to relative paths; renders now (private) and after going public
- Trade-off accepted by user direction: +1.3 MB per clone (supersedes the lean-clone orphan-branch design)
- Orphan assets branch now obsolete; remote deletion classifier-blocked (destructive remote op, not named by user) — left for user (GitHub UI trash icon or named approval)

#### TASK-029 — DA improvements round: all 8 HIGH findings fixed (DA-H1..H8) [P1] ✓
**Commit:** a2ad224 | **Completed:** 2026-06-11
**Source:** review-findings.md "Deep Framework Analysis" HIGH section; follows TASK-028 (CRITICALs).

- DA-H1: normalize_tool_path() in hook-common.sh (Windows drive-letter paths → /f/x form) wired into verify-deps (was a silent no-op on Windows) + auto-format/lint; 4 unit tests
- DA-H2: all 6 council agents gain §6 external-content-is-data; chairman write-path constrained to .claude/council/ with traversal rejection
- DA-H3: CLAUDE.framework.md enforcement claim corrected (Stop hook checks 3 files; DECISIONS/ECOSYSTEM are convention-only)
- DA-H4: v4 guide contracts path → root contracts/ (project-owned)
- DA-H5: git add -A → enumerated paths in wrapup.md, migrate-layout.sh, MIGRATION.md (both flows)
- DA-H6: .drift-state atomic tmp+mv write
- DA-H7: enforce-state anchored filename matching on file-paths-only log (+2 regression tests); verify-deps pipefail grep guard
- DA-H8: doctor Check 9 portable mtime chain + Check 5 mktemp
**Verified:** 59/59 bats, doctor clean, pattern-scan clean, config-security 0 CRITICAL. MEDIUM/LOW triage pending (review-findings.md).

#### TASK-028 — Deep-analysis sweep: all 8 CRITICAL findings fixed (DA-C1..C8) [P0] ✓
**Commit:** 4312933 + f504ade + 63c765a | **Completed:** 2026-06-11
**Source:** user-requested deep analysis (5 parallel audit agents; findings checkpointed 58e9d04 in review-findings.md). Named user authorisation "fix all critical now" covered the two settings.json items.

- DA-C1/C2: dangerous-command guard — python3-first dispatch in settings.json; rm detection rewritten as per-segment tokenizer (false-positive on absolute subpaths fixed — confirmed live; split/long flags, sudo, ~, drive roots now caught). 8 new bats cases.
- DA-C6: ssh/aws deny rules extended to Edit/Write + tilde-independent globs. Rejected: settings.json self-edit deny (severs doctor propagation).
- DA-C3: apply-update stage-then-swap (tree untouched until staging succeeds; swap failure prints git-restore command).
- DA-C4: check-updates flag survives throttled runs and network failures.
- DA-C5: scrape-review-findings blank-line undercount fixed + bats regression.
- DA-C8: bash>=4 guards (doctor/apply-update/run-tests/instinct-miner) + doctor Check 11 GNU-toolchain probe. Bonus catch: zero-width detector's grep -P was dead on git-bash too — rewritten as byte-level LC_ALL=C match with leading-BOM exception.
- DA-C7: .gitattributes pins LF for machine-parsed types (CRLF-class root fix); working copies refreshed.
**Verified:** 53/53 bats, doctor clean, config-security baseline unchanged, pattern-scan clean. Remaining DA findings (8 HIGH / 13 MEDIUM / 6 LOW) open in review-findings.md for the improvements round.

#### TASK-026 — settings.json hook-pattern uniformity (bash -c + $CLAUDE_PROJECT_DIR) [P3] ✓
**Commit:** e4e80e9 | **Completed:** 2026-06-10
**Authorisation history:** twice classifier-blocked as self-modification (general
autonomy grant, then blanket "proceed with everything" — both ruled insufficient);
landed once the user gave a named approval ("you have permission to do task 026").
The TASK-008 precedent held throughout: no workarounds attempted.

- All four remaining old-pattern hook commands (UserPromptSubmit drift-guard,
  PreToolUse block-dangerous + filter-test-output, Stop enforce-state) migrated from
  `cd "$(git rev-parse --show-toplevel)" && …` to the GOTCHAS-recommended uniform
  `bash -c 'cd "$CLAUDE_PROJECT_DIR" && …'` pattern already used by PostToolUse.
  All seven registered hooks now share one invocation shape; one less git spawn per fire.
- Consumer note: settings.json is project-owned (not manifest-updated) — existing
  consumers keep their working old-pattern entries; fresh clones get the uniform set.
  No doctor check added: the old pattern is functional for these events, so there is
  nothing to prescribe downstream.
**Verified:** settings.json valid JSON; all 7 hook commands confirmed on the new
pattern via jq; doctor clean (Check 1 extracts hook paths from the new strings);
config-security baseline unchanged (0 CRITICAL).

#### TASK-027 — Consumer clean templates: ECOSYSTEM/GOTCHAS/SUGGESTIONS join the self-mode redirect [P2] ✓
**Commit:** 801111a | **Completed:** 2026-06-10
**Source:** user decision ("proceed with everything", 2026-06-10) resolving STATUS Next Up #3. Executed via the documented contracted path: **contract updated first**, then the redirect widened, then root copies reset.

- `contract:state-file-paths` updated (in its new home, `framework/self/ECOSYSTEM.md`): redirect set is now EIGHT files (was five); the "ECOSYSTEM/GOTCHAS/FRAMEWORK-SUGGESTIONS always stay at .claude/" note replaced with the clean-template rule; history note preserved. Supersedes the same-day no-build decision (which was correct at the time — the user hadn't decided yet).
- Content moved: `.claude/ECOSYSTEM.md` → `framework/self/ECOSYSTEM.md` (framework-layout, state-file-paths, migration-behaviour contracts + ownership table), `.claude/GOTCHAS.md` → `framework/self/GOTCHAS.md` (7 framework-dev entries), `.claude/FRAMEWORK-SUGGESTIONS.md` → `framework/self/FRAMEWORK-SUGGESTIONS.md` (adopt/reject audit trail). Each carries a moved-here header.
- Root copies reset to clean consumer templates. ECOSYSTEM template examples are now deliberately `status:draft` (developer agent refuses leftovers — closes a v1-era footgun where examples shipped `status:stable`).
- References updated: CLAUDE.framework.md step-0 list (5→8 files), self/README, instinct-miner.sh (its GOTCHAS/SUGGESTIONS guidance paths now follow STATE_PREFIX — the old always-at-root override existed only because of the old contract), framework-layout tree self/ listing, v4 guide §11 pointer.
- **Consumer impact:** none on existing clones (state files aren't in the manifest — their current root copies stay theirs). Fresh clones start clean. instinct-miner fix propagates via the `insights/` dir-mirror.
**Verified:** doctor clean, pattern-scan clean, bats suite pass, config-security baseline unchanged.

#### TASK-025 — Spec-doc rewritten for v2: 2,151 lines → 418, zero stale refs [P2] ✓
**Commit:** 5f253d0 | **Completed:** 2026-06-10
**Shape chosen (AC1):** shrink-to-concepts. The v4 doc explains how the pieces fit and defers operational detail to where it ships: CLAUDE.framework.md (cold start/session rules — explicitly NOT duplicated, with the @import mechanism explained), component READMEs (update/doctor/insights/audit/tests), and the self-documenting templates. Precedence rule stated up front: component README beats this guide on conflict.
- AC2 ✓ Setup is now two scenarios (A greenfield / B existing incl. discovery + artifact rescue) on the v2 flow: settings → restart → customise → init-framework-version.sh → tag; upgrading = the update system, the v3 diff-two-docs prompt is gone.
- AC3 ✓ zero stale path references (one intentional historical mention of the retired layout in the v4 changelog line); /context-as-agent-action, /btw, "separate Sonnet allowance"/no-Haiku claims, and Phase 0-9 checklist all removed; model guidance now principles + alias-based.
- AC4 ✓ README Getting Started prompt updated to `.claude/claude-code-dev-framework.md` + "Section 12 scenario A/B" language; manifest entry unchanged; README hooks table gained the missing verify-deps row.
- New content reflecting v2 reality: hooks table incl. verify-deps/statusline + profiles, machinery section (update/doctor/insights/audit/tests + doctor-as-propagation-channel principle), council, BUG-001 anchoring warning, determinism-before-automation, and an anti-patterns row memorialising the v3 false auto-load claim ("verify platform behaviour against current docs").
**Verified:** doctor clean, pattern-scan clean, AC3 grep clean, doc 418 lines.

#### TASK-024 — External-audit quick-fix bundle: @import, statusline, hook hardening, hygiene [P1] ✓
**Commit:** 74cd602 | **Completed:** 2026-06-10
**Source:** 2026-06-10 external audit (full notes: C:\Claude\notes\multi-agent-framework-analysis.md). Two claims verified against code.claude.com docs before changing anything: (a) Claude Code auto-loads ONLY CLAUDE.md/CLAUDE.local.md — no `CLAUDE*.md` wildcard, markdown links not followed; (b) statusline data arrives on stdin — `$CLAUDE_STATUS_JSON` never existed.

1. **@import fix (the big one):** CLAUDE.md template now `@CLAUDE.framework.md`-imports the framework rules (a plain link meant they only reached sessions if the model volunteered to read the file). False "auto-loads all CLAUDE*.md" claims corrected in CLAUDE.md + ECOSYSTEM layout contract. **doctor Check 3 upgraded** to require the @import form (CRITICAL otherwise) — consumers' CLAUDE.md is project-owned, so the doctor finding is the propagation path for all 8 existing clones.
2. **Statusline fixed:** new `.claude/hooks/statusline.sh` reads the stdin JSON (ctx % | model | branch, cwd-independent via `.workspace.current_dir`); settings.json points at it; manifest ships it; **doctor Check 10** flags the dead `$CLAUDE_STATUS_JSON` pattern in consumer settings (settings.json is project-owned — same propagation logic). doctor Check 1 now also reads `statusLine.command` so the script isn't flagged as an unwired hook.
3. **filter-test-output:** runner match no longer `^`-anchored — matches after `cd X &&`/`;` (the documented `cd 01_Project && npm test` form NEVER matched before; dead code in the standard flow); runner set now npm/pytest/go/dotnet/cargo; boundary class prevents `npm testify` false-positives.
4. **enforce-state-update:** honours `stop_hook_active` — yields instead of re-blocking when Claude Code re-fires the Stop hook, ending the block-loop risk for sessions with nothing to update.
5. **drift-guard:** per-session counter reset keyed on the payload `session_id` (counters were lifetime — "every 8 prompts" measured across sessions and the compaction nudge's "N prompts this session" text was false); Indicator 3 rewritten to count entries *under* `### In Progress` (old grep matched the heading itself → never fired; was in Known Issues).
6. **Hygiene:** deep-research-report.md moved off the root into `framework/docs/` (root is contract-limited); ECOSYSTEM layout tree updated (council agents, council/security commands, statusline/verify-deps/lib hooks, config-security.sh, tests/); stale `00_framework/` path in ECOSYSTEM template comment fixed; doctor README rows 3/9/10 corrected (9 was never documented); stale STATUS Next Up items cleared (verify-deps registration shipped in d5a77bc; harness item superseded by TASK-014).

**Tests:** 8 new bats regression cases (filter x3 incl. the documented-form case that would have caught the dead filter, enforce-state x2 control+yield, drift-guard x3 incl. session-reset). Suite, doctor, pattern-scan, config-security all clean post-change.

#### TASK-023 — Remove multi-project mode (single framework per project) [P2] ✓
**Commit:** 0a8e36b | **Completed:** 2026-06-10
**Source:** user decision 2026-06-10 — practical usage showed single-clone-per-project is the better model; fleet check confirmed zero multi-mode adopters across all 8 consumers.

- Deleted `.claude/framework/project/` (7 files: mode.sh, new.sh, switch.sh, list.sh, adopt-current.sh, project-state.txt, README) and `.claude/commands/framework-mode.md`.
- Manifest: removed the `project/` dir entry + `framework-mode.md` file entry — consumer copies self-delete on next apply-update via the "(removed upstream)" path.
- CLAUDE.framework.md: Cold Start step 0 is now framework-self mode only (multi-mode resolution paragraph removed).
- doctor.sh: Check 6 retired (tombstone comment keeps numbering stable); registration call removed; doctor README table updated.
- init-framework-version.sh: `FRAMEWORK_MODE` preserve/write logic removed; `.framework-version` no longer carries the field (leftover lines in consumers are inert).
- healthcheck.md: Part 0.1 (mode resolution) removed; 0.2/0.3 renumbered to 0.1/0.2 incl. the cross-reference.
- README.md: "Single vs Multi-Project Mode" section + `/framework-mode` and `project/` table rows removed.
- ECOSYSTEM.md `contract:framework-layout`: `framework-mode.md` and `project/` removed from the canonical tree.
- .gitignore: `projects/*/01_Project|02_solution` block removed.
- MIGRATION.md: new top section documents the removal + un-stash path for the (nonexistent) multi-mode consumer.
- **Verified:** bash -n clean on edited scripts; doctor clean; pattern-scan clean; bats suite pass; zero live references to framework-mode/FRAMEWORK_MODE/projects/_active outside history files.

#### TASK-011 — Unified hook profiles + opt-out convention [P2] ✓
**Commit:** 211e56b | **Completed:** 2026-06-02
**Source:** ECC `ECC_HOOK_PROFILE` / `ECC_DISABLED_HOOKS`.

- New sourced helper `.claude/hooks/lib/hook-common.sh` resolves `CLAUDE_HOOK_PROFILE=minimal|standard|strict` (default standard) + `CLAUDE_DISABLED_HOOKS="id1,id2"` once. `hook_enabled <id> <tier>` with tiers safety/normal/strict.
- All 7 hooks retrofitted with a fail-open gate (missing helper → hook runs as before): `format`, `lint`, `verify-deps`, `filter-test-output`, `drift-guard`, `enforce-state` (normal); `block-dangerous` (safety, Python inline check).
- doctor Check 1 changed to `-maxdepth 1` so the sourced `lib/` helper isn't flagged as an unregistered hook.
- Documented in CLAUDE.framework.md "Hook Configuration"; legacy opt-outs (`CLAUDE_DEP_VERIFY=0`, etc.) preserved.
- **Verified:** profile/disable logic unit-tested (minimal silences normal hooks, keeps block-dangerous; disable-list overrides; strict-tier gated); all hooks `bash -n` clean; doctor clean.

#### TASK-009 — Config-surface security auditor [P1] ✓
**Commit:** 211e56b | **Completed:** 2026-06-02
**Source:** ECC "AgentShield" — audits the harness's OWN config surface (vs `/security` = project code).

- New `.claude/framework/audit/config-security.sh` (manifest-covered via `audit/` dir mirror). Scans 5 surfaces: settings.json permission breadth + secret-deny baseline; hooks (`curl|bash`, `eval`, unquoted tool_input interpolation); agent prompts (read-only-but-writable, wildcard tools); MCP configs (`npx -y` auto-install, shell-piped commands); instruction files (override phrasing, zero-width/bidi chars).
- `--format text|json`; **exit 2 on CRITICAL** (CI build gate).
- Wired into `/security` Part 4 as 4a (auditor) + 4b (manual spot-checks). No new top-level command — extended existing surface per the 2026-05-14 decision.
- **Verified:** self-scan = 0 CRITICAL / 1 WARNING (intentional `$cmd` interpolation in filter-test-output) / 1 INFO; malicious-fixture test caught all 3 CRITICAL classes with exit 2.

#### TASK-012 — Compaction nudge + cost markers (folded into existing hooks) [P3] ✓
**Commit:** 211e56b | **Completed:** 2026-06-02
**Source:** ECC memory-persistence (suggest-compact + cost-tracker). **Folded into existing hooks — no new files, no settings.json change** (per "don't multiply surface").

- **Compaction nudge** = drift-guard Indicator 5 (UserPromptSubmit — reaches the model before it responds). Fires every `CLAUDE_SUGGEST_COMPACT_TURNS` prompts (default 25). Gated by the `suggest-compact` ID.
- **Cost markers** = `cost-tracker` sub-feature in enforce-state-update.sh (Stop). Emits `{"hook":"cost-tracker","tool_uses":N,"transcript_lines":L}` per session end. Gated by the `cost-tracker` ID.
- framework-metrics.md gained an "Avg Tool Calls / Session" column + auto-source notes.
- **Verified:** nudge fires at threshold and is suppressible via `CLAUDE_DISABLED_HOOKS=suggest-compact`; cost marker emits correct counts; both `bash -n` clean.

#### TASK-010 — Auto-instinct miner → proposes GOTCHAS / FRAMEWORK-SUGGESTIONS [P2] ✓
**Commit:** 211e56b | **Completed:** 2026-06-02
**Source:** ECC continuous-learning-v2 — re-scoped to human-in-the-loop (propose, never auto-write).

- New `.claude/framework/insights/instinct-miner.sh` (manifest-covered via `insights/` dir mirror). Auto-discovers the session transcript by repo-basename match under `~/.claude/projects/` (or `--transcript`/`CLAUDE_TRANSCRIPT_DIR`). Scans genuine user turns for correction/directive signals, clusters by normalized snippet, attaches seen-count as confidence.
- Writes proposals to `.claude/.instinct-candidates.md` (gitignored) ONLY; never touches GOTCHAS/SUGGESTIONS. Suppressed below `INSTINCT_MIN_SIGNALS` (default 3). Honours framework-self redirect in its guidance.
- Wired into `/wrapup` step 2.
- **Verified:** synthetic-transcript test produced candidates with seen-counts; below-threshold session wrote no flag; `bash -n` clean.

#### TASK-018 — fault-injection test tier [P1] ✓
**Commit:** f624e44 | **Completed:** 2026-06-02
**Source:** second research pass — ToolMisuseBench deterministic fault-injection pattern.

- New `framework/tests/fault_injection.bats` (11 tests): feed hooks malformed/garbage/truncated input, assert **fail-open** (no crash, no false block) — the tier above happy-path bats, where fail-open guarantees silently break.
- **Caught + fixed two real fail-open bugs:** (1) `block-dangerous-commands.py` crashed (traceback) on non-JSON stdin → wrapped `json.load` in try/except, exit 0 on parse failure + non-dict guard; (2) `verify-deps.sh` exited 5 (not 0) on a non-JSON event because `set -euo pipefail` + `file=$(… | jq …)` aborts with jq's code → added `|| true`. Both now fail open. config-security correctly does the OPPOSITE (flags malformed settings.json as CRITICAL — an auditor must not stay silent).

#### TASK-019 — golden-fixture regression for config-security [P2] ✓
**Commit:** f624e44 | **Completed:** 2026-06-02
**Source:** second research pass — the achievable form of "golden-trace replay" for a *deterministic* detector (we can't replay the LLM detectors — don't own the model client).

- `framework/tests/fixtures/cfgsec-sample/` (stable tree: curl|bash hook, override-phrasing CLAUDE.md, read-only-but-Write agent, npx -y MCP, clean settings) + `golden/cfgsec-sample.findings` (expected severity|surface|location set — not message text, so wording changes don't break it) + `golden_config_security.bats`.
- Runs the auditor on a non-git copy (so `git rev-parse||pwd` resolves to the copy), compares finding identity set to golden; CRLF-tolerant (Git-Bash jq emits CRLF on -r). Caught my own wrong line-number in the golden while building it.

#### TASK-020 — input-pinning --verify variant [P2] ✓
**Commit:** f624e44 | **Completed:** 2026-06-02
**Source:** second research pass — golden-trace replay's attribution insight, adapted to what we can do (pin input, can't stub model).

- Added `/healthcheck --verify N --pin` to the determinism runbook: snapshot the exact bytes a detector consumed on run 1, replay that frozen input to runs 2…N. **Attribution verdict**: findings stable on pinned input → variance was *environmental drift* (fix the environment); findings still vary → *pure model nondeterminism* (reach for per-criterion analytic rubric + ensemble). Mirror image of `--perturb`. Runbook-only (healthcheck.md).

#### TASK-014 — bats-core + shellcheck hook regression harness [P1] ✓
**Commit:** f624e44 | **Completed:** 2026-06-02
**Source:** claude.ai research pass (bats-core) — fills Section B gap #1 (no hook regression harness).

- New `.claude/framework/tests/` (manifest dir-mirror): `run-tests.sh` (bats + shellcheck, opt-in by availability — absent tool = skip+hint unless `--require`), `helpers.bash` (hermetic per-test temp git repo so hook telemetry/state never touches the real tree), `lib_hook_common.bats` (7 profile/opt-out unit tests), `hooks_behavior.bats` (12 per-hook behavioural tests), `audit_config_security.bats` (4 auditor tests), README.
- bats runs via `bats` or `npx bats` (Node-only fallback — verified locally via npx, 23/23 pass).
- **Caught a real latent bug while writing it:** `config-security.sh`'s `[ -d X ] || return` returned the failed test's status (1) under `set -e`, aborting the auditor on any repo lacking `.claude/hooks` or `.claude/agents`. Fixed to `return 0`. Exactly the harness's value.

#### TASK-016 — instinct-miner success capture (dual-source distillation) [P2] ✓
**Commit:** f624e44 | **Completed:** 2026-06-02
**Source:** claude.ai research — ReasoningBank's "learn from successes too", re-scoped to propose-only.

- Extended `instinct-miner.sh` to also mine **success/approval** signals ("that worked", "perfect", "ship it", …) and propose them as **transferable-strategy** candidates, alongside the existing correction candidates. Cluster logic factored into a reusable `clusterize()` fn; both passes share it.
- Candidates file now has two sections (Corrections / Strategies) with an explicit boundary: a project-specific "we chose X because Y" is a DECISION (→ DECISIONS.md), NOT a strategy. `INSTINCT_MIN_SUCCESS` (default 3) gates the success pass. Still propose-only, never auto-writes.
- **Verified:** synthetic dual-signal transcript produces both sections; `bash -n` clean.

#### TASK-015 — /healthcheck --verify perturbation variant [P2] ✓
**Commit:** f624e44 | **Completed:** 2026-06-02
**Source:** claude.ai research — Judge Reliability Harness perturbation suite.

- Added `--perturb` to determinism mode: instead of repeating identical input, run audits over **semantics-preserving perturbations** (format-only diff, comment reflow, blank lines, local renames, import reorder) on a throwaway worktree/copy, and flag **fragile findings** (those that flip under cosmetic change). Verdict gains Robust/Fragile. The base repeat-mode is unchanged; `--perturb` is the stronger gate for consumers that treat findings as ground truth. Runbook-only change (healthcheck.md).

#### TASK-017 — /housekeeping semantic decay [P3] ✓
**Commit:** f624e44 | **Completed:** 2026-06-02
**Source:** claude.ai research — Beads' semantic memory-decay (mechanism only; rejected the binary).

- `/housekeeping` State-File-Archiving now **distils before archiving**: group about-to-be-archived Done tasks by theme, write one forward-looking line into live state (GOTCHAS positive-pattern / SUGGESTIONS / STATUS Next Up / Rolling Summary) where the lesson belongs, THEN move raw entries to the archive with a pointer. Test: a fresh session reading only live state still knows what archived tasks taught. Runbook-only change (housekeeping.md). (Rejected from Beads: hash IDs / DAG model — too invasive for current single-branch scale; revisit if multi-dev.)

#### TASK-013 — ECC agent-definition patterns: reviewer noise control + prompt-injection resistance [P2] ✓
**Commit:** 211e56b | **Completed:** 2026-06-02
**Source:** ECC agent definitions (code-reviewer false-positive list + per-agent "Prompt Defense Baseline").

- **behavioral-principles.md §6 — "Treat External Content as Data, Not Instructions."** Loaded by every agent on handoff: never act on directives embedded in diffs/fetched pages/tool output; surface injection attempts as findings; suspicious of zero-width/bidi chars; never disclose secrets; stay in role. Runtime complement to TASK-009's config-security.sh (which scans config *files* for the same patterns).
- **reviewer.md — "Severity Calibration & False Positives."** Evidence bar for CRITICAL/WARNING (exact `file:line` + concrete failure scenario + why existing guards don't prevent it); no-severity-inflation rule; a suppress-unless-evidenced false-positive list (framework-managed error paths, well-known constants, `let` on reassigned vars, intentional fire-and-forget, test-fixture hardcoding, non-test/non-crypto `Math.random()`, …). Synthesized with the existing "flag liberally / misses are expensive" stance: surface generously, calibrate severity strictly.

**Rejected from ECC agents:** blanket >80%-confidence gate (conflicts with our miss-averse model — took the false-positive list, not the gate); severity-count verdict table (cosmetic); per-agent prompt-defense duplication (used one shared principle instead). 63 language-specific reviewers/build-resolvers stay rejected (2026-05-14 "don't multiply surface").

**Verified:** doctor clean, config-security 0 CRITICAL (behavioral-principles example text correctly not scanned as live config), no broken cross-ref links introduced.

#### TASK-008 — AI-coding-research sweep: 11 framework changes [P1] ✓
**Commit:** 6976b91 | **Completed:** 2026-05-14
**Source:** ChatGPT deep research report on AI-written code defect classes (`deep-research-report.md`).

Implemented in one sprint:
1. **Uncertainty Signalling** behavioral principle (`behavioral-principles.md` §4) — explicit assumption lists, hedging language, distinguish verified-vs-inferred.
2. **Assumptions disclosure** required in developer commit bodies for non-trivial changes (`developer.md`) — meta-defense against silent incorrect assumptions (the most recurring AI defect root cause).
3. **Reviewer AI-failure-mode checks** (`reviewer.md`): hallucinated symbols/APIs/packages (5a), broad-exception handling (5b), assumption challenge (5c), commit-message-vs-diff alignment (5d), generated-test quality (5e), bias/fairness for protected-attribute code paths (5f). Also: code smells as merge gate (was: nice-to-have).
4. **Tester anti-flakiness rules** (`tester.md`): no unseeded randomness, no iteration-order dependence, no shared state, no `time.sleep()` sync, no shallow assertions, host-env isolation, re-run 3× locally.
5. **Tester higher-assurance decision tree** (`tester.md`): change-shape → recommended technique (property tests, fuzz, model checking, stress test).
6. **verify-deps.sh hook** (`.claude/hooks/`) — best-effort registry existence check on every Write/Edit of `package.json` / `pyproject.toml` / `requirements*.txt` / `Cargo.toml` / `go.mod` / `*.csproj`. npm + PyPI fully automated; cargo/go/nuget detection-only.
7. **/security command** (`.claude/commands/security.md`) — stack-agnostic SAST + secret-scan + SCA + license-check sweep, complementary to per-PR reviewer security checks.
8. **/healthcheck --verify N** determinism mode (`healthcheck.md`) — gate before any consumer is built on /healthcheck output. Codifies the 2026-04-26 BUG-001 lesson.
9. **doctor.sh Check 9** — detector-consumer invariant. Warns if framework code that READs `review-findings.md` was added/modified without a `/healthcheck --verify` run since.
10. **framework-metrics.md AI-defect-escape table** — hallucinated deps caught pre/post-commit, broad-catch introduced, smell findings, post-merge bugs on AI commits.
11. **FRAMEWORK-SUGGESTIONS entry** — gap table preserving the full report's mapping for future reference.

**Settings.json registration of verify-deps.sh hook** was BLOCKED by the auto-classifier (self-modification of agent config). Listed as pending user approval — one-line entry added to PostToolUse hooks block. Hook is functional and registered in framework-manifest.txt; downstream consumers register it in their own settings.json on pull.

**Verified:** doctor clean, init.sh clean, framework-drift-guard clean, pattern-scan clean.

#### TASK-007 — Council of Agents: `/council` deliberation feature [P2] ✓
**Commit:** a1d398b | **Completed:** 2026-04-26
**Verified:** AC1-AC8 ✓ — full smoke test on contract-drift question, transcript.md + report.html written, doctor clean. Chairman verdict: validate trendline before shipping any automation.

#### TASK-001 — Upstream repo restructure: file moves + reference updates + manifest [P1] ✓
**Commit:** 9663226 | **Completed:** 2026-04-24  
**Verified:** AC1 ✓ AC2 ✓ AC3 ✓ AC5 ✓ AC6 ✓ AC8 ✓ — doctor clean, pattern-scan clean

#### TASK-002 — Write migrate-layout.sh [P2] ✓
**Commit:** 8647dd9 | **Completed:** 2026-04-24  
**Verified:** idempotency ✓, both migration scenarios (clean + pre-existing .claude/framework/) ✓

#### TASK-003 — Hook migration into apply-update.sh [P2] ✓
**Commit:** 8647dd9 | **Completed:** 2026-04-24  
**Verified:** pre-flight detection added before VERSION_FILE check ✓

#### TASK-004 — Update MIGRATION.md with new layout step [P3] ✓
**Commit:** 8647dd9 | **Completed:** 2026-04-24  
**Verified:** Option A (curl) and Option B (manual) documented ✓

#### TASK-005 — Tester: verify upstream restructure [P1] ✓
**Commit:** 8647dd9 (verified before commit) | **Completed:** 2026-04-24  
**Verified:** AC1 ✓ AC2 ✓ AC3 ✓ AC5 ✓ AC6 ✓ AC7 ✓ AC8 ✓ AC9 ✓ AC10 ✓

#### TASK-006 — Tester: verify consumer migration simulation [P2] ✓
**Commit:** 8647dd9 (verified before commit) | **Completed:** 2026-04-24  
**Verified:** clean migration ✓, merge-into-existing migration ✓, idempotency ✓, all invariants ✓

<!-- When Done exceeds ~20 items, move older entries to .claude/framework/docs/archives/tasks-archive.md -->

---

## Bug-Fix Lane

<!-- Short lifecycle for defects: Reported → Fixing → Verify → Done -->
<!-- Severity: P0 (blocking) | P1 (major) | P2 (minor) | P3 (cosmetic) -->

### Fixing

### Verify

### Reported

### Done

#### BUG-002 — migrate-layout.sh dirty-tree refusal never fired (porcelain grep off by one column) [P1] ✓
**Severity:** P1 (safety check silently dead since the script shipped) | **Source:** found writing TASK-032's AC4 tests; confirmed with a live porcelain probe before fixing
**Commit:** 7851515 | **Completed:** 2026-06-12

**Root cause:** `git status --porcelain` v1 lines are `XY PATH` — two status chars, a space, then the path. The dirty-check grep `^..(00_framework/|TASKS\.md|...)` consumed the two status chars and then required the path alternation to match at position 3, which is always the space — so it matched nothing, ever. Migration would proceed (and `git mv` + commit) over uncommitted framework-path changes.

**Fix:** pattern now consumes the space (`^.. \"?(...)`, quote-tolerant for paths git quotes). Regression test `migrate-layout: refuses with uncommitted framework-path changes` verified to fail against the unfixed script and pass with the fix.

**Lesson:** exactly the class TASK-032 exists for — a refusal path that no happy-path run ever exercises. The dirty checks in apply-update (different implementation, plumbing-based) were already correct and are now pinned by their own tests.

#### BUG-001 — /healthcheck append-only review-findings.md causes subagent anchoring on re-run [P2] ✓
**Severity:** P2 (framework hardening, not blocking) | **Source:** detector-stability experiment 2026-04-26 (3-run /healthcheck on reqtool unchanged tree showed 44→34→30 monotonic decay)
**Commit:** 03c13d4 | **Completed:** 2026-04-26

**Root cause:** Subagents told to PERSIST to `.claude/review-findings.md` read prior content to find their insertion point. Once exposed to prior runs' findings (and within-run earlier parts' findings), they anchor on them. Run-2 reviewer literally wrote *"Alignment with Run 1: All four DRIFT items consistent... confirming detector stability."* That's anchoring, not independent assessment.

**Contributing factor (not the bug, but compounded it):** orchestrator's experiment prompt design ("RUN 2 of 3 in stability experiment", "insert before existing block") leaked context to subagents and primed them for consistency.

**Fix:**
1. Part 0 now rotates `.claude/review-findings.md` → `.claude/review-findings/<timestamp>.md` at start of every run
2. Every subagent prompt (Parts 1.3, 2, 3, 4) now contains an explicit guard: *"Do NOT read `.claude/review-findings.md` before forming your audit. That file is write-only for you. Audit independently."*
3. `.gitignore` updated for the archive directory

**Verified:** runbook inspection shows both fixes in place. Live re-validation deferred — next /healthcheck on reqtool is the real test, but it should be from a fresh session with no priming language.

**Knock-on:** the 2 → 8 → 12 historical drift trend that motivated the contract-drift mitigation work was measured against the same structurally-vulnerable file. We can't trust that trend as decision input. Contract-drift mitigation is dropped from Next Up pending a clean rebaseline post-BUG-001.


