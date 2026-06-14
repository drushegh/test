#!/usr/bin/env bash
# doctor.sh — point-in-time framework integrity check.
#
# Complementary to:
#   - .claude/framework/update/ (pulls improvements)
#   - .claude/framework/insights/ (longitudinal efficacy)
#
# Doctor answers "is the framework intact RIGHT NOW?" — static state
# that should always hold. Runs on cold start (cheap, instantaneous;
# no throttle) and on demand. Silent when clean; writes
# .framework-doctor-findings.md when issues are detected. Cold start
# surfaces findings via AskUserQuestion.
#
# Invariants checked:
#   1. Hook scripts referenced in settings.json exist on disk,
#      and every hook file on disk is referenced in settings.json.
#   2. Cross-references (markdown links to local paths) in CLAUDE.md,
#      CLAUDE.framework.md, and framework-shipped docs point at files
#      that exist.
#   3. CLAUDE.md @imports CLAUDE.framework.md (a plain link is NOT
#      enough — Claude Code only inlines @path imports).
#   4. Every path in .claude/framework/update/framework-manifest.txt exists
#      locally. Missing paths mean apply-update.sh will fail mid-copy.
#   5. .framework-version (if present) has all required fields set.
#   6. TASKS.md has no duplicate TASK-NNN heading IDs.
#   9. Detector-consumer determinism: if any framework code added in
#      recent commits references .claude/review-findings.md or its
#      rotated archive as INPUT (not just output), warn unless
#      /healthcheck --verify has been run since.
#  10. statusLine.command reads stdin, not the nonexistent
#      $CLAUDE_STATUS_JSON env var.
#
# Exit codes:
#   0 — all checks pass OR findings written to flag file (cold start continues)
#   1 — fatal script error
#
# Dependencies: jq, grep, awk, find.

set -euo pipefail

# Bash 4+ guard (DA-C8): this script uses mapfile, which bash 3.2 (stock
# macOS) lacks — without the guard it dies mid-run with a confusing error
# and NO checks execute. Fail loudly and early instead.
if [ "${BASH_VERSINFO[0]:-0}" -lt 4 ]; then
  echo "doctor: bash >= 4 required (found ${BASH_VERSION:-unknown})." >&2
  echo "doctor: on macOS: brew install bash, then re-run. No checks were performed." >&2
  exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"
FLAG_FILE="$PROJECT_ROOT/.claude/.framework-doctor-findings.md"
MANIFEST_FILE="$PROJECT_ROOT/.claude/framework/update/framework-manifest.txt"
SETTINGS_FILE="$PROJECT_ROOT/.claude/settings.json"
VERSION_FILE="$PROJECT_ROOT/.claude/.framework-version"

# Always remove stale flag — we recompute fresh each run.
rm -f "$FLAG_FILE"

# --- Finding collection ----------------------------------------------
# Each element: "SEVERITY|CHECK|MESSAGE". Severity is CRITICAL|WARNING|INFO.
findings=()
add_finding() { findings+=("$1|$2|$3"); }

