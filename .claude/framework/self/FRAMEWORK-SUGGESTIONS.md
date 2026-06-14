# Framework Improvement Suggestions — Framework Development

Live FRAMEWORK-SUGGESTIONS.md used when `.claude/framework-self.flag` is present
(moved here from `.claude/FRAMEWORK-SUGGESTIONS.md` 2026-06-10, TASK-027 — the
root copy is now the clean consumer template). Entries here are the upstream
adopt/reject audit trail; consumer suggestions arrive via their own root copies.

These are ideas for improving the multi-agent framework itself.
They do NOT get implemented in this project — they get reviewed and
potentially incorporated into the framework repo for future projects.

<!-- Any agent can add a suggestion at any time — don't wait for session end. -->
<!-- Include enough context that a human reading this later can understand the problem and the proposed solution. -->
<!-- Newest entries at the top. -->
<!-- The test: "Could something different in the framework have prevented this problem?" -->

---

## [2026-06-12] Brainstorm backlog — pitched, not yet chosen

User picked 4 of 10 pitched items (filed as TASK-032..035). The other six
are parked here so they survive; pick up when relevant:

1. **`/fleet` — consumer fleet status** (top pick by leverage):
   fleet.conf of local consumer paths → per-consumer framework version vs
   upstream, dirty state, pending migrations, AND auto-generated
   paste-ready downstream prompts. Converts the user's most manual
   workflow (hand-relaying prompts between Claude instances across 8
   clones) into one command. File-based, no daemon.
2. **`/publish-prep` — go-public checklist**: L6 consumer-name sweep over
   self/, secrets/history scan, LICENSE/README/image-link checks, personal
   path scan, go/no-go report. Becomes urgent the day the repo flips
   public (README images already forced this question once).
3. **Stale-claim drift indicator**: drift-guard nags on NO claimed task but
   not on a task claimed-and-untouched for N sessions (the inverse
   failure). Cheap via blame-age of the claim line.
4. **Release channels**: FRAMEWORK_CHANNEL=stable|edge in .framework-version
   — stable pins to deliberately-cut tags + CHANGELOG quoted by the update
   flag; edge = today's HEAD-of-main behaviour. Consumers currently absorb
   mid-refactor weeks wholesale.
5. **Host-agnostic update paths**: ls-remote already is; MIGRATION.md curl
   fallbacks hardcode raw.githubusercontent.com — breaks for the planned
   GitHub Enterprise / current Bitbucket consumers. Small sweep.
6. **TASK-022 ordering note**: when the board's 021/022 come up, do 022
   (context bundles) first — every audit this week hand-assembled subagent
   context; demand is proven. TASK-034 is deliberately a cheap subset of
   021's payoff (noted in its AC4).

---

## [2026-06-02] ECC-repo inspiration review — adopted ideas + rejection rationale

**Status:** FILED as TASK-009..012 (framework-self board). This entry preserves the full
gap mapping and the rejection rationale so a future session doesn't re-litigate the rejected items.

**Source:** ECC harness-optimization repo (github.com/affaan-m/ECC), reviewed 2026-06-02 at user request.

| ECC feature | Our response | Disposition |
| ----------- | ------------ | ----------- |
| AgentShield (audits CLAUDE.md/settings.json/hooks/agents/MCP for injection + perms) | TASK-009 config-surface auditor (doctor check class or `/security --config`) | Adopted P1 — real gap; `/security` only covers project code |
| continuous-learning-v2 (instinct mining, confidence scoring, /evolve into skills) | TASK-010 propose-for-approval GOTCHAS/SUGGESTIONS miner over telemetry pipeline | Adopted P2 — keep human-in-loop + file-based; drop the autonomous SQLite store |
| `ECC_HOOK_PROFILE` + `ECC_DISABLED_HOOKS` | TASK-011 unified profile/disable convention | Adopted P2 — supersedes ad-hoc per-hook opt-outs |
| memory-persistence (suggest-compact, cost-tracker Stop hook) | TASK-012 suggest-compact + cost Stop hooks → framework-metrics | Adopted P3 — operationalises manual context-budget rule |
| 63 specialized agents / 249 skills | — | Rejected — violates 2026-05-14 "don't multiply surface"; generic reviewer hosts the checks |
| Cross-harness adapters (Cursor/Codex/Gemini/Zed) | — | Rejected — Claude-Code-specific by design |
| Desktop GUI dashboard + Rust control-plane (ecc2) | — | Rejected — out of scope for a state-file framework |
| Already covered: per-PR review, project SAST/SCA, config integrity, threshold telemetry, anti-pattern hooks | reviewer / `/security` / doctor / insights / pattern-scan | No action |

