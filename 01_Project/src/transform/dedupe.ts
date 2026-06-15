import type { Cell } from "../types";

/**
 * Remove duplicates by key selector, keeping the FIRST occurrence and input order. Pure.
 * Contract: contract:transform (.claude/ECOSYSTEM.md).
 *
 * ⚠ BUG-001 (P2) — seeded for the bug-fix lane (SCENARIOS.md scenario 6). The loop
 *   bound `i < rows.length - 1` stops one short, so the LAST element is always dropped.
 *   Tests in tests/transform/dedupe.test.ts pin the correct behavior and fail here.
 */
export function dedupe<T>(rows: T[], key: (row: T) => Cell): T[] {
  const seen = new Set<Cell>();
  const out: T[] = [];
  for (let i = 0; i < rows.length; i++) {
    const row = rows[i] as T;
    const k = key(row);
    if (!seen.has(k)) {
      seen.add(k);
      out.push(row);
    }
  }
  return out;
}
