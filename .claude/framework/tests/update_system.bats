#!/usr/bin/env bats
# Update-system test tier (TASK-032): apply-update / check-updates /
# migrate-layout / doctor against synthetic local-path upstream + consumer
# fixtures (see update_helpers.bash). Fully offline; everything lives in
# $BATS_TEST_TMPDIR.

load update_helpers

# --- apply-update.sh --------------------------------------------------

@test "apply-update: happy path — file overwrite, dir mirror, project sibling survives" {
  build_upstream
  build_consumer
  run apply_update
  [ "$status" -eq 0 ]
  grep -q "owned v2" "$CONSUMER/.claude/framework/owned/file.txt"
  [ -f "$CONSUMER/.claude/framework/owned/new-in-v2.txt" ]
  grep -q "hook v2"  "$CONSUMER/.claude/hooks/sample-hook.sh"
  grep -q "rules v2" "$CONSUMER/CLAUDE.framework.md"
  # Project-owned sibling in the shared hooks dir is untouched.
  grep -q "must survive" "$CONSUMER/.claude/hooks/project-hook.sh"
  [[ "$output" == *"path(s) updated"* ]]
}

@test "apply-update: pin + LAST_CHECKED rewritten, pending flag cleared" {
  build_upstream
  build_consumer
  echo "stale notification" > "$CFLAG"
  run apply_update
  [ "$status" -eq 0 ]
  grep -q "^FRAMEWORK_PINNED_SHA=$UPSTREAM_V2_SHA" "$CVERSION"
  ! grep -q "1970-01-01" "$CVERSION"
  [ ! -f "$CFLAG" ]
}

@test "apply-update: upstream-removal path deletes local-only manifest entry" {
  build_upstream
  build_consumer
  mkdir -p "$CONSUMER/.claude/framework/retired"
  echo "old feature" > "$CONSUMER/.claude/framework/retired/feature.sh"
  echo ".claude/framework/retired/" >> "$CONSUMER/.claude/framework/update/framework-manifest.txt"
  git -C "$CONSUMER" add -A
  git -C "$CONSUMER" commit -qm "consumer has a path upstream no longer ships"
  run apply_update
  [ "$status" -eq 0 ]
  [[ "$output" == *"removed upstream"* ]]
  [ ! -e "$CONSUMER/.claude/framework/retired" ]
}

@test "apply-update: dirty tree (modified file) refuses with tree untouched" {
  build_upstream
  build_consumer
  echo "local edit" >> "$CONSUMER/.claude/framework/owned/file.txt"
  run apply_update
  [ "$status" -eq 1 ]
  [[ "$output" == *"refusing"* ]]
  [[ "$output" == *".claude/framework/owned"* ]]
  grep -q "local edit" "$CONSUMER/.claude/framework/owned/file.txt"
  grep -q "hook v1" "$CONSUMER/.claude/hooks/sample-hook.sh"
  grep -q "^FRAMEWORK_PINNED_SHA=$UPSTREAM_V1_SHA" "$CVERSION"
}

@test "apply-update: dirty tree (staged change) refuses" {
  build_upstream
  build_consumer
  echo "staged edit" >> "$CONSUMER/CLAUDE.framework.md"
  git -C "$CONSUMER" add CLAUDE.framework.md
  run apply_update
  [ "$status" -eq 1 ]
  [[ "$output" == *"refusing"* ]]
  grep -q "^FRAMEWORK_PINNED_SHA=$UPSTREAM_V1_SHA" "$CVERSION"
}

@test "apply-update: dirty tree (untracked file in framework path) refuses" {
  build_upstream
  build_consumer
  echo "wip" > "$CONSUMER/.claude/framework/owned/untracked-wip.txt"
  run apply_update
  [ "$status" -eq 1 ]
  [[ "$output" == *"refusing"* ]]
  [[ "$output" == *"untracked-wip.txt"* ]]
  [ -f "$CONSUMER/.claude/framework/owned/untracked-wip.txt" ]
  grep -q "owned v1" "$CONSUMER/.claude/framework/owned/file.txt"
}

@test "apply-update: missing upstream manifest warns loudly and falls back to local (DA-M5)" {
  build_upstream --no-manifest
  build_consumer
  run apply_update
  [ "$status" -eq 0 ]
  [[ "$output" == *"no framework-manifest.txt"* ]]
  [[ "$output" == *"LOCAL manifest"* ]]
  # Local-manifest fallback still applies entries that exist upstream.
  grep -q "owned v2" "$CONSUMER/.claude/framework/owned/file.txt"
  grep -q "rules v2" "$CONSUMER/CLAUDE.framework.md"
}

