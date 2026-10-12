# GitHub Action — event-driven OCR on every PR

When the user wants OCR to run automatically on PRs (independent of any agent session), posting inline review comments. Complements the local skill: local review = pre-ship self-critique gate; CI review = independent verification after push, re-running on every new commit.

## Setup (per repo)

1. Create a **scoped OpenRouter key** (openrouter.ai/settings/keys) with a spend limit for CI use. Never store the main OMP/OpenRouter key in repo secrets.
2. Repo secrets (Settings → Secrets and variables → Actions):
   - `OCR_LLM_URL` = `https://openrouter.ai/api/v1/chat/completions`
   - `OCR_LLM_AUTH_TOKEN` = the scoped OpenRouter key
   - `OCR_LLM_MODEL` = e.g. `z-ai/glm-5.3`
3. Install the workflow:

```bash
mkdir -p .github/workflows
curl -o .github/workflows/ocr-review.yml \
  https://raw.githubusercontent.com/alibaba/open-code-review/main/examples/github_actions/ocr-review.yml
```

4. Recommended edits:
   - Trigger on `synchronize` too, so every pushed commit gets re-reviewed — that closes the loop with the agent.
   - Keep the `/open-code-review` comment trigger for on-demand reruns.
   - Pin the CLI version for reproducibility: `npm install -g @alibaba-group/open-code-review@<version>`.
   - The workflow disables thinking mode via `llm.extra_body`; remove that line if the critic model needs thinking.

## Notes

- The workflow writes the legacy `llm.*` config block (`ocr config set llm.url / llm.auth_token / llm.model`) — not the provider system — so the secrets map directly. `OCR_LLM_AUTH_TOKEN` here is a CI secret name; OCR's own env var is `OCR_LLM_TOKEN`.
- `pull_request_target` is used so secrets are available on fork PRs; OCR only reads the diff and does not execute PR code.
- Findings post as inline PR review comments; entries without line info fold into a summary comment.
- Reusable composite action: `uses: alibaba/open-code-review@main` with inputs like `effort`, `max_tokens_budget`, `llm_reasoning_effort` (works for GLM-5.x reasoning steering), `stream_progress`.
- Loop back into the harness: after OCR comments on a PR, read them via `gh api repos/{owner}/{repo}/pulls/{number}/comments` (or the `pr://<N>` internal URL) and address findings in the next commit.

Full input list and posting modes: upstream CI doc at
`https://github.com/alibaba/open-code-review/blob/main/pages/src/content/docs/en/integrations/ci.md`