# --- Check 1: Hook ↔ settings.json consistency -----------------------
check_hooks() {
  if [ ! -f "$SETTINGS_FILE" ]; then
    add_finding "WARNING" "hooks" "No .claude/settings.json found — hooks will not run. Fix: restore settings.json or run Claude Code init."
    return
  fi

  if ! command -v jq >/dev/null 2>&1; then
    add_finding "INFO" "hooks" "jq missing — cannot introspect settings.json for hook consistency. Install jq: https://jqlang.github.io/jq/download/"
    return
  fi

  # Extract every `.hooks[...].hooks[...].command` string from settings.json
  # (plus statusLine.command — the statusline reader also lives under
  # .claude/hooks/ and must not be flagged as dead code), then pull the hook
  # path out of commands like `bash .claude/hooks/foo.sh` or
  # `python .claude/hooks/foo.py`.
  mapfile -t referenced_paths < <(
    jq -r '(.hooks // {} | to_entries | .[] | .value[]? | .hooks[]? | .command // empty), (.statusLine.command // empty)' "$SETTINGS_FILE" \
      | grep -oE '\.claude/hooks/[A-Za-z0-9_.-]+\.(sh|py)' \
      | sort -u
  )

  # Every referenced path should exist on disk.
  for p in "${referenced_paths[@]}"; do
    if [ ! -f "$PROJECT_ROOT/$p" ]; then
      add_finding "CRITICAL" "hooks" "\`.claude/settings.json\` references \`$p\` but the file is missing. The hook will silently not fire. Fix: restore the script, or remove the entry from settings.json."
    fi
  done

  # Every hook file on disk should be referenced in settings.json.
  # maxdepth 1 so sourced helper libraries under .claude/hooks/lib/ are
  # NOT treated as registerable hooks — they're included via `source`,
  # never wired into settings.json directly.
  if [ -d "$PROJECT_ROOT/.claude/hooks" ]; then
    mapfile -t on_disk < <(
      find "$PROJECT_ROOT/.claude/hooks" -maxdepth 1 -type f \( -name '*.sh' -o -name '*.py' \) -printf '.claude/hooks/%f\n' | sort -u
    )
    for p in "${on_disk[@]}"; do
      if ! printf '%s\n' "${referenced_paths[@]}" | grep -qxF "$p"; then
        # Dispatcher-driven hooks (TASK-035): a hook invoked by a hook
        # that IS registered (post-edit-dispatch.sh runs auto-format /
        # auto-lint / verify-deps) is wired, just indirectly. Treat
        # "basename appears in a registered hook's file" as referenced.
        indirect=0
        for r in "${referenced_paths[@]}"; do
          [ -f "$PROJECT_ROOT/$r" ] || continue
          if grep -qF "$(basename "$p")" "$PROJECT_ROOT/$r" 2>/dev/null; then
            indirect=1
            break
          fi
        done
        [ "$indirect" = 1 ] && continue
        add_finding "WARNING" "hooks" "\`$p\` exists on disk but isn't referenced in \`.claude/settings.json\` (directly, or via a registered dispatcher hook). Either wire it up or delete the file (dead code)."
      fi
    done
  fi
}

# --- Check 2: Cross-references in core docs --------------------------
# Parse markdown links [text](path) in framework-shipped docs. If the
# path looks like a local file (no http/https/mailto, no pure anchor)
# and doesn't exist relative to the link's containing file OR the
# project root, flag it.
check_cross_refs() {
  local scan_files=()
  for f in "$PROJECT_ROOT/CLAUDE.md" "$PROJECT_ROOT/CLAUDE.framework.md"; do
    [ -f "$f" ] && scan_files+=("$f")
  done
  while IFS= read -r f; do
    scan_files+=("$f")
  done < <(find "$PROJECT_ROOT/.claude/agents/framework" "$PROJECT_ROOT/.claude/framework/agent_docs" -maxdepth 3 -type f -name '*.md' 2>/dev/null)

  for f in "${scan_files[@]}"; do
    local f_dir
    f_dir=$(dirname "$f")
    # Extract markdown link targets: [...](path)
    while IFS= read -r target; do
      # Skip external URLs, mailto, pure anchors, code-block paths.
      case "$target" in
        http://*|https://*|mailto:*|'#'*|'') continue ;;
      esac
      # Strip any trailing #anchor or ?query.
      local clean_target="${target%%#*}"
      clean_target="${clean_target%%\?*}"
      [ -z "$clean_target" ] && continue

      # Resolve relative to the containing file first, then project root.
      local resolved=""
      if [ -e "$f_dir/$clean_target" ]; then
        resolved="$f_dir/$clean_target"
      elif [ -e "$PROJECT_ROOT/$clean_target" ]; then
        resolved="$PROJECT_ROOT/$clean_target"
      fi

      if [ -z "$resolved" ]; then
        # Skip paths that are obviously meant as placeholders or shell commands.
        case "$clean_target" in
          *'$'*|*'{{'*|*'...'*) continue ;;
        esac
        local rel_f="${f#$PROJECT_ROOT/}"
        add_finding "WARNING" "cross-refs" "\`$rel_f\` links to \`$clean_target\` but the target doesn't exist. Fix: restore the file, update the link, or remove the reference."
      fi
    done < <(grep -oE '\]\([^)]+\)' "$f" | sed 's/^](\(.*\))$/\1/')
  done
}

