---
description: "Onboard a new repository — analyse codebase and propose project-level OMP config"
---

Analyse the current repository and propose a project-level `.omp/` setup tailored to its tech stack.

## Steps

### 1. Analyse the Repository

Scan the codebase to understand:
- **Languages and frameworks** — package.json, requirements.txt, go.mod, Cargo.toml, etc.
- **Project structure** — monorepo vs single package, directory layout
- **Existing configs** — CI/CD, linting, formatting, testing setup
- **README** — exists? comprehensive or sparse?
- **Existing OMP/Claude/Cursor configs** — `.omp/`, `.claude/`, `.cursor/` directories

### 2. Propose Configs

Based on the analysis, propose project-level configs. Present as a summary table with rationale:

**README.md** — if missing or sparse, draft one covering: what the project is, how to set up, how to run, how to test, how to deploy.

**Agents** (`.omp/agents/*.md`) — suggest project-specific agents based on the stack. Examples:
- Django project → `migrations` agent for schema management
- Monorepo → `workspace-nav` agent for cross-package coordination
- API project → `api-design` agent for endpoint contracts

**Skills** (`.omp/skills/*/SKILL.md`) — suggest project-specific skills. Examples:
- "deploy" skill with the project's deploy workflow
- "test-strategy" skill for the project's testing patterns

**Commands** (`.omp/commands/*.md`) — suggest project-specific commands. Examples:
- `/deploy` — run the deploy pipeline
- `/test` — run the test suite with appropriate flags
- `/lint` — run linting and formatting
- `/db` — common database operations

**Rules** (`.omp/rules/*.md`) — suggest project-specific rules. Examples:
- Framework conventions (e.g., Next.js App Router patterns)
- Import ordering specific to the project
- Naming conventions from the codebase

### 3. Present and Approve

Show all proposals in a structured summary. For each item:
- What it is
- Why it's useful for this project
- Estimated complexity (simple config vs needs thought)

Ask the user to approve, modify, or reject each proposal. Accept partial approval.

### 4. Create

On approval:
1. Create `.omp/` directory structure
2. Write all approved config files
3. Generate or update README.md if approved
4. Show a summary of what was created

### 5. Optionally Commit

Ask if the user wants to commit the `.omp/` setup. If yes, create a commit with a descriptive message.

## Constraints

- Do NOT create anything without user approval. Propose first, act second.
- Do NOT overwrite existing `.omp/` configs without explicit permission.
- Keep proposals practical — don't suggest 15 agents for a 3-file project.
- Project-level configs should complement, not duplicate, the global harness.
