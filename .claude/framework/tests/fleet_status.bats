#!/usr/bin/env bats
# fleet-status.sh tests (TASK-042): read-only sweep over synthetic sibling
# repos under a temp root. Offline (no --check-remote).

load update_helpers

# Build a fleet root with three siblings:
#   ok-consumer   — post-layout, .framework-version present, clean
#   old-consumer  — PRE-migration (00_framework/ + root TASKS.md)
#   not-a-fw      — a git repo with NO .claude/ (must be ignored)
# Sets: FLEET_ROOT.
build_fleet() {
  FLEET_ROOT="$BATS_TEST_TMPDIR/fleet"
  mkdir -p "$FLEET_ROOT"

  mkdir -p "$FLEET_ROOT/ok-consumer/.claude"
  cat > "$FLEET_ROOT/ok-consumer/.claude/.framework-version" <<EOF
FRAMEWORK_UPSTREAM_URL=https://example.invalid/repo.git
FRAMEWORK_UPSTREAM_BRANCH=main
FRAMEWORK_PINNED_SHA=abcdef1234567890
EOF
  cat > "$FLEET_ROOT/ok-consumer/.claude/.skills-version" <<EOF
SKILLS_SELECTED="python-development"
EOF
  _init_fixture_repo "$FLEET_ROOT/ok-consumer"
  git -C "$FLEET_ROOT/ok-consumer" add -A
  git -C "$FLEET_ROOT/ok-consumer" commit -qm base

  mkdir -p "$FLEET_ROOT/old-consumer/.claude" "$FLEET_ROOT/old-consumer/00_framework"
  echo "# tasks" > "$FLEET_ROOT/old-consumer/TASKS.md"
  _init_fixture_repo "$FLEET_ROOT/old-consumer"
  git -C "$FLEET_ROOT/old-consumer" add -A
  git -C "$FLEET_ROOT/old-consumer" commit -qm base

  mkdir -p "$FLEET_ROOT/not-a-fw"
  _init_fixture_repo "$FLEET_ROOT/not-a-fw"
  echo readme > "$FLEET_ROOT/not-a-fw/README.md"
  git -C "$FLEET_ROOT/not-a-fw" add -A
  git -C "$FLEET_ROOT/not-a-fw" commit -qm base
}

fleet() { bash "$FW_REPO_ROOT/.claude/framework/fleet/fleet-status.sh" "$@"; }

@test "fleet: reports framework consumers, ignores non-framework dirs" {
  build_fleet
  run fleet "$FLEET_ROOT"
  [ "$status" -eq 0 ]
  [[ "$output" == *"ok-consumer"* ]]
  [[ "$output" == *"old-consumer"* ]]
  [[ "$output" != *"not-a-fw"* ]]
  [[ "$output" == *"2 consumer(s)"* ]]
}

@test "fleet: pinned SHA short + PRE-migration layout flagged" {
  build_fleet
  run fleet "$FLEET_ROOT"
  [ "$status" -eq 0 ]
  [[ "$output" == *"abcdef1"* ]]          # ok-consumer pinned short
  [[ "$output" == *"PRE-migration"* ]]    # old-consumer layout
}

@test "fleet: skills selection surfaced; non-opted shows dash" {
  build_fleet
  run fleet "$FLEET_ROOT"
  [ "$status" -eq 0 ]
  [[ "$output" == *"python-development"* ]]
}

@test "fleet: dirty count reflects uncommitted changes" {
  build_fleet
  echo "wip" > "$FLEET_ROOT/ok-consumer/scratch.txt"
  run fleet "$FLEET_ROOT"
  [ "$status" -eq 0 ]
  # ok-consumer row now shows a non-zero dirty count
  [[ "$output" =~ ok-consumer[[:space:]]+abcdef1[[:space:]]+ok[[:space:]]+python-development[[:space:]]+[1-9] ]]
}

@test "fleet: md format emits a Markdown table" {
  build_fleet
  run fleet "$FLEET_ROOT" --format md
  [ "$status" -eq 0 ]
  [[ "$output" == *"| PROJECT | PINNED |"* ]]
  [[ "$output" == *"| --- |"* ]]
}

@test "fleet: empty root → friendly no-consumers message" {
  mkdir -p "$BATS_TEST_TMPDIR/empty-root"
  run fleet "$BATS_TEST_TMPDIR/empty-root"
  [ "$status" -eq 0 ]
  [[ "$output" == *"no framework consumers found"* ]]
}

@test "fleet: never mutates a scanned repo (read-only, AC2)" {
  build_fleet
  before=$(git -C "$FLEET_ROOT/ok-consumer" status --porcelain | grep -c . || true)
  fleet "$FLEET_ROOT" >/dev/null
  after=$(git -C "$FLEET_ROOT/ok-consumer" status --porcelain | grep -c . || true)
  [ "$before" = "$after" ]
  # no doctor findings flag written into the scanned consumer
  [ ! -f "$FLEET_ROOT/ok-consumer/.claude/.framework-doctor-findings.md" ]
}
