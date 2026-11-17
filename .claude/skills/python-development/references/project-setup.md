# Project Setup

## Standard Layout

```
myproject/
├── src/
│   └── mypackage/
│       ├── __init__.py
│       ├── main.py
│       ├── api/
│       ├── models/
│       └── utils/
├── tests/
│   ├── conftest.py
│   ├── test_api.py
│   └── test_models.py
├── pyproject.toml
├── README.md
└── .gitignore
```

`src/` layout prevents accidental imports of the uninstalled package. For
small/medium projects a flat `app/` package is fine (see architecture.md).

## pyproject.toml Template

```toml
[project]
name = "mypackage"
version = "0.1.0"
requires-python = ">=3.11"
dependencies = [
    "pydantic>=2.0.0",
]

# Dev tooling as a PEP 735 dependency group: `uv add --dev` writes here and
# `uv sync` installs it by default. (An extra under
# [project.optional-dependencies] would need `uv sync --extra dev`.)
[dependency-groups]
dev = [
    "pytest>=8.0.0",
    "pytest-cov>=5.0.0",
    "pytest-asyncio>=0.23.0",
    "ruff>=0.4.0",
    "pyright>=1.1.350",
]

[tool.ruff]
line-length = 88

[tool.ruff.lint]
select = ["E", "F", "I", "N", "W", "UP", "B"]
# I = import sorting (replaces isort), UP = pyupgrade, B = bugbear

[tool.pyright]
typeCheckingMode = "standard"

[tool.pytest.ini_options]
testpaths = ["tests"]
addopts = "--cov=mypackage --cov-report=term-missing"
asyncio_mode = "auto"
```

If the project uses mypy instead of pyright:

```toml
[tool.mypy]
python_version = "3.11"
warn_return_any = true
warn_unused_configs = true
disallow_untyped_defs = true
```

## Toolchain

```bash
uv init && uv add pydantic            # uv preferred for new projects
uv add --dev pytest ruff pyright
uv run pytest

ruff check . --fix                    # lint + import sort (rule "I")
ruff format .                         # format (replaces black; no import sorting)
pyright .                             # type check

# Security / supply chain when relevant
bandit -r .
pip-audit
```

ruff replaces black (`ruff format`), isort (`ruff check` with the `I`
rules — `ruff format` alone does not sort imports), and most of pylint —
don't add those separately to new projects. Match the existing toolchain in established repos.

## Native and GPU Dependencies

- **Installing a torch-dependent package can silently replace CUDA torch
  with the CPU build from PyPI.** After any `pip install`/`uv add` that
  pulls `torch` transitively, check
  `python -c "import torch; print(torch.__version__, torch.cuda.is_available())"`.
  Repair by reinstalling from the PyTorch index for your CUDA version
  (`pip install torch --index-url https://download.pytorch.org/whl/<cuXXX>
  --force-reinstall --no-deps` — take the exact tag from pytorch.org).
  With uv, pin torch to that index via `[[tool.uv.index]]` +
  `[tool.uv.sources]` so it cannot drift back.
- **A segfault in a native extension cannot be caught.** `try: import x
  except ImportError:` does not protect the process when the import
  crashes the interpreter (seen with mismatched MinGW-built NumPy wheels
  on a new Python version on Windows). For an *optional* native
  dependency, probe it in a child process first and import in-process
  only if the probe exits 0:

  ```python
  ok = subprocess.run([sys.executable, "-c", "import fast_ranker"],
                      capture_output=True, timeout=60).returncode == 0
  ```
- Promoting an optional dependency to a required one unmasks every test
  gated by `pytest.importorskip("<pkg>")`, and those tests may carry
  stale expectations. Grep for them and run each newly active file.

## Package Exports

```python
# mypackage/__init__.py
"""mypackage - package description."""

__version__ = "0.1.0"

from mypackage.models import User, Post
from mypackage.utils import format_name

__all__ = ["User", "Post", "format_name"]
```

## Import Conventions

Order: stdlib → third-party → local, blank line between groups (ruff's `I`
rules enforce this). Explicit imports only — never `from module import *`.
