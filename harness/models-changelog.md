# Models Changelog

## 2026-11-02 — Qwen3.8 Flash added (agentic role + fallback chains)

Qwen3.8 Flash (Alibaba, Aug 26 2026; 125B MoE/~6B act., multimodal text+image+video in, 1M ctx, $0.15/$0.47 per 1M, single OpenRouter provider: Alibaba Cloud Int'l) added to the lineup after a model-scout review. Hermes default and OMP default/code stay GLM 5.3 (faster 109 vs 59 tok/s, measured AA indices, 37 providers vs 1).

- `agentic`: openrouter/z-ai/glm-5.3 -> openrouter/qwen/qwen3.8-flash — role is now differentiated; Qwen Flash is agentic-specialized (DeepSWE 1.1 58.7, SWE-bench Pro 62.5, Agents' Last Exam score 51.2) with 3x cheaper output for the token-heavy agentic loop. `task`/`sonic` inherit via `@agentic`.
- `retry.fallbackChains` (@default/@code/@agentic): openrouter/qwen/qwen3.8-flash inserted as first fallback, ahead of gemini-3.8-flash ($0.75/$3.75 — Qwen is 5x cheaper in / 8x cheaper out). Oracle/advisor chains untouched.
- Confidence: fallbacks High; agentic role Medium (self-reported Qwen benchmarks, no AA Agentic Index yet as of 2026-11-02).
- Unchanged: default/code (GLM 5.3), oracle (claude-opus-5.5), advisor chain (gpt-5.6-sol), providers, cycleOrder.
- Related (Hermes side, same review): Hermes `local` alias repointed from retired mlx-lm :8080 setup to Splash :8000 (ajgazin/Qwen3.8-27B-Heretic-unsloth-GGUF:UD_Q5_K_M); Hermes default remains z-ai/glm-5.3.

## 2026-10-10 — Simplified to a 4-role lineup

Architecture: `default` (general-purpose) / `code` (code generation) / `agentic` (task execution) / `oracle` (user-approved top-tier consult). All three working models set to GLM 5.3 per owner decision.

- `default`: z-ai/glm-5.3 -> openrouter/z-ai/glm-5.3 (same model, unambiguous provider-prefixed selector)
- `code`: google/gemini-3.7-flash -> openrouter/z-ai/glm-5.3
- `agentic` (new role): openrouter/z-ai/glm-5.3; `task` role aliased to `@agentic`; bundled `task`/`sonic` agents routed via `task.agentModelOverrides`
- `oracle` (new role): openrouter/anthropic/claude-opus-5.5 — AA Intelligence #2 (57.6), LMArena Text #2 (1507), LMArena Agent #1 (14.3), WebDev #1 (1813); different family from the working lineup for independent perspective
- `advisor`: z-ai/glm-5.3 -> `@oracle` — advisor subsystem stays user-gated (`/advisor on`); removed `advisor: true` from architect/legal/security frontmatter so spawns never auto-consult the oracle
- Removed 13 legacy tier roles (code-cheap/optimal, reason-cheap/optimal, content-cheap/optimal, research-cheap/optimal, super-cheap, cheap) and their domain-default aliases
- `cycleOrder`: [super-cheap, cheap, default] -> [default, oracle] (Ctrl+P toggles to the oracle manually)
- `retry.fallbackChains`: @default/@code/@agentic -> [gemini-3.8-flash, deepseek-v4.1-flash] (flash-class peers; oracle excluded from automatic chains); advisor -> [gpt-5.6-sol]
- Bug fix: agent frontmatter referenced undefined roles (@reason-best, @code-balanced, @reason-balanced, @content-balanced, @research-balanced, @fast) — every agent was silently inheriting `default`. Rewired: frontend/backend/qa -> @code; data-generator -> @agentic; architect/content-writer/finance/legal/researcher/security -> @default.
- model-scout SKILL.md rewritten for the 4-role architecture

**Unchanged:** providers (models.yml), memory backend (mnemopi), disabledProviders, tools approval.
