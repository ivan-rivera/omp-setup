---
description: "Merge all open PRs sequentially — review, order, resolve conflicts, verify, then update main and the live harness"
---

Merge this repository's open PRs one at a time, resolving every conflict along the way, then bring `main` and the live harness up to date. `$ARGUMENTS` optionally lists specific PR numbers; empty means all open PRs.

## Non-negotiables

- Never force-push `main`; never push a merge you have not verified.
- The main checkout's `harness/` is symlinked to `~/.omp/agent/` and is **live** — never switch it off `main` mid-run. Do all conflict resolution in a git worktree (`git worktree add ~/.omp/wt/<slug> <branch>`; reuse an existing worktree for the branch if it is clean and current).
- Resolve conflicts as the **union** of both intents when both are wanted, or keep the side that reflects current reality when the other is stale — the PR descriptions usually say which. Never invent third content; never resolve by "take mine".
- Merge commits only, no rebase/squash: this repo's history is merge commits and PRs may carry merge-coordination comments that rebase would orphan.

## 1. Inventory and review

1. List open PRs: `pr://?state=open&limit=50` (or `gh pr list`).
2. Read every PR in full (`pr://<N>`): purpose, files, verification, and especially any **merge-dependency notes** — suggested order, union tables, known-stale references. They are instructions from the author; follow them.
3. `git fetch origin`; note how far local `main` trails.

## 2. Order the merges

- Dry-run every PR against **current** `origin/main`:
  `git merge-tree --write-tree --name-only origin/main origin/<head>` — exit 0 = clean, 1 = conflicts.
- For sibling PRs touching the same files: clean ones first; land wholesale rewrites (e.g. a README sync / drift-check PR) **last** so its final state reflects everything else.
- Announce the order with one line of justification per PR.

## 3. Merge loop

Repeat per PR; **re-dry-run at the top of every iteration** — `main` moves after each merge and yesterday's conflict can be today's clean merge.

**Clean PR:**

```bash
gh pr merge <N> --merge --subject "Merge pull request #<N> from <owner>/<head>"
```

If GitHub reports conflicts on a merge you know is clean right after a push, its async mergeability check is lagging: wait ~5s, check `gh pr view <N> --json mergeable`, retry once.

**Conflicting PR:** resolve on the branch, then merge.

1. In the worktree: `git merge origin/main` (not rebase).
2. Resolve each conflict per the union rule. Where a PR's notes name things that have since been renamed or moved, reconcile to the **current tree**, not the note's snapshot.
3. Verify hermetically — against the branch's harness, never the live one:

   ```bash
   TMP=$(mktemp -d)
   mkdir -p "$TMP/.omp" "$TMP/.local/bin"
   ln -s <worktree>/harness "$TMP/.omp/agent"
   ln -s "$HOME/.omp/plugins" "$TMP/.omp/plugins"
   ln -s "$HOME/.local/bin/python3" "$TMP/.local/bin/python3"
   ln -s <main-checkout>/vendor <worktree>/vendor   # tracked ppt-master skill symlink resolves into gitignored vendor/
   for s in brag brag-slim composio-cli; do
     [ -e <worktree>/harness/skills/$s ] || \
       ln -s <main-checkout>/harness/skills/$s <worktree>/harness/skills/$s
   done
   (cd <worktree> && HOME="$TMP" just test) && rm -rf "$TMP"
   ```

   Gitignored fetched skills (brag, brag-slim, composio-cli) are absent from fresh worktrees — symlink them from the main checkout.
   The vendor/skill symlinks are throwaway scaffolding: dir-anchored ignore patterns don't cover symlinks, so `git add -A` would commit them. Stage only the files you resolved.
4. Commit with a message stating the resolution, push the branch, then `gh pr merge <N> --merge` (same async-check caveat).
5. `git fetch origin` before the next PR.

`just test` failing after resolution → stop and re-examine; escalate if the fix is not obvious.

## 4. Update main and the live harness

1. Reconcile dirty files in the main checkout against `origin/main`: a locally-modified live file (e.g. `config.yml`, `mcp.json`) that is semantically identical to main's new version — key order aside — can be discarded; anything meaningfully different goes to the user first.
2. `git pull --ff-only`; the working tree must end clean.
3. `just test` (live, real HOME) must pass. Run `just status`; if a PR changed an install target, rerun that target (`just install-<x>`). `just setup` is for from-scratch machines, not updates.
4. Machine-side state (containers, launchd agents, credentials) is not in git — check the merged PRs' notes for steps like `just hindsight-up` or `composio login` and run what applies.

## 5. Report

One line per PR: number, title, how it merged (clean, or conflicts resolved + what the union kept). Then the harness-update result and the live `just test` verdict.

## Escalate to the user when

- A conflict's correct resolution is genuinely ambiguous — competing intents, no guidance in any PR description.
- `just test` still fails after a reasoned resolution.
- A PR is draft, blocked, or its description contradicts its diff.
- Anything destructive: deleting branches, rewriting history, discarding local work that is not provably redundant.
- The set cannot be ordered safely (circular or mutually stale dependency notes).
