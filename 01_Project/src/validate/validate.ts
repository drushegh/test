import type { Result, Row } from "../types";

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
 */
export function validate(
  value: unknown,
  schema: Schema,
): Result<Row> & { issues?: ValidationIssue[] } {
  const issues: ValidationIssue[] = [];
  const record = typeof value === "object" && value !== null && !Array.isArray(value)
    ? (value as Record<string, unknown>)
    : {};

  for (const [field, fieldSchema] of Object.entries(schema)) {
    const required = fieldSchema.required !== false;
    const raw = record[field];

    // Check presence for required fields
    if (required && (raw === undefined || raw === null)) {
      issues.push({ field, message: `field "${field}" is required` });
      continue;
    }

    // Skip type-check if field is absent and not required
    if (raw === undefined || raw === null) {
      continue;
    }

    // Check type match
    const actualType = typeof raw;
    const expectedType = fieldSchema.type;

    const typeMatches =
      (expectedType === "null" && raw === null) ||
      (expectedType !== "null" && actualType === expectedType);

    if (!typeMatches) {
      issues.push({
        field,
        message: `field "${field}" expected ${expectedType}, got ${raw === null ? "null" : actualType}`,
      });
    }
  }

  if (issues.length > 0) {
    return { ok: false, error: `validation failed: ${issues.length} issue(s)`, issues };
  }

  // Build typed Row from validated fields (only schema-declared fields, cast to Cell)
  const row: Row = {};
  for (const field of Object.keys(schema)) {
    const raw = record[field];
    if (raw !== undefined) {
      row[field] = raw as import("../types").Cell;
    }
  }

  return { ok: true, value: row };
}
