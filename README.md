# OMP Harness

Personal Oh-My-Pi harness for a solo full-stack developer. Version-controlled agent configs, skills, rules, and model routing — symlinked to `~/.omp/agent/`.

## Prerequisites

- [just](https://github.com/casey/just) — `brew install just`
- [bun](https://bun.sh) >= 1.3.14 — installed automatically by `just install-deps`
- [node](https://nodejs.org) 22+ — for npx-based MCP servers and the Hyperframes CLI (`npx hyperframes`)
- [FFmpeg](https://ffmpeg.org) — `brew install ffmpeg`; encodes `/skill:brag` videos (also installed by `just install-deps`)
- [gh](https://cli.github.com) — GitHub CLI (used directly, no MCP)
- [git](https://git-scm.com) >= 2.41 — required by OCR for diff generation
- [uv](https://docs.astral.sh/uv/) — Python manager for PPT Master (auto-installed by brew when needed)

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
| `just install` | Install deps, OMP, plugins, OCR, PPT Master, brag skills |
| `just install-plugins` | Register the impeccable marketplace, install the design skill plugin |
| `just update-impeccable` | Pull the latest impeccable skill version from upstream |
| `just install-ocr` | Install/update the `ocr` CLI, pin its OpenRouter config |
| `just install-ppt-master` | Install/update the PPT Master slide-generation skill (vendor clone, uv venv, Python deps) |
| `just install-brag` | Install/update the brag + brag-slim launch-video skills from [latent-spaces/brag](https://github.com/latent-spaces/brag) into gitignored `harness/skills/` |
| `just link` | Symlink harness to ~/.omp/agent/ |
| `just unlink` | Remove symlink, optionally restore backup |
| `just status` | Show symlink, OMP version, env vars |
| `just test` | Verify harness structure and config |
| `just check-env` | Verify required env vars |
| `just help` | List all targets |

## What's Included

- **10 agents**: frontend, backend, architect, security, qa, legal, finance, researcher, content-writer, data-generator
- **7 skills** (+ 2 optional launch-video skills fetched from upstream): brainstorming, frontend-design, model-scout, skill-creator, extension-creator, ocr-review, ppt-master (upstream [PPT Master](https://github.com/hugohe3/ppt-master), vendored); brag + brag-slim via `just install-brag`
- **2 commands**: `/intro` (harness orientation), `/onboard` (repo setup)
- **4 rules**: python-style, typescript-style, pr-size-limit, omp-tips
- **Model routing**: 5 domains x 4 tiers via OpenRouter, Ollama placeholder
- **Memory**: mnemopi (local SQLite)
- **MCPs**: Context7, Tavily
- **OCR code review (manual-only)**: `ocr` CLI (npm, OpenRouter-backed) — `/skill:ocr-review` or plain "review this" language runs it on explicit request; no hooks/automation by design
- **Impeccable design skill**: installed as an OMP marketplace plugin from [pbakaus/impeccable](https://github.com/pbakaus/impeccable) (Apache-2.0, © Paul Bakaus) — no vendored copies in this repo. `/skill:impeccable <command> <target>` exposes its 24 design commands (`init`, `shape`, `critique`, `audit`, `polish`, `bolder`, `animate`, `live`, ...). Per-project state (`PRODUCT.md`, `DESIGN.md`, `.impeccable/`) lives in each app repo. Loaded via the `claude-plugins` provider (re-enabled in `config.yml`; Claude Code's own `~/.claude` registry stays opt-in-gated).
- **Impeccable design detector hook**: `harness/hooks/post/impeccable-design.ts` — after every `edit`/`write` on a UI file inside an Impeccable project, runs the plugin's engine and injects findings as model context (per-edit pass; 5s budget). Disable per project with `hook.enabled: false` in `.impeccable/config.json`, or globally with `IMPECCABLE_HOOK_DISABLED`.
- **Launch videos**: `/skill:brag` (full, Hyperframes-rendered) and `/skill:brag-slim` (local tools) — **not vendored**; fetched from [latent-spaces/brag](https://github.com/latent-spaces/brag) via `just install-brag` (included in `just install`). Update = rerun the same target; optionally pin a ref: `just install-brag v0.4.0`

## PPT Master (slide generation)

`/skill:ppt-master` in any OMP session turns a topic, PDF, DOCX, or pasted text into a natively
editable `.pptx` (real shapes, charts, tables, speaker notes). Projects and exports land in the
vendored clone under `vendor/ppt-master/projects/<name>/` — its scripts anchor to their repo root.
Its machine state — the vendored clone (`vendor/ppt-master`), a dedicated uv venv
(`~/.local/share/ppt-master/venv`), and a `python3` wrapper (`~/.local/bin/python3`) — is
installed by `just install-ppt-master` and excluded from git. The skill ships an integrity gate
(attribution guard), so it must stay unmodified; update by rerunning the target.

- **Model**: upstream recommends large-context models (Kimi K3 / Claude); the default OpenRouter
  model works with a quality gap — `/model` before long decks.
- **Images**: zero-config web image search works out of the box. For AI generation, reuse your
  existing `OPENROUTER_API_KEY` via `~/.ppt-master/.env` with `IMAGE_BACKEND=openrouter` and
  `OPENROUTER_MODEL=google/gemini-nano-banana-2.1`. Optional free `PEXELS_API_KEY` /
  `PIXABAY_API_KEY` improve web-search image quality.
- **License**: the skill is MIT (Hugo He), vendored unmodified; the optional PyMuPDF dependency
  is AGPL-3.0 (PDF sources only — relevant only if you redistribute a bundle that includes it).

## Updating

From within this repo, run `/update` in OMP to check for new OMP releases and propose harness revisions.

To update model assignments based on benchmarks, run `/skill:model-scout` in any OMP session.

To pull the latest impeccable skill from upstream: `just update-impeccable` (or `omp plugin marketplace update impeccable && omp plugin upgrade impeccable@impeccable` — same flow as `/marketplace update` + `/marketplace upgrade` in a session).

