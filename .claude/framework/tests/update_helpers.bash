# update_helpers.bash — fixture builders for the update-system test tier
# (apply-update / check-updates / migrate-layout / doctor). Loaded by
# update_system.bats via `load update_helpers`.
#
# Technique: `git clone` accepts plain local directory paths, so a synthetic
# upstream repo under $BATS_TEST_TMPDIR plays the role of the GitHub remote
# and the whole tier runs offline. The consumer fixtures carry the REAL
# scripts under test (copied from this repo) so the scripts' own
# SCRIPT_DIR-relative project-root resolution works exactly as shipped —
# everything they touch stays inside the fixture.
#
# Fixture repos deliberately have NO .gitattributes: with global
# core.autocrlf=true (the Windows default) the upstream clone's checkout
# arrives CRLF, which exercises the scripts' CRLF-strip paths for real.

FW_REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
UPDATE_SRC="$FW_REPO_ROOT/.claude/framework/update"
DOCTOR_SRC="$FW_REPO_ROOT/.claude/framework/doctor"

_init_fixture_repo() {  # <dir>
  git -C "$1" init -q -b main
  git -C "$1" config user.email test@example.com
  git -C "$1" config user.name test
  git -C "$1" config commit.gpgsign false
}

# Synthetic manifest shared by upstream and consumer:
# one dir-mirror entry, three file-overwrite entries (incl. a command
# file for the TASK-039 collision-notice cases).
write_fixture_manifest() {  # <path>
  cat > "$1" <<'EOF'
# synthetic manifest (test fixture)
.claude/framework/owned/
.claude/hooks/sample-hook.sh
.claude/commands/wrapup.md
CLAUDE.framework.md
EOF
}

# Builds the synthetic upstream with two commits on main.
# Usage: build_upstream [--no-manifest]
# Sets: UPSTREAM, UPSTREAM_V1_SHA, UPSTREAM_V2_SHA.
build_upstream() {
  local with_manifest=1
  [ "${1:-}" = "--no-manifest" ] && with_manifest=0

  UPSTREAM="$BATS_TEST_TMPDIR/upstream"
  mkdir -p "$UPSTREAM/.claude/framework/owned" "$UPSTREAM/.claude/hooks" \
           "$UPSTREAM/.claude/commands"
  _init_fixture_repo "$UPSTREAM"
  if [ "$with_manifest" = 1 ]; then
    mkdir -p "$UPSTREAM/.claude/framework/update"
    write_fixture_manifest "$UPSTREAM/.claude/framework/update/framework-manifest.txt"
  fi
  echo "owned v1" > "$UPSTREAM/.claude/framework/owned/file.txt"
  echo "hook v1"  > "$UPSTREAM/.claude/hooks/sample-hook.sh"
  echo "wrapup command v1" > "$UPSTREAM/.claude/commands/wrapup.md"
  echo "rules v1" > "$UPSTREAM/CLAUDE.framework.md"
  git -C "$UPSTREAM" add -A
  git -C "$UPSTREAM" commit -qm "v1"
  UPSTREAM_V1_SHA=$(git -C "$UPSTREAM" rev-parse HEAD)

  echo "owned v2"  > "$UPSTREAM/.claude/framework/owned/file.txt"
  echo "new in v2" > "$UPSTREAM/.claude/framework/owned/new-in-v2.txt"
  echo "hook v2"   > "$UPSTREAM/.claude/hooks/sample-hook.sh"
  echo "wrapup command v2" > "$UPSTREAM/.claude/commands/wrapup.md"
  echo "rules v2"  > "$UPSTREAM/CLAUDE.framework.md"
  git -C "$UPSTREAM" add -A
  git -C "$UPSTREAM" commit -qm "v2: framework changes"
  UPSTREAM_V2_SHA=$(git -C "$UPSTREAM" rev-parse HEAD)
}

