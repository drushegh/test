import { describe, it, expect } from "vitest";
import { formatJSON } from "../../src/format/formatJSON";
import { parseJSON } from "../../src/parse/parseJSON";

// SCENARIO 5 — long-running stream. This suite is INTENTIONALLY slow (several seconds of
// deterministic CPU work) so a "run the full test suite" prompt produces a pane that
// streams output over time, keeps the orchestrator signature ring charging, and exercises
// PTY survival across view switches/resizes. It uses only the two reference impls so it
// PASSES regardless of the backlog — its job is duration, not a red signal.
//
// Determinism: fixed seed-free integer data, fixed iteration count. Same run every time.
// Tune ITERATIONS if your machine makes this too fast/slow to observe.
const ROWS = 20_000;
const ITERATIONS = 120;

describe("pipeline throughput (intentionally slow — scenario 5)", () => {
  it("round-trips a large dataset deterministically", () => {
    const data = Array.from({ length: ROWS }, (_, i) => ({ id: i, sq: i * i }));

    let checksum = 0;
    for (let it = 0; it < ITERATIONS; it++) {
      const text = formatJSON(data);
      const parsed = parseJSON(text);
      if (!parsed.ok) throw new Error("round-trip failed");
      checksum += text.length;
    }

    // Stable, machine-independent expectation: every iteration serializes the same data.
    const oneText = formatJSON(data);
    expect(checksum).toBe(oneText.length * ITERATIONS);
  });
});
