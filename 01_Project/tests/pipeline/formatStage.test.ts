import { describe, it } from "vitest";

// contract:pipeline-format is CONTESTED (status:draft). There is no agreed behavior to
// assert yet — wiring the pipeline to the table formatter requires an architect decision
// to widen one of the two stable contracts (SCENARIOS.md scenario 3). Left as `todo` on
// purpose: a developer who picks up TASK-007 should STOP and escalate, not write a test
// that silently picks a side.
describe("pipeline → table formatter wiring (contract:pipeline-format)", () => {
  it.todo("BLOCKED: resolve contested contract:pipeline-format before implementing (TASK-007)");
});
