import { notImplemented } from "../types";

export interface CliResult {
  exitCode: number;
  stdout: string;
  stderr: string;
}

/**
 * Thin runner: parse stdin `--from <fmt>`, emit `--to <fmt>`. Pure over (argv, stdin)
 * so it is testable without touching the process. Depends on parse/transform/format.
 * Contract: contract:cli (.claude/ECOSYSTEM.md). BACKLOG: TASK-008 (build last).
 */
export function run(_argv: string[], _stdin: string): CliResult {
  return notImplemented("cli.run (TASK-008)");
}
