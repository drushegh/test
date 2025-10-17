from pathlib import Path

import pytest

from sample_app.storage import TaskManager


def test_add_and_list_tasks(tmp_path: Path) -> None:
    manager = TaskManager(tmp_path / "tasks.json")
    manager.add_task("Write documentation")
    manager.add_task("Implement feature")

    pending = manager.list_tasks()
    assert [task.description for task in pending] == [
        "Write documentation",
        "Implement feature",
    ]


def test_complete_task_marks_done(tmp_path: Path) -> None:
    manager = TaskManager(tmp_path / "tasks.json")
    task = manager.add_task("Ship release")

    updated = manager.complete_task(task.id)

    assert updated.done is True
    assert manager.list_tasks(include_completed=True)[0].done is True


def test_complete_task_raises_for_missing_id(tmp_path: Path) -> None:
    manager = TaskManager(tmp_path / "tasks.json")
    manager.add_task("Test edge cases")

    with pytest.raises(KeyError):
        manager.complete_task(999)

