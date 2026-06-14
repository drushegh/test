// Shared vocabulary for every datakit module. See contract:shared-types in
// .claude/ECOSYSTEM.md — this file IS that contract. Touch rarely.

export type Cell = string | number | boolean | null;
export type Row = Record<string, Cell>;

export type Result<T> =
  | { ok: true; value: T }
  | { ok: false; error: string };

export interface Stage<I, O> {
  readonly name: string;
  run(input: I): O;
}

export interface Table {
  columns: string[];
  rows: Row[];
}

/**
 * Uniform marker for unimplemented backlog items. Stubs throw this so a test run
 * produces a clear, greppable red signal ("NotImplemented: <what>") rather than a
 * confusing wrong-answer failure. Replace the whole stub when implementing.
 */
export class NotImplementedError extends Error {
  constructor(what: string) {
    super(`NotImplemented: ${what}`);
    this.name = "NotImplementedError";
  }
}

export function notImplemented(what: string): never {
  throw new NotImplementedError(what);
}
