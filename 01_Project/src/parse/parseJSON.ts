import type { Result } from "../types";

/**
 * Parse exactly one JSON document.
 * Contract: contract:parse (.claude/ECOSYSTEM.md).
 *
 * ⚠ BUG-003 (P3) — seeded for the bug-fix lane. Empty/whitespace-only input should
 *   be an ERROR (ok:false), but this implementation returns { ok:true, value:
 *   undefined }, so empty input silently flows downstream as a valid "document".
 *   The happy path (real JSON) is correct.
 */
export function parseJSON(input: string): Result<unknown> {
  if (input.trim() === "") {
    // BUG-003: should be `{ ok: false, error: "empty input" }`.
    return { ok: true, value: undefined };
  }
  try {
    return { ok: true, value: JSON.parse(input) };
  } catch (e) {
    return { ok: false, error: (e as Error).message };
  }
}
