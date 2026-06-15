/**
 * Group rows by a string key into a Map, preserving first-seen key order. Pure.
 * Contract: contract:transform. TASK-004.
 */
export function groupBy<T>(rows: T[], key: (row: T) => string): Map<string, T[]> {
  const result = new Map<string, T[]>();
  for (const row of rows) {
    const k = key(row);
    const group = result.get(k);
    if (group !== undefined) {
      group.push(row);
    } else {
      result.set(k, [row]);
    }
  }
  return result;
}
