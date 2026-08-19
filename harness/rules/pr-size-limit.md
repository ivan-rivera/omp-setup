---
description: "Limit PRs to 400 lines of code"
alwaysApply: true
---

# PR Size Limit

During planning, estimate the expected diff size in lines of code changed (added + removed).

**Exclude from the count:** config files (YAML, TOML, JSON, INI, ENV), markup (Markdown, RST), lock files, generated outputs, migrations, and test fixtures/snapshots.

**If the estimate exceeds 400 LOC:**

1. Stop and flag it before writing any code.
2. Propose a concrete split into multiple PRs with clear scope boundaries for each.
3. Ask the user for approval before proceeding — either with the split or an acknowledged exception for a single large PR.

Do not silently create large PRs. The check happens at planning time, not at commit time.
