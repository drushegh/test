import type { Cell } from "../types";

/**
 * Stable ascending sort by a key selector. Pure.
 * Contract: contract:transform. TASK-004.
 *
 * G3: copies input with spread before sorting — Array.prototype.sort mutates in place.
 */
export function sort<T>(rows: T[], key: (row: T) => Cell): T[] {
  return [...rows].sort((a, b) => {
    const ka = key(a);
    const kb = key(b);
    if (ka === kb) return 0;
    if (ka === null) return -1;
    if (kb === null) return 1;
    return ka < kb ? -1 : 1;
  });
}
