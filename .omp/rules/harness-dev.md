---
description: "OMP harness config editing conventions"
globs: ["harness/**", "justfile"]
alwaysApply: false
---

# Harness Development

This repository contains OMP configuration files. When editing files under `harness/`:

- **Agents** (`agents/*.md`): YAML frontmatter must include `name` and `description`. Valid fields: `name`, `description`, `model`, `tools`, `spawns`, `advisor`, `autoloadSkills`, `thinkingLevel`, `blocking`, `prewalk`, `readSummarize`, `output`.
- **Rules** (`rules/*.md`): YAML frontmatter must include `description`. Valid fields: `description`, `globs`, `alwaysApply`, `condition`, `astCondition`, `scope`, `interruptMode`.
- **Skills** (`skills/*/SKILL.md`): YAML frontmatter must include `name` and `description`. Valid fields: `name`, `description`, `globs`, `alwaysApply`, `hide`.
- **Commands** (`commands/*.md`): YAML frontmatter must include `description`. Arguments via `$1`, `$2`, `$@`, `$ARGUMENTS`.
- **config.yml**: Main settings file. Check `omp config list` for valid keys before adding new ones.
- **models.yml**: Provider definitions. Valid `api` values: `openai-completions`, `openai-responses`, `anthropic-messages`, `google-generative-ai`.
- **mcp.json**: MCP server definitions. Valid `type` values: `stdio`, `http`, `sse`.

## Documentation Sync

`README.md` is the live inventory of harness capabilities; `harness/models-changelog.md` and friends record history. A changelog entry is never a substitute: a capability missing from the README is invisible to every future session.

When a change adds, removes, or renames a capability — agent, skill, command, rule, hook, MCP server, model role or routing, provider, env var, prerequisite, or install/update justfile target — update `README.md` in the same PR:

- **What's Included**: counts and lists must match `harness/` exactly (`just test` enforces this).
- **Prerequisites / Environment Variables / Justfile Targets**: add, edit, or remove rows to match reality.
- Delete entries for removed capabilities — the README describes current state, not history.

When adding or changing agents, skills, or commands, also update `harness/rules/omp-tips.md` with a reference entry.
