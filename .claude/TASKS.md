# Task Board

Last updated: 2026-06-14 by orchestrator (framework setup verified + skills tier opt-in — all 38 catalogue skills synced; no feature/bug tasks changed this session)

---

## Feature Lane

<!-- Full lifecycle for planned work: Todo → In Progress → Ready for Review → In Review → Ready for Test → Testing → Done -->

### In Progress

### Ready for Review

### Ready for Test

### Todo (Priority Order)

### Blocked

### Done

<!-- When Done exceeds ~20 items, move older entries to .claude/framework/docs/archives/tasks-archive.md -->

---

## Bug-Fix Lane

<!-- Short lifecycle for defects: Reported → Fixing → Verify → Done -->
<!-- Use this lane for bugs, regressions, and hotfixes — not planned feature work. -->
<!-- Severity: P0 (blocking) | P1 (major) | P2 (minor) | P3 (cosmetic) -->

### Fixing

### Verify

### Reported

### [BUG-001] `truncate()` splits UTF-16 surrogate pairs
- **Severity:** P1
- **Source:** reviewer agent (review finding C-1) — detail in `.claude/review-findings.md`
- **Reported:** 2026-06-14 by reviewer agent
- **Symptom:** `truncate("Hello 💩 World", 10)` slices mid-surrogate, yielding the malformed `"Hello \uD83D..."`.
- **Expected:** Slice on Unicode code points (e.g. `Array.from(input)`) so multi-byte characters are never split.

### [BUG-002] `truncate()` accepts `max = NaN`, returns "..." instead of throwing
- **Severity:** P2
- **Source:** reviewer agent (review finding C-2) — detail in `.claude/review-findings.md`
- **Reported:** 2026-06-14 by reviewer agent
- **Symptom:** `NaN < 4` is `false`, so the guard is bypassed; `truncate("hello", NaN)` silently returns `"..."`.
- **Expected:** Guard with `!Number.isInteger(max) || max < 4` so non-integer/`NaN` input throws `RangeError`.

<!-- Template:
### [BUG-XXX] Short description
- **Severity:** P0 | P1 | P2 | P3
- **Source:** TASK-XXX / review finding / test failure / user report
- **Reported:** {{date}} by {{agent}}
- **Symptom:** What's broken
- **Expected:** What should happen
-->

### Done
