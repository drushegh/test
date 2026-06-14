# PLAN-framework-restructure — Framework Root Cleanup

**Created:** 2026-04-24  
**Spec:** [SPEC-framework-restructure.md](../specs/SPEC-framework-restructure.md)  
**Status:** Ready for development  

---

## Objective

Eliminate `.claude/framework/` from the project root and move all framework-related files
under `.claude/`. State files (TASKS.md, STATUS.md, etc.) move from root to `.claude/`.
Only `CLAUDE.md`, `CLAUDE.framework.md`, and `.gitignore` remain at root.

Zero functionality removed. Pure restructure.

---

## Contracts (stable — safe to implement against)

| Contract ID | What it specifies |
|-------------|------------------|
| `contract:framework-layout` | Canonical on-disk layout after restructure |
| `contract:state-file-paths` | Where each state file lives; framework-self redirect pattern |
| `contract:migration-behavior` | migrate-layout.sh interface, exit codes, invariants |

All three contracts are in `ECOSYSTEM.md`.

---

## Task Sequence

```
TASK-001 (Developer, P1)
  └─ Upstream restructure: git mv + sed sweep + manifest update
  └─ Single commit. Repo is in new layout and fully working after this.

TASK-002 (Developer, P2) ← depends on TASK-001
  └─ Write migrate-layout.sh (consumer migration script)

TASK-003 (Developer, P2) ← depends on TASK-002
  └─ Hook migration into apply-update.sh (pre-flight detection)

TASK-004 (Developer, P3) ← depends on TASK-001
  └─ Update MIGRATION.md with layout migration docs

TASK-005 (Tester, P1) ← depends on TASK-001
  └─ Verify upstream restructure (AC1-AC3, AC5-AC10)

TASK-006 (Tester, P2) ← depends on TASK-002, TASK-003, TASK-005
  └─ Verify consumer migration simulation (AC4-AC5)
```

**Parallel opportunities:** TASK-004 can run in parallel with TASK-002/003.
TASK-005 can begin as soon as TASK-001 is done (before TASK-002/003 start).

---

## TASK-001 Implementation Guide

This is the hardest task. Follow this order precisely to avoid mid-flight broken state.

### Step 1 — Compile the reference map

Before moving anything, grep to confirm counts:

```bash
# How many .claude/framework/ refs in framework-owned files?
grep -rn "00_framework" \
  CLAUDE.framework.md .claude/commands/ .claude/hooks/ .claude/agents/ \
  .claude/framework/ 2>/dev/null | grep -v ".git" | wc -l

# How many bare state-file refs (TASKS.md without .claude/ prefix)?
grep -rn '\bTASKS\.md\|STATUS\.md\|DECISIONS\.md\|ECOSYSTEM\.md\|GOTCHAS\.md' \
  CLAUDE.framework.md .claude/ 2>/dev/null | grep -v ".git" | wc -l
```

### Step 2 — Stage all git mv operations (do NOT commit yet)

```bash
# Move the framework directory tree
git mv .claude/framework/ .claude/framework/

# Move root state files
git mv TASKS.md       .claude/TASKS.md         2>/dev/null || true
git mv STATUS.md      .claude/STATUS.md         2>/dev/null || true
git mv DECISIONS.md   .claude/DECISIONS.md      2>/dev/null || true
git mv ECOSYSTEM.md   .claude/ECOSYSTEM.md      2>/dev/null || true
git mv GOTCHAS.md     .claude/GOTCHAS.md        2>/dev/null || true
git mv FRAMEWORK-SUGGESTIONS.md .claude/FRAMEWORK-SUGGESTIONS.md 2>/dev/null || true
git mv claude-progress.txt .claude/claude-progress.txt 2>/dev/null || true
git mv framework-metrics.md .claude/framework-metrics.md 2>/dev/null || true

# Move framework config
git mv .framework-version .claude/.framework-version 2>/dev/null || true
```

**Note:** In framework-self mode, TASKS.md etc. are at `.claude/framework/self/` not root.
The root equivalents are empty templates — still `git mv` them.

### Step 3 — Run automated sed sweep

Apply substitutions in this order (specific before general to avoid partial matches):

```bash
FILES=$(find .claude/framework/ CLAUDE.framework.md CLAUDE.md -type f \
  \( -name "*.md" -o -name "*.sh" -o -name "*.py" -o -name "*.txt" -o -name "*.conf" \))

for f in $FILES; do
  # 1. Self-mode redirect path: most specific first
  sed -i 's|.claude/framework/self/|.claude/framework/self/|g' "$f"

  # 2. Main directory move
  sed -i 's|.claude/framework/|.claude/framework/|g' "$f"

  # 3. Temp flag files at root
  sed -i 's|\.framework-update-available\.md|.claude/.framework-update-available.md|g' "$f"
  sed -i 's|\.framework-insight-alert\.md|.claude/.framework-insight-alert.md|g' "$f"
  sed -i 's|\.framework-doctor-findings\.md|.claude/.framework-doctor-findings.md|g' "$f"
  sed -i 's|\.framework-version|.claude/.framework-version|g' "$f"

  # 4. Bare state file references — add .claude/ prefix
  # Use word-boundary anchors to avoid matching inside paths that already have the prefix
  sed -i 's|"\([^.]\)TASKS\.md|".claude/TASKS.md|g' "$f"   # inside quoted paths
  # ... (developer must grep-and-verify each substitution; sed patterns here are illustrative)
done
```