# Builds a consumer pinned at upstream v1, carrying the real update scripts.
# Requires build_upstream to have run. Sets: CONSUMER, CVERSION, CFLAG.
build_consumer() {
  CONSUMER="$BATS_TEST_TMPDIR/consumer"
  mkdir -p "$CONSUMER/.claude/framework/update" \
           "$CONSUMER/.claude/framework/owned" \
           "$CONSUMER/.claude/hooks" \
           "$CONSUMER/.claude/commands"
  cp "$UPDATE_SRC/apply-update.sh" "$UPDATE_SRC/check-updates.sh" \
     "$CONSUMER/.claude/framework/update/"
  write_fixture_manifest "$CONSUMER/.claude/framework/update/framework-manifest.txt"
  echo "owned v1" > "$CONSUMER/.claude/framework/owned/file.txt"
  echo "hook v1"  > "$CONSUMER/.claude/hooks/sample-hook.sh"
  echo "wrapup command v1" > "$CONSUMER/.claude/commands/wrapup.md"
  echo "rules v1" > "$CONSUMER/CLAUDE.framework.md"
  echo "project hook — must survive updates" > "$CONSUMER/.claude/hooks/project-hook.sh"

  CVERSION="$CONSUMER/.claude/.framework-version"
  CFLAG="$CONSUMER/.claude/.framework-update-available.md"
  cat > "$CVERSION" <<EOF
FRAMEWORK_UPSTREAM_URL=$UPSTREAM
FRAMEWORK_UPSTREAM_BRANCH=main
FRAMEWORK_PINNED_SHA=$UPSTREAM_V1_SHA
FRAMEWORK_LAST_CHECKED=1970-01-01T00:00:00Z
EOF
  _init_fixture_repo "$CONSUMER"
  git -C "$CONSUMER" add -A
  git -C "$CONSUMER" commit -qm "consumer baseline (pinned v1)"
}

# Replace one FIELD=VALUE line in the consumer's .framework-version.
set_version_field() {  # <field> <value>
  grep -v "^$1=" "$CVERSION" > "$CVERSION.tmp"
  echo "$1=$2" >> "$CVERSION.tmp"
  mv "$CVERSION.tmp" "$CVERSION"
}

apply_update()  { ( cd "$CONSUMER" && bash .claude/framework/update/apply-update.sh ); }
check_updates() { ( cd "$CONSUMER" && bash .claude/framework/update/check-updates.sh ); }

# Old-layout consumer for migrate-layout tests. The real migrate-layout.sh
# sits at its shipped location (.claude/framework/update/), which is also
# the realistic shape: the script arrives before migration runs, so step 1
# always takes the merge-into-existing-dir branch.
# Usage: build_old_layout_consumer [full|dir-only|tasks-only]
# Sets: OLDC.
build_old_layout_consumer() {
  local shape="${1:-full}"
  OLDC="$BATS_TEST_TMPDIR/old-consumer"
  mkdir -p "$OLDC/.claude/framework/update"
  cp "$UPDATE_SRC/migrate-layout.sh" "$OLDC/.claude/framework/update/"

  if [ "$shape" != "tasks-only" ]; then
    mkdir -p "$OLDC/00_framework/insights"
    echo "insight notes" > "$OLDC/00_framework/insights/notes.txt"
  fi
  if [ "$shape" != "dir-only" ]; then
    echo "# tasks"  > "$OLDC/TASKS.md"
    echo "# status" > "$OLDC/STATUS.md"
  fi
  echo "FRAMEWORK_PINNED_SHA=abc" > "$OLDC/.framework-version"
  printf 'See 00_framework/self/README.md\nRead 00_framework/insights/notes.txt\n' > "$OLDC/CLAUDE.md"
  printf '.framework-update-available.md\n# see 00_framework/self/README.md\n' > "$OLDC/.gitignore"

  _init_fixture_repo "$OLDC"
  git -C "$OLDC" add -A
  git -C "$OLDC" commit -qm "old layout baseline"
}

migrate_layout() { ( cd "$OLDC" && bash .claude/framework/update/migrate-layout.sh ); }

