# Gotchas & Lessons Learned — Framework Development

Framework-dev gotchas. Live GOTCHAS.md used when `.claude/framework-self.flag`
is present (moved here from `.claude/GOTCHAS.md` 2026-06-10, TASK-027 — the
root copy is now the clean consumer template).

<!-- Any agent that encounters a non-obvious behaviour, workaround, or "thing I wish I'd known" adds it here. -->
<!-- Each entry has a title, encounter count, problem description, fix, and first-seen date. -->
<!-- When an agent hits a known gotcha again, increment the count — don't add a duplicate. -->
<!-- If a gotcha reaches 5+ encounters, consider fixing the underlying cause — log a task in TASKS.md. -->
<!-- Organised by category (technology, project-specific, etc.) -->

---

## Framework development

### Windows jq emits CRLF — `$()` strips the \r (MSYS bash), `read` does NOT

**Encounters:** 2 (2026-06-02 TASK-019 golden fixtures; 2026-06-12 TASK-021 live on the first v2 telemetry emit)

**Problem:** the winget jq (MSVC build 1.8.1 — the only jq on the dev
machine, in EVERY environment incl. interactive git-bash) terminates each
output line with CRLF, even through a pipe. Verified empirically
2026-06-12: `jq -r .a | od -c` → `x \r \n`. What saves the existing
codebase is MSYS bash command substitution: `v=$(... | jq -r ...)` strips
the trailing `\r\n` entirely, so every `$()`-based consumer gets a CLEAN
value (and on Linux/macOS jq never emits CRLF — `$()` sites are safe on
all platforms). But `read < <(... | jq -r ...)` strips only the `\n` —
the `\r` survives into the variable. In read-based code: (a) embedded in
a JSON string it's a raw control character — the whole line becomes
unparseable (v2 telemetry events were corrupt the moment the new
read-based emit path ran); (b) `[ "$var" = "true" ]` comparisons silently
fail ("true\r" ≠ "true"); (c) `[ -f "$path" ]` fails on a real file.

**The trap shape:** refactoring a working `$(jq -r …)` into a multi-value
`read < <(jq -r …)` extraction (e.g. to save a jq spawn) silently
re-introduces the \r that `$()` had been hiding — exactly how TASK-021
hit it. CORRECTION of this entry's first version: it claimed the old
`stop_hook_active` `$()` comparison was latent-broken — wrong; `$()`
strips the \r, the old code was always fine. Only read-based consumption
breaks.

**Fix:** strip at every jq-fed `read` site: `var="${var%$'\r'}"` after the
read, or `"${var//$'\r'/}"` at a choke point (telemetry_emit sanitises its
env ids as belt-and-suspenders). The CRLF-class root fix (.gitattributes,
DA-C7) does NOT cover this — it's jq's runtime output, not file content.

**Where to check:** any `read`/`mapfile` fed by jq output. `$(jq …)` sites
are safe. Pin with a strict-parse test (`jq -se .` over the produced
file) — that's what caught it live. Sweep 2026-06-12 confirmed the rest of
the repo: all other read-sites consume MSYS tools (find/grep/awk — no
CRLF); config-security's `jq -c | read` loop is safe because the \r lands
as trailing JSON whitespace and its inner `$()` extractions re-strip.

### A subagent constraint in behavioral-principles.md must be swept across ALL four agent defs

**Encounters:** 1 (2026-06-12, caught by /healthcheck Part 1 deep audit)

**Problem:** TASK-038 added §7 (subagent RED-LINES: no commit/push/lifecycle
transitions) to behavioral-principles.md but only wired developer.md to point
at it. tester.md's "After Testing" section still said "Commit your test files"
and "move task to Done" — a delegated Tester would follow its own file and
commit + transition the board, exactly the behaviour §7 forbids. architect.md
had the same latent gap. The conflict shipped and was caught only by the next
healthcheck.

**Fix / rule:** when you add or change a cross-cutting agent constraint in
behavioral-principles.md, in the SAME commit audit all four framework agent
defs (architect, developer, tester, reviewer) for instructions that now
contradict it, and reconcile each. The shared principle file is necessary but
not sufficient — per-agent action lists override it in practice. Same class as
[[the framework-layer sweep lesson]]: a pattern change must hit every layer at
once.

