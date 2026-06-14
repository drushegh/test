import { describe, it, expect } from "vitest";
import { parseNDJSON } from "../../src/parse/parseNDJSON";

// Pins contract:parse for NDJSON. Fails until TASK-002 is implemented.
describe("parseNDJSON", () => {
  it("parses one value per line", () => {
    const r = parseNDJSON('{"a":1}\n{"a":2}');
    expect(r).toEqual({ ok: true, value: [{ a: 1 }, { a: 2 }] });
  });

  it("ignores a trailing newline — no phantom element (GOTCHA G2)", () => {
    const r = parseNDJSON('{"a":1}\n{"a":2}\n');
    if (!r.ok) throw new Error(r.error);
    expect(r.value).toHaveLength(2);
  });
});
