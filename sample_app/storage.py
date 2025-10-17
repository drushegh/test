"""Task storage management for the sample application."""
from __future__ import annotations

from dataclasses import dataclass, asdict
from pathlib import Path
from typing import Iterable, List
import json


@dataclass
class Task:
    """Represents a single task in the todo list."""

    id: int
    description: str
    done: bool = False


class TaskManager:
    """Persist tasks on disk using a JSON file."""

    def __init__(self, storage_path: Path | str):
        self._storage_path = Path(storage_path)
        self._storage_path.parent.mkdir(parents=True, exist_ok=True)

    @property
    def storage_path(self) -> Path:
        """Return the backing storage path."""

        return self._storage_path

    def _load_raw(self) -> List[dict]:
        if not self._storage_path.exists():
            return []
        with self._storage_path.open("r", encoding="utf-8") as fh:
            data = json.load(fh)
        if not isinstance(data, list):
            raise ValueError("Invalid task storage format: expected a list")
        return data

    def _dump_raw(self, tasks: Iterable[Task]) -> None:
        payload = [asdict(task) for task in tasks]
        with self._storage_path.open("w", encoding="utf-8") as fh:
            json.dump(payload, fh, indent=2, ensure_ascii=False)

    def load_tasks(self) -> List[Task]:
        """Load all tasks from disk."""

        return [Task(**item) for item in self._load_raw()]

    def _next_id(self, tasks: List[Task]) -> int:
        if not tasks:
            return 1
        return max(task.id for task in tasks) + 1

    def add_task(self, description: str) -> Task:
        """Create a new task and persist it."""

        tasks = self.load_tasks()
        new_task = Task(id=self._next_id(tasks), description=description)
        tasks.append(new_task)
        self._dump_raw(tasks)
        return new_task

    def complete_task(self, task_id: int) -> Task:
        """Mark a task as completed."""

        tasks = self.load_tasks()
        for task in tasks:
            if task.id == task_id:
                if task.done:
                    return task
                task.done = True
                self._dump_raw(tasks)
                return task
        raise KeyError(f"Task with id {task_id} does not exist")

    def list_tasks(self, include_completed: bool = False) -> List[Task]:
        """Return the tasks filtered by completion state."""

        tasks = self.load_tasks()
        if include_completed:
            return tasks
        return [task for task in tasks if not task.done]

