---
description: "Python style conventions"
globs: ["*.py", "*.pyi"]
alwaysApply: false
---

# Python Style

- PEP 8 compliance. Use a formatter (black/ruff) — don't manually fix style.
- Type hints on all public functions and method signatures. Use `from __future__ import annotations` for modern syntax.
- f-strings over `.format()` or `%` formatting.
- `pathlib.Path` over `os.path` for filesystem operations.
- Dataclasses or Pydantic models for data containers — avoid raw dicts for structured data.
- No bare `except:` — always catch specific exceptions. Use `except Exception` at minimum.
- Prefer `logging` over `print` for anything beyond quick debugging.
- Use context managers (`with`) for resource management (files, connections, locks).
- Imports: stdlib first, third-party second, local third. One import per line for `from` imports.
- Prefer list/dict/set comprehensions over `map`/`filter` when readability is equal.
