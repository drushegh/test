Report the framework status of every consumer project under a directory —
which are on a stale framework, which haven't migrated layout, which opted
into skills, which have uncommitted work. Read-only; never touches a
scanned repo.

Use when managing more than one framework project (agency/portfolio use,
or your own multi-repo setup) and you want a single table instead of
opening each repo.

## Run

```bash
bash .claude/framework/fleet/fleet-status.sh [ROOT] [--format text|md] [--check-remote]
```

- `ROOT` — directory whose immediate subdirectories are scanned. Default:
  the parent of this repo (i.e. sibling projects). On this setup that's
  typically `F:\Git\Personal` or `F:\Git\Work` — pass the one you want, or
  a parent that contains both.
- `--format md` — Markdown table (paste into notes/issues).
- `--check-remote` — also `ls-remote` each project's framework upstream and
  flag those BEHIND their pinned SHA (network; slower). Off by default.

## Interpreting the table

| Column | Meaning |
| --- | --- |
| PINNED | short framework SHA from `.framework-version` (`(none)` = not on the update system) |
| LAYOUT | `ok`, or `PRE-migration` if it still has `00_framework/` or a root `TASKS.md` → run `migrate-layout.sh` there |
| SKILLS | `SKILLS_SELECTED` from `.skills-version`, or `-` if not opted in |
| DIRTY | uncommitted-change count |
| REMOTE | `up-to-date` / `BEHIND` / `unreachable` (only with `--check-remote`) |

## After reading

This command only reports. To act on a stale consumer, go to that repo and
run the relevant tool there (`migrate-layout.sh` for PRE-migration,
`apply-update.sh` for BEHIND). Don't mutate consumers from here.
