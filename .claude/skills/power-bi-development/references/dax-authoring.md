# DAX Authoring Correctness

The bugs here are *silent* — wrong numbers, not errors. Prove every
rewrite by executing old and new versions across several filter contexts
and diffing results.

## Variable semantics: evaluated once, where defined, lazily

A `VAR` is a value frozen in the filter+row context **at the point of
definition**, computed at most once, and only if a reachable branch uses
it. Three failure modes:

```dax
-- TIME-SHIFT BUG: the shift is a no-op; x froze before CALCULATE
VAR x = [Sales Amount]
RETURN CALCULATE(x, SAMEPERIODLASTYEAR('Date'[Date]))   -- WRONG

-- RIGHT: keep the measure reference inside the CALCULATE
CALCULATE([Sales Amount], SAMEPERIODLASTYEAR('Date'[Date]))
```

- **Branch evaluation**: because `VAR`s are lazy, a heavy `VAR`
  referenced only in one `IF` branch is normally computed only when that
  branch is taken — but the engine may still choose an eager plan that
  computes both branches (common inside iterators). Don't assume either
  way: check the query plan / server timings in DAX Studio, and move the
  `VAR` inside the branch expression if both are being computed.
- A variable shadowing a column name silently wins — prefix variables
  with `_`. Variables are immutable; "running total in a loop" thinking
  must restructure as an iterator.

## DIVIDE vs `/`

`DIVIDE(n, d)` blanks on zero/blank denominators; bare `/` raises errors
or emits Infinity/NaN that poisons downstream aggregates. Default to
`DIVIDE` in measures. The narrow exception: inside a hot iterator,
`/` avoids a formula-engine callback — but **only after** pre-filtering
the iterated table to guarantee non-zero (`CALCULATETABLE('Items',
'Items'[Rate] <> 0)`). Note `DIVIDE(n, d, alt)` fires the alternate on
blank denominators too, and a blank from DIVIDE is indistinguishable
from no-data blank — supply an explicit alternate where downstream
logic branches on `ISBLANK`.

## Measure vs calculated column

Calc columns are computed at refresh in row context — they cannot see
slicers or filters, ever. If the value must respond to user filtering
(% of total, rank within selection, running totals), it's a measure; a
calc-column version bakes in the whole-table answer and *looks correct
in an unfiltered test visual*. Always test against a slicer selection.

`CALCULATE` inside a calc column triggers context transition over the
whole table and creates dependency on **every column** — two such
columns = the classic circular-dependency error (which names the second
column, not the design flaw in the first). Where unavoidable, restrict
the dependency surface: `ALLEXCEPT('T', 'T'[Key])`, or `ALLNOBLANKROW`
on keyless tables. Cost: calc columns are ~4x the size of source
columns and don't materialise on DirectQuery/Direct Lake.

## CALCULATE discipline

- **Filter columns, not tables**: `CALCULATE([X], Sales[Channel] = "Web")`
  — a table filter (`FILTER(Sales, ...)`) iterates and breaks
  expectations around overriding existing filters.
- Boolean predicates are sugar for `FILTER(ALL(col), ...)` — they
  *replace* existing filters on that column; use `KEEPFILTERS` to
  intersect instead.
- Context transition (`CALCULATE` in row context, including every
  measure reference inside an iterator) is powerful and expensive —
  know when it's happening.

## Time intelligence

- One **marked date table**, contiguous dates, no auto date/time tables
  in production models.
- Classic TI functions (`DATESYTD`, `SAMEPERIODLASTYEAR`) need the
  marked date table and assume a Gregorian/fiscal-year calendar. For
  week-based and retail (4-4-5, 4-5-4) calendars use **calendar-based
  time intelligence** (Enhanced DAX Time Intelligence, introduced as a
  preview Sept 2025 — check its current status): define a calendar on
  the date table and pass it to TI functions (`TOTALYTD(..., 'Calendar')`,
  week functions such as `TOTALWTD`). Hand-built calendar-arithmetic
  patterns remain the fallback where that feature isn't available.
- Wrap TI measures so blanks beyond the data range don't project phantom
  periods: `IF(NOT ISBLANK([Sales]), [Sales PY])` style guards.

## Hygiene

- Format strings on every measure; dynamic format strings via
  `formatStringDefinition` where the unit varies.
- `SUMMARIZE` only for grouping by columns; never add expressions inside
  it (use `ADDCOLUMNS(SUMMARIZE(...))` or `SUMMARIZECOLUMNS`).
- `ISBLANK()` vs `= 0` vs `= ""` are three different tests; DAX blanks
  coerce surprisingly in comparisons — be explicit.
- Naming: measures get business names (`Total Sales`), no table prefix;
  columns referenced always table-qualified (`Sales[Amount]`), measures
  never (`[Total Sales]`).

Docs: https://learn.microsoft.com/dax/ ·
https://learn.microsoft.com/power-bi/guidance/dax-divide-function-operator ·
https://learn.microsoft.com/power-bi/transform-model/desktop-calculated-columns
(plus SQLBI: variables-in-dax, understanding-circular-dependencies)
