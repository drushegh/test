import { describe, it, expect } from "vitest";
import { formatTable } from "../../src/format/formatTable";

// Pins contract:format for the table renderer. Fails until TASK-005 is implemented.
describe("formatTable", () => {
  it("renders aligned columns derived from the first row", () => {
    const out = formatTable([
      { id: "1", name: "Ada" },
      { id: "2", name: "Linus" },
    ]);
    const lines = out.split("\n");
    expect(lines[0]).toContain("id");
    expect(lines[0]).toContain("name");
    // every line padded to the same width
    const widths = new Set(lines.map((l) => l.length));
    expect(widths.size).toBe(1);
  });
});
