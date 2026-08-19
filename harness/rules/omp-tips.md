---
description: "Suggest OMP shortcuts and features when relevant"
alwaysApply: true
---

# OMP Tips

When the user's request or workflow clearly matches an available OMP feature, append a one-line tip suggesting the shorthand. Do not repeat a tip the user has already seen in this session.

## Shorthand Suggestions

If the user's natural-language request matches a command, skill, or keyword below, suggest it:

**Built-in commands:**

| Command | Use when the user... |
|---------|---------------------|
| `/vibe` | wants to orchestrate multiple agents on a complex task |
| `/advisor on` | is working on something complex without advisor oversight |
| `/review` | asks for a code review |
| `/collab` | wants pair-programming mode |
| `/memory` | wants to store, search, or manage durable facts |
| `/fresh` | wants to start a clean session |
| `/model <name>` | wants to switch models mid-session |
| `Alt+A` | wants to see or manage running subagents (Agent Hub) |

**Prompt keywords:**

| Keyword | Use when the user... |
|---------|---------------------|
| `orchestrate` | wants parallel subagent work with verification |
| `ultrathink` | wants deep multi-step reasoning |

**Custom commands (this harness):**

| Command | Use when the user... |
|---------|---------------------|
| `/intro` | wants an orientation to OMP and this harness |
| `/onboard` | wants to set up OMP for a new repository |
| `/update` | wants to check for OMP updates (only in the omp-setup repo) |

**Custom skills (this harness):**

| Skill | Use when the user... |
|-------|---------------------|
| `/skill:brainstorming` | is about to start a new feature or project without a clear plan |
| `/skill:model-scout` | wants to update model assignments based on benchmarks |
| `/skill:frontend-design` | is making visual design decisions for UI |
| `/skill:extension-creator` | wants to build a custom OMP extension |
| `/skill:skill-creator` | wants to create a new OMP skill |

## Feature Discovery

When the user manually does something that OMP handles natively, suggest the feature. Examples:

- Manually coordinating agents → suggest `/vibe`
- Manually searching past context → suggest `/memory` or `recall`
- Working on a high-stakes task without advisor → suggest `/advisor on`
- Manually switching models → suggest `/model` or `Ctrl+P`
- Asking "what can you do" → suggest `/intro`

**Format:** `Tip: you can use /command for this.` — one line, end of response. No preamble.
