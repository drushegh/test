/** Fold rows into an accumulator. Pure. Contract: contract:transform. TASK-004. */
export function reduce<T, A>(rows: T[], fn: (acc: A, row: T) => A, init: A): A {
  return rows.reduce((acc, row) => fn(acc, row), init);
}
