import type { Row } from "../types";
import { notImplemented } from "../types";

/**
 * Render rows as an aligned text table. Columns derived from Object.keys(rows[0]).
 * Contract: contract:format (.claude/ECOSYSTEM.md).
 *
 * ⚠ This signature is HALF of the contested contract:pipeline-format. It takes Row[]
 *   and makes NO promise about caller-supplied column ordering. The pipeline wants to
 *   pass a `Table` (with `columns`). Do NOT change this signature to resolve that —
 *   it is an architect decision (see SCENARIOS.md scenario 3).
 *
 * BACKLOG: TASK-005. Implementation intentionally absent.
 */
export function formatTable(_rows: Row[]): string {
  return notImplemented("formatTable (TASK-005)");
}