**Warning:** The sed sweep for bare state-file references is the highest-risk step.
Verify each substitution manually before staging. The `grep -n` output from Step 1
is the checklist — cross off each one.

### Step 4 — Update framework-manifest.txt

Replace every `.claude/framework/` path with `.claude/framework/`. Add new state-file paths
to the manifest if they should be update-managed (they should NOT be — state files are
consumer-owned, not manifest-tracked).

### Step 5 — Verify

```bash
# AC6: no remaining 00_framework refs
grep -r "00_framework" .claude/ CLAUDE.framework.md CLAUDE.md 2>/dev/null
# → must be empty

# AC7: no bare state-file refs (outside .claude/ prefix context)
# Manual review required — grep and read each match

# AC5: doctor clean
bash .claude/framework/doctor/doctor.sh

# AC8: manifest sanity
grep "00_framework" .claude/framework/update/framework-manifest.txt
# → must be empty
```

### Step 6 — Commit

```bash
git add -A
git commit -m "feat: framework layout migration — .claude/framework/ → .claude/framework/ (TASK-001)"
```

---

## TASK-002 Implementation Guide

Write `.claude/framework/update/migrate-layout.sh` implementing `contract:migration-behavior`
exactly.

Structure:

```bash
#!/bin/bash
# migrate-layout.sh — one-time layout migration for consumers upgrading from
# .claude/framework/ layout to .claude/framework/ layout.
# See contract:migration-behavior in ECOSYSTEM.md.

set -euo pipefail

OLD_LAYOUT=false
[ -d "00_framework" ] && OLD_LAYOUT=true
[ -f "TASKS.md" ]     && OLD_LAYOUT=true

if [ "$OLD_LAYOUT" = "false" ]; then
  echo "migrate-layout: already on new layout — nothing to do."
  exit 0
fi

echo "migrate-layout: old layout detected — migrating..."

# Step 1: git mv .claude/framework/
git mv .claude/framework/ .claude/framework/ || { echo "ERROR: git mv failed"; exit 2; }

# Step 2: git mv state files (only if they exist at root)
for f in TASKS.md STATUS.md DECISIONS.md ECOSYSTEM.md GOTCHAS.md \
         FRAMEWORK-SUGGESTIONS.md claude-progress.txt framework-metrics.md; do
  [ -f "$f" ] && git mv "$f" ".claude/$f" || true
done

# Step 3: .framework-version
[ -f ".framework-version" ] && git mv .framework-version .claude/.framework-version || true

# Step 4: update CLAUDE.md references
sed -i 's|.claude/framework/|.claude/framework/|g' CLAUDE.md 2>/dev/null || true

# Step 5: commit
git commit -m "chore: framework layout migration — .claude/framework/ → .claude/framework/" \
  || { echo "ERROR: git commit failed"; exit 2; }

echo "migrate-layout: migration committed."

# Step 6: doctor check
echo "migrate-layout: running doctor..."
bash .claude/framework/doctor/doctor.sh
DOCTOR_EXIT=$?
if [ $DOCTOR_EXIT -ne 0 ]; then
  echo "CRITICAL: doctor found issues after migration — fix before continuing."
  exit 1
fi

echo "migrate-layout: done — layout migration successful."
exit 0
```

**Key requirements:**
- Every `while read` loop gets the CRLF strip (`line="${line%$'\r'}"`)
- `set -euo pipefail` — but exit 2 for git errors, not bash -e default
- Test on Windows Git Bash before shipping

---

## Risk Register

| Risk | Mitigation |
|------|-----------|
| sed false-positive corrupts a file | Grep-verify each substitution; use narrow anchored patterns |
| manifest misses a path | AC8 grep check on manifest; dry-run apply-update on fresh clone |
| framework-self redirect breaks | AC9 explicit test; doctor Check 8 covers flag state |
| apply-update.sh can't bootstrap itself | pre-flight check at top of apply-update.sh calls migrate before doing anything |
| Consumer has custom content in state files | git mv preserves content — no data loss |
| CRLF in new while-read loops | GOTCHAS.md lesson applied; CR strip in all new loops |

---

## Downstream Communication

After TASK-001 is committed and pushed, send this to downstream consumers:

---

**Downstream prompt (copy-paste ready):**

> Framework restructure landed upstream. Run your next update and the migration will run
> automatically:
>
> ```bash
> bash .claude/framework/update/apply-update.sh
> ```
>
> The update system will detect the old layout, run `migrate-layout.sh` to move
> `.claude/framework/` → `.claude/framework/` and all root state files → `.claude/`, then
> run `doctor.sh` to verify nothing broke. Your state file content is preserved.
>
> After the update, your root will contain only: `CLAUDE.md`, `CLAUDE.framework.md`,
> `.gitignore`, `.claude/`, and your project directory.
>
> If doctor reports any CRITICAL findings, fix them before continuing. WARN/INFO findings
> can be addressed at your next session.

---

## Definition of Done

- [ ] TASK-001: committed, doctor clean, grep checks pass
- [ ] TASK-002: migrate-layout.sh written, idempotency verified
- [ ] TASK-003: apply-update.sh pre-flight added
- [ ] TASK-004: MIGRATION.md updated
- [ ] TASK-005: all AC1-AC3, AC5-AC10 verified by tester
- [ ] TASK-006: consumer simulation passes
- [ ] Downstream prompt sent to consumers
