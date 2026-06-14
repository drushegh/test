import type { Result, Row } from "../types";
import { notImplemented } from "../types";

export type FieldType = "string" | "number" | "boolean" | "null";

export interface FieldSchema {
  type: FieldType;
  required?: boolean; // default true
}

export type Schema = Record<string, FieldSchema>;

export interface ValidationIssue {
  field: string;
  message: string;
}

/**
 * Validate `value` against `schema`, collecting EVERY failing field.
 * Contract: contract:validate (.claude/ECOSYSTEM.md).
 *
 * BACKLOG: TASK-003. Implementation intentionally absent.
 */
export function validate(
  _value: unknown,
  _schema: Schema,
): Result<Row> & { issues?: ValidationIssue[] } {
  return notImplemented("validate (TASK-003)");
}