@test "apply-update: staging failure aborts with working tree fully intact (DA-C3)" {
  build_upstream
  build_consumer
  # Force phase-1 staging to fail by shadowing `cp` on PATH (chmod-based
  # unwritable dirs are not reliable on Windows git-bash). git clone does
  # not shell out to cp, so the failure lands exactly at the staging copy.
  mkdir -p "$BATS_TEST_TMPDIR/fakebin"
  printf '#!/bin/sh\nexit 1\n' > "$BATS_TEST_TMPDIR/fakebin/cp"
  chmod +x "$BATS_TEST_TMPDIR/fakebin/cp"
  PATH="$BATS_TEST_TMPDIR/fakebin:$PATH" run apply_update
  [ "$status" -eq 3 ]
  [[ "$output" == *"staging"* ]]
  [[ "$output" == *"No changes were made"* ]]
  grep -q "owned v1" "$CONSUMER/.claude/framework/owned/file.txt"
  grep -q "hook v1"  "$CONSUMER/.claude/hooks/sample-hook.sh"
  grep -q "^FRAMEWORK_PINNED_SHA=$UPSTREAM_V1_SHA" "$CVERSION"
  # trap cleanup removed the staging dir
  ! ls "$CONSUMER/.claude"/.update-staging.* 2>/dev/null
}

@test "apply-update: customised command file → loud collision notice (TASK-039)" {
  build_upstream
  build_consumer
  # Consumer replaced the framework command with their OWN version (committed
  # — so the dirty-check passes and it would be silently destroyed).
  echo "MY CUSTOM healthcheck-style command" > "$CONSUMER/.claude/commands/wrapup.md"
  git -C "$CONSUMER" add -A
  git -C "$CONSUMER" commit -qm "local custom command"
  run apply_update
  [ "$status" -eq 0 ]
  [[ "$output" == *"COMMAND COLLISION"* ]]
  [[ "$output" == *".claude/commands/wrapup.md"* ]]
  # Overwrite still happened (manifest paths are framework-owned).
  grep -q "wrapup command v2" "$CONSUMER/.claude/commands/wrapup.md"
}

@test "apply-update: stock command file evolving upstream → NO collision noise (TASK-039)" {
  build_upstream
  build_consumer
  run apply_update
  [ "$status" -eq 0 ]
  [[ "$output" != *"COMMAND COLLISION"* ]]
  grep -q "wrapup command v2" "$CONSUMER/.claude/commands/wrapup.md"
}

@test "apply-update: missing .framework-version exits 2" {
  build_upstream
  build_consumer
  rm "$CVERSION"
  run apply_update
  [ "$status" -eq 2 ]
}

# --- check-updates.sh -------------------------------------------------

@test "check-updates: throttle honoured — recently checked, no network attempt" {
  build_upstream
  build_consumer
  # An unreachable URL proves the throttle short-circuits before any
  # network use: a live check against this URL would exit 3.
  set_version_field FRAMEWORK_UPSTREAM_URL "$BATS_TEST_TMPDIR/does-not-exist"
  set_version_field FRAMEWORK_LAST_CHECKED "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  run check_updates
  [ "$status" -eq 0 ]
  [ ! -f "$CFLAG" ]
}

@test "check-updates: pending flag survives a throttled run (DA-C4 regression)" {
  build_upstream
  build_consumer
  echo "PENDING-MARKER-123" > "$CFLAG"
  set_version_field FRAMEWORK_LAST_CHECKED "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  run check_updates
  [ "$status" -eq 0 ]
  grep -q "PENDING-MARKER-123" "$CFLAG"
}

@test "check-updates: pending flag survives a network failure (DA-C4 regression)" {
  build_upstream
  build_consumer
  echo "PENDING-MARKER-456" > "$CFLAG"
  set_version_field FRAMEWORK_UPSTREAM_URL "$BATS_TEST_TMPDIR/does-not-exist"
  run check_updates
  [ "$status" -eq 3 ]
  grep -q "PENDING-MARKER-456" "$CFLAG"
}

@test "check-updates: live up-to-date clears stale flag and bumps LAST_CHECKED" {
  build_upstream
  build_consumer
  echo "stale flag from an old check" > "$CFLAG"
  set_version_field FRAMEWORK_PINNED_SHA "$UPSTREAM_V2_SHA"
  run check_updates
  [ "$status" -eq 0 ]
  [ ! -f "$CFLAG" ]
  ! grep -q "1970-01-01" "$CVERSION"
}

