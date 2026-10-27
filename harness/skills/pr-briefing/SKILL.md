---
name: pr-briefing
description: "Explain a pull request as a briefing for a human: ELI5 summary, key changes with practical implications, gotchas and confusion points, anchored to code lines and chunks. Use whenever the user asks to open, create, release, ship, or put up a PR — once the PR exists, close that turn with its briefing. Also use on demand for any PR, theirs or someone else's: 'brief me on PR #12', 'explain/summarize this PR', a pasted GitHub PR URL, owner/repo#N, or /skill:pr-briefing. Explainer, not critique — /skill:ocr-review handles reviews."
alwaysApply: false
---

# PR briefing — an explainer, not a review

Produce a briefing that lets a human understand a PR without reading the diff: what it does in plain language, what actually changed and why it matters, where the tricky bits are, and the exact code to look at. The reader hasn't followed the work — sometimes it's the author's own PR (fresh eyes on their own change), sometimes someone else's PR in a repo you've never opened.

This is deliberately not a review: no verdicts, no style opinions, no fix suggestions. `/skill:ocr-review` is the critic; this is the guide.

## When to run

1. **PR release** — the user asked to open, create, release, or ship a PR: do that task first, then close the same turn with the briefing for the new PR. If the user announces they just opened or pushed a PR themselves, brief that one too.
2. **On demand** — any PR, any repo, any author: `/skill:pr-briefing <ref>`, `/briefing <ref>`, "brief/explain/summarize PR …", a pasted PR URL, or `owner/repo#N`.

The protocol is identical in both cases; only the source of the PR ref differs.

## Resolve the target PR

| Input | Target |
|---|---|
| This session just created a PR | That PR — number/URL from the `gh pr create` output |
| `N` | PR N in the current repo |
| URL or `owner/repo#N` | That repo's PR |
| Branch name, "mine", "current" | `gh pr view <branch> --json number,url` → number |
| Nothing resolvable | Ask which PR |

## Gather

Work from primary sources — the briefing is only as good as what you actually read:

1. `read pr://<N>` — title, state, author, base ← head, body. The body usually carries the what/why; mine it before touching code.
2. `read pr://<N>/diff` — per-file index with sizes; use it to plan how deep to go.
3. `read pr://<N>/diff/<i>` for each file worth reading, or `pr://<N>/diff/all` when the PR is small. Cross-repo: `pr://<owner>/<repo>/<N>/...`.
4. When hunks alone don't explain a change, read the surrounding file at those lines (callers, config, sibling code paths) — the diff shows what changed, not what it means.
5. Follow linked issues (`read issue://<N>`) and any PRs the body references.

For a PR you just built in this session, session context supplies the why — but verify every citation against the actual diff. If `pr://` doesn't resolve (permissions, enterprise host), fall back to `gh pr view <ref> --json number,title,body,baseRefName,headRefName,author,additions,deletions` and `gh pr diff <ref>`.

## Write the briefing

```markdown
# PR briefing — <repo>#<N>: <title>

<state · author · base ← head · N files, +A −D>

## ELI5

## Key changes

## Gotchas & head-scratchers

## Code anchors
```

**ELI5** — 2–4 sentences, plain language, user-visible outcome first. Expand or avoid domain jargon; an analogy only if it genuinely earns its place. Write for someone who has never seen this codebase. This section never grows with PR size.

**Key changes** — bullets grouped by theme, not by file. Each bullet: what changed (cite `path:start-end`) → the practical implication — what's different for whoever uses, runs, or extends this code (behavior, UX, performance, compatibility, ops). The implication is the point; a bullet that only restates the diff adds nothing.

**Gotchas & head-scratchers** — the section readers come for. Anything a human might trip on:

- non-obvious behavior and edge cases; things that look wrong but are intentional (and vice versa)
- implicit assumptions, ordering/rollout constraints, breaking changes, migration steps
- misleading names, magic values, config/env dependencies, security- or perf-relevant behavior
- TODOs, dead code, or half-finished edges the PR leaves behind

Each item: what it is → why it trips a reader → `path:line` → where to go next (code to read, linked issue, doc, or a question worth asking the author). If you find nothing real, say "None spotted" — a fabricated gotcha costs more trust than an empty section.

**Code anchors** — 2–4 verbatim chunks from the new side of the diff, ≤5 lines each, each with `path:start-end` and one line on why it matters. Only the load-bearing spots; the diff index is already the full map.

### Shape (condensed real example — omp-setup#8)

```markdown
# PR briefing — omp-setup#8: Add herdr-orchestrator skill

MERGED · @ivan-rivera · main ← feat/herdr-orchestrator-skill · 4 files, +176 −3

## ELI5
Adds a playbook that turns this OMP tab into a controller: it opens one herdr tab per chunk of
work, sends each worker its instructions, watches their status, and checks the results — so
several agent tasks run in parallel without babysitting each terminal.

## Key changes
- **New skill** — `harness/skills/herdr-orchestrator/SKILL.md:1-132`: the overseer workflow
  (gate, tab spawn, dispatch, monitor, teardown) → `/skill:herdr-orchestrator` and natural
  language like "orchestrate this across tabs" now trigger it in any session.
- **Install wiring** — `justfile:18-19,294+`: `install-herdr` recipe chained into `just install`;
  `just test` fails if the skill file goes missing.
…
```

### Scale to the PR

- Small (≤ ~10 files): every file gets its due.
- Large: group the file index into areas, name each theme, deep-dive only the areas that carry the behavior, and say what you collapsed ("38 files in 5 areas; the 2 that carry the behavior below").

### Honesty rules

- Every path, line number, and quote must come from the diff or files you actually read — never reconstruct a line from memory.
- Cite post-change line numbers (the new-file side of hunks).
- A suspected bug is a gotcha phrased as "may surprise: …" plus a pointer to `/skill:ocr-review` — not a verdict.
- Briefing length tracks PR size; a one-file PR gets a tight page, not padding.

## Deliver

Present the briefing in chat. If the user wants it on the PR itself, post it with `gh pr comment <N> --body-file <tmpfile>` — ask first.
