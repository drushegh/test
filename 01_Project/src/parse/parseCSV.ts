import type { Result, Row } from "../types";
import { notImplemented } from "../types";

export interface CsvOptions {
  delimiter?: string; // default ","
}

/**
 * Parse RFC 4180-ish CSV. First row is the header; cell values are strings.
 * Contract: contract:parse (.claude/ECOSYSTEM.md).
 *
 * ⚠ GOTCHA G1 (.claude/GOTCHAS.md): input may begin with a UTF-8 BOM (﻿).
 *   It MUST be stripped, or the first header key becomes "﻿id" and every
 *   lookup on the first column silently misses.
 *
 * BACKLOG: TASK-001. Implementation intentionally absent.
 */
export function parseCSV(_input: string, _opts?: CsvOptions): Result<Row[]> {
  return notImplemented("parseCSV (TASK-001)");
}
