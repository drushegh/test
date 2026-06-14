import { notImplemented } from "../types";

/** Keep rows where `pred` is true. Pure. Contract: contract:transform. BACKLOG: TASK-004. */
export function filter<T>(_rows: T[], _pred: (row: T, i: number) => boolean): T[] {
  return notImplemented("transform.filter (TASK-004)");
}
