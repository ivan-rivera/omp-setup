# Oh-My-Pi Harness Setup — Tasks

> **Owner:** Ivan Rivera
> **Repo:** `git@github.com:ivan-rivera/omp-setup.git`
> **Purpose:** Version-controlled OMP harness for a solo full-stack developer exploring multiple business ideas. Acts as a personal team of AI assistants across research, prototyping, content, code, and analysis.

---

## Repository Target Structure

```
omp-setup/
├── justfile                              # Install deps, symlink configs
├── tasks.md                              # This file — task tracker
├── .gitignore
├── harness/                              # Symlinked to ~/.omp/agent/
│   ├── config.yml                        # Main config
│   ├── models.yml                        # Provider + model definitions
│   ├── mcp.json                          # MCP servers
│   ├── AGENTS.md                         # Lean global context
│   ├── models-changelog.md               # Model update history (managed by model-scout)
│   ├── rules/
│   │   ├── python-style.md
│   │   ├── typescript-style.md
│   │   ├── pr-size-limit.md
│   │   └── omp-tips.md
│   ├── agents/
│   │   ├── frontend.md
│   │   ├── backend.md
│   │   ├── architect.md
│   │   ├── security.md
│   │   ├── qa.md
│   │   ├── legal.md
│   │   ├── finance.md
│   │   ├── researcher.md
│   │   ├── content-writer.md
│   │   └── data-generator.md
│   ├── skills/
│   │   ├── brainstorming/SKILL.md
│   │   ├── frontend-design/SKILL.md
│   │   ├── model-scout/SKILL.md
│   │   └── extension-creator/SKILL.md
│   ├── commands/
│   │   ├── intro.md
│   │   └── onboard.md
│   └── tools/
├── .omp/                                 # Project-level OMP config (for this repo only)
│   └── commands/
│       └── update.md
```

---

## Task 1: Repo Scaffolding & Justfile

### Context

Initialise the git repository, connect to the remote, create the directory skeleton, and write the justfile. The justfile is the single entry point for all setup operations — installing OMP, its prerequisites, and any plugins.

### Prerequisites

- `just` command runner installed (`brew install just`)
- `bun` runtime v1.3.14+ (OMP dependency)
- `gh` CLI for GitHub operations

### Spec

**Git init & remote:**
- `git init` the repo
- `git remote add origin git@github.com:ivan-rivera/omp-setup.git`
- Create `.gitignore` (ignore `.omp/sessions/`, `.omp/plugins/`, `.omp/natives/`, OS files, editor files)

**Directory skeleton:**
- Create all directories under `harness/` as shown in the target structure
- Add `.gitkeep` to empty directories so they're tracked

**Justfile targets:**

| Target | Purpose |
|--------|---------|
| `install-deps` | Install bun (if missing), node (if missing for npx-based MCPs) |
| `install-omp` | Install OMP via `bun install -g @oh-my-pi/pi-coding-agent` |
| `install-plugins` | Install any OMP plugins (skill-creator, etc.) — initially empty, populated in Task 4 |
| `install` | Meta-target: runs `install-deps`, `install-omp`, `install-plugins` |
| `link` | Symlink `harness/` → `~/.omp/agent/` (backs up existing dir first) |
| `unlink` | Remove symlink, restore backup if one exists |
| `setup` | Meta-target: runs `install` then `link` |
| `status` | Show current symlink state, OMP version, installed plugins |

**Symlink strategy:**
- `link` target checks if `~/.omp/agent/` exists
  - If it's already a symlink → warn and ask to overwrite
  - If it's a real directory → move to `~/.omp/agent.backup.YYYY-MM-DD`
  - Then create: `ln -s $(pwd)/harness ~/.omp/agent`
- `~/.omp/` itself is NOT touched — only the `agent/` subdirectory is symlinked
- This preserves OMP-managed directories (`sessions/`, `plugins/`, `natives/`)

### Checklist

- [x] Initialise git repo and connect to remote
- [x] Create `.gitignore`
- [x] Create directory skeleton under `harness/`
- [x] Write justfile with all targets listed above
- [x] Verify `just install` works on a clean system
- [x] Verify `just link` and `just unlink` work correctly
- [ ] Make initial commit and push

### Notes

