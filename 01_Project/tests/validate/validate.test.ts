import { describe, it, expect } from "vitest";
import { validate, type Schema } from "../../src/validate/validate";

// Pins contract:validate. Fails until TASK-003 is implemented.
const schema: Schema = {
  id: { type: "string" },
  age: { type: "number", required: false },
};

describe("validate", () => {
  it("accepts a conforming row", () => {
    const r = validate({ id: "1", age: 30 }, schema);
    expect(r.ok).toBe(true);
  });

  it("collects every failing field", () => {
    const r = validate({ age: "old" }, schema); // id missing, age wrong type
    expect(r.ok).toBe(false);
    if (r.ok) return;
    expect(r.issues?.map((i) => i.field).sort()).toEqual(["age", "id"]);
  });
});