@test "check-updates: update available writes a sane flag file" {
  build_upstream
  build_consumer
  run check_updates
  [ "$status" -eq 0 ]
  [ -f "$CFLAG" ]
  grep -q "${UPSTREAM_V1_SHA:0:7}" "$CFLAG"
  grep -q "${UPSTREAM_V2_SHA:0:7}" "$CFLAG"
  grep -q "v2: framework changes" "$CFLAG"
  grep -q "## To apply" "$CFLAG"
}

# --- migrate-layout.sh ------------------------------------------------

@test "migrate-layout: detects old layout via 00_framework/ alone" {
  build_old_layout_consumer dir-only
  run migrate_layout
  [ "$status" -eq 0 ]
  [[ "$output" == *"old layout detected"* ]]
  [ ! -d "$OLDC/00_framework" ]
  [ -f "$OLDC/.claude/framework/insights/notes.txt" ]
}

@test "migrate-layout: detects old layout via root TASKS.md alone" {
  build_old_layout_consumer tasks-only
  run migrate_layout
  [ "$status" -eq 0 ]
  [[ "$output" == *"old layout detected"* ]]
  [ ! -f "$OLDC/TASKS.md" ]
  [ -f "$OLDC/.claude/TASKS.md" ]
}

@test "migrate-layout: full migration invariants — moves, rewrites, commit" {
  build_old_layout_consumer full
  run migrate_layout
  [ "$status" -eq 0 ]
  # Framework dir merged into .claude/framework/
  [ ! -d "$OLDC/00_framework" ]
  [ -f "$OLDC/.claude/framework/insights/notes.txt" ]
  # State + config files moved
  [ ! -f "$OLDC/TASKS.md" ];           [ -f "$OLDC/.claude/TASKS.md" ]
  [ ! -f "$OLDC/STATUS.md" ];          [ -f "$OLDC/.claude/STATUS.md" ]
  [ ! -f "$OLDC/.framework-version" ]; [ -f "$OLDC/.claude/.framework-version" ]
  # Reference rewrites
  grep -q ".claude/framework/" "$OLDC/CLAUDE.md"
  ! grep -q "00_framework" "$OLDC/CLAUDE.md"
  grep -q ".claude/.framework-update-available.md" "$OLDC/.gitignore"
  grep -q ".claude/framework/self/README.md" "$OLDC/.gitignore"
  # Migration commit exists
  git -C "$OLDC" log -1 --format=%s | grep -q "layout migration"
}

@test "migrate-layout: idempotent — second run is a no-op" {
  build_old_layout_consumer full
  run migrate_layout
  [ "$status" -eq 0 ]
  local head_after_first
  head_after_first=$(git -C "$OLDC" rev-parse HEAD)
  run migrate_layout
  [ "$status" -eq 0 ]
  [[ "$output" == *"already on new layout"* ]]
  [ "$(git -C "$OLDC" rev-parse HEAD)" = "$head_after_first" ]
}

@test "migrate-layout: stray .env.local is NOT swept into the migration commit (DA-H5)" {
  build_old_layout_consumer full
  echo "SECRET=hunter2" > "$OLDC/.env.local"
  run migrate_layout
  [ "$status" -eq 0 ]
  # Not in the migration commit, not tracked, still on disk.
  ! git -C "$OLDC" show --name-only --format= HEAD | grep -q ".env.local"
  ! git -C "$OLDC" ls-files | grep -q ".env.local"
  [ -f "$OLDC/.env.local" ]
}

@test "migrate-layout: refuses with uncommitted framework-path changes (BUG-002 regression)" {
  build_old_layout_consumer full
  echo "uncommitted work" >> "$OLDC/TASKS.md"
  run migrate_layout
  [ "$status" -eq 2 ]
  [[ "$output" == *"uncommitted changes"* ]]
  # Migration did not proceed.
  [ -f "$OLDC/TASKS.md" ]
  [ -d "$OLDC/00_framework" ]
}

# --- doctor.sh --------------------------------------------------------

@test "doctor: clean tree is silent (exit 0, no findings flag)" {
  build_doctor_consumer
  run run_doctor
  [ "$status" -eq 0 ]
  # On GNU userland with jq present the flag must be entirely absent.
  # Tolerate environment-dependent findings (gnu-toolchain WARNING on
  # BSD/macOS, jq-missing INFO) — but never a CRITICAL.
  if [ -f "$DOCFLAG" ]; then
    ! grep -q "CRITICAL" "$DOCFLAG"
  fi
  if command -v jq >/dev/null 2>&1 && sed --version 2>/dev/null | grep -q GNU; then
    [ ! -f "$DOCFLAG" ]
  fi
}

