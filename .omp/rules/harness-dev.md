---
description: "OMP harness config editing conventions"
globs: ["harness/**"]
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

When adding new agents, skills, or commands, also update `harness/rules/omp-tips.md` with a reference entry.
