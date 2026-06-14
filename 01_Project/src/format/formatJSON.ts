/**
 * Pretty-print any JSON-serializable value with 2-space indent.
 * Contract: contract:format (.claude/ECOSYSTEM.md).
 *
 * This is a correct reference implementation (gives the pipeline one working
 * end-to-end path and a passing test among the red backlog).
 */
export function formatJSON(value: unknown): string {
  return JSON.stringify(value, null, 2);
}
