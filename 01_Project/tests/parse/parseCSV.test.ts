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
});
