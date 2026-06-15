import type { Result } from "../types";

/**
 * Parse newline-delimited JSON: one JSON value per line.
 * Contract: contract:parse (.claude/ECOSYSTEM.md).
 *
 * ⚠ GOTCHA G2 (.claude/GOTCHAS.md): a file written with a trailing newline ends in an
 *   empty final line. Splitting on "\n" naively yields a trailing "" that JSON.parse
 *   rejects — do NOT emit it as an element and do NOT error on it. Skip empty lines.
 */
export function parseNDJSON(input: string): Result<unknown[]> {
  const results: unknown[] = [];
  const lines = input.split("\n");
  for (const line of lines) {
    if (line.trim() === "") continue; // GOTCHA G2: skip empty/whitespace-only lines
    try {
      results.push(JSON.parse(line));
    } catch (e) {
      return { ok: false, error: (e as Error).message };
    }
  }
  return { ok: true, value: results };
}
