import type { Cell } from "../types";
import { notImplemented } from "../types";

/**
 * Stable ascending sort by a key selector. Pure.
 * Contract: contract:transform. BACKLOG: TASK-004.
 *
 * ⚠ GOTCHA G3 (.claude/GOTCHAS.md): Array.prototype.sort mutates IN PLACE. This
 *   operator must copy first (e.g. `[...rows].sort(...)`) — mutating the caller's
 *   array breaks purity and corrupts other operators reading the same input in
 *   parallel pipelines.
 */
export function sort<T>(_rows: T[], _key: (row: T) => Cell): T[] {
  return notImplemented("transform.sort (TASK-004)");
}
