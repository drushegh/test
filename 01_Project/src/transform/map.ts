import { notImplemented } from "../types";

/** Map each row through `fn`. Pure. Contract: contract:transform. BACKLOG: TASK-004. */
export function map<I, O>(_rows: I[], _fn: (row: I, i: number) => O): O[] {
  return notImplemented("transform.map (TASK-004)");
}
