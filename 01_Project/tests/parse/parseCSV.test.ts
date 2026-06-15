import { describe, it, expect } from "vitest";
import { parseCSV } from "../../src/parse/parseCSV";

// Pins contract:parse for CSV. Fails until TASK-001 is implemented.
describe("parseCSV", () => {
  it("parses a header row + records", () => {
    const r = parseCSV("id,name\n1,Ada\n2,Linus");
    expect(r).toEqual({
      ok: true,
      value: [
        { id: "1", name: "Ada" },
        { id: "2", name: "Linus" },
      ],
    });
  });

  it("strips a leading UTF-8 BOM (GOTCHA G1)", () => {
    const r = parseCSV("﻿id,name\n1,Ada");
    if (!r.ok) throw new Error(r.error);
    // Without BOM stripping the first key would be "﻿id".
    expect(Object.keys(r.value[0]!)).toEqual(["id", "name"]);
  });

  it("keeps commas inside quoted fields", () => {
    const r = parseCSV('id,note\n1,"a,b"');
    expect(r).toEqual({ ok: true, value: [{ id: "1", note: "a,b" }] });
  });

  // --- Regression tests for review findings ---

  // A-1: quoted field as the FINAL header field must not produce a spurious
  // trailing empty header. Before the fix, parseRow would see i === line.length
  // after the closing quote and push an extra "" cell, injecting a junk key.
  it("A-1: quoted final header field does not produce a spurious extra header", () => {
    const r = parseCSV('"id","name"\n1,Ada');
    if (!r.ok) throw new Error(r.error);
    expect(Object.keys(r.value[0]!)).toEqual(["id", "name"]);
    expect(r.value[0]).toEqual({ id: "1", name: "Ada" });
  });

  // A-1 variant: quoted field as the FINAL data cell likewise must not produce
  // an extra key in the row object.
  it("A-1: quoted final data cell does not inject a junk empty key", () => {
    const r = parseCSV('id,name\n1,"Ada"');
    if (!r.ok) throw new Error(r.error);
    expect(Object.keys(r.value[0]!)).toEqual(["id", "name"]);
    expect(r.value[0]).toEqual({ id: "1", name: "Ada" });
  });

  // A-3: an empty-string delimiter must return ok:false immediately rather than
  // hanging in an infinite loop (indexOf("", i) === i always → i never advances).
  it("A-3: empty-string delimiter returns ok:false with a descriptive error", () => {
    const r = parseCSV("id,name\n1,Ada", { delimiter: "" });
    expect(r.ok).toBe(false);
    if (!r.ok) {
      expect(r.error).toMatch(/delimiter must be exactly one character/);
    }
  });

  // A-3 extension: a multi-character delimiter is equally unsupported.
  it("A-3: multi-character delimiter returns ok:false", () => {
    const r = parseCSV("id||name\n1||Ada", { delimiter: "||" });
    expect(r.ok).toBe(false);
  });

  // Custom single-character delimiter happy path (uncovered by original suite).
  it("custom delimiter (pipe) parses correctly", () => {
    const r = parseCSV("id|name\n1|Ada\n2|Linus", { delimiter: "|" });
    expect(r).toEqual({
      ok: true,
      value: [
        { id: "1", name: "Ada" },
        { id: "2", name: "Linus" },
      ],
    });
  });

  // Escaped-quote ("" inside a quoted field) happy path (uncovered by original suite).
  it('escaped double-quote ("" → ") inside a quoted field is decoded', () => {
    const r = parseCSV('id,note\n1,"say ""hello"""');
    expect(r).toEqual({ ok: true, value: [{ id: "1", note: 'say "hello"' }] });
  });

  // Trailing delimiter on an unquoted row should still emit the empty final cell
  // (regression guard: the A-1 fix must not break legitimate trailing delimiters).
  it("trailing delimiter on an unquoted row produces an empty final cell", () => {
    const r = parseCSV("id,name,extra\n1,Ada,");
    if (!r.ok) throw new Error(r.error);
    expect(r.value[0]).toEqual({ id: "1", name: "Ada", extra: "" });
  });
});