# --- Check 3: CLAUDE.md has include pointer --------------------------
check_claude_include() {
  local claude="$PROJECT_ROOT/CLAUDE.md"
  local framework="$PROJECT_ROOT/CLAUDE.framework.md"

  # If CLAUDE.framework.md doesn't exist, this project may predate the
  # split — that's a separate migration concern, not a doctor finding.
  if [ ! -f "$framework" ]; then
    return
  fi

  if [ ! -f "$claude" ]; then
    add_finding "CRITICAL" "claude-md" "CLAUDE.framework.md exists but CLAUDE.md is missing. Every project needs a CLAUDE.md with project-specific content and a pointer to CLAUDE.framework.md."
    return
  fi

  # The pointer must be an @import. Claude Code auto-loads ONLY CLAUDE.md
  # and CLAUDE.local.md (no CLAUDE*.md wildcard), and plain markdown links
  # are NOT followed — only the `@path` import syntax inlines a file into
  # session context (verified against the code.claude.com memory docs,
  # 2026-06-10). A link-style pointer means the framework rules reach the
  # session only if the model volunteers to read the file.
  if grep -qE '(^|[[:space:]])@(\./)?CLAUDE\.framework\.md' "$claude"; then
    return
  fi
  if grep -qF "CLAUDE.framework.md" "$claude"; then
    add_finding "CRITICAL" "claude-md" "CLAUDE.md mentions CLAUDE.framework.md but does not @import it — Claude Code does not follow markdown links, so the framework rules are NOT reaching sessions. Fix: replace the pointer with an import line: \`@CLAUDE.framework.md\`."
  else
    add_finding "CRITICAL" "claude-md" "CLAUDE.md does not reference CLAUDE.framework.md. Framework-shipped instructions (cold start, agent rules, state file rules) will be missing from sessions. Fix: add \`@CLAUDE.framework.md\` near the top of CLAUDE.md."
  fi
}

