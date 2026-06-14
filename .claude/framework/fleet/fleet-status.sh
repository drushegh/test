#!/usr/bin/env bash
# fleet-status.sh — read-only status sweep across sibling framework consumers
# (TASK-042). Answers "which of my projects are on a stale framework?" as a
# table instead of a vibe.
#
# Usage:
#   bash .claude/framework/fleet/fleet-status.sh [ROOT] [--format text|md] [--check-remote]
#
#   ROOT            directory to scan (default: the parent of this repo, i.e.
#                   sibling projects). Each immediate subdirectory that is a
#                   git repo containing .claude/ is reported.
#   --format        text (aligned columns, default) | md (Markdown table).
#   --check-remote  also ls-remote each project's framework upstream and show
#                   ahead/behind vs its pinned SHA (network; slower). Off by
#                   default so the sweep is fast and fully offline.
#
# READ-ONLY: never writes to or mutates any scanned repo (AC2). Doctor is NOT
# run on consumers (it would write their findings flag); layout era + pinned
# SHA already answer the staleness question. Fail-soft per project — one
# broken repo is reported as such and never aborts the sweep.
#
# Exit codes: 0 always (reporting tool).

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
THIS_REPO="$(cd "$SCRIPT_DIR/../../.." && pwd)"

ROOT=""
FORMAT="text"
CHECK_REMOTE=0
while [ $# -gt 0 ]; do
  case "$1" in
    --format) FORMAT="${2:-text}"; shift 2 ;;
    --format=*) FORMAT="${1#*=}"; shift ;;
    --check-remote) CHECK_REMOTE=1; shift ;;
    -h|--help) grep -E '^#( |$)' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) ROOT="$1"; shift ;;
  esac
done
[ -n "$ROOT" ] || ROOT="$(cd "$THIS_REPO/.." && pwd)"

# Resolve one project's row → tab-separated:
#   name \t pinned \t layout \t skills \t dirty \t remote
_row() {
  local dir="$1" name pinned layout skills dirty remote
  name="$(basename "$dir")"

  # framework pin
  local vf="$dir/.claude/.framework-version"
  if [ -f "$vf" ]; then
    local sha
    sha=$(grep -E '^FRAMEWORK_PINNED_SHA=' "$vf" 2>/dev/null | cut -d= -f2- | tr -d '\r')
    pinned="${sha:0:7}"
    [ -z "$pinned" ] && pinned="(empty)"
  else
    pinned="(none)"
  fi

  # layout era: pre-migration if 00_framework/ or a bare root TASKS.md exists
  if [ -d "$dir/00_framework" ] || [ -f "$dir/TASKS.md" ]; then
    layout="PRE-migration"
  else
    layout="ok"
  fi

  # skills opt-in
  local sv="$dir/.claude/.skills-version"
  if [ -f "$sv" ]; then
    local sel
    sel=$(grep -E '^SKILLS_SELECTED=' "$sv" 2>/dev/null | cut -d= -f2- | tr -d '"\r')
    skills="${sel:-(none)}"
  else
    skills="-"
  fi

  # dirty? (read-only: git status is non-mutating)
  if git -C "$dir" rev-parse --git-dir >/dev/null 2>&1; then
    local n
    n=$(git -C "$dir" status --porcelain 2>/dev/null | grep -c . || true)
    dirty="$n"
  else
    dirty="?"
  fi

  # optional remote freshness
  remote="-"
  if [ "$CHECK_REMOTE" = 1 ] && [ -f "$vf" ]; then
    local url branch pinsha latest
    url=$(grep -E '^FRAMEWORK_UPSTREAM_URL=' "$vf" | cut -d= -f2- | tr -d '\r')
    branch=$(grep -E '^FRAMEWORK_UPSTREAM_BRANCH=' "$vf" | cut -d= -f2- | tr -d '\r')
    pinsha=$(grep -E '^FRAMEWORK_PINNED_SHA=' "$vf" | cut -d= -f2- | tr -d '\r')
    if [ -n "$url" ] && [ -n "$branch" ]; then
      latest=$(git ls-remote "$url" "refs/heads/$branch" 2>/dev/null | awk '{print $1}')
      if [ -z "$latest" ]; then remote="unreachable"
      elif [ "$latest" = "$pinsha" ]; then remote="up-to-date"
      else remote="BEHIND"; fi
    fi
  fi

  printf '%s\t%s\t%s\t%s\t%s\t%s\n' "$name" "$pinned" "$layout" "$skills" "$dirty" "$remote"
}

rows=()
for dir in "$ROOT"/*/; do
  dir="${dir%/}"
  [ -d "$dir/.claude" ] || continue
  git -C "$dir" rev-parse --git-dir >/dev/null 2>&1 || continue
  # fail-soft: a row that errors is reported, never aborts the loop
  row=$(_row "$dir" 2>/dev/null) || row="$(basename "$dir")"$'\t'"(scan error)"$'\t-\t-\t-\t-'
  rows+=("$row")
done

if [ ${#rows[@]} -eq 0 ]; then
  echo "fleet: no framework consumers found under $ROOT"
  exit 0
fi

hdr_cols=("PROJECT" "PINNED" "LAYOUT" "SKILLS" "DIRTY" "REMOTE")
if [ "$FORMAT" = "md" ]; then
  printf '| %s | %s | %s | %s | %s | %s |\n' "${hdr_cols[@]}"
  printf '| --- | --- | --- | --- | --- | --- |\n'
  for r in "${rows[@]}"; do
    IFS=$'\t' read -r a b c d e f <<<"$r"
    printf '| %s | %s | %s | %s | %s | %s |\n' "$a" "$b" "$c" "$d" "$e" "$f"
  done
else
  { printf '%s\t%s\t%s\t%s\t%s\t%s\n' "${hdr_cols[@]}"
    printf '%s\n' "${rows[@]}"
  } | column -t -s $'\t'
fi

echo ""
echo "fleet: ${#rows[@]} consumer(s) under $ROOT  (LAYOUT=PRE-migration → needs migrate-layout; DIRTY=uncommitted count$([ "$CHECK_REMOTE" = 1 ] || echo "; pass --check-remote for upstream freshness"))"
exit 0