- OMP v17.3.8 installed. Requires bun >= 1.3.14 (1.3.11 fails with SyntaxError). Justfile updated to enforce this.
- `check-env` target added ahead of schedule (spec'd in Task 8) since it's a natural fit here.
- `GITHUB_TOKEN` not set on this machine — needs to be added to shell profile.
- Harness symlinked to `~/.omp/agent/` and verified working.

---

## Task 2: Global Context (AGENTS.md) & Claude Isolation

### Context

Create the lean global context file and configure OMP to NOT read from `~/.claude/` or other editor config directories. The global context should be minimal — it's injected into every session, so bloat here is expensive.

### Spec

**AGENTS.md** (placed at `harness/AGENTS.md`):
- Keep under ~50 lines
- Establish identity: solo full-stack dev, exploring multiple business ideas
- Set communication style: casual but high-signal, no fluff, no filler phrases, markdown for scannability
- Set quality bar: complete artifacts (no placeholders), challenge bad ideas (not a yes-bot), favour correct over fast
- Reference that rules, skills, and agents exist for domain-specific guidance — don't duplicate them here
- Do NOT include any model preferences, tool configurations, or project-specific details

**config.yml** (placed at `harness/config.yml`):

```yaml
disabledProviders:
  - claude
  - claude-plugins
  - codex
  - cursor
  - windsurf
  - cline
  - github
```

This disables ALL external config discovery sources, ensuring OMP reads ONLY from its native `.omp/` directories (i.e., our `harness/` symlink). No surprise config leakage from other editors or tools.

Additionally in config.yml, set the approval mode to a sensible default:
```yaml
tools:
  approval: write   # Confirm write operations, auto-approve reads
```

### Checklist

- [ ] Create `harness/AGENTS.md` with lean global context (~50 lines max)
- [ ] Create `harness/config.yml` with disabled providers and approval mode
- [ ] Verify OMP starts cleanly and does not load any Claude/Cursor/etc configs
- [ ] Verify AGENTS.md content appears in the system prompt

### Notes

_Space for the implementing agent to record discoveries._

---

## Task 3: Rules Setup

### Context

Create conditional rules that load only when relevant. OMP rules support `globs` for file-type scoping, `alwaysApply` for universal rules, and `condition`/`astCondition` for pattern-triggered injection.

### Spec

**Rule 1: Python Style** (`harness/rules/python-style.md`)
- `globs: ["*.py", "*.pyi"]`
- `alwaysApply: false`
- Content: PEP 8 compliance, type hints on all public functions, f-strings over `.format()`, pathlib over os.path, dataclasses/pydantic for data containers, avoid bare `except`
- Keep concise — style bullet points, not a tutorial

**Rule 2: TypeScript Style** (`harness/rules/typescript-style.md`)
- `globs: ["*.ts", "*.tsx", "*.js", "*.jsx"]`
- `alwaysApply: false`
- Content: strict mode, explicit return types on exported functions, `const` by default, named exports over default, barrel files only at package boundaries, prefer `interface` over `type` for object shapes
- Keep concise

**Rule 3: PR Size Limit** (`harness/rules/pr-size-limit.md`)
- `alwaysApply: true`
- Content: During planning, estimate the expected diff size (lines of code changed, excluding config/generated/lock files). If >400 LOC, MUST propose breaking the work into multiple PRs with clear scope boundaries. Ask user for approval before proceeding with either a single large PR or the proposed split. Do not silently create large PRs.

**Rule 4: OMP Tips** (`harness/rules/omp-tips.md`)
- `alwaysApply: true`
- Content: Two responsibilities:
  1. **Shorthand suggestions** — maintain awareness of available slash commands (custom, OMP built-in like `/review`, `/vibe`, `/collab`, `/advisor`), skills (`/skill:brainstorming`, `/skill:model-scout`, etc.), and prompt keywords (`orchestrate`, `ultrathink`). When the user's natural-language request clearly matches one, append a brief tip: "Tip: next time you can use `/command` for this."
  2. **Feature discovery** — when the user manually does something OMP has a built-in for (e.g., manually coordinating multiple agents when `/vibe` exists, manually searching memory when `/memory` exists), suggest the feature. This includes nudging `/advisor on` when the task looks complex and advisors are off. Keep tips to one line, don't repeat a tip the user has already seen in the same session.
- This rule should include a reference list of key OMP built-in commands and features so the agent has the knowledge to make suggestions. Curate this list — don't dump the entire OMP manual.

### Checklist

- [ ] Create `harness/rules/python-style.md` with globs and concise style guide
- [ ] Create `harness/rules/typescript-style.md` with globs and concise style guide
- [ ] Create `harness/rules/pr-size-limit.md` as always-apply planning guard
- [ ] Create `harness/rules/omp-tips.md` as always-apply with shorthand + feature discovery + advisor nudge
- [ ] Verify rules load correctly: always-apply rules appear in system prompt, glob-scoped rules activate only when matching files are in context
- [ ] Verify tips rule fires appropriately (manual test: ask something that matches a command)

### Notes

_Space for the implementing agent to record discoveries._

---

## Task 4: Skill Creator Setup

### Context

Install a skill-creator plugin that helps build new OMP skills with best practices, test harnesses, and proper structure. The user believes there's an existing one for Claude Code (Superpowers plugin has one). We need to either find an OMP-native equivalent or adapt one.

All plugin installations must go through the justfile.

### Spec

**Research phase:**
1. Check if OMP has a built-in skill-creator or an official plugin for it
2. Check if the Superpowers skill-creator can be adapted to OMP's skill format
3. Check the OMP plugin registry / community for skill-creator plugins

**Installation:**
- If an OMP-native plugin exists: add install command to justfile's `install-plugins` target
- If adapting from Superpowers: port the skill to `harness/skills/skill-creator/SKILL.md`
- If building from scratch: create `harness/skills/skill-creator/SKILL.md` that guides users through:
  - Naming and scoping the skill
  - Writing SKILL.md with proper frontmatter (`name`, `description`, `globs`, `alwaysApply`)
  - Structuring skill directories
  - Including test/validation approach
  - Referencing OMP skill docs for format compliance

**Justfile update:**
- Add any plugin install commands to the `install-plugins` target
- If the skill is file-based (not a plugin), no justfile change needed — it lives in `harness/skills/`

### Checklist

- [ ] Research available skill-creator plugins (OMP native, Superpowers, community)
- [ ] Install or create the skill-creator skill
- [ ] Update justfile `install-plugins` target if a plugin install is needed
- [ ] Verify the skill appears in OMP's skill listing
- [ ] Test: use the skill to scaffold a dummy skill, verify output structure

### Notes

_Space for the implementing agent to record discoveries._

---

## Task 5: Custom Skills, Commands & Extension Creator

### Context

Create custom skills (brainstorming, frontend-design, model-scout, extension-creator), and two global commands (`/intro`, `/onboard`).

### Spec

**Skill 1: Brainstorming** (`harness/skills/brainstorming/SKILL.md`)

Inspired by the Superpowers brainstorming skill. Guides collaborative idea exploration before implementation.

- **Flow:** Classify scope (spike/bounded/architectural) → ask clarifying questions → propose approaches with tradeoffs → present design → get approval before implementation
- **Key principles:**
  - Never jump to implementation without understanding the problem
  - Propose 2-3 approaches with tradeoffs and a recommendation
  - Scale process to task size (spike = quick probe, bounded = short design in chat, architectural = full spec)
  - Hard gate: user must approve before any implementation starts
- **Frontmatter:** `alwaysApply: false`, no globs (invoked explicitly via `/skill:brainstorming`)
- Keep the skill under ~200 lines. Focus on the decision framework, not verbose templates.

**Skill 2: Frontend Design** (`harness/skills/frontend-design/SKILL.md`)

Guides intentional visual design decisions when building or reshaping UI.

- **Scope:** aesthetic direction, typography, colour, spacing, component design, accessibility
- **Key principles:**
  - Design for distinctiveness — avoid looking like a default template
  - Justify choices based on user friction and cognitive load
  - Mobile-first, accessible by default (WCAG AA minimum)
  - Reference design tokens / design system if one exists in the project
- **Frontmatter:** `globs: ["*.tsx", "*.jsx", "*.vue", "*.svelte", "*.css", "*.scss"]`, `alwaysApply: false`

**Skill 3: Model Scout** (`harness/skills/model-scout/SKILL.md`)

Benchmark-driven model selection and rotation.

- **Flow:**
  1. Fetch current benchmark data from OpenRouter API (`/api/v1/models` endpoint provides pricing, context length, and benchmark scores) and optionally other benchmark sources (Chatbot Arena, LMSYS, etc.)
  2. Map benchmark task categories to agent roles:
     - `code-generation` → backend, frontend, qa
     - `code-review` → qa (secondary)
     - `reasoning` → architect, security, legal, finance
     - `research / information-retrieval` → researcher
     - `creative-writing / content` → content-writer
     - `data-extraction` → data-generator
     - `instruction-following` → orchestration roles
  3. For each agent, recommend the best model per tier (`best`, `balanced`, `fast`, `free`)
  4. Compare recommendations against current `models.yml` and present a diff
  5. On user approval, update `models.yml` and append a dated entry to `harness/models-changelog.md`:
     ```
     ## 2026-08-19
     - code-generation/balanced: anthropic/claude-sonnet-4 → google/gemini-2.5-pro (benchmark: +5% on HumanEval)
     - reasoning/best: anthropic/claude-opus-4 → anthropic/claude-opus-4.1 (new release)
     ```
  6. Never auto-apply changes — always present diff and wait for approval
- **Frontmatter:** `alwaysApply: false` (invoked via `/skill:model-scout`)
- The skill should instruct the agent on how to access OpenRouter's API for model metadata. The `OPENROUTER_API_KEY` env var will already be configured for the provider.

**Skill 4: Extension Creator** (`harness/skills/extension-creator/SKILL.md`)

Guides building custom OMP extensions (TypeScript/JavaScript modules).

- **Flow:**
  1. Clarify what the extension should do (new tool, event hook, custom command, keyboard shortcut, message rendering)
  2. Scaffold the extension module with proper structure (default export factory, `pi` API usage)
  3. Guide through the OMP extension API: `pi.registerTool()`, `pi.registerCommand()`, `pi.registerShortcut()`, `pi.on()` for events
  4. Explain available event types: session lifecycle (`session_start`, `session_shutdown`), turn events (`input`, `agent_start`, `agent_end`), tool events (`tool_call`, `tool_result`), reliability (`ttsr_triggered`, `auto_retry_start`)
  5. Remind to run `/reload-plugins` after creating or modifying extensions
- **Key constraints:**
  - Extensions cannot call runtime methods during module load — register first, act from events/commands/tools
  - Output goes to `~/.omp/plugins/` (global) or `<cwd>/.omp/extensions/` (project-level)
  - Module format: TypeScript or JavaScript with default export
- **Frontmatter:** `alwaysApply: false` (invoked via `/skill:extension-creator`)

**Command 1: `/intro`** (`harness/commands/intro.md`)

Interactive OMP orientation command. Reconciles OMP's current feature set with the user's custom harness.

- **What it does:**
  1. Reads OMP documentation from the installed version (or fetches from GitHub if docs aren't local)
  2. Reads the user's harness: agents, skills, rules, commands, model roles, memory config, MCP servers
  3. Presents a structured overview:
     - **Your agents** — who they are, what they do, how to spawn them
     - **Your skills** — what's available, how to invoke each
     - **Your commands** — custom slash commands and what they do
     - **Your rules** — what's always-on vs conditional
     - **Key OMP features** — `/vibe`, `/advisor`, `orchestrate`, Agent Hub (`Alt+A`), `/memory`, `/collab`, prompt keywords
     - **Model routing** — current tiers, how to switch, how to update via model-scout
  4. Provides 3-5 practical examples of common workflows (e.g., "start a new feature", "research a topic", "review code", "orchestrate a complex task")
  5. Stays in conversational mode to answer follow-up questions about any feature
- **Frontmatter:** No globs, no alwaysApply — purely on-demand
- The command should be concise in its markdown body (instructions to the agent, not a manual). The agent generates the overview dynamically by reading current configs.

**Command 2: `/onboard`** (`harness/commands/onboard.md`)

Repository onboarding command. Analyzes a new codebase and proposes project-level OMP configs.

- **What it does:**
  1. Analyzes the current repository: file structure, languages, frameworks, existing configs, README, CI/CD, package files
  2. Proposes a project-level `.omp/` setup:
     - **README.md** — generates or improves the repo's README if missing/sparse
     - **Agents** — suggests project-specific agents based on the tech stack (e.g., a Django project might get a `migrations` agent)
     - **Skills** — suggests project-specific skills (e.g., a monorepo might get a `workspace-nav` skill)
     - **Commands** — suggests project-specific commands (e.g., `/deploy`, `/test`, `/lint`)
     - **Rules** — suggests project-specific rules (e.g., framework conventions, import ordering)
  3. Presents all proposals as a summary with rationale
  4. On approval, creates the `.omp/` directory and all proposed files
  5. Optionally commits the setup
- **Frontmatter:** No globs, no alwaysApply — purely on-demand
- The command should NOT create anything without user approval. Present proposals first, act second.

### Checklist

- [ ] Create `harness/skills/brainstorming/SKILL.md`
- [ ] Create `harness/skills/frontend-design/SKILL.md`
- [ ] Create `harness/skills/model-scout/SKILL.md`
- [ ] Create `harness/skills/extension-creator/SKILL.md`
- [ ] Create `harness/commands/intro.md`
- [ ] Create `harness/commands/onboard.md`
- [ ] Verify all skills and commands appear in OMP's listings
- [ ] Test brainstorming: invoke and walk through a sample scenario
- [ ] Test model-scout: invoke and verify it can fetch model data from OpenRouter
- [ ] Test `/intro`: invoke and verify it reads harness configs and presents overview
- [ ] Test `/onboard`: invoke in a sample repo and verify proposals are sensible

### Notes

_Space for the implementing agent to record discoveries._

---

## Task 6: Agent Roster

### Context

Create 10 subagents, each with a clear domain, appropriate model role, tool access, and optional advisor pairing. Agents are Markdown files with YAML frontmatter in `harness/agents/`.

### Spec

**Agent-to-role mapping:**

| Agent | Model Role | Advisor Default | Benchmark Category | Tools (subset) | Spawns |
|-------|------------|-----------------|-------------------|----------------|--------|
| `frontend` | `@code-balanced` | off | code-generation | read, write, edit, bash, glob, grep | `[]` |
| `backend` | `@code-balanced` | off | code-generation | read, write, edit, bash, glob, grep | `[]` |
| `architect` | `@reason-best` | **on** | reasoning | read, glob, grep, bash | `["frontend", "backend"]` |
| `security` | `@reason-best` | **on** | reasoning | read, bash, glob, grep | `[]` |
| `qa` | `@code-balanced` | off | code-generation | read, write, edit, bash, glob, grep | `[]` |
| `legal` | `@reason-best` | **on** | reasoning | read, grep | `[]` |
| `finance` | `@reason-balanced` | off | reasoning | read, bash, grep | `[]` |
| `researcher` | `@research-balanced` | off | research | read, bash, glob, grep | `[]` |
| `content-writer` | `@content-balanced` | off | creative-writing | read, write, edit | `[]` |
| `data-generator` | `@fast` | off | data-extraction | read, write, bash | `[]` |

**Agent definition format** (each `harness/agents/<name>.md`):

```markdown
---
name: <agent-name>
description: "<one-line purpose>"
model: "<@role>"
tools: [<tool-list>]
spawns: [<child-agents>]
advisor: <true|false>
autoloadSkills: [<relevant-skills>]
---

<System prompt: 3-10 lines establishing identity, domain expertise, constraints, and output expectations. No fluff.>
```

**System prompt guidelines per agent:**
- **frontend**: React/Next.js/Tailwind focus, mobile-first, accessibility, component isolation
- **backend**: API design, database schema, auth, server-side logic, security-aware
- **architect**: System design, tradeoff analysis, interface contracts, scalability. Can spawn frontend/backend for implementation.
- **security**: Threat modelling, OWASP, dependency audit, secrets detection, input validation
- **qa**: Test strategy, unit/integration/e2e tests, edge cases, test infrastructure
- **legal**: Privacy policy, ToS, GDPR/compliance, licensing, IP review. Conservative and thorough.
- **finance**: Financial modelling, pricing strategy, unit economics, P&L, runway analysis
- **researcher**: Market research, competitive analysis, technical investigation, synthesis from multiple sources
- **content-writer**: Blog posts, docs, landing page copy, email campaigns, tone-consistent writing
- **data-generator**: Synthetic datasets, test fixtures, mock data, seed data, CSV/JSON generation

**Model role declarations** (in `config.yml`):

The `modelRoles` section should define roles using a `{domain}-{tier}` naming convention. Initial population:

```yaml
modelRoles:
  # Code domain
  code-best: openrouter/TBD          # Set by model-scout
  code-balanced: anthropic/claude-sonnet-4
  code-fast: google/gemini-2.5-flash
  code-free: TBD                     # Set by model-scout

  # Reasoning domain
  reason-best: anthropic/claude-opus-4
  reason-balanced: anthropic/claude-sonnet-4
  reason-fast: google/gemini-2.5-flash
  reason-free: TBD

  # Content domain
  content-best: TBD
  content-balanced: anthropic/claude-sonnet-4
  content-fast: google/gemini-2.5-flash
  content-free: TBD

  # Research domain
  research-best: TBD
  research-balanced: google/gemini-2.5-pro
  research-fast: google/gemini-2.5-flash
  research-free: TBD

  # Orchestration
  orch-best: TBD
  orch-balanced: anthropic/claude-sonnet-4
  orch-fast: google/gemini-2.5-flash
  orch-free: TBD

  # Cross-cutting
  advisor: openai/gpt-4.1
  fast: google/gemini-2.5-flash
  local: ollama/placeholder           # Not wired yet

  # Default fallback
  default: anthropic/claude-sonnet-4
```

TBD entries are placeholders for model-scout to fill based on benchmarks.

**Advisor configuration:**

OMP's advisor is a **shadow reviewer** — a second model that monitors an agent's transcript and injects course-corrections. It is NOT a separate agent in the roster. Key mechanics:

- `advisor: true` in agent frontmatter enables the advisor using the `@advisor` model role
- `advisor: "specific/model:thinkingLevel"` sets a per-agent advisor model directly
- `/advisor on|off` toggles advisors session-wide at runtime
- Per-agent runtime control via the `/agents` hub (no file edits needed)
- `task.agentAdvisor` in config.yml persists per-agent preferences

**Default advisor state per agent:**

| Agent | `advisor` default | Rationale |
|-------|------------------|-----------|
| `architect` | `true` | High-stakes system design decisions |
| `security` | `true` | Security analysis must be thorough |
| `legal` | `true` | Legal analysis requires precision |
| `frontend` | `false` | Toggle on with `/advisor on` when needed |
| `backend` | `false` | Toggle on with `/advisor on` when needed |
| `qa` | `false` | Toggle on with `/advisor on` when needed |
| `finance` | `false` | Toggle on with `/advisor on` when needed |
| `researcher` | `false` | Toggle on with `/advisor on` when needed |
| `content-writer` | `false` | Toggle on with `/advisor on` when needed |
| `data-generator` | `false` | Rarely needs oversight |

**How to toggle advisors at runtime:**
- `/advisor on` / `/advisor off` — session-wide toggle
- `/agents` hub — per-agent toggle without editing files
- `task.agentAdvisor` in config.yml — persist per-agent preferences across sessions
- The OMP tips rule (Task 3) will nudge you to enable advisors when it detects complex work

**Advisor model:**
The `@advisor` model role should use a strong reasoning model (`anthropic/claude-opus-4` via OpenRouter). Using the same provider simplifies cost tracking. A different model family (e.g., `openai/gpt-4.1`) could be used for independent perspective — this is a tuning decision best revisited after initial usage.

### Checklist

- [ ] Add `modelRoles` to `harness/config.yml`
- [ ] Create `harness/agents/frontend.md`
- [ ] Create `harness/agents/backend.md`
- [ ] Create `harness/agents/architect.md` (with advisor + spawns)
- [ ] Create `harness/agents/security.md` (with advisor)
- [ ] Create `harness/agents/qa.md`
- [ ] Create `harness/agents/legal.md`
- [ ] Create `harness/agents/finance.md`
- [ ] Create `harness/agents/researcher.md`
- [ ] Create `harness/agents/content-writer.md`
- [ ] Create `harness/agents/data-generator.md`
- [ ] Verify all agents appear in OMP's agent listing
- [ ] Test: spawn at least 2 agents (one with advisor, one without) and verify model routing

### Notes

_Space for the implementing agent to record discoveries._

---

## Task 7: Memory Setup

### Context

Configure the mnemopi memory backend for local, reviewable, controllable memory. Mnemopi uses SQLite and provides tools to retain, recall, reflect on, and edit memories.

### Spec

**config.yml additions:**

```yaml
memories:
  backend: mnemopi
  maxRolloutAgeDays: 30
  minRolloutIdleHours: 12
  summaryInjectionTokenLimit: 3000   # Keep lean — lower than default 5000

mnemopi:
  retainEveryNTurns: 4              # Auto-retain durable signals every 4 turns
  recallLimit: 8                     # Max memories to surface per recall
  injectionTokenLimit: 3000          # Cap memory injection in system prompt
```

**What this gives you:**
- `retain` — save durable facts, preferences, decisions
- `recall` — search memories by topic
- `reflect` — synthesise answers from accumulated memory
- `memory_edit` — update or delete specific memories
- `/memory` — built-in slash command for memory management

**Lean context principle:**
- Injection limits set to 3000 tokens (not the default 5000) to keep system prompt lean
- `retainEveryNTurns: 4` balances capture vs noise
- You can always manually `retain` or `memory_edit` to curate

### Checklist

- [ ] Add memory configuration to `harness/config.yml`
- [ ] Verify mnemopi backend activates on session start
- [ ] Test: retain a fact, recall it in a new session, edit it, delete it
- [ ] Verify injection stays within token limits (check system prompt size)

### Notes

_Space for the implementing agent to record discoveries._

---

## Task 8: MCP & CLI Integration

### Context

Configure three MCP servers: Context7 (library docs), Tavily (web research), and GitHub (repo operations). These are declared in `harness/mcp.json` and run via stdio transport (npx-based).

### Spec

**`harness/mcp.json`:**

```json
{
  "mcpServers": {
    "context7": {
      "type": "stdio",
      "command": "npx",
      "args": ["-y", "@context7/mcp-server"]
    },
    "tavily": {
      "type": "stdio",
      "command": "npx",
      "args": ["-y", "@tavily/mcp-server"],
      "env": {
        "TAVILY_API_KEY": "${TAVILY_API_KEY}"
      }
    },
    "github": {
      "type": "stdio",
      "command": "npx",
      "args": ["-y", "@modelcontextprotocol/server-github"],
      "env": {
        "GITHUB_PERSONAL_ACCESS_TOKEN": "${GITHUB_TOKEN}"
      }
    }
  }
}
```

**Environment variables required:**
- `TAVILY_API_KEY` — set in shell profile or `.env`
- `GITHUB_TOKEN` — GitHub personal access token (or `gh auth token` output)
- `OPENROUTER_API_KEY` — for the model provider (configured in models.yml)

**Justfile update:**
- Add a `check-env` target that verifies required env vars are set and warns about missing ones
- Add npm package names to any `install-deps` steps if npx caching is insufficient

**Verification:**
- `/mcp list` should show all three servers
- `/mcp test context7`, `/mcp test tavily`, `/mcp test github` should pass

### Checklist

- [ ] Create `harness/mcp.json` with all three server configs
- [ ] Add `check-env` target to justfile
- [ ] Verify Context7 MCP connects and can resolve a library
- [ ] Verify Tavily MCP connects and can run a search
- [ ] Verify GitHub MCP connects and can list repos
- [ ] Document required env vars in a `README.md` or justfile help target

### Notes

_The exact npm package names for the MCP servers should be verified at implementation time — they may have changed. Use `/mcp test` to validate._

---

## Task 9: Provider & Model Routing

### Context

Configure OpenRouter as the primary LLM provider and Ollama as a local placeholder. Define the model roles that agents reference.

### Spec

**`harness/models.yml`:**

```yaml
providers:
  openrouter:
    baseUrl: https://openrouter.ai/api/v1
    apiKey: OPENROUTER_API_KEY
    api: openai-completions

  ollama:
    baseUrl: http://127.0.0.1:11434
    api: openai-responses
    auth: none
    discovery:
      type: ollama
```

**Model roles** are declared in `config.yml` under `modelRoles:` (already specified in Task 6). This task is about wiring the provider layer.

**Fallback chain** (optional but recommended):

```yaml
retry:
  fallbackChains:
    "@default":
      - anthropic/claude-sonnet-4
      - google/gemini-2.5-pro
      - google/gemini-2.5-flash
```

If the primary model is unavailable, fall back through the chain. All models route through OpenRouter.

**Default model:**
- Set the default session model to `anthropic/claude-sonnet-4` via OpenRouter
- This is used when no agent-specific role is active

### Checklist

- [ ] Create `harness/models.yml` with OpenRouter and Ollama providers
- [ ] Add `modelRoles` to `harness/config.yml` (if not already done in Task 6)
- [ ] Add fallback chain configuration
- [ ] Verify OMP connects to OpenRouter and can complete a prompt
- [ ] Verify model role resolution: start a session, spawn an agent, confirm it uses the mapped model
- [ ] Verify Ollama provider is declared but does not error when Ollama is not running

### Notes

_The `OPENROUTER_API_KEY` env var must be set. Add to the `check-env` justfile target._

---

## Task 10: Project-Level Self-Update Config

### Context

Create project-level OMP configs specifically for this repository (omp-setup). The key feature is an `/update` command that checks for OMP updates, summarises changes, and suggests harness revisions.

### Spec

**Directory:** `.omp/` at the root of the omp-setup repo (NOT inside `harness/` — this is project-level config for when you're working in this repo).

**Command: `/update`** (`.omp/commands/update.md`)

A self-maintenance command for keeping the harness current with OMP's evolution.

- **What it does:**
  1. Checks the currently installed OMP version (`omp --version` or `bun pm ls -g`)
  2. Fetches the latest OMP releases/changelog from GitHub (`gh api repos/can1357/oh-my-pi/releases`)
  3. Compares installed vs latest — reports what's new
  4. Analyses the changelog for changes that affect the harness:
     - New agent/skill/rule frontmatter fields
     - New built-in commands or features
     - Breaking changes to config format
     - New model provider support or API changes
     - New memory backends or tools
  5. For each relevant change, proposes a concrete harness revision:
     - "New `prewalk` field on agents — consider adding to `data-generator` for faster edits"
     - "New `/collab` command added — update `omp-tips.md` reference list"
     - "Config format change: `modelRoles` now supports inline fallbacks — simplify `retry.fallbackChains`"
  6. On approval, applies revisions to harness files and logs changes to a `harness/update-log.md`
  7. Optionally runs `bun install -g @oh-my-pi/pi-coding-agent` to update OMP itself
- **Frontmatter:** No globs, no alwaysApply — purely on-demand
- This command should be conservative — propose changes, explain impact, wait for approval. Never auto-apply.

**Optional additions to `.omp/`:**
- `.omp/rules/harness-dev.md` — a rule scoped to this repo's files (`globs: ["harness/**"]`) that reminds the agent this is an OMP config repo, not a regular codebase. Ensures edits follow OMP's file formats (YAML frontmatter, correct field names, etc.)

### Checklist

- [ ] Create `.omp/commands/update.md`
- [ ] Create `.omp/rules/harness-dev.md` (optional — include if useful)
- [ ] Add `update-log.md` reference to directory structure
- [ ] Test `/update`: invoke in this repo, verify it can fetch OMP release info
- [ ] Test: simulate a harness revision proposal and verify it produces sensible suggestions

### Notes

_Space for the implementing agent to record discoveries._

---

## Task 11: Symlink & Final Integration

### Context

Wire everything together: ensure the justfile's `link` target correctly symlinks the harness, verify the full stack works end-to-end, and do a final sanity check.

### Spec

**End-to-end verification sequence:**

1. `just setup` — installs deps, OMP, plugins, and symlinks harness
2. Start OMP in a test project directory
3. Verify:
   - AGENTS.md content in system prompt ✓
   - No Claude/Cursor/etc config leakage ✓
   - Rules: open a `.py` file → Python style rule loads ✓
   - Rules: open a `.ts` file → TypeScript style rule loads ✓
   - Rules: PR size limit and OMP tips are always present ✓
   - Skills: `/skill:brainstorming`, `/skill:model-scout`, `/skill:frontend-design`, `/skill:extension-creator` all listed ✓
   - Commands: `/intro`, `/onboard` respond correctly ✓
   - Agents: all 10 agents visible in agent listing ✓
   - Spawn an agent → correct model role used ✓
   - Advisor fires on architect/security agents ✓
   - Memory: retain + recall works ✓
   - MCP: all three servers connect ✓
   - Model routing: OpenRouter responds ✓
4. Document any issues found and fix them

**Justfile polish:**
- Add a `help` target that lists all available targets with descriptions
- Add a `test` target that runs the verification sequence above (or as much as can be automated)
- Ensure all targets are idempotent (safe to run multiple times)

**README.md:**
- Brief setup instructions: prerequisites, `just setup`, required env vars
- Not a full manual — OMP's own docs cover that

### Checklist

- [ ] Verify `just link` symlinks correctly and `just unlink` restores
- [ ] Run full end-to-end verification sequence
- [ ] Add `help` target to justfile
- [ ] Add `test` target to justfile (automated checks where possible)
- [ ] Create minimal `README.md` with setup instructions
- [ ] Fix any issues found during integration testing
- [ ] Final commit and push

### Notes

_Space for the implementing agent to record discoveries._

---

## Task Dependency Graph

```
Task 1 (Scaffolding)
  └─→ Task 2 (AGENTS.md + config.yml)
        └─→ Task 3 (Rules)
        └─→ Task 4 (Skill Creator)
        │     └─→ Task 5 (Skills, Commands & Extension Creator)
        └─→ Task 9 (Provider + Model Routing)
        │     └─→ Task 6 (Agent Roster) — depends on model roles from Task 9
        │           └─→ Task 7 (Memory)
        └─→ Task 8 (MCP Integration)
        └─→ Task 10 (Project-Level Self-Update)
              └─→ Task 11 (Symlink + Final Integration) — depends on everything
```

Tasks 3, 4, 8, 9, and 10 can run in parallel after Task 2.
Task 5 depends on Task 4 (skill creator helps build other skills).
Task 6 depends on Task 9 (agents reference model roles).
Task 11 is the final integration gate.

---

## Session Continuity Protocol

When picking up this task list in a new session:

1. Read this file to see current state
2. Check which tasks are completed (`[x]`) vs pending (`[ ]`)
3. Read the "Notes" section of the last completed task for any context
4. Start the next pending task
5. After completing a task, update this file:
   - Mark checklist items as done
   - Add any discoveries to the Notes section
   - If scope changed, update subsequent task specs