# --- Check 4: framework-manifest.txt paths exist ---------------------
check_manifest_paths() {
  if [ ! -f "$MANIFEST_FILE" ]; then
    add_finding "INFO" "manifest" ".claude/framework/update/framework-manifest.txt not found. If this project hasn't adopted the update system, see .claude/framework/update/MIGRATION.md."
    return
  fi

  while IFS= read -r line; do
    line="${line%$'\r'}"
    [[ -z "$line" || "$line" =~ ^[[:space:]]*# ]] && continue
    local path="${line%/}"
    if [ ! -e "$PROJECT_ROOT/$path" ]; then
      add_finding "CRITICAL" "manifest" "framework-manifest.txt lists \`$path\` but the path doesn't exist locally. apply-update.sh will fail mid-copy when it tries to mirror this path. Fix: restore the path, or remove the entry from the manifest."
    fi
  done < "$MANIFEST_FILE"
}

# --- Check 5: .framework-version validity ----------------------------
check_framework_version() {
  if [ ! -f "$VERSION_FILE" ]; then
    # Not all projects have opted in yet — not a failure.
    return
  fi

  # Source in a subshell so we don't leak vars into doctor's environment.
  # mktemp, not a predictable /tmp path (DA-H8): on a restricted /tmp the
  # old redirect failed silently and the check always passed.
  local missing_tmp
  missing_tmp=$(mktemp 2>/dev/null) || missing_tmp="$PROJECT_ROOT/.claude/.doctor-missing.$$"
  (
    # shellcheck disable=SC1090
    source "$VERSION_FILE"
    [ -z "${FRAMEWORK_UPSTREAM_URL:-}" ]    && echo "FRAMEWORK_UPSTREAM_URL"
    [ -z "${FRAMEWORK_UPSTREAM_BRANCH:-}" ] && echo "FRAMEWORK_UPSTREAM_BRANCH"
    [ -z "${FRAMEWORK_PINNED_SHA:-}" ]      && echo "FRAMEWORK_PINNED_SHA"
  ) > "$missing_tmp" 2>/dev/null || true

  if [ -s "$missing_tmp" ]; then
    local missing_csv
    missing_csv=$(tr '\n' ',' < "$missing_tmp" | sed 's/,$//')
    add_finding "CRITICAL" "framework-version" ".framework-version is missing required fields: $missing_csv. Updates will not work. Fix: re-run \`bash .claude/framework/update/init-framework-version.sh --force\`."
  fi
  rm -f "$missing_tmp"
}

# --- Check 6: (retired) ----------------------------------------------
# Check 6 (multi-project mode consistency) was removed 2026-06-10 along
# with multi-project mode itself (TASK-023). Number retained so later
# check numbers stay stable across docs and findings history.

# --- Check 7: No duplicate TASK-NNN heading IDs ----------------------
check_task_duplicates() {
  # Framework-self mode: state files live under .claude/framework/self/ when
  # the flag is present (upstream framework dev only).
  local state_root="$PROJECT_ROOT"
  if [ -f "$PROJECT_ROOT/.claude/framework-self.flag" ]; then
    state_root="$PROJECT_ROOT/.claude/framework/self"
  fi
  local tasks="$state_root/TASKS.md"
  [ ! -f "$tasks" ] && return

  # Only match task IDs that appear in headings (#### [TASK-NNN] or
  # ### [TASK-NNN] or - **TASK-NNN** — style). Avoid counting references
  # inside prose.
  mapfile -t dups < <(
    grep -oE '(#+\s*\[(TASK|BUG)-[0-9]+\]|\*\*(TASK|BUG)-[0-9]+\*\*)' "$tasks" \
      | grep -oE '(TASK|BUG)-[0-9]+' \
      | sort \
      | uniq -d
  )

  for id in "${dups[@]}"; do
    add_finding "WARNING" "tasks" "TASKS.md contains duplicate heading entries for \`$id\`. Task IDs must be unique — commit linkage and status tracking break with duplicates. Fix: rename one, merge them, or move one to Done with a ✓."
  done
}

# --- Check 8: framework-self.flag must not be committed to git -------
# The flag is per-clone local state — it tells hooks/cold-start to
# redirect to .claude/framework/self/. If it's tracked by git, a fresh
# clone would inherit it and activate framework-self mode in a
# consumer project, which is broken (state files aren't populated,
# .claude/framework/self/ may not be in the manifest). Flag it loudly.
check_framework_self_flag_untracked() {
  local flag=".claude/framework-self.flag"
  [ ! -f "$PROJECT_ROOT/$flag" ] && return
  # Is the flag tracked by git in this repo?
  if git -C "$PROJECT_ROOT" ls-files --error-unmatch -- "$flag" >/dev/null 2>&1; then
    add_finding "WARNING" "framework-self" "\`$flag\` is tracked by git in this repo. The flag is meant to be per-clone local state (present only in the upstream framework repo to enable self-dogfooding). Committing it causes fresh clones and apply-update'd consumers to inherit framework-self mode incorrectly. Fix: \`git rm --cached .claude/framework-self.flag\` and add \`.claude/framework-self.flag\` to \`.gitignore\`."
  fi
}

# --- Check 9: Detector-consumer determinism --------------------------
# If any framework script/hook/agent has been recently added or modified
# to READ .claude/review-findings.md (or its rotated archive) — i.e.,
# build automation on top of /healthcheck output — warn unless
# /healthcheck --verify has run since the introducing commit. This is
# the BUG-001 defense: don't ship consumers against a detector that
# hasn't had its determinism verified.
#
# Heuristic: search framework-owned paths for files modified in the
# last 30 commits that grep for `review-findings` and look like they
# READ the file (cat, head, grep, jq, parse) rather than just APPEND
# (the rotation case and the normal write pattern).
check_detector_consumers() {
  # Files to scan: framework code only (not docs, not the runbook itself).
  # `.claude/framework/doctor/` is intentionally EXCLUDED — doctor.sh is
  # the checker for this invariant and its check pattern necessarily
  # contains the string "review-findings", which would cause a self-match.
  local scan_paths=(
    "$PROJECT_ROOT/.claude/hooks"
    "$PROJECT_ROOT/.claude/framework/insights"
    "$PROJECT_ROOT/.claude/framework/audit"
  )
  # The runbook itself (healthcheck.md) is the producer, not a consumer.
  # The scrape-review-findings.sh script is a known legitimate consumer
  # (insights pipeline) — it's older than this check and pre-existed
  # BUG-001's surfacing.
  local known_consumers="scrape-review-findings.sh"

  local recently_changed=""
  recently_changed=$(git -C "$PROJECT_ROOT" log --name-only --pretty=format: -30 -- \
    .claude/hooks .claude/framework/insights .claude/framework/audit 2>/dev/null \
    | sort -u | grep -v '^$' || true)
  [ -z "$recently_changed" ] && return

  local suspect_files=()
  while IFS= read -r f; do
    [ -z "$f" ] && continue
    [ ! -f "$PROJECT_ROOT/$f" ] && continue
    # Skip known legitimate consumers
    case "$(basename "$f")" in
      $known_consumers) continue ;;
    esac
    # Does the file READ review-findings? Grep for read-like patterns.
    if grep -qE '(cat|head|tail|jq|grep|awk|sed)[[:space:]][^|]*review-findings' "$PROJECT_ROOT/$f" 2>/dev/null \
       || grep -qE '<[[:space:]]*[^|<>]*review-findings' "$PROJECT_ROOT/$f" 2>/dev/null; then
      suspect_files+=("$f")
    fi
  done <<<"$recently_changed"

  [ ${#suspect_files[@]} -eq 0 ] && return

  # Has /healthcheck --verify been run since the most recent of these
  # files was last touched? The marker is a determinism summary under
  # .claude/review-findings/_determinism-*.md.
  # Portable mtime (DA-H8): GNU stat -c, BSD stat -f, GNU date -r, else 0.
  # The old bare `date -r` is a different flag on BSD date (epoch display,
  # not file mtime) so the check silently degraded off-GNU.
  _mtime() {
    stat -c %Y "$1" 2>/dev/null || stat -f %m "$1" 2>/dev/null \
      || date -r "$1" +%s 2>/dev/null || echo 0
  }

  local newest_consumer_mtime=0
  for f in "${suspect_files[@]}"; do
    local m
    m=$(_mtime "$PROJECT_ROOT/$f")
    [ "$m" -gt "$newest_consumer_mtime" ] && newest_consumer_mtime="$m"
  done

  local newest_verify_mtime=0
  if [ -d "$PROJECT_ROOT/.claude/review-findings" ]; then
    local v vf
    # Portable replacement for `find -printf '%T@'` (GNU-only, DA-H8).
    while IFS= read -r vf; do
      v=$(_mtime "$vf")
      [ "$v" -gt "$newest_verify_mtime" ] && newest_verify_mtime="$v"
    done < <(find "$PROJECT_ROOT/.claude/review-findings" -name '_determinism-*.md' 2>/dev/null)
  fi

  if [ "$newest_verify_mtime" -lt "$newest_consumer_mtime" ]; then
    local files_csv
    files_csv=$(printf '%s, ' "${suspect_files[@]}")
    files_csv="${files_csv%, }"
    add_finding "WARNING" "detector-consumer" "Recent framework changes ($files_csv) appear to READ \`.claude/review-findings.md\` — i.e., consume /healthcheck output. No \`/healthcheck --verify\` run found since these files were modified. Run \`/healthcheck --verify 3\` and confirm output is stable before relying on these consumers. Rationale: BUG-001 (2026-04-26) — consumers built on non-deterministic detector output silently shipped against unreliable data."
  fi
}

# --- Check 10: statusline reads stdin, not a phantom env var ----------
# Claude Code delivers statusline data as JSON on STDIN. There is no
# CLAUDE_STATUS_JSON env var — a command that reads it renders permanent
# "?" placeholders. Consumers' settings.json is project-owned (not
# manifest-updated), so this check is how the fix reaches existing clones.
check_statusline() {
  [ ! -f "$SETTINGS_FILE" ] && return
  command -v jq >/dev/null 2>&1 || return
  local cmd
  cmd=$(jq -r '.statusLine.command // empty' "$SETTINGS_FILE" 2>/dev/null || true)
  [ -z "$cmd" ] && return
  if [[ "$cmd" == *CLAUDE_STATUS_JSON* ]]; then
    add_finding "WARNING" "statusline" "settings.json statusLine reads \$CLAUDE_STATUS_JSON, which Claude Code never sets — the status line has been rendering placeholders. Status data arrives as JSON on stdin. Fix: set statusLine.command to \`bash .claude/hooks/statusline.sh\` (shipped stdin reader)."
  fi
}

# --- Check 11: GNU toolchain capabilities ------------------------------
# Several framework scripts depend on GNU extensions that BSD/macOS stock
# tools silently lack: find -printf (doctor Checks 1/9, instinct-miner
# discovery), date -d (update/insights throttles), sed -i without ''
# (migrate-layout rewrites). On BSD tools these don't error visibly — the
# features just go dead. Say so loudly once instead (DA-C8).
check_gnu_toolchain() {
  local missing=()
  find /dev/null -maxdepth 0 -printf '' >/dev/null 2>&1 \
    || missing+=("find -printf (doctor hook/mtime checks, instinct-miner discovery)")
  date -u -d '1970-01-01T00:00:00Z' +%s >/dev/null 2>&1 \
    || missing+=("GNU date -d (update/insights throttles never engage)")
  sed --version 2>/dev/null | grep -q GNU \
    || missing+=("GNU sed -i (migrate-layout path rewrites silently skip)")

  [ ${#missing[@]} -eq 0 ] && return
  local list
  list=$(printf '%s; ' "${missing[@]}")
  list="${list%; }"
  add_finding "WARNING" "gnu-toolchain" "Non-GNU userland detected — these framework features are silently degraded: $list. Fix on macOS: \`brew install coreutils findutils gnu-sed grep\` and put the gnubin dirs on PATH, or accept the listed degradations."
}

# --- Check 12: upstream framework-dev content leaked into state files --
# Clones made before the 2026-06-10 clean-template switch (TASK-027)
# inherited the upstream repo's own framework-development GOTCHAS /
# FRAMEWORK-SUGGESTIONS content in their root .claude/ state files. Those
# entries describe building the framework itself, not the consumer's
# project — noise for every session that reads them. State files are
# consumer-owned (never manifest-updated), so this doctor warning is the
# propagation channel (TASK-024 principle). Fingerprints are entry titles
# unique to the leaked upstream content; the clean templates ship none of
# them. The upstream repo itself keeps its dev content under
# .claude/framework/self/ — not scanned here — so it stays clean too.
check_state_file_leak() {
  local f hits=""
  for f in "$PROJECT_ROOT/.claude/GOTCHAS.md" "$PROJECT_ROOT/.claude/FRAMEWORK-SUGGESTIONS.md"; do
    [ -f "$f" ] || continue
    if grep -qE "SCRIPT_DIR depth is move-sensitive|Bulk sed on paths can create double-prefix|00_framework/ → \.claude/framework/ restructure" "$f" 2>/dev/null; then
      hits+="${f##*/} "
    fi
  done
  [ -z "$hits" ] && return
  add_finding "WARNING" "state-files" "${hits% }contains upstream framework-development entries (pre-2026-06-10 template leak, TASK-027). They describe the framework's OWN development, not this project — prune them (keep anything genuinely about this project). /housekeeping's adopted-feedback step is a good moment."
}

# --- Run all checks --------------------------------------------------
check_hooks
check_cross_refs
check_claude_include
check_manifest_paths
check_framework_version
check_task_duplicates
check_framework_self_flag_untracked
check_detector_consumers
check_statusline
check_gnu_toolchain
check_state_file_leak

# --- Write flag file if any findings ---------------------------------
if [ ${#findings[@]} -eq 0 ]; then
  exit 0
fi

# Sort findings by severity: CRITICAL first, WARNING next, INFO last.
sorted_findings=()
for sev in CRITICAL WARNING INFO; do
  for f in "${findings[@]}"; do
    [[ "$f" == "$sev|"* ]] && sorted_findings+=("$f")
  done
done

now_iso=$(date -u +%Y-%m-%dT%H:%M:%SZ)
crit_count=$(printf '%s\n' "${findings[@]}" | grep -c '^CRITICAL|' || true)
warn_count=$(printf '%s\n' "${findings[@]}" | grep -c '^WARNING|' || true)
info_count=$(printf '%s\n' "${findings[@]}" | grep -c '^INFO|' || true)

{
  echo "# Framework Doctor — Issues Detected"
  echo
  echo "**Scan time:** $now_iso"
  echo "**Findings:** $crit_count CRITICAL, $warn_count WARNING, $info_count INFO"
  echo
  echo "## Findings"
  echo
  for f in "${sorted_findings[@]}"; do
    local_sev="${f%%|*}"
    rest="${f#*|}"
    check_name="${rest%%|*}"
    msg="${rest#*|}"
    echo "- **$local_sev** — [$check_name] $msg"
    echo
  done
  echo "## What to do"
  echo
  echo "CRITICAL findings should be resolved before continuing — they"
  echo "indicate broken framework state that will cause silent failures."
  echo
  echo "WARNING findings should be triaged; some may be intentional"
  echo "(e.g., a hook kept around but not wired yet)."
  echo
  echo "INFO findings are informational only — no action required unless"
  echo "a related feature is relevant to you."
  echo
  echo "To dismiss for this session: \`rm .claude/.framework-doctor-findings.md\`."
  echo "Doctor re-scans on every cold start (no throttle — state issues"
  echo "don't get less broken over time)."
} > "$FLAG_FILE"

echo "doctor: ${#findings[@]} finding(s) ($crit_count CRITICAL, $warn_count WARNING, $info_count INFO) — see $FLAG_FILE"
exit 0