### git-bash grep lacks -P (PCRE) — capability-probe, don't platform-assume

**Encounters:** 1 (2026-06-11, deep-analysis DA-C8 follow-on)

**Problem:** `grep -P` is commonly described as a "GNU vs BSD/macOS" gap, but Windows git-bash (MINGW64) grep ALSO lacks it. config-security.sh's zero-width/bidi hidden-character detector used `grep -nP ... 2>&1 >/dev/null`, and the redirect swallowed the "invalid option" error — the CRITICAL-class detector was silently dead on the framework's primary platform from the day it shipped. Static review had mislabelled it a macOS-only risk.

**Fix:** byte-level UTF-8 matching under `LC_ALL=C` (`grep -qE $'\xe2\x80[\x8b-\x8f...]'`) needs no PCRE and works everywhere. U+FEFF checked only past byte 3 so leading Windows BOMs don't false-fire.

**Lesson:** when a feature depends on a tool capability, probe the capability at runtime (doctor Check 11 pattern) instead of assuming it from the platform — the probe found in seconds what four healthchecks and an external audit missed.

### PowerShell here-string commit messages get mangled — use git commit -F

**Encounters:** 2 (2026-06-11, same session)

**Problem:** Multi-line `git commit -m @'...'@` here-strings sent through the PowerShell tool intermittently parse wrong when the body contains double-quoted phrases (e.g. `"(this session)"`, `"fix all critical now"`) — the message splits at the quote and git receives the remainder as pathspecs (`error: pathspec 'session) ...' did not match`).

**Fix:** write the message to a temp file (`.git/COMMIT_MSG_TMP`) with the Write tool and use `git commit -F`, then delete it. Reliable for any body content.

### Append-only audit/output files cause subagent anchoring on re-run

**Encounters:** 1 (2026-04-26, root cause confirmed via 3-run /healthcheck stability experiment on reqtool unchanged tree)

**Problem:** When a slash command instructs subagents to PERSIST findings/output to a shared file (e.g. `.claude/review-findings.md`), and that file is append-only across runs, every subsequent run's subagents will read the file before writing — they have to, to find the right insertion point. Once exposed to prior content, they self-suppress duplicates and anchor on prior findings. Result: monotonic decay across re-runs, indistinguishable from "the issues were fixed" but actually "the detector is forgetting."

**Concrete failure:** /healthcheck on the same unchanged tree produced 44 → 34 → 30 findings across three consecutive runs. A real CRITICAL bug (`isinstance(r, BaseException)` swallowing KeyboardInterrupt) was reported in runs 1 and 2, then *vanished* from run 3. Run-2 reviewer literally wrote *"Alignment with Run 1: All four DRIFT items consistent... confirming detector stability"* — that's anchoring, not independent assessment.

**Compounding factor:** orchestrator priming language ("RUN N of M in stability experiment", "insert before existing block") gives subagents meta-context they shouldn't have. Even without explicit "dedupe" instructions, helpful-assistant behaviour fires.

**Fix pattern (applied to /healthcheck in BUG-001):**
1. **Rotate the shared file at the start of every run.** Move `<file>.md` to `<file>/<timestamp>.md` (or similar archive) before any subagent touches it. Run starts clean.
2. **Add an explicit independence rule to every subagent prompt:** *"Do NOT read `<file>.md` before forming your audit. That file is write-only for you."* Belt-and-suspenders against within-run anchoring (e.g. Part 4 reading findings from Parts 1-3).
3. **Don't pass meta-experiment context to subagents.** Subagents should see only their audit task, not framing like "this is run 2" or "we're testing detector stability."

**Generalises beyond /healthcheck:** any framework command using a shared persistent file as the subagent output sink has this risk. Future framework design: prefer per-subagent return values aggregated by the orchestrator over shared-file accumulation.

---

### PostToolUse hooks need `bash -c` wrapper + `$CLAUDE_PROJECT_DIR` on Windows VSCode

