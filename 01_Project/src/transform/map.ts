/** Map each row through `fn`. Pure. Contract: contract:transform. TASK-004. */
export function map<I, O>(rows: I[], fn: (row: I, i: number) => O): O[] {
  return rows.map((row, i) => fn(row, i));
}
