---
name: model-scout
description: "Benchmark-driven model selection and rotation for the OMP harness. Use when the user wants to update model assignments, check which models are best for specific tasks, compare model performance, review pricing, or keep their model config on the bleeding edge. Also use when new models are released and the user wants to know if they should switch."
alwaysApply: false
---

# Model Scout

Keep the harness model config current with the best available models across task categories.

## How Models Are Configured

This harness uses a role-based model routing system:

- **`harness/models.yml`** — defines providers (OpenRouter, Ollama) and their connection details
- **`harness/config.yml`** under `modelRoles:` — maps role names to specific models
- **Agent frontmatter** — each agent references a role (e.g., `model: "@code-balanced"`)

Roles follow a `{domain}-{tier}` convention:
- **Domains**: `code`, `reason`, `content`, `research`, `orch` (orchestration)
- **Tiers**: `best` (max quality), `balanced` (default, cost/quality optimised), `fast` (speed/throughput), `free` (zero cost)
- **Cross-cutting**: `advisor`, `fast`, `local`, `default`

## Process

### 1. Gather Benchmark Data

Fetch current model data from OpenRouter:

```bash
curl -s https://openrouter.ai/api/v1/models \
  -H "Authorization: Bearer $OPENROUTER_API_KEY" | head -c 50000
```

The response includes per-model: `id`, `pricing`, `context_length`, `top_provider`, and benchmark scores.

Also check these sources if available:
- Chatbot Arena / LMSYS leaderboard (for head-to-head rankings)
- Artificial Analysis (for throughput and latency benchmarks)
- Provider-specific benchmarks (Anthropic, OpenAI, Google evals)

### 2. Map Benchmark Categories to Roles

| Benchmark Category | Harness Roles | Agents |
|--------------------|---------------|--------|
| Code generation (HumanEval, SWE-bench, etc.) | `code-*` | frontend, backend, qa |
| Reasoning (GPQA, MATH, ARC-AGI, etc.) | `reason-*` | architect, security, legal, finance |
| Research / information retrieval | `research-*` | researcher |
| Creative writing / content | `content-*` | content-writer |
| Data extraction / instruction following | `fast`, `orch-*` | data-generator, orchestration |

### 3. Recommend Models Per Tier

For each domain, recommend the best model at each tier:

| Tier | Selection Criteria |
|------|-------------------|
| `best` | Highest benchmark score, cost secondary |
| `balanced` | Best score-per-dollar ratio |
| `fast` | Lowest latency and highest throughput, acceptable quality |
| `free` | Free-tier models on OpenRouter with acceptable quality |

Present recommendations as a comparison table:

```
| Role             | Current Model              | Recommended Model          | Benchmark Delta | Cost Delta |
|------------------|---------------------------|---------------------------|-----------------|------------|
| code-balanced    | anthropic/claude-sonnet-4  | anthropic/claude-sonnet-4  | (no change)     | —          |
| reason-best      | anthropic/claude-opus-4    | anthropic/claude-opus-4.1  | +3% GPQA        | +$2/1M     |
```

### 4. Present Diff and Get Approval

Show the user:
1. A table of proposed changes (current → recommended, with benchmark and cost deltas)
2. Total estimated monthly cost impact (if they provide usage patterns)
3. Any models that are new releases worth noting

**Never auto-apply changes.** Wait for explicit approval.

### 5. Apply Changes

On approval:

1. Update `modelRoles` in `harness/config.yml` with new model assignments
2. Append a dated entry to `harness/models-changelog.md`:

```markdown
## YYYY-MM-DD

- `code-balanced`: anthropic/claude-sonnet-4 → new/model-name (benchmark: +X% on HumanEval)
- `reason-best`: anthropic/claude-opus-4 → anthropic/claude-opus-4.1 (new release, +3% GPQA)

**Unchanged:** code-fast, reason-balanced, content-balanced, research-balanced
```

3. If `models-changelog.md` doesn't exist, create it with a header

## Constraints

- Only recommend models available on OpenRouter (the configured provider)
- For the `local` tier, only recommend models available via Ollama — but don't wire them up, just note them as options
- Don't change the `advisor` role without explicit discussion — it's intentionally a different model family for independent oversight
- Don't remove the `default` fallback role
- If benchmark data is unavailable or stale, say so rather than guessing
