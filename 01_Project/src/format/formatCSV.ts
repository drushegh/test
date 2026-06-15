import type { Row } from "../types";

/**
 * Render rows as RFC 4180 CSV. Header from Object.keys(rows[0]).
 * Contract: contract:format (.claude/ECOSYSTEM.md).
 *
 * ⚠ BUG-002 (P2) — seeded for the bug-fix lane. A field containing the delimiter, a
 *   double-quote, or a newline MUST be wrapped in quotes (with inner quotes doubled).
 *   This implementation joins raw values, so a value like `a,b` splits into two
 *   columns and corrupts the row. tests/format/formatCSV.test.ts pins the fix.
 */
export function formatCSV(rows: Row[]): string {
  if (rows.length === 0) return "";
  const cols = Object.keys(rows[0] as Row);
  const lines = [cols.join(",")];
  const quote = (v: string): string =>
    v.includes(",") || v.includes('"') || v.includes("\n")
      ? `"${v.replace(/"/g, '""')}"`
      : v;
  for (const row of rows) {
    lines.push(cols.map((c) => quote(String((row as Row)[c] ?? ""))).join(","));
  }
  return lines.join("\n");
}
