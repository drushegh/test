Framework maintenance tasks. Run this deliberately when needed — not part of
any agent's normal workflow.

## Rolling Summary

Check claude-progress.txt. If there are ~10+ detailed entries since the
last Rolling Summary update:

1. Read all detailed entries since the last summary
2. Rewrite the "## Rolling Summary" section: compress into 5 bullets
   covering key decisions, tasks completed, patterns established, and
   current trajectory
3. If detailed entries exceed ~30, move older ones to
   .claude/framework/docs/archives/progress-archive.txt and keep the most
   recent 15

## Framework Metrics

Update framework-metrics.md:

1. Read `.claude/telemetry/.hook-metrics` for raw hook counters (written by `.claude/framework/insights/rollup.sh`)
2. Read `.claude/review-findings.md` for review finding stats
   (total, acted on, ignored, wontfix)
3. Count bugs in the Bug-Fix Lane of TASKS.md (reported, fixed, cycle time)
4. Check for contract drift events in recent review findings
5. Fill in the metric tables in framework-metrics.md
6. Reset raw counters in `.claude/telemetry/.hook-metrics`
7. Note any actionable insights — if a metric looks bad, log a suggestion
   in FRAMEWORK-SUGGESTIONS.md

## State File Archiving

Check if any state files need archiving:

- TASKS.md Done section > ~20 items → archive older (see semantic-decay below)
- DECISIONS.md > ~50 entries (or per-file `decisions/`, per project CLAUDE.md) → move older to .claude/framework/docs/archives/decisions-archive.md
- review-findings.md fully resolved cycles → move to .claude/framework/docs/archives/findings-archive.md
- test-findings.md fully resolved cycles → move to .claude/framework/docs/archives/findings-archive.md

### Semantic decay (don't just move — distil first)

Blunt "move the oldest N to an archive file" loses the signal those tasks
carried. Before archiving completed TASKS.md entries, **summarise them
forward** so the knowledge survives in active state, not just cold storage:

1. Group the about-to-be-archived Done entries by theme (a feature area, a
   bug class, a subsystem).
2. For each group, write ONE distilled line into the live record where it
   belongs — *not* a new log:
   - A durable pattern those tasks established → a positive-pattern entry in
     `GOTCHAS.md` (or a `FRAMEWORK-SUGGESTIONS.md` note if it implies a
     framework change). This is the same "what worked, generalise it"
     capture the instinct-miner proposes — housekeeping is where stragglers
     get distilled.
   - A still-relevant constraint or direction → fold into STATUS.md
     "Next Up" or the claude-progress Rolling Summary.
3. THEN move the raw entries to `.claude/framework/docs/archives/tasks-archive.md`, prefixed with a one-line
   header pointing at where their distilled lesson now lives.

The test: after archiving, a fresh session reading only the *live* state
files should still know what those completed tasks taught — the archive is
provenance, not the only copy of the lesson. Skip distillation only for
purely mechanical tasks that taught nothing (a rename, a version bump).

## Adopted-Feedback Reconciliation

Your GOTCHAS.md and FRAMEWORK-SUGGESTIONS.md entries about the *framework
itself* may already be fixed upstream — the framework team sweeps consumer
feedback files, adopts items, and ships the fixes in updates. The registry
of adoptions ships with the framework:

1. Read `.claude/framework/docs/ADOPTED-FEEDBACK.md` (framework-owned,
   updated on every framework update you pull).
2. For each registry row, check your `.claude/GOTCHAS.md` and
   `.claude/FRAMEWORK-SUGGESTIONS.md` for a matching entry. Match on
   TOPIC, not wording — your entry is in your own words (the row's last
   column describes what to look for).
3. If your pinned framework version is at or past the row's commit
   (compare `FRAMEWORK_PINNED_SHA` in `.claude/.framework-version` /
   check `git log` of your last update), the local entry is stale:
   remove it, or annotate it `✅ adopted upstream <TASK-XXX>` if its
   context is still useful history.
4. Project-specific entries (about YOUR code, not the framework) are
   never touched by this step.

This keeps consumer feedback files describing only *open* concerns — a
stale "the framework should X" entry that upstream already shipped misleads
every future session that reads it.

## Commit

Commit all changes with: `chore: framework housekeeping — rolling summary, metrics, archiving`
