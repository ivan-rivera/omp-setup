---
name: herdr-orchestrator
description: "Orchestrate large tasks across multiple real OMP sessions in herdr tabs: the current tab becomes an overseer that spawns one tab per work unit, dispatches self-contained briefs, and keeps a bird's-eye view of every worker's state. Use when the user wants to orchestrate or parallelize work across multiple OMP instances or terminal tabs, asks for a tab per task, wants an overseer/controller session with a view over other agent sessions, or mentions herdr tabs/workspaces for agent work. Not for in-process subagent delegation — `task`/`/vibe` already cover that."
alwaysApply: false
---

# herdr orchestrator (overseer + worker OMP sessions)

This tab becomes the **overseer**: it plans the work, spawns one herdr tab per work unit, dispatches prompts to each worker OMP session, monitors their lifecycle, and integrates the results. Workers are real, interactive OMP sessions — the user can click into any tab and talk to a worker directly at any time. The overseer holds the bird's-eye view so the user doesn't have to.

herdr recognizes OMP natively (agent kind `omp`) and tracks per-agent lifecycle state. Every command below talks to the current herdr session over its socket — no TUI involved.

## 1. Gate: this only works inside herdr

```bash
test "${HERDR_ENV:-}" = 1
```

If the check fails, stop — never try to drive herdr from outside a herdr pane. Tell the user:

> This skill needs OMP running inside a herdr session, so it can create tabs and observe agent state. Your session auto-saves — exit OMP, run `herdr` in your terminal, start OMP inside a herdr tab with `omp -c` (continues this session), then ask me again.

When the check passes, herdr has injected the calling pane's context: `HERDR_WORKSPACE_ID`, `HERDR_TAB_ID`, `HERDR_PANE_ID`. Use these instead of guessing IDs.

## 2. One-time setup: OMP state integration

```bash
herdr integration status | grep '^omp:'
```

If it reports `not installed`, install once:

```bash
herdr integration install omp
```

This writes a small OMP extension (`~/.omp/agent/extensions/herdr-omp-agent-state.ts`) that reports OMP's lifecycle state to herdr, making `idle`/`working`/`blocked`/`done` accurate for OMP panes. It takes effect for OMP instances started after installation; already-running workers fall back to herdr's terminal-output detection.

## 3. Plan the fan-out

- Decompose the task into **self-contained units with disjoint file scopes** (split by files/directories, not just features — all workers share one working tree). If a unit can't be specified without live back-and-forth, keep it in the overseer.
- Size honestly: one tab per focused objective; 2–4 tabs when units are genuinely parallel. Each tab is a full OMP session with its own context and token burn — never fan out work one session should just do. A single tab is a fine outcome.
- Name workers: lowercase slug matching `[a-z][a-z0-9_-]{0,31}`, unique among live agents (e.g. `auth-api`, `ui-forms`, `docs-refresh`). Reuse the slug as the tab label so tabs and agents line up.

## 4. Spawn a worker tab

```bash
herdr tab create --workspace "$HERDR_WORKSPACE_ID" --cwd "$PWD" --label <slug> --no-focus
```

Parse the JSON response — tab id at `.result.tab.tab_id`, root pane id at `.result.root_pane.pane_id` (inspect the response if a path differs; never derive IDs from labels or order). Then start OMP in that pane:

```bash
herdr agent start <name> --kind omp --pane <pane-id>
```

`agent start` returns once herdr has detected OMP and considers it ready for input (default 30 s; raise with `--timeout` on slow machines). Record `name → tab_id` — you need the mapping for teardown. `--no-focus` keeps the user in this tab; workers run in the background of the same workspace.

## 5. Dispatch work

```bash
herdr agent prompt <name> "<brief>" --wait --timeout 900000
```

The brief must be fully self-contained — workers share nothing with this conversation:

```
Goal: <one sentence>
Scope: <files/dirs this worker owns — touch nothing else>
Context: <everything needed to start: repo layout, APIs, conventions, relevant paths>
Constraints: <boundaries, style rules, invariants>
Acceptance: <observable criteria — commands to run, expected output>
Report: reply with a concise summary; write anything longer to /tmp/<slug>-report.md and reply with the path
```

- `--wait` returns at the first settled `idle`/`done`/`blocked` observed after the turn starts working. 15–30 min (`900000`–`1800000`) suits code tasks; use `120000`–`300000` for questions.
- You can prompt several workers in a row and then wait on each — dispatch is not serialized per worker.
- If a worker is `blocked`, `agent prompt` rejects the input — resolve the block first (§7).

## 6. Monitor — bird's-eye view

```bash
herdr agent list                  # every live agent + state: the dashboard
herdr agent get <name>            # one agent's state and pane
herdr agent read <name> --source recent-unwrapped --lines 200   # its recent output
herdr agent wait <name> --timeout 900000                        # block on one worker
```

Poll `agent list` between your own work instead of busy-waiting. States:

| State | Meaning | Action |
|---|---|---|
| `working` | Mid-turn | Wait |
| `idle` / `done` | Settled, ready for input | Read result, verify (§8) |
| `blocked` | Approval/question dialog on screen | Read the pane, resolve or escalate (§7) |
| `unknown` | Present but unclassifiable | Inspect with `agent get` + `agent read` before acting |

A timeout does **not** mean the prompt wasn't delivered — inspect `agent read` before resubmitting anything.

## 7. Working alongside the user

- Workers' tabs are ordinary herdr tabs: the user can focus any of them and type to that OMP directly. That is a feature, not interference — but it means the overseer never assumes a worker is where it left it.
- Before prompting a worker, check `herdr agent get <name>` (and a short read) in case the user redirected it.
- Never steal focus: create tabs with `--no-focus`; if the user must look at a worker, say which tab label to open rather than focusing it for them.
- On `blocked`: `herdr agent read <name>` to see the dialog. Surface it to the user and let them answer in the tab, or answer yourself with `herdr agent send-keys <name> <key>` only when the user has delegated that approval. Never blind-approve.

## 8. Integrate and verify

When a worker settles: read its reply (`agent read`; follow the report-file path if given). Workers are agents — verify their claims in this session before declaring anything done: run the checks, read the diff. For gaps, prompt the worker with the specific gap (cheaper than redoing); fold only trivial integration fixes in yourself.

## 9. Teardown

When every unit is done and verified, summarize the results. Then ask the user before closing worker tabs:

```bash
herdr tab close <tab_id>
```

Close only the tabs this overseer created (your recorded `name → tab_id` map). Never close workspaces, tabs, or panes you didn't create.

## Shared state across workers

- All tabs share one working tree (workers spawn with `--cwd "$PWD"`). Disjoint file scopes prevent collisions; repo-state mutations (branch switches, commits) go through one place — normally the overseer, after workers settle.
- For durable cross-session notes and handoffs, write to the agents vault (`Agents/OMP/Projects/<Project>/`, see the agents-vault skill) — every worker can read the same notes.

## Hard rules

- Never run bare `herdr` — it launches the TUI.
- Never run `herdr server stop` or kill herdr processes from a session.
- Parse IDs from JSON responses; `jq` is available.
- CLI server errors are JSON on stderr with exit 1; syntax errors exit 2.
- Names must be unique among live agents; a name dies with its agent and is reusable after.
