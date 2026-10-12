---
name: ocr-review
description: "Independent AI code review via the `ocr` CLI (Alibaba open-code-review, already installed and configured with OpenRouter). Manual-only: run when the user explicitly asks — via /skill:ocr-review, or natural language like 'review this diff/PR/branch', 'run OCR', 'critique or self-review my changes', or 'find bugs/security/performance issues in a diff, commit, or branch'. Never self-trigger at PR/push/ship time and never wrap it in hooks or automation — runs occasionally hang. Not for optical character recognition (scanning documents or images)."
alwaysApply: false
---

# OCR — On-Demand Independent Review

`ocr` (npm: `@alibaba-group/open-code-review`) reviews Git diffs with a deterministic pipeline (file selection, bundling, rule matching) plus a tool-using LLM agent — different signal from reviewing the code yourself, which is the point: it's an external critic for the self-critique loop.

Already set up on this machine: provider `openrouter`, model `z-ai/glm-5.3`, key picked up from `OPENROUTER_API_KEY` in the shell env. Config lives at `~/.opencodereview/config.json` (no secret stored there). Do not reconfigure unless the user asks.

## When to run

Manual-only, by design: no hook or automation fires it, because OCR runs occasionally hang. Run it only when the user explicitly asks — `/skill:ocr-review`, 'review this diff/PR/branch', 'run OCR', 'critique my changes' — and never on your own just because work is about to ship; suggest it instead.

- **Review with fix intent** — run the loop protocol below on the staged/committed change, fix real findings, re-review, then ship.
- **Review without fix intent** — report only, ask before touching code.
- Not OCR's job: optical character recognition on documents/images.

## Loop protocol (review with fix intent)

1. Determine the base ref (`main` by default; the PR's base branch if known). Skim the change and write 1–2 sentences of business context (what + why) — passing it via `--background` measurably improves review quality.
2. Run the review (see Command patterns).
3. Read the JSON output file in full, triage (below), fix every real critical/high/medium finding.
4. Re-run the review on the updated diff. Stop when no critical/high/medium findings remain (low is optional).
5. Add a short "Self-review (OCR)" note to the PR description: rounds run, findings fixed, findings judged false positives (with reasoning).

Guardrail: at most 3 rounds. Ping-ponging with the critic past that means a design disagreement — surface the remaining findings to the user instead of looping.

## Command patterns

Always `--audience agent` (suppresses the progress UI) and `--output <file>` (large reviews overflow stdout; never pipe OCR output through `head`/`tail` — it drops earlier comments). Use `--format json` for parsing; `--format text` only when the user wants the human rendering. Run from the repo root, or pass `--repo <path>`.

| Situation | Command |
|---|---|
| PR / branch ready to ship | `ocr review --from <base> --to HEAD --format json --output /tmp/ocr_out.json --audience agent -b "<context>"` |
| Working copy (staged + unstaged + untracked) | `ocr review --format json --output /tmp/ocr_out.json --audience agent -b "<context>"` |
| Single commit | add `--commit <sha>` instead of `--from/--to` |
| Whole files, no diff (unfamiliar codebase audit) | `ocr scan --path <dir>` |
| Dry-run: which files get reviewed | `ocr review --preview` |
| Different critic model for this run | add `--model <openrouter-id>` (critic diversity) |

## Triage

Each comment: `path`, `content`, `start_line`/`end_line` (both `0` = positioning failed — locate the real spot manually from the comment content), `category` (bug / security / performance / maintainability / test / style / documentation / other), `severity` (critical / high / medium / low), optional `suggestion_code`, `existing_code`.

- **Fix**: critical/high/medium — bugs, security, real performance issues, broken contracts.
- **Fix if trivial and safe**: low-severity items with concrete `suggestion_code`.
- **Report, don't fix**: style/doc nits, debatable design preferences, suspected false positives. Verify a finding against the code before acting on it — and never make a finding disappear by suppressing it; either fix the code or justify why it's not real.

Report findings grouped by severity: `path:line [category] — description > fix`.

## Cost & behavior knobs

- `--effort low|medium|high` — review depth; default medium (2 review rounds; `--timeout` scales with it).
- `--max-tokens-budget <n>` — cap total tokens for the run; over-budget groups finish their current round and report partial results.
- `--concurrency <n>` — default 8 file workers; lower it if OpenRouter rate-limits.
- `--timeout <minutes>` — per-review-group budget (default 15). Per-request HTTP timeout via `OCR_LLM_TIMEOUT` (seconds, default 300).
- Interrupted range/commit review: `ocr session list`, rerun with `--resume <id>`.
- `--exclude '<gitignore-patterns>'` — skip generated/testdata paths.

## Project rules

Optional per-repo conventions: `<repo>/.opencodereview/rule.json` (a matched user rule replaces built-in defaults; `merge_system_rule: true` keeps both). Preview what applies: `ocr rules check <file>`. Use it for house rules like "all new endpoints validate input schemas" or "no new HTTP clients in handlers".

## Alternatives

- `ocr delegate` — OCR does file selection + rule resolution, and this harness's own model performs the review; no OCR LLM needed. Weaker for self-critique (author model = reviewer model); useful when the key is unavailable.
- Event-driven CI review (posts inline comments on every PR, re-runs on each push): read `references/github-action.md` — requires the OpenRouter key as a repo secret, so use a scoped key.

## Troubleshooting

- `ocr: command not found` → `just install-ocr` from the omp-setup repo (or `npm i -g @alibaba-group/open-code-review`)
- LLM errors → `ocr llm test` (expect `provider:openrouter`, `z-ai/glm-5.3`). The key comes from `OPENROUTER_API_KEY` (set in `~/.zshrc`); if a non-interactive shell lacks it, export it before running.
- `unknown flag: --output` → CLI older than v1.10: `npm i -g @alibaba-group/open-code-review@latest`, then rerun.
- Verify success: exit code 0 and the output file parses as JSON; stderr carries per-file failure warnings.
