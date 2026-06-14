import type { Result } from "../types";
import { notImplemented } from "../types";

/**
 * Parse newline-delimited JSON: one JSON value per line.
 * Contract: contract:parse (.claude/ECOSYSTEM.md).
 *
 * ⚠ GOTCHA G2 (.claude/GOTCHAS.md): a file written with a trailing newline ends in an
 *   empty final line. Splitting on "\n" naively yields a trailing "" that JSON.parse
 *   rejects — do NOT emit it as an element and do NOT error on it. Skip empty lines.
 *
 * BACKLOG: TASK-002. Implementation intentionally absent.
 */
export function parseNDJSON(_input: string): Result<unknown[]> {
  return notImplemented("parseNDJSON (TASK-002)");
}
