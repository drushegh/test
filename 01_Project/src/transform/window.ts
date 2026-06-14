import { notImplemented } from "../types";

/**
 * Fixed-size contiguous windows; drops a trailing partial window (length < size). Pure.
 * Contract: contract:transform. BACKLOG: TASK-004.
 */
export function window<T>(_rows: T[], _size: number): T[][] {
  return notImplemented("transform.window (TASK-004)");
}
