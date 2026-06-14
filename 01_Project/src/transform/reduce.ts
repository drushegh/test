import { notImplemented } from "../types";

/** Fold rows into an accumulator. Pure. Contract: contract:transform. BACKLOG: TASK-004. */
export function reduce<T, A>(_rows: T[], _fn: (acc: A, row: T) => A, _init: A): A {
  return notImplemented("transform.reduce (TASK-004)");
}
