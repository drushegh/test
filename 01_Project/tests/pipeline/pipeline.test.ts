import { describe, it, expect } from "vitest";
import { compose, tabulate } from "../../src/pipeline/pipeline";
import type { Stage } from "../../src/types";

// Pins contract:pipeline (compose + tabulate). Fails until TASK-006 is implemented.
const inc: Stage<number, number> = { name: "inc", run: (n) => n + 1 };
const dbl: Stage<number, number> = { name: "dbl", run: (n) => n * 2 };

describe("compose", () => {
  it("chains stages left-to-right", () => {
    const s = compose(inc, dbl); // (n+1)*2
    expect(s.run(3)).toBe(8);
  });
});

describe("tabulate", () => {
  it("produces a Table with first-seen column order across heterogeneous rows", () => {
    const s = tabulate();
    const t = s.run([{ a: 1 }, { b: 2 }, { a: 3, b: 4 }]);
    expect(t.columns).toEqual(["a", "b"]);
    expect(t.rows).toHaveLength(3);
  });
});