---

## [2026-05-14] AI-coding-research sweep — gap table preserved for future reference

**Status:** PARTIALLY ADDRESSED 2026-05-14. Most actionable items shipped this session as TASK-008 (11 changes across reviewer/tester/developer/behavioral-principles + new verify-deps.sh hook + /security command + /healthcheck --verify mode + doctor Check 9 + framework-metrics AI-defect section). This entry preserves the full mapping for items deferred or domain-specific, plus the source-of-truth for what each report finding maps to.

**Source:** `.claude/framework/docs/deep-research-report.md` (2026-05-14; moved off the project root 2026-06-10 — the root is contract-limited to CLAUDE.md, CLAUDE.framework.md, .gitignore) — ChatGPT deep research on AI-written code defects, 13-row issue taxonomy, ~30 cited studies.

**Gap table:**

| Report finding | Framework response | Status |
| -------------- | ------------------ | ------ |
| Spec-first prompting | architect → developer split + ECOSYSTEM.md contracts with status:draft/stable | Already covered |
| Generation/review separation | Developer ≠ Reviewer, separate sessions, clean-context skepticism | Already covered |
| Small-batch generation | One task at a time, atomic commits, TASK-XXX linkage | Already covered |
| Surgical-change discipline | behavioral-principles.md §3 + reviewer enforcement | Already covered |
| "AI as junior dev" stance | reviewer.md prompt header | Already covered |
| Reproduce-before-fix | tester.md bug-verification workflow | Already covered |
| Decision rationale | DECISIONS.md template | Already covered |
| Functional bugs / logic errors | reviewer + tester + behavioral-principles | Already covered |
| Hallucinated APIs/packages | reviewer §5a + verify-deps.sh hook (npm + PyPI auto, cargo/go/nuget detect-only) | **TASK-008 ✓** |
| Incorrect assumptions | developer.md Assumptions section + reviewer §5c challenge + behavioral §4 Uncertainty Signalling | **TASK-008 ✓** |
| Security vulns (SQL/path/shell injection) | reviewer §5 + /security command + grep patterns for known AI-failure cases | **TASK-008 ✓** |
| Code smells (89.3% of AI issues) | reviewer "Code Smells" section gated at CRITICAL (was: WARNING) | **TASK-008 ✓** |
| Generated-test flakiness | tester anti-flakiness rules (step 3) + reviewer §5e on AI-written tests | **TASK-008 ✓** |
| Doc/PR-vs-diff drift | reviewer §5d commit-message-vs-diff alignment | **TASK-008 ✓** |
| Uncertainty signalling | behavioral-principles.md §4 (new) | **TASK-008 ✓** |
| Bias/fairness | reviewer §5f optional (triggered by protected-attribute branching) | **TASK-008 ✓** |
| Property/fuzz/concurrency hints | tester.md step 2 decision table | **TASK-008 ✓** |
| Defect-escape metrics | framework-metrics.md AI-Authored Defect Escape section | **TASK-008 ✓** |
| Detection determinism | /healthcheck --verify N + doctor Check 9 (codifies 2026-04-26 BUG-001 lesson) | **TASK-008 ✓** |
| SAST/SCA/secret-scan orchestration | /security command (stack-agnostic dispatch) | **TASK-008 ✓** |
| License / public-code match | /security Part 5 (opt-in) | **TASK-008 ✓** (opt-in) |
| Concurrency model checking | tester decision table recommends; framework doesn't ship tooling | Stack-specific, by design |
| Performance benchmarking | tester decision table recommends; framework doesn't ship tooling | Stack-specific, by design |
| Repeated test execution for flake detection | tester anti-flakiness rule "re-run new tests 3× locally" | **TASK-008 ✓** |
| Hard compile/type-check gate | Existing auto-lint hook; reviewer enforces. No CI gate (framework is harness-side) | Already covered |
| Provenance for AI commits | Co-Authored-By trailer convention + framework-metrics tracking | Already covered + extended |

