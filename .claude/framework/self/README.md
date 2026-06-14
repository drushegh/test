# `.claude/framework/self/` — Upstream Framework Dev State

This directory holds the state files used **when the framework is
developing itself** (i.e., inside the upstream repository at
[github.com/drushegh/claude-code-multi-agent-framework](https://github.com/drushegh/claude-code-multi-agent-framework)).
It exists so framework-dev work (task boards, session logs, decision
records, metric snapshots for this repo's own development) doesn't
leak into projects that consume the framework.

## Who should care

- **You are a consumer** (your project pulls framework files via
  `apply-update.sh`): you can ignore this directory entirely. It has
  no effect on your project. Deleting it is safe; keeping it is
  harmless. It is not listed in `framework-manifest.txt`, so future
  `apply-update.sh` runs will not touch or propagate it.
- **You are working on the framework itself**: this is where the real
  state lives. Root `TASKS.md`/`STATUS.md`/etc. are the clean
  templates consumers inherit. Your live task board, session log,
  decision log, contracts (`ECOSYSTEM.md`), gotchas, and framework
  suggestions all live here (the last three joined the redirect set
  on 2026-06-10, TASK-027 — see `contract:state-file-paths`).

## How the redirect activates

A flag file `.claude/framework-self.flag` (gitignored — present only
in the upstream clone) toggles framework-self mode. When present:

- Cold-start step 0 reads this flag and resolves all later state-file
  paths to `.claude/framework/self/<filename>`.
- `framework-drift-guard.sh`, `doctor.sh`, and
  `insights/update-metrics.sh` honour the flag and read/write the
  redirected paths.
- The Stop hook (`enforce-state-update.sh`) accepts updates to either
  root or `.claude/framework/self/` state files — grep-based filename
  match is layout-agnostic.

To activate in a fresh upstream clone:

```bash
touch .claude/framework-self.flag
```

## What if I pull this into a consumer by mistake?

Nothing breaks. Without the flag, no code path reads from or writes
to this directory. It is inert. If you find it untidy, delete it.
