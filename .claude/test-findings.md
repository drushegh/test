# Test Findings

<!-- Written by the Tester agent. Separate from review-findings.md (Reviewer's file). -->
<!-- Each test cycle has: date, task ID, test results, contract drift, and bugs filed. -->
<!-- When a cycle is fully resolved, move to .claude/framework/docs/archives/findings-archive.md. -->

## 2026-06-14 — Test Landscape Audit (all tasks)

### Run summary (actual Vitest output)

- Test files: 9 failed | 3 passed | 1 skipped (13 total)
- Tests:      22 failed | 16 passed | 1 todo  (39 total)
- Duration:   2.64 s

### Per-module breakdown

| Module | File | Tests | Passing | Failing | Reason for failures |
|--------|------|-------|---------|---------|---------------------|
| parseCSV | tests/parse/parseCSV.test.ts | 10 | 10 | 0 | Fully implemented; all regression tests (A-1, A-3, BOM, pipe delimiter, escaped quotes) pass |
| parseJSON | tests/parse/parseJSON.test.ts | 3 | 2 | 1 | BUG-003: empty-string input returns `{ok:true, value:undefined}` instead of `{ok:false}` |
| parseNDJSON | tests/parse/parseNDJSON.test.ts | 2 | 0 | 2 | NotImplementedError — TASK-002 stub |
| formatCSV | tests/format/formatCSV.test.ts | 3 | 1 | 2 | BUG-002: no quoting/escaping of cells containing delimiter or double-quotes |
| formatJSON | tests/format/formatJSON.test.ts | 1 | 1 | 0 | Correct reference impl |
| formatTable | tests/format/formatTable.test.ts | 1 | 0 | 1 | NotImplementedError — TASK-005 stub |
| dedupe | tests/transform/dedupe.test.ts | 3 | 2 | 1 | BUG-001: loop bound `i < rows.length - 1` drops last element; immutability test passes |
| operators (map/filter/reduce/sort/flatten/groupBy/window) | tests/transform/operators.test.ts | 8 | 0 | 8 | NotImplementedError — all 7 operators are TASK-004 stubs |
| validate | tests/validate/validate.test.ts | 2 | 0 | 2 | NotImplementedError — TASK-003 stub |
| pipeline (compose/tabulate) | tests/pipeline/pipeline.test.ts | 2 | 0 | 2 | NotImplementedError — TASK-006 stub |
| formatStage | tests/pipeline/formatStage.test.ts | 1 todo | 0 | 0 | Intentionally blocked — contested contract:pipeline-format (TASK-007) |
| throughput (slow) | tests/pipeline/throughput.slow.test.ts | 1 | 1 | 0 | Uses only reference impls (formatJSON + parseJSON); passes by design |
| cli | tests/cli/cli.test.ts | 2 | 0 | 2 | NotImplementedError — TASK-008 stub |

### Seeded bugs confirmed by live run

- BUG-001 (dedupe, P2): `dedupe` drops last element due to `i < rows.length - 1`. Confirmed failing.
- BUG-002 (formatCSV, P2): No quoting of delimiter/double-quote characters. Confirmed failing with exact assertion mismatch.
- BUG-003 (parseJSON, P3): Empty string returns `{ok:true, value:undefined}`. Confirmed failing.

### Top 3 modules for green-tests-per-effort

1. **transform/operators (TASK-004)** — 8 tests, all stubs, all trivially one-liners (`arr.map`, `arr.filter`, `arr.reduce`, `[...arr].sort`, `arr.flat(1)`, Map-based groupBy, sliding window). Highest test yield for lowest implementation complexity.
2. **parseNDJSON (TASK-002)** — 2 tests, pure string split + JSON.parse loop with empty-line skip. Tiny implementation, immediate green.
3. **formatCSV BUG-002 fix** — 2 tests currently red; a single `quoteCell` helper (wrap in quotes if value contains `,`, `"`, or `\n`; double inner quotes) converts 2 failing to 2 passing without touching any other module.
<!-- Newest test cycles at the top. -->

## 2026-06-14 — TASK-001 (parseCSV)

### Vitest result

```
 RUN  v2.1.9

 ✓ tests/parse/parseCSV.test.ts (3 tests) 4ms

 Test Files  1 passed (1)
       Tests  3 passed (3)
   Start at  22:22:53
   Duration  2.39s
```

All 3 pinned tests pass.

### Contract compliance verdict: PASS (with coverage gaps — no blocking violations)

The implementation satisfies every normative clause of `contract:parse` for `parseCSV`:
- Returns `Result<Row[]>` (never throws).
- First row becomes header keys.
- All cell values are strings (no coercion).
- Quoted fields containing the delimiter are handled correctly.
- Escaped quotes (`""` → `"`) work correctly.
- G1 BOM stripping is present and tested — the test asserts `Object.keys(r.value[0])` equals `["id", "name"]`, confirming the BOM character is gone from the first key.
- Custom `delimiter` option is wired (probed manually — works for `;` and `\t`).
- Multi-line quoted fields (newline inside a quoted field) work correctly.
- CRLF (`\r\n`) line endings are handled.

No CONTRACT DRIFT found.

### Coverage gaps (implementation behaviours with no test coverage)

1. **Custom `delimiter` option** — The `CsvOptions.delimiter` field is part of the contract signature and is implemented, but zero tests exercise it. Any regression (e.g., delimiter accidentally ignored) would go undetected.
   - Suggested test: `parseCSV("id;name\n1;Ada", { delimiter: ";" })` → `[{ id: "1", name: "Ada" }]`

2. **Escaped quotes (`""` → `"`)** — The contract explicitly names this case. The existing test "keeps commas inside quoted fields" uses a quoted field but contains no `""` sequence. The escaped-quote code path in `parseRow` is untested.
   - Suggested test: `parseCSV('id,note\n1,"say ""hi"""')` → `[{ id: "1", note: 'say "hi"' }]`

3. **Multi-line quoted fields** — The contract says "quoted fields may contain commas and escaped quotes"; `splitLines` additionally handles embedded newlines. This is untested and the `splitLines` quote-toggle approach (naive `inQuotes = !inQuotes` per `"` character) is only correct for structurally valid RFC 4180 inputs. The logic is accidentally correct for all valid inputs (even number of `"` chars guaranteed by RFC 4180), but there is no test to document this invariant or catch a regression.
   - Suggested test: `parseCSV('id,note\n1,"line1\nline2"\n2,end')` → two rows where row 1's `note` is `"line1\nline2"`.

4. **`ok:false` malformed-input path** — The contract prose states parsers "never throw on malformed input" and return `Result`. The implementation fulfils the no-throw requirement but the `catch` branch that returns `{ ok: false, error: ... }` is dead code for any input reachable in practice: the parser is written so no exception can escape (it never explicitly throws). The `ok:false` discriminant is never exercised by any test. This is a coverage gap rather than a bug, but it means the error-reporting path is entirely unverified.
   - Note: the contract says `Result<Row[]>` (not "must return `ok:false` for malformed input") — "never throws" is the normative requirement. The `ok:false` path being unreachable does not constitute a contract violation.

5. **Short rows (fewer cells than header)** — When a data row has fewer columns than the header, the implementation fills missing cells with `""`. This is reasonable behaviour but is undocumented in the contract and untested.

6. **Extra columns (more cells than header)** — Extra cells are silently dropped (only `headers.length` keys are emitted). Untested and not specified by contract.

7. **CRLF line endings** — Handled by `splitLines`, but not covered by any test.

### Bugs filed

None. No P0–P3 bugs found. All observed behaviours are consistent with the contract or fall into the "unspecified, reasonable default" category.
