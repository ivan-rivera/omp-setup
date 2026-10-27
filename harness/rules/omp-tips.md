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
| `/briefing` | wants an explainer of a pull request — theirs or someone else's: ELI5, key changes, gotchas |
| `/merge-prs` | wants all open PRs reviewed, merged sequentially with conflicts resolved, and the harness updated after |
| `/update` | wants to check for OMP updates (only in the omp-setup repo) |
| `/intercom` or `Alt+M` | wants to send a message or question to another live OMP session |

**Custom skills (this harness):**

| Skill | Use when the user... |
|-------|---------------------|
| `/skill:brainstorming` | is about to start a new feature or project without a clear plan |
| `/skill:model-scout` | wants to update model assignments based on benchmarks |
| `/skill:frontend-design` | is making visual design decisions for UI |
| `/skill:extension-creator` | wants to build a custom OMP extension |
| `/skill:skill-creator` | wants to create a new OMP skill |
| `/skill:pr-briefing` | wants a PR briefed/explained in plain language, with key changes, implications, and gotchas; also fires automatically when a PR is released |
| `/skill:ocr-review` | wants an independent AI code review of a diff, commit, or branch before shipping a PR |
| `/skill:agents-vault` | wants OMP to read or write project notes, handoffs, or decision records in the shared Obsidian vault (`~/Documents/hive`) |
| `/skill:orchestrate` | wants to run a goal as a coordinated agent fleet — a herdr goal session with milestone workspaces, coordinator + worker tabs, a shared ledger, and convergent verification |
| `/skill:impeccable` | wants frontend/UI design work: shaping, critique, polish, audit, bolder/quieter, animation, or a design-system pass |
| `/skill:ppt-master` | wants a slide deck, presentation, or PPTX generated from a topic or document, or an existing deck beautified, restyled, filled, animated, or narrated |
| `/skill:brag` | wants a short, shareable launch video for a project or live site URL — music, motion, share copy (installed via `just install-brag`) |
| `/skill:brag-slim` | wants the same launch video built with local tools only, no Hyperframes (installed via `just install-brag`) |

## Feature Discovery

When the user manually does something that OMP handles natively, suggest the feature. Examples:

- Manually coordinating agents → suggest `/vibe`
- Manually searching past context → suggest `/memory` or `recall`
- Working on a high-stakes task without advisor → suggest `/advisor on`
- Manually switching models → suggest `/model` or `Ctrl+P`
- Asking "what can you do" → suggest `/intro`

**Format:** `Tip: you can use /command for this.` — one line, end of response. No preamble.
