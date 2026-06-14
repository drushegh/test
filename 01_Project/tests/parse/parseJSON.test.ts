import { describe, it, expect } from "vitest";
import { parseJSON } from "../../src/parse/parseJSON";

describe("parseJSON", () => {
  it("parses a valid document (PASSES — reference impl)", () => {
    expect(parseJSON('{"a":1}')).toEqual({ ok: true, value: { a: 1 } });
  });

  it("reports malformed JSON as an error (PASSES — reference impl)", () => {
    expect(parseJSON("{nope}").ok).toBe(false);
  });

  it("treats empty input as an error (FAILS — BUG-003)", () => {
    // Buggy impl returns { ok:true, value:undefined } for "".
    expect(parseJSON("").ok).toBe(false);
  });
});
