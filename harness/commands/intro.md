---
description: "OMP orientation — overview of your harness, features, and workflows"
---

Give the user a comprehensive orientation to OMP and their custom harness. Generate the overview dynamically by reading the current state.

## Steps

1. **Read the harness config.** Scan these paths and summarise what's configured:
   - `~/.omp/agent/agents/*.md` — list each agent, its role, model tier, and whether advisor is on
   - `~/.omp/agent/skills/*/SKILL.md` — list each skill and how to invoke it
   - `~/.omp/agent/commands/*.md` — list each custom command
   - `~/.omp/agent/rules/*.md` — list each rule, note which are always-apply vs conditional
   - `~/.omp/agent/config.yml` — model roles, memory backend, approval mode
   - `~/.omp/agent/models.yml` — configured providers
   - `~/.omp/agent/mcp.json` — connected MCP servers

2. **Present a structured overview** using tables for scannability:
   - **Your agents** — name, purpose, model tier, advisor status
   - **Your skills** — name, trigger, how to invoke
   - **Your commands** — name, what it does
   - **Your rules** — name, always-on vs conditional (with globs)
   - **Model routing** — current tiers and how to switch (`/model`, `Ctrl+P`, `/skill:model-scout`)
   - **Memory** — backend, how to use (`/memory`, `retain`, `recall`, `memory_edit`)
   - **MCP servers** — what's connected

3. **Key OMP features** — summarise these built-in capabilities:
   - `/vibe` — director mode for orchestrating multiple agents
   - `/advisor on|off` — toggle advisor oversight
   - `/collab` — pair-programming mode
   - `/review` — code review
   - `orchestrate` — keyword for parallel subagent work
   - `ultrathink` — keyword for deep multi-step reasoning
   - `Alt+A` — Agent Hub TUI for monitoring subagents
   - `/model <name>` or `Ctrl+P` — switch models mid-session
   - `/fresh` — clean session
   - `/memory` — memory management

4. **Workflow examples** — provide 3-5 practical examples:
   - "Start a new feature": `/skill:brainstorming` → plan → implement
   - "Research a topic": spawn `researcher` agent or use `orchestrate`
   - "Review code": `/review` or spawn `qa` agent
   - "Orchestrate a complex task": `/vibe` or type `orchestrate`
   - "Update model config": `/skill:model-scout`

5. **Stay conversational.** Answer follow-up questions about any feature. If the user asks about something OMP can do that isn't in the harness, explain how to set it up.
