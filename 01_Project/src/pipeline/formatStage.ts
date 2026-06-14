import type { Stage, Table } from "../types";
import { notImplemented } from "../types";

/**
 * ⚠⚠ CONTESTED CONTRACT — DO NOT IMPLEMENT WITHOUT ARCHITECT SIGN-OFF ⚠⚠
 * Anchor: contract:pipeline-format  (status:draft)  — see .claude/ECOSYSTEM.md
 *
 * This is the pipeline's terminal table-formatting stage. The pipeline guarantees
 * stable column ordering and therefore wants to hand the formatter a `Table`
 * (which carries `columns`):
 *
 *     type TableFormatStage = Stage<Table, string>;   // what the pipeline expects
 *
 * But contract:format promises only:
 *
 *     formatTable(rows: Row[]): string                // no `columns`, no ordering
 *
 * These cannot both be satisfied as written. Resolving it requires WIDENING one of
 * the two stable contracts (format to accept `Table`, or pipeline to emit `Row[]`
 * and drop its ordering guarantee) — a cross-module change.
 *
 * Per Agent Rules: developers tighten inline but WIDENING → STOP and escalate to the
 * architect. This stub exists so the conflict is impossible to miss (SCENARIOS.md
 * scenario 3). It deliberately does not compile a wiring that pretends to work.
 *
 * BACKLOG: TASK-007 (escalation expected, not implementation).
 */
export type TableFormatStage = Stage<Table, string>;

export function tableFormatStage(): TableFormatStage {
  return notImplemented(
    "pipeline→format wiring is BLOCKED on contested contract:pipeline-format (TASK-007) — escalate to architect",
  );
}