@test "doctor: dispatcher-driven hook (unregistered but invoked by a registered hook) is NOT flagged (TASK-035)" {
  command -v jq >/dev/null 2>&1 || skip "jq required for the hooks check"
  build_doctor_consumer
  # child-hook.sh isn't in settings.json, but the registered sample-hook.sh
  # invokes it — indirect wiring, not dead code.
  printf '#!/usr/bin/env bash\nbash "$(dirname "$0")/child-hook.sh"\n' > "$DOC/.claude/hooks/sample-hook.sh"
  printf '#!/usr/bin/env bash\nexit 0\n' > "$DOC/.claude/hooks/child-hook.sh"
  run run_doctor
  [ "$status" -eq 0 ]
  if [ -f "$DOCFLAG" ]; then
    ! grep -q "child-hook.sh" "$DOCFLAG"
  fi
}

@test "doctor: truly unwired hook on disk IS still flagged (control for indirect-wiring pass)" {
  command -v jq >/dev/null 2>&1 || skip "jq required for the hooks check"
  build_doctor_consumer
  printf '#!/usr/bin/env bash\nexit 0\n' > "$DOC/.claude/hooks/orphan-hook.sh"
  run run_doctor
  [ "$status" -eq 0 ]
  grep -q "orphan-hook.sh" "$DOCFLAG"
}

@test "doctor: missing hook file referenced in settings.json → CRITICAL [hooks]" {
  command -v jq >/dev/null 2>&1 || skip "jq required for the hooks check"
  build_doctor_consumer
  rm "$DOC/.claude/hooks/sample-hook.sh"
  run run_doctor
  [ "$status" -eq 0 ]
  grep -q '\*\*CRITICAL\*\* — \[hooks\]' "$DOCFLAG"
  grep -q "sample-hook.sh" "$DOCFLAG"
}

@test "doctor: link-style CLAUDE.md pointer (no @import) → CRITICAL [claude-md]" {
  build_doctor_consumer
  printf '# Project\n\nSee [framework rules](CLAUDE.framework.md).\n' > "$DOC/CLAUDE.md"
  run run_doctor
  [ "$status" -eq 0 ]
  grep -q '\*\*CRITICAL\*\* — \[claude-md\]' "$DOCFLAG"
  grep -q "does not @import" "$DOCFLAG"
}

@test "doctor: manifest entry with no local path → CRITICAL [manifest]" {
  build_doctor_consumer
  echo ".claude/framework/ghost-dir/" >> "$DOC/.claude/framework/update/framework-manifest.txt"
  run run_doctor
  [ "$status" -eq 0 ]
  grep -q '\*\*CRITICAL\*\* — \[manifest\]' "$DOCFLAG"
  grep -q "ghost-dir" "$DOCFLAG"
}

@test "doctor: empty .framework-version field → CRITICAL [framework-version]" {
  build_doctor_consumer
  cat > "$DOC/.claude/.framework-version" <<'EOF'
FRAMEWORK_UPSTREAM_URL=https://example.invalid/repo.git
FRAMEWORK_UPSTREAM_BRANCH=main
FRAMEWORK_PINNED_SHA=
FRAMEWORK_LAST_CHECKED=1970-01-01T00:00:00Z
EOF
  run run_doctor
  [ "$status" -eq 0 ]
  grep -q '\*\*CRITICAL\*\* — \[framework-version\]' "$DOCFLAG"
  grep -q "FRAMEWORK_PINNED_SHA" "$DOCFLAG"
}

@test "doctor: leaked upstream framework-dev GOTCHAS content → WARNING [state-files] (Check 12)" {
  build_doctor_consumer
  cat >> "$DOC/.claude/GOTCHAS.md" <<'GOTCHA'

### SCRIPT_DIR depth is move-sensitive — add one `..` per extra directory level

Leaked upstream entry from a pre-2026-06-10 clone.
GOTCHA
  run run_doctor
  [ "$status" -eq 0 ]
  [ -f "$DOCFLAG" ]
  grep -q "state-files" "$DOCFLAG"
  grep -q "framework-development entries" "$DOCFLAG"
}

@test "doctor: clean consumer GOTCHAS template does NOT trigger Check 12 (control)" {
  build_doctor_consumer
  run run_doctor
  [ "$status" -eq 0 ]
  if [ -f "$DOCFLAG" ]; then
    ! grep -q "state-files" "$DOCFLAG"
  fi
}