**Encounters:** 1 (2026-04-24, root cause confirmed via diagnostic)
**Encountered:** `auto-format.sh` and `auto-lint.sh` showed 0 events in 340 telemetry events despite heavy Write/Edit usage.

**Problem:** The hook command pattern `cd "$(git rev-parse --show-toplevel)" && bash .claude/hooks/foo.sh` works for `PreToolUse` and `UserPromptSubmit` hooks but fails silently for `PostToolUse` on Windows VSCode Claude Code extension. The `$(...)` shell substitution doesn't evaluate in PostToolUse's exec context, so the chain dies before `bash` is reached. No error surfaces; the hook just never runs.

Confirmed via diagnostic: a minimal hook using `bash -c 'echo ... > /tmp/log'` (inline subshell, no substitution) DID fire under PostToolUse, while the same handler invoked via `cd "$(git rev-parse...)" && bash ...` did not.

**Fix:** Use `bash -c 'cd "$CLAUDE_PROJECT_DIR" && bash .claude/hooks/foo.sh'` for PostToolUse hooks. The `bash -c` wrapper forces the command into a subshell where env vars (including the canonical `$CLAUDE_PROJECT_DIR` Claude Code sets) evaluate correctly.

```json
"PostToolUse": [
  {
    "matcher": "Write|Edit|MultiEdit",
    "hooks": [
      { "type": "command",
        "command": "bash -c 'cd \"$CLAUDE_PROJECT_DIR\" && bash .claude/hooks/auto-format.sh'" }
    ]
  }
]
```

**Where to check:** Any new PostToolUse hook. PreToolUse, UserPromptSubmit, and Stop hooks tolerate the older `cd "$(git rev-parse...)"` pattern, but PostToolUse does not. For new hooks, prefer the `bash -c '...'` + `$CLAUDE_PROJECT_DIR` pattern uniformly — it works in all hook contexts and is cheaper than spawning git per-invocation.

---

### SCRIPT_DIR depth is move-sensitive — add one `..` per extra directory level

**Encounters:** 1 (2026-04-24)
**Encountered:** All 14 framework subdirectory scripts computed project root incorrectly after the 00_framework/ → .claude/framework/ restructure.

**Problem:** Scripts used `SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"` then `PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"`. When scripts lived at `00_framework/<subdir>/` (2 levels deep), `../..` correctly reached project root. After moving to `.claude/framework/<subdir>/` (3 levels deep), `../..` only reached `.claude/` — one level short. The error was silent (doctor.sh silently wrote its flag file to `.claude/` instead of the project root).

**Fix:** Count how deep the script lives from the project root and use the right number of `..` hops:
- At `.claude/framework/<subdir>/` (3 levels) → `$SCRIPT_DIR/../../..`
- At `.claude/framework/` (2 levels) → `$SCRIPT_DIR/../..`
- Scripts that use `git rev-parse --show-toplevel` are immune.

**Where to check:** Any time a framework script is moved to a different directory depth, grep for `SCRIPT_DIR/\.\.` and update the hop count. Alternative: switch to `git rev-parse --show-toplevel` which is depth-independent.

---

### Bulk sed on paths can create double-prefix corruption

**Encounters:** 1 (2026-04-24)
**Encountered:** During 00_framework/ → .claude/framework/ restructure sed sweep.

**Problem:** When multiple sed substitutions share overlapping patterns, the second pass can match something the first pass already transformed. E.g., substituting `/.framework-update-available.md` → `/.claude/.framework-update-available.md` ran on files where the path was already `.claude/.framework-update-available.md`, producing `.claude/.claude/.framework-update-available.md`. Script silently tried to write to a nonexistent double-nested path.

**Fix:** After any bulk sed sweep, grep for doubled path components: `grep -r "\.claude/\.claude/" .claude/`. Also run `grep -r "\.\.claude/"` for other variants. Fix any hits before committing.

**Where to check:** After any bulk sed that modifies path strings. Run the double-prefix grep as part of the verification step.

---

## Shell scripting on Windows

### CRLF breaks `while IFS= read -r line` loops

**Encounters:** 1 (2026-04-18)
**Encountered:** 6 separate loops across 5 framework scripts were silently broken

