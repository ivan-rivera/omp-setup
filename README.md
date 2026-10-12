# OMP Harness

Personal Oh-My-Pi harness for a solo full-stack developer. Version-controlled agent configs, skills, rules, and model routing — symlinked to `~/.omp/agent/`.

## Prerequisites

- [just](https://github.com/casey/just) — `brew install just`
- [bun](https://bun.sh) >= 1.3.14 — installed automatically by `just install-deps`
- [node](https://nodejs.org) — for npx-based MCP servers
- [gh](https://cli.github.com) — GitHub CLI (used directly, no MCP)
- [git](https://git-scm.com) >= 2.41 — required by OCR for diff generation

## Setup

```bash
git clone git@github.com:ivan-rivera/omp-setup.git
cd omp-setup
just setup
```

This installs dependencies, OMP, and the OCR code-review CLI, and symlinks `harness/` to `~/.omp/agent/`.

OCR is pinned to the OpenRouter provider (`z-ai/glm-5.3` by default — override per machine with the `OCR_MODEL` env var) and reads its key from `OPENROUTER_API_KEY`; no secret is stored in `~/.opencodereview/config.json`.

## Environment Variables

Set these in your shell profile (`~/.zshrc` or `~/.bashrc`):

| Variable | Purpose |
|----------|---------|
| `OPENROUTER_API_KEY` | LLM provider + OCR code review (required) |
| `TAVILY_API_KEY` | Web research MCP (required) |

Check with `just check-env`.

## Justfile Targets

| Target | Purpose |
|--------|---------|
| `just setup` | Full install + symlink |
| `just install` | Install deps, OMP, plugins, OCR |
| `just install-ocr` | Install/update the `ocr` CLI, pin its OpenRouter config |
| `just link` | Symlink harness to ~/.omp/agent/ |
| `just unlink` | Remove symlink, optionally restore backup |
| `just status` | Show symlink, OMP version, env vars |
| `just test` | Verify harness structure and config |
| `just check-env` | Verify required env vars |
| `just help` | List all targets |

## What's Included

- **10 agents**: frontend, backend, architect, security, qa, legal, finance, researcher, content-writer, data-generator
- **6 skills**: brainstorming, frontend-design, model-scout, skill-creator, extension-creator, ocr-review
- **2 commands**: `/intro` (harness orientation), `/onboard` (repo setup)
- **4 rules**: python-style, typescript-style, pr-size-limit, omp-tips
- **Model routing**: 5 domains x 4 tiers via OpenRouter, Ollama placeholder
- **Memory**: mnemopi (local SQLite)
- **MCPs**: Context7, Tavily
- **OCR code-review gate**: `ocr` CLI (npm, OpenRouter-backed) — `/skill:ocr-review` reviews diffs/commits/branches before a PR ships

## Updating

From within this repo, run `/update` in OMP to check for new OMP releases and propose harness revisions.

To update model assignments based on benchmarks, run `/skill:model-scout` in any OMP session.
