import { describe, it, expect } from "vitest";
import { run } from "../../src/cli/index";

// Pins contract:cli. Fails until TASK-008 (depends on parse + format being done first).
describe("cli.run", () => {
  it("converts CSV stdin to JSON", () => {
    const res = run(["--from", "csv", "--to", "json"], "id,name\n1,Ada");
    expect(res.exitCode).toBe(0);
    const parsed = JSON.parse(res.stdout);
    expect(parsed).toEqual([{ id: "1", name: "Ada" }]);
  });

  it("reports a non-zero exit code on unknown format", () => {
    const res = run(["--from", "xml", "--to", "json"], "");
    expect(res.exitCode).not.toBe(0);
    expect(res.stderr).not.toBe("");
  });
});
