# fleet/ — multi-consumer status sweep

`fleet-status.sh` walks the sibling directories of a framework repo and
reports each consumer's framework status in one table: pinned SHA, layout
era (whether it still needs `migrate-layout.sh`), skills opt-in, uncommitted
count, and (with `--check-remote`) upstream freshness.

Read-only — it never writes to or mutates a scanned repo, and it does NOT
run doctor on consumers (that would write their findings flag). It answers
"which of my projects are on a stale framework?" without opening each one.

```bash
bash .claude/framework/fleet/fleet-status.sh [ROOT] [--format text|md] [--check-remote]
```

Surfaced by the `/fleet` command (`.claude/commands/fleet.md`). Primarily
for multi-repo / agency-portfolio use; harmless (one-row) for a single repo.
To act on a stale consumer, go to that repo and run the relevant tool there —
this command only reports.
