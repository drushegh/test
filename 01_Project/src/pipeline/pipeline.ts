import type { Stage, Row, Table } from "../types";
import { notImplemented } from "../types";

/**
 * Type-checked left-to-right composition of stages. Output of stage N must equal
 * input of stage N+1 (enforced by the overloads).
 * Contract: contract:pipeline (.claude/ECOSYSTEM.md). BACKLOG: TASK-006.
 */
export function compose<A, B>(s1: Stage<A, B>): Stage<A, B>;
export function compose<A, B, C>(s1: Stage<A, B>, s2: Stage<B, C>): Stage<A, C>;
export function compose<A, B, C, D>(
  s1: Stage<A, B>,
  s2: Stage<B, C>,
  s3: Stage<C, D>,
): Stage<A, D>;
export function compose(..._stages: Stage<unknown, unknown>[]): Stage<unknown, unknown> {
  return notImplemented("pipeline.compose (TASK-006)");
}

/**
 * Stage that turns Row[] into a column-ordered Table. The pipeline's column-ordering
 * GUARANTEE lives here (union of keys in first-seen order, or `columnsHint` if given).
 * BACKLOG: TASK-006.
 */
export function tabulate(_columnsHint?: string[]): Stage<Row[], Table> {
  return notImplemented("pipeline.tabulate (TASK-006)");
}
