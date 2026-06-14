import { describe, it, expect } from "vitest";
import { map } from "../../src/transform/map";
import { filter } from "../../src/transform/filter";
import { reduce } from "../../src/transform/reduce";
import { sort } from "../../src/transform/sort";
import { flatten } from "../../src/transform/flatten";
import { groupBy } from "../../src/transform/groupBy";
import { window } from "../../src/transform/window";

// The fan-out surface (TASK-004 / scenario 2). One independent describe per operator
// so failures map cleanly onto parallel work. `dedupe` is tested separately (BUG-001).
describe("map", () => {
  it("maps each element", () => {
    expect(map([1, 2, 3], (x) => x * 2)).toEqual([2, 4, 6]);
  });
});

describe("filter", () => {
  it("keeps matching elements", () => {
    expect(filter([1, 2, 3, 4], (x) => x % 2 === 0)).toEqual([2, 4]);
  });
});

describe("reduce", () => {
  it("folds to an accumulator", () => {
    expect(reduce([1, 2, 3], (a, x) => a + x, 0)).toBe(6);
  });
});

describe("sort", () => {
  it("sorts ascending by key", () => {
    expect(sort([{ n: 3 }, { n: 1 }, { n: 2 }], (r) => r.n)).toEqual([
      { n: 1 },
      { n: 2 },
      { n: 3 },
    ]);
  });

  it("does NOT mutate its input (GOTCHA G3)", () => {
    const input = [{ n: 3 }, { n: 1 }];
    sort(input, (r) => r.n);
    expect(input).toEqual([{ n: 3 }, { n: 1 }]);
  });
});

describe("flatten", () => {
  it("flattens one level", () => {
    expect(flatten([[1, 2], [3], [4, 5]])).toEqual([1, 2, 3, 4, 5]);
  });
});

describe("groupBy", () => {
  it("groups by key, first-seen order", () => {
    const g = groupBy([{ k: "a" }, { k: "b" }, { k: "a" }], (r) => r.k);
    expect([...g.keys()]).toEqual(["a", "b"]);
    expect(g.get("a")).toHaveLength(2);
  });
});

describe("window", () => {
  it("makes fixed-size windows, dropping the partial tail", () => {
    expect(window([1, 2, 3, 4, 5], 2)).toEqual([
      [1, 2],
      [3, 4],
    ]);
  });
});
