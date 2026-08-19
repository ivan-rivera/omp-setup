---
description: "Check for OMP updates and propose harness revisions"
---

Check for Oh-My-Pi updates and analyse what changes affect this harness.

## Steps

### 1. Check Current Version

Run `omp --version` to get the installed version. If `omp` is not in PATH, try `~/.bun/bin/omp --version`.

### 2. Fetch Latest Releases

```bash
gh api repos/can1357/oh-my-pi/releases --jq '.[0:5] | .[] | "v\(.tag_name) (\(.published_at[:10])): \(.name)"'
```

Compare the installed version against the latest release. If already current, report that and stop (unless the user wants a deeper review).

### 3. Analyse Changelog

For each new release between the installed version and latest, read the release body:

```bash
gh api repos/can1357/oh-my-pi/releases --jq '.[0].body'
```

Look for changes that affect this harness:

| Change Type | Impact | Example |
|-------------|--------|---------|
| New frontmatter fields | Agent/skill/rule definitions may benefit | `prewalk` field on agents |
| New built-in commands | Update `omp-tips.md` reference list | New `/collab` command |
| Config format changes | May need to update `config.yml` or `models.yml` | `modelRoles` syntax change |
| New provider support | Could add to `models.yml` | New API type added |
| New memory backends | Could change `memory.backend` setting | New backend option |
| Breaking changes | Must update before upgrading | Renamed config keys |
| New features | Inform the user, potentially update tips rule | Agent Hub improvements |

### 4. Propose Revisions

For each relevant change, propose a concrete action:

```
## Proposed Revisions

1. **[agents]** New `prewalk` field available — consider adding to `data-generator` agent for faster edits after planning.
   - File: `harness/agents/data-generator.md`
   - Change: Add `prewalk: true` to frontmatter

2. **[tips]** New `/collab` command added in v17.4.0 — add to omp-tips reference list.
   - File: `harness/rules/omp-tips.md`
   - Change: Add row to built-in commands table

3. **[config]** `modelRoles` now supports inline fallbacks — could simplify `retry.fallbackChains` in models.yml.
   - File: `harness/models.yml`
   - Change: Move fallback config into role definitions
```

Present all proposals and wait for approval. Accept partial approval.

### 5. Apply and Log

On approval:
1. Apply the approved revisions to harness files
2. Append a dated entry to `harness/update-log.md`:

```markdown
## YYYY-MM-DD — OMP vX.Y.Z → vA.B.C

- Updated `data-generator.md`: added `prewalk: true`
- Updated `omp-tips.md`: added `/collab` to built-in commands table
- Skipped: inline fallbacks migration (deferred)
```

3. If `update-log.md` doesn't exist, create it with a header

### 6. Optionally Upgrade OMP

Ask if the user wants to upgrade OMP itself:

```bash
bun install -g @oh-my-pi/pi-coding-agent
```

Only run on explicit approval. Report the new version after upgrade.

## Constraints

- Never auto-apply changes. Propose, explain, wait for approval.
- Never downgrade OMP.
- If the changelog mentions breaking changes, warn prominently before any upgrade.
- This command only works in the omp-setup repository (it reads harness files at relative paths).
