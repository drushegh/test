import { describe, it, expect } from "vitest";
import { dedupe } from "../../src/transform/dedupe";

// Pins BUG-001 (dedupe drops last element). These FAIL against the seeded buggy impl
// and are the verification gate for the bug-fix lane (SCENARIOS.md scenario 6).
describe("dedupe", () => {
  it("keeps the LAST element when it is unique (BUG-001)", () => {
    expect(dedupe([{ id: 1 }, { id: 2 }, { id: 3 }], (r) => r.id)).toEqual([
      { id: 1 },
      { id: 2 },
      { id: 3 },
    ]);
  });

  it("removes a duplicate but preserves the first occurrence", () => {
    expect(dedupe([{ id: 1 }, { id: 1 }, { id: 2 }], (r) => r.id)).toEqual([
      { id: 1 },
      { id: 2 },
    ]);
  });

  it("does not mutate its input (GOTCHA G3)", () => {
    const input = [{ id: 1 }, { id: 1 }];
    dedupe(input, (r) => r.id);
    expect(input).toHaveLength(2);
  });
});
