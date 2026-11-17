# Test integrity — tests that cannot fail

A green test is only evidence if it **could have been red**. Every pattern below
shipped a passing suite over a real defect. The one rule behind all of them:
**before trusting a new test, make it fail on purpose** — run it against a stub,
empty or reverted implementation and confirm it goes red for the right reason.

## Tautological assertions

These pass whatever the code does:

```typescript
expect(items.length).toBeGreaterThanOrEqual(0); // always true
expect(items).toBeTruthy();                      // [] is truthy
if (result) { expect(result.id).toBe(7); }       // skipped when result is missing
expect(save).toHaveBeenCalledWith(order);        // passes on 1 call or 50
```

Fixes: assert exact values (`toHaveLength(3)`, `toEqual([...])`); never put an
assertion inside a conditional (assert the precondition instead:
`expect(result).toBeDefined()`); pair `toHaveBeenCalledWith` with
`toHaveBeenCalledTimes(1)` when the count matters.

## Fault injection must look like real input

- **Inject using the file's own bytes.** A bare-LF line injected into a CRLF
  file "proved" a matcher that could never match a real line (`split('\n')`
  leaves a trailing `\r`). Detect and reuse the file's line ending, write in
  binary mode, and parse with `split(/\r?\n/)`.
- **Validation tests that only submit empty forms** exercise only the
  "required" branch of each validator. Add a junk-fill phase (over-long,
  wrong-format, boundary values). Skip input types that reject programmatic
  values (a file input throws when you set `.value`), plus checkboxes/radios.
- **Shell capture strips trailing newlines.** `"$(printf 'x')"` and
  `"$(printf 'x\n\n')"` capture the same string, so `out="$(cmd)"` cannot test
  an "ends in exactly one newline" contract. Capture to a file and assert bytes:
  `tail -c1 file | od -An -tx1` is `0a`, and `tail -c2` is not `0a 0a`.

## Recorded data that never varies

A snapshot or receipt field that is constant in every run (an all-empty
column, a toast that is always hidden, a wizard step never reached) is
decoration, not a check. Assert that recorded fields carry **varying, non-empty**
data across the scenarios, or remove them.

## Coverage holes that look like coverage

- **Redundant defences tested only together hide each other's absence.** If a
  validating caller and an inner guard both reject bad input, test the inner
  guard directly (bypass the caller). Removing either defence must turn the
  suite red.
- **A tested pure helper does not test its caller.** Testing a geometry helper
  says nothing about the draw loop that uses it. Extract the loop's output as
  data (the marks/commands it would draw), test that, and keep the loop a
  trivial consumer.
- **Fast-path vs canonical equivalence** must compare the whole replayed
  series, not one point. A bug can hide at every `t ≠ now`.
- **Self-comparison determinism tests** (run twice, compare) cannot catch a
  uniform behaviour shift. Pair them with a hash pinned to a frozen constant,
  and add every new command/event type to the golden scenario.
- **Verify scripts must not mirror the code's simplification.** A check that
  takes `[0]` of a join, exactly as the code does, agrees with the bug. Filter
  out cardinality-narrowing rows before taking `[0]`, or assert the cardinality.
- **Source-scanning tests that assert a pattern is ABSENT** trip on their own
  literal (and on comments that quote it). Build the pattern from parts
  (`'ev' + 'al('`) and reword such comments.
- **Verify populated states and the live mount point.** A component suite was
  green while the component was not mounted in the real layout. Visual sign-off
  against an empty shell missed dozens of unported styles. Mocked IPC hid
  reload, StrictMode and timing bugs. Use fixture-populated captures and check
  the real mount path in the running app (→ `ui-verification`).

## Stubs, doubles and smoke tests

- **Stubs of external binaries/services are more permissive than the real
  thing.** A stub CLI that ignored unknown flags hid a missing required flag
  across hundreds of green tests. Decide per flag/field whether the stub
  enforces it, and keep an **env-gated real-binary smoke test** that runs
  against the genuine tool.
- **A headless boot smoke test misses runtime errors that need real input and
  timing.** Widen its error filter to the engine's deferred/runtime warnings,
  and grep logs from a real interactive run for error markers too.

## SKIP is not a pass

- A skipped test is a test **not run**. A suite or script that prints SKIP and
  exits 0 must be reported as "N skipped", never folded into "green".
- **Unmasked skips:** promoting an optional dependency to required un-skips
  tests gated on it (`pytest.importorskip("pkg")`, `it.skipIf`, env guards),
  and their expectations may be stale. Grep for the gate and run each newly
  unmasked file before claiming the suite passes.
- Count honestly: when a runner prints no aggregate (see
  `js-test-runner-pitfalls.md`, workspaces), sum per-package totals yourself
  and paste the literal pass lines.

## Mutation discipline

Mutation testing (deliberately breaking code to see if tests notice) is the
direct measure of "could this fail?". Done by hand or by a harness:

- Keep a captured log of each mutant and its result. A score with no log is a
  claim, not evidence.
- The person or agent claiming the score is not the one who verifies it.
- A harness must back the file up **at mutation time**, verify the restore
  byte-for-byte, and **refuse to run on a file with uncommitted changes**. A
  stale-backup restore nearly destroyed uncommitted work.
- Tooling: Stryker (JS/TS, .NET), mutmut (Python), PIT (JVM) (verify current
  versions before adopting).
