/**
 * Fixed-size contiguous windows; drops a trailing partial window (length < size). Pure.
 * Contract: contract:transform. TASK-004.
 */
export function window<T>(rows: T[], size: number): T[][] {
  const result: T[][] = [];
  for (let i = 0; i + size <= rows.length; i += size) {
    result.push(rows.slice(i, i + size));
  }
  return result;
}