# Doctor-clean consumer: every invariant doctor checks holds. Broken-state
# tests start from this and mutate exactly one thing.
# Sets: DOC, DOCFLAG.
build_doctor_consumer() {
  DOC="$BATS_TEST_TMPDIR/doctor-consumer"
  DOCFLAG="$DOC/.claude/.framework-doctor-findings.md"
  mkdir -p "$DOC/.claude/framework/doctor" \
           "$DOC/.claude/framework/update" \
           "$DOC/.claude/hooks"
  cp "$DOCTOR_SRC/doctor.sh" "$DOC/.claude/framework/doctor/"
  cat > "$DOC/.claude/settings.json" <<'EOF'
{
  "hooks": {
    "PostToolUse": [
      {
        "matcher": "Write|Edit",
        "hooks": [
          {
            "type": "command",
            "command": "bash -c 'cd \"$CLAUDE_PROJECT_DIR\" && bash .claude/hooks/sample-hook.sh'"
          }
        ]
      }
    ]
  }
}
EOF
  printf '#!/usr/bin/env bash\nexit 0\n' > "$DOC/.claude/hooks/sample-hook.sh"
  printf '# Project\n\n@CLAUDE.framework.md\n' > "$DOC/CLAUDE.md"
  printf '# framework rules\n' > "$DOC/CLAUDE.framework.md"
  cat > "$DOC/.claude/framework/update/framework-manifest.txt" <<'EOF'
.claude/hooks/sample-hook.sh
CLAUDE.framework.md
EOF
  cat > "$DOC/.claude/.framework-version" <<'EOF'
FRAMEWORK_UPSTREAM_URL=https://example.invalid/repo.git
FRAMEWORK_UPSTREAM_BRANCH=main
FRAMEWORK_PINNED_SHA=0000000000000000000000000000000000000000
FRAMEWORK_LAST_CHECKED=1970-01-01T00:00:00Z
EOF
  _init_fixture_repo "$DOC"
  git -C "$DOC" add -A
  git -C "$DOC" commit -qm "doctor baseline"
}

run_doctor() { ( cd "$DOC" && bash .claude/framework/doctor/doctor.sh ); }

# --- Skills-sync fixtures (TASK-036) ----------------------------------

# Synthetic skills upstream: two skills (python/, rust/), one commit.
# Sets: SKILLS_UPSTREAM, SKILLS_UPSTREAM_SHA.
build_skills_upstream() {
  SKILLS_UPSTREAM="$BATS_TEST_TMPDIR/skills-upstream"
  mkdir -p "$SKILLS_UPSTREAM/python" "$SKILLS_UPSTREAM/rust"
  _init_fixture_repo "$SKILLS_UPSTREAM"
  printf -- '---\nname: python\n---\npython skill v1\n' > "$SKILLS_UPSTREAM/python/SKILL.md"
  printf 'python reference notes\n' > "$SKILLS_UPSTREAM/python/reference.md"
  printf -- '---\nname: rust\n---\nrust skill v1\n' > "$SKILLS_UPSTREAM/rust/SKILL.md"
  git -C "$SKILLS_UPSTREAM" add -A
  git -C "$SKILLS_UPSTREAM" commit -qm "skills v1"
  SKILLS_UPSTREAM_SHA=$(git -C "$SKILLS_UPSTREAM" rev-parse HEAD)
}

# Consumer with the real skills-sync.sh at canonical depth and a
# .skills-version pointing at the local upstream.
# Usage: build_skills_consumer [<selected-skills>]   (default "python")
# Sets: SCONSUMER, SVERSION.
build_skills_consumer() {
  local selected="${1:-python}"
  SCONSUMER="$BATS_TEST_TMPDIR/skills-consumer"
  mkdir -p "$SCONSUMER/.claude/framework/update"
  cp "$UPDATE_SRC/skills-sync.sh" "$UPDATE_SRC/skills-check.sh" \
     "$SCONSUMER/.claude/framework/update/"
  SVERSION="$SCONSUMER/.claude/.skills-version"
  cat > "$SVERSION" <<EOF
SKILLS_UPSTREAM_URL=$SKILLS_UPSTREAM
SKILLS_UPSTREAM_BRANCH=main
SKILLS_PINNED_SHA=
SKILLS_SELECTED="$selected"
EOF
  _init_fixture_repo "$SCONSUMER"
  git -C "$SCONSUMER" add -A
  git -C "$SCONSUMER" commit -qm "skills consumer baseline"
}

skills_sync() { ( cd "$SCONSUMER" && bash .claude/framework/update/skills-sync.sh "$@" ); }
skills_check() { ( cd "$SCONSUMER" && bash .claude/framework/update/skills-check.sh "$@" ); }
SFLAG() { echo "$SCONSUMER/.claude/.skills-update-available.md"; }

# Replace/append one FIELD=VALUE line in the consumer's .skills-version.
set_skills_field() {  # <field> <value>
  grep -v "^$1=" "$SVERSION" > "$SVERSION.tmp" 2>/dev/null || true
  echo "$1=$2" >> "$SVERSION.tmp"
  mv "$SVERSION.tmp" "$SVERSION"
}
set_skills_pin() { set_skills_field SKILLS_PINNED_SHA "$1"; }
