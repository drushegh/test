import { notImplemented } from "../types";

/**
 * Group rows by a string key into a Map, preserving first-seen key order. Pure.
 * Contract: contract:transform. BACKLOG: TASK-004.
 */
export function groupBy<T>(_rows: T[], _key: (row: T) => string): Map<string, T[]> {
  return notImplemented("transform.groupBy (TASK-004)");
}
