/** Keep rows where `pred` is true. Pure. Contract: contract:transform. TASK-004. */
export function filter<T>(rows: T[], pred: (row: T, i: number) => boolean): T[] {
  return rows.filter((row, i) => pred(row, i));
}