**Problem:** On Windows with `core.autocrlf=true` (default for git-bash), text files are checked out with CRLF line endings. `read -r` consumes the trailing `\n` but leaves the `\r`. So a manifest line `00_framework/doctor/` becomes `00_framework/doctor\r` after stripping trailing `/` — which matches nothing in the filesystem. No error; silent failure. The user had to find this by shipping and hitting the bug.

**Fix:** Always strip CR at the top of the loop, BEFORE any pattern matching:

```bash
while IFS= read -r line; do
  line="${line%$'\r'}"          # ← add this line
  [[ -z "$line" || "$line" =~ ^[[:space:]]*# ]] && continue
  ...
done < "$file"
```

**Where to check:** `grep -rn 'while IFS= read' .claude/`. Every match must have the CR strip.

**Related:** `source "$file"` on msys bash handles CRLF automatically — that's a quirk of msys, not POSIX. On Linux CI or other POSIX shells, `source` on CRLF produces `\r`-tailed variables. Use `source <(tr -d '\r' < "$file")` if you need guaranteed portability.

---

### `set -euo pipefail` + `grep` no-match kills the script

**Encounters:** 1 (2026-04-18)

**Problem:** With `set -euo pipefail`, a pipeline that starts with `grep` exits non-zero when grep finds no matches. In command substitution this can terminate the whole script silently (`mode=$(grep ... | cut ... | tr ...)` crashes on missing grep match).

**Symptom:** `bash script.sh; echo "exit=$?"` reports `exit=1` with no output. `bash -x` shows the script dying mid-pipeline.

**Fix:** Append `|| true` to tolerate no-match in optional reads:

```bash
mode=$(grep -E '^FRAMEWORK_MODE=' "$VERSION_FILE" | cut -d= -f2- | tr -d '\r' || true)
mode="${mode:-single}"
```

**When it matters:** reading optional config values, detecting presence of a line, any scenario where "no match" is a valid state.

---

### awk `\b` word-boundary doesn't work in mawk (Git Bash default)

**Encounters:** 1 (2026-04-18)

**Problem:** POSIX awk and mawk (the default `awk` in Git Bash on Windows) don't support `\b` as a word-boundary. A pattern like `/^[[:space:]]*done\b/` silently compiles but never matches — no error, just zero hits. Only gawk supports `\b`. On Linux CI the same script would work under gawk; on a Windows developer machine it silently misbehaves.

**Symptom:** An awk-based scanner returns no matches where grep/gawk would find them. Extra-insidious because it's platform-conditional.

**Fix:** Use an explicit non-word-character class instead:

```awk
# WRONG (gawk-only — silent miss on mawk):
/^[[:space:]]*done\b/

# RIGHT (portable across awk implementations):
/^[[:space:]]*done([^a-zA-Z0-9_]|$)/
```

**Where it matters:** any awk regex in a framework script that needs word-boundary semantics. First seen in `.claude/framework/audit/pattern-scan.sh` (the matching-`done` detector for while-read loops). A passing test on Linux is not sufficient — the Git Bash execution path must be checked separately.

---

### `grep -c` with `|| echo 0` produces "0\n0" on zero matches

**Encounters:** 1 (2026-04-16, fixed 2026-04-18)

**Problem:** `grep -c` prints its count (including `0` on no matches) AND exits with status 1 when the count is zero. The common-looking pattern `$(grep -c pattern || echo 0)` triggers the fallback in the zero-match case, so stdout captures both the `0` from grep and the `0` from echo — yielding `"0\n0"`. Downstream integer comparisons then fail with `[: integer expression expected`.

**Symptom:** `.claude/hooks/framework-drift-guard.sh: line 45: [: 0 0: integer expression expected`. Hook still exits 0, so Claude Code doesn't break — but the drift-detection logic silently never fires.

**Fix:** Drop the fallback. `grep -c` already prints `0` on no match, so the `|| echo 0` is redundant:

```bash
# WRONG:
COUNT=$(git diff --name-only HEAD | grep -c "pattern" || echo "0")

# RIGHT:
COUNT=$(git diff --name-only HEAD | grep -c "pattern")
```

Applied to `framework-drift-guard.sh` lines 43-44 on 2026-04-18.
