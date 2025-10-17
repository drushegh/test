"""Command line interface for the sample task manager application."""
from __future__ import annotations

import argparse
from pathlib import Path
from typing import Iterable

from .storage import TaskManager

DEFAULT_STORAGE = Path.home() / ".sample_tasks.json"


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        description="Manage a todo list stored in a local JSON file."
    )
    parser.add_argument(
        "--storage",
        type=Path,
        default=DEFAULT_STORAGE,
        help=(
            "Path to the JSON file used for storing tasks. "
            "Defaults to ~/.sample_tasks.json"
        ),
    )
    subparsers = parser.add_subparsers(dest="command", required=True)

    add_parser = subparsers.add_parser("add", help="Add a new task")
    add_parser.add_argument("description", help="Description of the task")

    list_parser = subparsers.add_parser("list", help="List existing tasks")
    list_parser.add_argument(
        "--all",
        action="store_true",
        help="Include completed tasks in the output",
    )

    complete_parser = subparsers.add_parser(
        "complete", help="Mark a task as completed"
    )
    complete_parser.add_argument("task_id", type=int, help="Identifier of the task")

    return parser


def render_tasks(tasks: Iterable) -> str:
    """Return a human readable representation of tasks."""

    lines = ["ID  Description                           Status"]
    lines.append("--  -------------------------------------  --------")
    for task in tasks:
        status = "done" if task.done else "pending"
        lines.append(f"{task.id:<3} {task.description:<37} {status}")
    if len(lines) == 2:
        lines.append("(no tasks found)")
    return "\n".join(lines)


def main(argv: list[str] | None = None) -> str:
    parser = build_parser()
    args = parser.parse_args(argv)
    manager = TaskManager(args.storage)

    if args.command == "add":
        task = manager.add_task(args.description)
        return f"Added task {task.id}: {task.description}"
    if args.command == "list":
        tasks = manager.list_tasks(include_completed=args.all)
        return render_tasks(tasks)
    if args.command == "complete":
        try:
            task = manager.complete_task(args.task_id)
        except KeyError as exc:
            raise SystemExit(str(exc)) from exc
        return f"Marked task {task.id} as done"
    raise SystemExit("Unknown command")


if __name__ == "__main__":  # pragma: no cover
    print(main())