**Settings.json hook registration is the one outstanding piece** — auto-classifier blocked the edit; needs explicit user authorisation. See STATUS.md Next Up #0.

**Items deferred indefinitely as out-of-framework-scope:**
- Mutation testing tools (consumer-chooses)
- Specific SAST tool selection (consumer-chooses; /security dispatches by availability)
- License-policy enforcement specifics (consumer-chooses; /security Part 5 is opt-in)
- Public-code-match orchestration (depends on Copilot/org settings; out of scope)

---

## [2026-04-26] Discipline: validate detection determinism before consuming detector output

**Status:** OPEN (lesson, not a bug — worth codifying somewhere agents/users will encounter it).

**The pattern:** Several deferred items in framework history have proposed building automation against /healthcheck output (contract-drift mitigation, doctor invariants, insights triggers). The premise is always "/healthcheck reports X, so we should do Y about X." A 3-run stability experiment on 2026-04-26 disproved the premise for the contract-drift case: same unchanged tree, three consecutive /healthcheck runs, findings count went 44 → 34 → 30 (decaying because subagents anchored on the append-only review-findings.md). Without a determinism check, we'd have shipped a heuristic against a non-deterministic input.

**Suggested discipline (verbatim, save for memory or doctrine):** *"Validate detection determinism before shipping anything that consumes the detector's output."* Concretely — before any framework command builds on /healthcheck (or any other detector's) output:
1. Run the detector at least three times on an unchanged tree.
2. Confirm counts and items are stable (or, if unstable, understand the variance source).
3. Use a fresh session for each run with no priming language about "this is a stability test."

**Where this could live:**
- A line in CLAUDE.framework.md's "Code Quality Rules" section
- A test mode for /healthcheck that explicitly runs N iterations and reports variance
- A doctor invariant: warn if any framework code has been changed in the last N commits to consume /healthcheck output without a determinism note

**Why it matters:** the council saved this case (chairman demanded validation before automation), but the framework can't rely on every consumer running /council before every detector-consumer. Bake the discipline in.

---

## [2026-04-24] PostToolUse hook telemetry gap — RESOLVED

**Status:** RESOLVED 2026-04-24 in this session.

**Root cause confirmed:** The hook command pattern `cd "$(git rev-parse --show-toplevel)" && bash .claude/hooks/foo.sh` works for PreToolUse, UserPromptSubmit, and Stop hooks on Windows VSCode but fails silently for PostToolUse — the `$(...)` shell substitution doesn't evaluate in the PostToolUse exec context, so the chain dies before `bash` runs.

**Diagnostic that proved it:** Minimal inline hook `bash -c 'echo ... > /tmp/log'` fired under PostToolUse; same handler invoked via `cd "$(git rev-parse...)" && bash ...` did not.

**Fix applied:** Updated `.claude/settings.json` PostToolUse entry to use `bash -c 'cd "$CLAUDE_PROJECT_DIR" && bash .claude/hooks/foo.sh'`. `$CLAUDE_PROJECT_DIR` is the canonical env var Claude Code sets for the project root, and the `bash -c` wrapper forces a subshell where it evaluates correctly.

**Verified working:** Telemetry events.jsonl now shows `format` and `lint` events firing on Write/Edit operations.

**GOTCHAS.md entry added** so future hook authors avoid the trap. PreToolUse/UserPromptSubmit/Stop hooks left with the older pattern since they work — but new hooks should prefer the `bash -c` + `$CLAUDE_PROJECT_DIR` pattern uniformly.

---

## [2026-04-18] /healthcheck filename collision for projects that already have a local /healthcheck

**Problem:** `.claude/commands/healthcheck.md` is now framework-owned (listed in framework-manifest.txt). Projects that already shipped their own `/healthcheck` command (e.g. reqtool) will have their version overwritten on next apply-update run. The file-level manifest prevents dir-mirror from wiping the whole `.claude/commands/` dir, but doesn't help with exact-filename collisions.

**Suggested options (pick one or surface in MIGRATION.md):**

1. **Rename the framework version** — `.claude/commands/framework-healthcheck.md` → `/framework-healthcheck`. Leaves user's `/healthcheck` untouched. Cleanest semantic but the command name is less discoverable.
2. **Detect collision before apply-update** — apply-update.sh grows a pre-copy check: for each file-level manifest entry, check if local version differs from upstream AND has uncommitted edits. If so, refuse and ask user to rename or consent. Closest to the existing safety check philosophy.
3. **Extension pattern** — framework `/healthcheck` sources an optional `.claude/healthcheck.local.md` appended to its runbook. Users who want to extend rather than replace keep their bits in `.local.md`.

Not urgent; user knows about it and can rename their reqtool file before pulling. But for long-term multi-user framework it'd be a gotcha.

---

## [2026-04-18] Audit discipline: grep pattern classes across the WHOLE repo, not just changed files

**Problem:** During the multi-project-mode audit (2026-04-18), I reviewed the new project scripts carefully and caught 4 real issues (data-loss, pipefail, reserved names, CRLF). But I missed identical CRLF bugs in the pre-existing update system (`apply-update.sh`, `check-updates.sh`) because my audit scope was "newly-written code." User shipped the update to a real project and hit the bug in production.

**The pattern that would have caught it:**
```bash
grep -rn 'while IFS= read -r line' .claude/framework/ .claude/hooks/ .claude/commands/
```
Any while-read loop is vulnerable to CRLF on Windows. Auditing the newly-written code and seeing the pattern, I should have grep'd for the same pattern across the whole framework and added CRLF stripping everywhere in the same commit.

**Suggested framework addition:** a lightweight `.claude/framework/audit/pattern-scan.sh` or similar that greps for known-vulnerable patterns (while-read without CR strip, `grep -c || echo 0`, `$(...)` under `set -e` with no `|| true`, etc.) and reports any matches. Could be called by `doctor.sh` or run on-demand via `/healthcheck`.

**Or:** document this as an explicit step in the reviewer agent's prompt — "after examining the diff, grep the whole repo for the patterns you just reviewed; any unchanged occurrence of the same pattern is a latent bug."

---

## [2026-04-16] framework-drift-guard.sh: `grep -c ... || echo 0` pattern produces two-line output and breaks the downstream integer test — **FIXED 2026-04-18**

> Applied Option A (drop the fallback). See GOTCHAS.md "grep -c with || echo 0" for the preserved lesson. Keeping this entry for audit trail; can be archived with the rest of the SUGGESTIONS in a future housekeeping sweep.

**File:** `.claude/hooks/framework-drift-guard.sh` (~line 41)

**Symptom:**
```
.claude/hooks/framework-drift-guard.sh: line 41: [: 0 0: integer expression expected
```

**Root cause:** `grep -c` always prints its count (including `0` on no matches) *and* exits with status 1 when the count is zero. The current pattern:

```bash
PROJECT_CHANGES=$(git diff --name-only HEAD 2>/dev/null | grep -c "^01_Project/" || echo "0")
STATE_CHANGES=$(git diff --name-only HEAD 2>/dev/null | grep -cE "^(TASKS|STATUS|DECISIONS|ECOSYSTEM)\.md|^claude-progress\.txt" || echo "0")
```

triggers the `|| echo "0"` fallback in the zero-match case, so stdout captures *both* the `0` from `grep` AND the `0` from `echo` — yielding `"0\n0"`. The subsequent integer comparison (`[ "$PROJECT_CHANGES" -gt "$STATE_CHANGES" ]` or similar) then fails with the error above.

**Reproduction:** Run the hook in a clean git worktree (no uncommitted changes under `01_Project/`, no state-file edits). Error fires on every invocation. Platform-independent — POSIX `grep -c` behaviour, reproduces on Linux/macOS/Windows Git Bash.

**Impact:** Hook degrades gracefully — it still emits its `{}` and exits 0, so Claude Code doesn't break. **But the drift-detection logic that depends on the integer comparison never fires**, meaning the reminder about state files falling behind project changes is silently disabled. With the fix, the hook can actually do its job.

**Suggested fix (one of):**

**Option A — drop the fallback** (grep -c already prints 0, so the fallback is redundant):
```bash
PROJECT_CHANGES=$(git diff --name-only HEAD 2>/dev/null | grep -c "^01_Project/")
STATE_CHANGES=$(git diff --name-only HEAD 2>/dev/null | grep -cE "^(TASKS|STATUS|DECISIONS|ECOSYSTEM)\.md|^claude-progress\.txt")
```

**Option B — use `wc -l`** (immune to zero-match exit behaviour):
```bash
PROJECT_CHANGES=$(git diff --name-only HEAD 2>/dev/null | grep -c "^01_Project/" 2>/dev/null)
# or:
PROJECT_CHANGES=$(git diff --name-only HEAD 2>/dev/null | grep "^01_Project/" | wc -l)
```

**Option C — keep fallback, strip trailing extras:**
```bash
PROJECT_CHANGES=$(git diff --name-only HEAD 2>/dev/null | grep -c "^01_Project/" || echo 0)
PROJECT_CHANGES=${PROJECT_CHANGES%%$'\n'*}
```

Option A is the minimal change and matches how `wc -l` and `grep -c` are typically used. Recommended.

**Test harness idea:** A lightweight hook-level self-test would catch issues like this before they ship. Something like `bash .claude/framework/test-hooks.sh` that pipes representative stdin into each hook and asserts expected exit codes + stdout shape. Could live in `.claude/framework/tests/` so it's part of the framework upgrade bundle.

**Reporter context:** Found during Phase 6 end-to-end verification of a CharitiesRegDemo framework alignment (drushegh/CharitiesRegDemo). The aligning project went from an older scaffold to current upstream via a 6-phase restructure; running `bash (NON-EXISTENT)` then `bash .claude/hooks/framework-drift-guard.sh` surfaced this. Same repro expected for any fresh scaffold.

---

## [2026-06-12] /healthcheck Part 0.0 rotation re-tracks the gitignored archive

**Found:** this session's pre-push healthcheck. **Severity:** P3 (cosmetic, recurring cleanup).

The flat `.claude/review-findings.md` is TRACKED by design (checkpoint commits);
`.claude/review-findings/` is gitignored. Part 0.0 rotates the flat file into the
archive. If that rotation uses `git mv` (or `git mv || mv`), git carries the
tracked path INTO the ignored dir — producing a tracked file inside a gitignored
directory, which then needs a manual `git rm --cached` every healthcheck.

**Fix:** Part 0.0 should rotate with plain `mv` (not `git mv`), then stage the
deletion of the old tracked path explicitly: `mv review-findings.md
review-findings/<ts>.md` leaves git seeing the tracked file deleted; the new
flat file (written during the run) gets added normally; the archived copy stays
untracked as intended. Update the healthcheck skill's Part 0.0 wording to specify
plain `mv` and to NOT `git mv` into the archive.
