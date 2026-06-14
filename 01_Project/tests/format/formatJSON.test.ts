import { describe, it, expect } from "vitest";
import { formatJSON } from "../../src/format/formatJSON";

describe("formatJSON", () => {
  it("pretty-prints with 2-space indent (PASSES — reference impl)", () => {
    expect(formatJSON({ a: 1 })).toBe('{\n  "a": 1\n}');
  });
});
