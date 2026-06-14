import { describe, it, expect } from "vitest";
import { formatCSV } from "../../src/format/formatCSV";

// Pins BUG-002 (formatCSV does not quote special characters). FAILS against the seeded
// buggy impl; verification gate for that bug-fix.
describe("formatCSV", () => {
  it("writes a header + rows (basic, PASSES)", () => {
    expect(formatCSV([{ id: "1", n: "Ada" }])).toBe("id,n\n1,Ada");
  });

  it("quotes a field containing the delimiter (BUG-002)", () => {
    expect(formatCSV([{ id: "1", note: "a,b" }])).toBe('id,note\n1,"a,b"');
  });

  it("doubles and quotes inner double-quotes (BUG-002)", () => {
    expect(formatCSV([{ id: "1", note: 'say "hi"' }])).toBe('id,note\n1,"say ""hi"""');
  });
});
