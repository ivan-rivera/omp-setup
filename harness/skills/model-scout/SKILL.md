---
name: model-scout
description: "Benchmark-driven model selection and rotation for the OMP harness. Use when the user wants to update model assignments, check which models are best for specific tasks, compare model performance, review pricing, or keep their model config on the bleeding edge. Also use when new models are released and the user wants to know if they should switch."
alwaysApply: false
---

# Model Scout

Keep the harness model lineup current with the best available models. The architecture is deliberately minimal: **four conceptual models**, each chosen by benchmark evidence for its job.

## Model Architecture

| Role | Job | Selected by |
|------|-----|-------------|
| `default` | General-purpose workhorse: main conversation, reasoning, analysis, writing, research | Composite intelligence — Artificial Analysis (AA) Intelligence Index, LMArena Text Elo |
| `code` | Code generation | Executed-code benchmarks — SWE-bench Verified, LiveBench Coding, Terminal-Bench, Vibe Code Bench, then LMArena Coding/WebDev Elo |
| `agentic` | Task-execution driver: subagents running agreed-upon multi-step work with tools | Agentic benchmarks — LiveBench Agentic Coding, SkillsBench, APEX-Agents, LMArena Agent |
| `oracle` | Top-tier consult, engaged ONLY with user approval when working models get stuck | Breadth of #1 finishes across composite + agentic + hard-reasoning boards (AA Intelligence top-3) |

The three working models MAY be the same model — that is the current deliberate state. Diversify a role only on user request.

## Wiring

- **`harness/config.yml`** under `modelRoles:` — maps the four roles to concrete `openrouter/`-prefixed selectors, plus aliases:
  - `task: "@agentic"` — generic task agents; `task.agentModelOverrides` routes the bundled `task`/`sonic` agents
  - `advisor: "@oracle"` — the advisor subsystem resolves the oracle
- **`cycleOrder: [default, oracle]`** — Ctrl+P manually toggles workhorse ↔ oracle
- **`harness/models.yml`** — providers and `retry.fallbackChains`
- **Agent frontmatter** — each agent references a role:

| Role | Agents |
|------|--------|
| `@code` | frontend, backend, qa |
| `@agentic` | data-generator (plus generic `task`/`sonic` via overrides) |
| `@default` | architect, content-writer, finance, legal, researcher, security |

## Oracle Discipline (Hard Constraints)

- **Never automatic.** No retry fallback chain may include the oracle, and agents must not set `advisor: true` in frontmatter.
- User-approved paths only: `/advisor on` (attaches oracle review to the session), Ctrl+P cycle to oracle, or an explicit user request to consult it.
- Pick the oracle from the top of composite rankings, preferring a model family different from the working lineup for independent perspective.

## Process

### 1. Gather Benchmark Data

Fetch current model data from OpenRouter:

```bash
curl -s https://openrouter.ai/api/v1/models \
  -H "Authorization: Bearer $OPENROUTER_API_KEY" -o /tmp/openrouter-models.json
```

The response includes per-model: `id`, `pricing`, `context_length`, `supported_parameters`. It does NOT include benchmark scores — pull those from:
- Artificial Analysis (AA Intelligence Index, coding and agentic indices)
- LMArena / BenchLeader (Text, Coding, WebDev, Agent Elo)
- SWE-bench Verified, LiveBench, Terminal-Bench, Scale AI SEAL leaderboards

### 2. Map Benchmarks to Roles

Use the "Selected by" column in the architecture table. Evidence per role:
- `default`: AA Intelligence Index rank + LMArena Text Elo, balanced against $/1M pricing
- `code`: executed-code benchmarks first; Arena Coding Elo is preference, not correctness
- `agentic`: tool-use and long-horizon boards — a model that writes well but drives tools poorly is the wrong pick
- `oracle`: breadth of #1 finishes; cost is secondary (it is consulted rarely)

### 3. Present the Proposal

Show a comparison table: role, current model → recommended model, benchmark delta, cost delta ($/1M in/out). Note new releases worth watching even when they are not yet on OpenRouter.

**Never auto-apply changes.** Wait for explicit approval.

### 4. Apply Changes

On approval:

1. Update `modelRoles` (and `cycleOrder` if the tier structure changed) in `harness/config.yml`
2. Update agent frontmatter only if the role assignment itself changed
3. Update `retry.fallbackChains` in `harness/models.yml` — never adding the oracle to automatic chains
4. Append a dated entry to `harness/models-changelog.md` (create it with a header if missing):

```markdown
## YYYY-MM-DD

- `default`: old-model → new-model (benchmark: +X AA Intelligence, cost Δ $Y in / $Z out per 1M)
- `oracle`: (unchanged | old → new, reason)

**Unchanged:** code, agentic, wiring
```

5. Verify: YAML parses, every `@role` in agent frontmatter exists in `modelRoles`, `just test` passes.

## Constraints

- Only recommend models available on OpenRouter (the configured provider). Use `openrouter/`-prefixed selectors so bare vendor ids don't resolve to a native provider.
- For local models (Ollama), only note them as options — never wire them up.
- Don't remove the `default` role or the `task`/`advisor` aliases.
- Don't change the `oracle`'s user-gated wiring (no automatic paths) without explicit discussion.
- If benchmark data is unavailable or stale, say so rather than guessing.
