---
name: agents-vault
description: "Shared Obsidian vault as pull-based project memory. Vault lives at /Users/ivr/Documents/hive; OMP's slice is Agents/OMP/ (sibling Agents/Hermes/ belongs to the Hermes agent). Use when starting or resuming a multi-session project (read Agents/OMP/Projects/<Project>/ notes first), when work produces durable context worth keeping (decisions, handoff state, discovered facts, project dossiers), when coordinating subagents that need shared state, or when leaving an async message for the user from background work. Plain markdown files — no Obsidian app needed."
alwaysApply: false
---

# Agents vault (shared project memory)

The Obsidian vault at `/Users/ivr/Documents/hive` has an `Agents/` folder shared by multiple agents on this machine. **OMP reads and writes only the `Agents/OMP/` subdirectory** — the sibling `Agents/Hermes/` belongs to Hermes and must never be written. It is a **pull-based, human-editable data store** for durable, project-scoped context: the user reads and edits it in Obsidian; OMP works on the same plain markdown files with the usual file tools (`read`, `write`, `edit`, `grep`, `glob`) — no Obsidian app, API, or plugin required. The vault is also synced one-way into the shared Hindsight memory bank (`hindsight-obsidian-sync`), so both agents can recall its content semantically — the files remain the source of truth. If the vault path is ever missing, ask the user instead of guessing a new one.

## When to use

- Starting or resuming a multi-session project: check `Agents/OMP/Projects/<Project>/` for existing notes before asking the user.
- Recording durable project context: decisions, handoff state, discovered facts.
- Coordinating subagents that need shared state beyond their lossy summaries.
- Leaving async messages for the user from background work with no live session.

## Division of labor (do not blur these)

- Hindsight long-term memory (`xd://recall` / `xd://retain`, shared bank `ivr` with Hermes and the vault sync): small durable facts, preferences, environment facts — recalled automatically at session start.
- Skills: procedures and workflows.
- Session history: current-task detail only.
- **`Agents/OMP/`: bulky, evolving, project/task-scoped state** — loaded only when deliberately consulted.

Rule: **the vault holds state, never active configuration.** If a rule must apply every turn, it belongs in memory or a skill, not a note. If a note grows a stable rule, move the rule out and leave a pointer.

## What belongs there

- Project dossiers: goals, constraints, decisions, paths, current status.
- Task/handoff notes: state that must survive across sessions (session context does not).
- Decision records: "chose X over Y because Z" — things otherwise re-litigated each session.
- Agent-to-agent coordination: when delegating via `task`, pass each child the relevant note path in its `context`. Subagents get no conversation context and their summaries are lossy — the vault note is the durable record, and parallel children can read/write the same project folder as a shared blackboard.
- Async messages to the user (blockers/decisions from background work when no session is live). For interactive dialogue, use chat — never the vault.

## Conventions (deliberately minimal — let structure emerge)

- `Agents/OMP/Projects/<Project>/` is the only suggested structure. Below it, freeform: create files as the work demands, not preemptively.
- Do not scaffold empty folders, templates, or inbox files up front.
- Before resuming any multi-session project, look for and read its notes first; ask the user only if genuinely absent.
- After a task generates durable context (decisions, discovered facts, handoff state), write it to the project folder and say in chat where it landed.
- Prefer `[[wikilinks]]` between related notes.
- Never duplicate a note's content in memory: one line + path pointer at most.
- Never read or write outside `Agents/OMP/` — other agents' subdirectories are theirs.
