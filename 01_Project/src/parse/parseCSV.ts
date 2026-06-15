import type { Result, Row } from "../types";

export interface CsvOptions {
  delimiter?: string; // default ","
}

/**
 * Parse RFC 4180-ish CSV. First row is the header; cell values are strings.
 * Contract: contract:parse (.claude/ECOSYSTEM.md).
 *
 * ⚠ GOTCHA G1 (.claude/GOTCHAS.md): input may begin with a UTF-8 BOM (U+FEFF).
 *   It MUST be stripped, or the first header key becomes "﻿id" and every
 *   lookup on the first column silently misses.
 */
export function parseCSV(input: string, opts?: CsvOptions): Result<Row[]> {
  try {
    const delimiter = opts?.delimiter ?? ",";

    // Guard: delimiter must be exactly one character.
    // An empty string makes indexOf("", i) return i on every call → infinite loop.
    // A multi-character delimiter is not supported by RFC 4180 and would require a
    // different splitting strategy; reject it with a clear error rather than silently
    // producing garbage.
    if (delimiter.length !== 1) {
      return {
        ok: false,
        error: `delimiter must be exactly one character; got ${JSON.stringify(delimiter)}`,
      };
    }

    // G1: strip leading UTF-8 BOM (U+FEFF)
    const clean = input.startsWith("﻿") ? input.slice(1) : input;

    const lines = splitLines(clean);
    if (lines.length === 0) {
      return { ok: true, value: [] };
    }

    const headers = parseRow(lines[0]!, delimiter);
    const rows: Row[] = [];

    for (let i = 1; i < lines.length; i++) {
      const line = lines[i]!;
      if (line === "") continue;
      const cells = parseRow(line, delimiter);
      const row: Row = {};
      for (let j = 0; j < headers.length; j++) {
        row[headers[j]!] = cells[j] ?? "";
      }
      rows.push(row);
    }

    return { ok: true, value: rows };
  } catch (err) {
    return { ok: false, error: err instanceof Error ? err.message : String(err) };
  }
}

/**
 * Split input into logical lines, treating \r\n and \n as line endings.
 * Does NOT split on newlines inside quoted fields.
 */
function splitLines(input: string): string[] {
  const lines: string[] = [];
  let start = 0;
  let inQuotes = false;

  for (let i = 0; i < input.length; i++) {
    const ch = input[i];
    if (ch === '"') {
      inQuotes = !inQuotes;
    } else if (!inQuotes && ch === "\n") {
      const line = input.slice(start, i);
      // strip trailing \r for Windows line endings
      lines.push(line.endsWith("\r") ? line.slice(0, -1) : line);
      start = i + 1;
    }
  }

  // push final segment (may be empty if input ends with \n)
  const last = input.slice(start);
  lines.push(last.endsWith("\r") ? last.slice(0, -1) : last);

  return lines;
}

/**
 * Parse a single CSV row into an array of string cells.
 * Handles RFC 4180 quoting: quoted fields may contain the delimiter and
 * escaped double-quotes ("" → ").
 *
 * Fix A-1: tracks `afterQuotedField` so that when a quoted field is the last
 * field on the line (i lands at line.length immediately after the closing quote
 * and its trailing delimiter check), the outer loop does NOT emit a spurious
 * extra empty cell. Only a genuine dangling delimiter (unquoted path) emits the
 * trailing empty cell.
 */
function parseRow(line: string, delimiter: string): string[] {
  const cells: string[] = [];
  let i = 0;
  // Set to true after we finish parsing a quoted field. Cleared at the top of
  // each iteration. Used by the end-of-line guard to distinguish a genuine
  // trailing delimiter (should emit an empty cell) from a quoted final field
  // that already advanced i to line.length (must NOT emit a spurious extra cell).
  let afterQuotedField = false;

  while (i <= line.length) {
    if (i === line.length) {
      // We reached end-of-line. This is the trailing-delimiter case — e.g.
      // "a,b," — which should emit one final empty cell. However, when the
      // previous iteration was a quoted field that already advanced i to
      // line.length (by consuming the closing quote + its following delimiter),
      // we must NOT push a duplicate empty cell. The `afterQuotedField` flag
      // distinguishes the two situations.
      if (cells.length > 0 && !afterQuotedField) cells.push("");
      break;
    }

    afterQuotedField = false;

    if (line[i] === '"') {
      // quoted field
      i++; // skip opening quote
      let value = "";
      while (i < line.length) {
        if (line[i] === '"') {
          if (line[i + 1] === '"') {
            // escaped quote ("" → ")
            value += '"';
            i += 2;
          } else {
            // closing quote
            i++;
            break;
          }
        } else {
          value += line[i];
          i++;
        }
      }
      cells.push(value);
      // skip the delimiter that follows the closing quote (if present)
      if (line[i] === delimiter) i++;
      // Mark that we just finished a quoted field so the end-of-line guard
      // above knows not to push a spurious empty cell.
      afterQuotedField = true;
    } else {
      // unquoted field: read until delimiter or end of line
      const end = line.indexOf(delimiter, i);
      if (end === -1) {
        cells.push(line.slice(i));
        break;
      } else {
        cells.push(line.slice(i, end));
        i = end + delimiter.length;
        // if delimiter is at the very end, emit an empty trailing cell
        if (i === line.length) {
          cells.push("");
          break;
        }
      }
    }
  }

  return cells;
}
