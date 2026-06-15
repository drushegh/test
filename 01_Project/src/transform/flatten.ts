/** Flatten one level of nesting. Pure. Contract: contract:transform. TASK-004. */
export function flatten<T>(rows: T[][]): T[] {
  return ([] as T[]).concat(...rows);
}
