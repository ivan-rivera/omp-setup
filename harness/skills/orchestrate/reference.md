# orchestrate — reference

Companion to the orchestrate **SKILL.md**. Every role (origin agent, goal controller, milestone lead, worker, verifier) reads the SKILL.md for flow and this file for exact schemas, templates, and procedures. Names, paths, status values, and event types are normative — never invent variants.

## Ledger schema

Lives at `.orchestrate/<goal-slug>/` in the project repo (gitignored). Workers run in worktrees outside the main tree, so every brief states the ledger's **absolute path**.

```
.orchestrate/<goal-slug>/
├── goal.md            charter: objective, scope, non-goals, constraints, acceptance, formula, links
├── ledger.json        machine state (schema below)
├── events.jsonl       append-only event log, one JSON object per line
├── heartbeats.jsonl   patrol snapshots: {"ts": "...", "agents": {"<name>": "<state>", ...}}
├── briefs/            <task-id>.md — the exact dispatched briefs (resume compares brief_sha)
├── reports/           worker reports, verifier verdicts, final report.md
└── STOP               (optional) presence halts the health patrol loop
```

### ledger.json

```json
{
  "goal": {
    "slug": "<goal-slug>",
    "title": "<goal title>",
    "description": "<one-line objective>",
    "repo": "<absolute path to the project repo>",
    "status": "active",
    "created": "<ISO-8601>",
    "started": "<ISO-8601>",
    "completed": "<ISO-8601 or null>",
    "formula": "<path or 'default'>",
    "session": {
      "name": "<goal-slug>",
      "socket": "~/.config/herdr/sessions/<goal>/herdr.sock",
      "warp_tab_config": "~/.warp/tab_configs/orch_<goal>.toml"
    }
  },
  "milestones": [
    {
      "id": "m1",
      "label": "[m1] <milestone title>",
      "title": "<milestone title>",
      "status": "active",
      "workspace_id": "<herdr workspace id>",
      "lead": {
        "agent": "m1-lead",
        "alias": "<goal>-m1-lead",
        "tab_id": "<herdr tab id>",
        "pane_id": "<herdr pane id>"
      },
      "tasks": ["<task-id>", "..."]
    }
  ],
  "tasks": [
    {
      "id": "m1-<task-slug>",
      "milestone_id": "m1",
      "title": "<task title>",
      "status": "in_progress",
      "scope": ["<file/dir this worker owns>", "..."],
      "acceptance": ["<executable check or command>", "..."],
      "brief_path": "<ledger>/briefs/<task-id>.md",
      "brief_sha": "<sha256 of the brief file>",
      "worker": {
        "agent": "m1-<task-slug>",
        "alias": "<goal>-m1-<task-slug>",
        "tab_id": "<herdr tab id>",
        "pane_id": "<herdr pane id>",
        "worktree": "<absolute worktree path>",
        "branch": "<task branch name>"
      },
      "iterations": [
        {"n": 1, "started": "<ISO-8601>", "ended": "<ISO-8601>", "result": "<pass|fail|...>"}
      ],
      "verifications": [
        {"by": "verifier subagent", "verdict": "PASS", "notes": "<findings>"}
      ],
      "escalations": [
        {"type": "block", "from": "m1-<task-slug>", "ts": "<ISO-8601>", "resolved": "<ISO-8601 or null>"}
      ],
      "deps": ["<task-id>", "..."]
    }
  ]
}
```

### Status vocab

| Object | Values |
|---|---|
| goal, milestone | `planning` \| `active` \| `blocked` \| `done` \| `failed` \| `archived` |
| task | `pending` \| `dispatched` \| `in_progress` \| `verifying` \| `done` \| `failed` \| `oracle` \| `needs_human` |

### events.jsonl

One JSON object per line: `{"ts": "<ISO-8601>", "type": "<type>", "actor": "<agent or user>", ...payload}`. Always generate `ts` with `date -u +%FT%TZ` at write time — never hand-write or estimate it; a fabricated timestamp corrupts the staleness ladder and the cost window.

| Type | Actor | Payload fields |
|---|---|---|
| `goal.created` | origin agent | `slug`, `title`, `formula` |
| `milestone.created` | ctl | `milestone_id`, `title`, `workspace_id` |
| `task.created` | lead | `task_id`, `milestone_id`, `title`, `scope` |
| `task.dispatched` | lead | `task_id`, `agent`, `brief_sha` |
| `task.iteration` | worker | `task_id`, `n`, `result` |
| `task.verification` | verifier | `task_id`, `verdict`, `notes` |
| `escalation.raised` | any role | `task_id`, `escalation_type`, `summary` |
| `escalation.resolved` | recipient | `task_id`, `escalation_type`, `resolution` |
| `oracle.consulted` | lead | `task_id`, `diagnosis_path` |
| `worker.nudged` | lead | `task_id`, `agent` |
| `heartbeat.stale` | lead | `task_id`, `agent`, `last_change` |
| `cost.reported` | ctl | `total_tokens`, `total_cost`, `window` |
| `goal.completed` | ctl | `report_path` |
| `goal.archived` | ctl | `archive_path` |

### heartbeats.jsonl

Written by the health patrol loop only (see **Health patrol loop**): one line per interval.

```json
{"ts": "2026-10-26T12:00:00Z", "agents": {"m1-lead": "working", "m1-auth-api": "idle"}}
```

## Brief templates

Briefs are the only thing a recipient sees — the sender's context does not travel. Every brief states the ledger's **absolute** path, the repo, and the instruction to read the orchestrate skill section for the recipient's role. Dispatch the exact file stored in `briefs/<task-id>.md`; record its sha256 as `brief_sha`.

### Goal-controller brief

```markdown
Goal: <one-line objective>
Role: goal controller (`ctl`) for the herdr session `<goal-slug>`.
Ledger (absolute): /abs/path/to/repo/.orchestrate/<goal-slug>/
Repo: /abs/path/to/repo
Read `skill://orchestrate`, section "Goal controller" — it is your operating manual.
Scope: own the ledger; create milestone workspaces and leads; resolve cross-milestone dependencies and `block`/`question` escalations; monitor via heartbeats and intercom; on completion integrate, report cost, archive, and tear down.
Acceptance: every milestone `done` and verified; final report at <ledger>/reports/report.md; goal archived.
Constraints: never stop the session except as the final teardown step after explicit user confirmation; never blind-approve a blocked agent; parse IDs from JSON responses only.
Escalations: use the typed escalation grammar (see reference.md "Escalation grammar + handling matrix").
Report: write events to <ledger>/events.jsonl; keep ledger.json current after every state change.
```

### Milestone-lead brief

```markdown
Goal: <one-line objective>
Role: milestone lead (`<mN>-lead`) for workspace `[mN] <milestone title>` in herdr session `<goal-slug>`.
Ledger (absolute): /abs/path/to/repo/.orchestrate/<goal-slug>/
Repo: /abs/path/to/repo
Read `skill://orchestrate`, section "Milestone lead" — it is your operating manual.
Scope: decompose `<milestone title>` into tasks with disjoint scopes; create one worktree + worker tab + agent per task; dispatch task briefs; run verification; own convergence and oracle escalation; merge verified work into the milestone branch.
Acceptance: all tasks in milestone `<mN>` `done` with PASS verdicts; milestone branch merged; milestone status `done`.
Constraints: task scopes must be disjoint; worktree paths outside the main working tree at <repo>/../<repo-name>-orchestrations/<goal>/<task-slug>/; consult the oracle only after max_iterations failed iterations.
Escalations: use the typed escalation grammar (see reference.md "Escalation grammar + handling matrix").
Report: write task/milestone events to <ledger>/events.jsonl; update ledger.json; report milestone completion to `<goal>-ctl` via intercom.
```

### Task (worker) brief

```markdown
Goal: <one-line objective>
Role: worker (`<mN>-<task-slug>`) on task `<task-id>` in herdr session `<goal-slug>`.
Ledger (absolute): /abs/path/to/repo/.orchestrate/<goal-slug>/
Repo: /abs/path/to/repo — but work ONLY inside your worktree: /abs/path/to/worktree (branch `<branch>`).
Read `skill://orchestrate`, section "Worker" — it is your operating manual.
Scope: <files/dirs this worker owns — touch nothing else>
Acceptance: <executable checks/commands and expected output>
Constraints: <boundaries, style rules, invariants>; commit to your own task branch; never leave your worktree; you may spawn in-process subagents freely.
Escalation grammar (first line of any escalation): `ESCALATION <type>: <one-line summary>` where type is `block` | `question` | `done` | `needs-human`. Send via intercom to `<goal>-<mN>-lead` AND append an event to <ledger>/events.jsonl.
Report: write <ledger>/reports/<task-id>.md (what changed, evidence, checks run); log every iteration as a task.iteration event; escalate `done` to request verification.
```

### Non-OMP (Hermes) worker brief

Same contract as the task brief, with three substitutions for agents that lack the OMP harness and the intercom plugin:

- Replace the `skill://orchestrate` line with the absolute path to this skill (`/abs/path/to/harness/skills/orchestrate/SKILL.md`, section "Worker") — or inline the worker protocol directly when the worker cannot read OMP-harness paths.
- Replace the intercom escalation line with: append the `escalation.raised` event to `<ledger>/events.jsonl` yourself AND end your turn with the `ESCALATION <type>: <one-line summary>` line as your **final reply** — under the pane protocol the lead matches it with `pane wait-output --match "ESCALATION"` (see Heterogeneous workers in SKILL.md for the try-then-fallback dispatch: `agent start --kind hermes` first, pane pointer + explicit `send-keys enter` when detection fails).
- Worktree, branch, convergence loop, acceptance, and reports are identical.

### Verifier brief

```markdown
Goal: <one-line objective>
Role: independent verifier for task `<task-id>`.
Ledger (absolute): /abs/path/to/repo/.orchestrate/<goal-slug>/ — read briefs/<task-id>.md for the task's contract; do NOT read reports/<task-id>.md or any worker output — you judge the worktree, not the worker's claims.
Worktree (absolute): /abs/path/to/worktree — branch `<branch>`.
Read `skill://orchestrate`, section "Verification" — it is your operating manual.
Acceptance criteria (from the task brief, verbatim):
<acceptance criteria>
Verdict: reply `PASS` or `FAIL` plus findings. Run the acceptance checks yourself in the worktree; read the diff; trust nothing you cannot reproduce.
Constraints: you receive no implementation narrative by design — judge only against the brief and acceptance criteria.
Report: write <ledger>/reports/<task-id>-verdict.md; log a task.verification event.
```

The verifier brief deliberately contains **no implementation narrative** — only the task brief, acceptance criteria, worktree path, and branch. The worker's report stays with the lead; the verifier judges the artifact, never the story about the artifact.

## Formula spec

Formulas are reusable orchestration methods: agent-interpreted TOML. Resolution order:

1. Explicit path given by the user.
2. `<repo>/.orchestrate/formulas/*.toml`.
3. Skill default: `harness/skills/orchestrate/formulas/default.toml`.

### Fields

| Field | Type | Meaning |
|---|---|---|
| `formula` | string | Formula name |
| `description` | string | What the method does and when to use it |
| `vars` | table | Either `name = "default"` shorthand or `[vars.<name>]` with `description`, `required`, `default` |
| `steps` | array of tables | `id`, `title`, `description`, `needs=[]`, optional `condition`, optional `kind` hint (`milestone`\|`task`) |
| `policies.convergence` | table | `max_iterations`, `oracle_on_exhaustion`, `oracle_retries` |
| `policies.verification` | table | `independent` (fresh no-context verifier) |
| `policies.health` | table | `patrol`, `interval_s`, `stale_after_s` |
| `policies.isolation` | table | `worktrees`, `path_template` |
| `policies.reporting` | table | `cost` |
| `policies.archive` | table | `enabled`, `root` |

### Var expansion

`{{name}}` expands in any text field at plan time, from user-supplied values or var defaults.

### Condition grammar

Evaluated at plan time by the interpreting agent:

| Syntax | True when |
|---|---|
| `{{var}} == value` | var equals value |
| `{{var}} != value` | var differs from value |
| `{{var}}` | var is truthy |
| `!{{var}}` | var is falsy |

Falsy set: empty, `false`, `0`, `no`, `off`. Everything else is truthy.

### Reserved control step ids

Fixed semantics — never redefine:

| Step id | Fixed meaning |
|---|---|
| `clarify` | Intake: clarify the goal with the user |
| `charter` | Write goal.md charter + ledger bootstrap |
| `launch` | Create session, workspaces, tabs, agents, worktrees |
| `execute` | Run the work steps (milestones/tasks) |
| `verify` | Independent verification of each task |
| `integrate` | Merge verified work, close milestones |
| `report` | Final report + cost report |
| `archive` | Move ledger to archive, vault note |

Any other step id is a **work step**. At plan time the interpreting agent maps each work step to:

- a **milestone** — when `kind = "milestone"` or when other steps depend on it (`needs`), or
- a **task** inside `execute` — otherwise.

## Warp tab config

Write `~/.warp/tab_configs/orch_<goal>.toml` — snake_case stem, so every `-` in the kebab-case goal slug becomes `_` (goal `auth-overhaul` → stem `orch_auth_overhaul`) — then open it. The `warp://` scheme cannot run commands directly — tab configs are the mechanism.

```toml
name = "Orchestrate <goal>"

[[panes]]
id = "orch_<goal>"
type = "terminal"
directory = "<repo>"
commands = ["herdr session attach <goal>"]
is_focused = true
```

```bash
open "warp://tab_config/orch_<goal>"
```

No-Warp or non-macOS fallback: tell the user to run `herdr session attach <goal>` in any terminal.

## Health patrol loop

A plain shell script — no LLM, zero token cost. Write it to `<ledger>/patrol.sh` (it is a ledger artifact: inspectable, restartable), substitute the placeholders, then start it in the `patrol` pane. It exits when `<ledger>/STOP` exists or after `MAX_S` (default 12 h). `INTERVAL` comes from the formula's `policies.health.interval_s` (default 120).

```sh
#!/bin/sh
# Health patrol: append {"ts": ..., "agents": {name: state}} to heartbeats.jsonl.
LEDGER="{{ledger}}"      # absolute ledger path, e.g. /abs/repo/.orchestrate/<goal>
SESSION="{{goal}}"       # herdr session name
INTERVAL="{{interval_s}}"
MAX_S="{{max_s}}"        # hard lifetime cap, default 43200

start=$(date +%s)
while [ ! -f "$LEDGER/STOP" ] && [ $(( $(date +%s) - start )) -lt "$MAX_S" ]; do
  printf '{"ts":"%s","agents":%s}\n' \
    "$(date -u +%FT%TZ)" \
    "$(herdr --session "$SESSION" agent list | jq -c '.result.agents | map({key: (.name // .pane_id), value: .agent_status}) | from_entries')" \
    >> "$LEDGER/heartbeats.jsonl"
  sleep "$INTERVAL"
done
```

```bash
chmod +x <ledger>/patrol.sh
herdr --session <goal> pane run <pane-id> "<ledger>/patrol.sh"
```

**Never inline complex quoting through `pane run`** — the pane's interactive shell re-parses typed text and mangles nested quotes, braces, and commas (a jq program like the one above arrives split and stripped). `pane run` is for a bare script path or a simple command; anything richer lives in a script file. This is also why the alias command works: `/alias <slug>` is plain text.

The agent list JSON is `{"id":"cli:agent:list","result":{"agents":[...]}}`; each entry carries `agent_status` (lifecycle state: idle/working/blocked/done/unknown) and a `name` only for agents started via `herdr agent start <name>` — hence the defensive `(.name // .pane_id)` key and `.agent_status` value. Never use `.state` or bare `.name`: both are null for unnamed agents. Staleness handling (a task `in_progress` with no state change for `stale_after_s`, default 1800) is the lead's job: nudge the worker via intercom `send`, then re-dispatch, then escalate.

## Cost report procedure

On completion, the ctl reports cost via the AgentsView MCP. **Never fabricate numbers** — if the MCP is unavailable, write "cost unavailable".

1. Read the goal window from the ledger: `goal.created` → `goal.completed`.
2. Query the MCP by writing JSON args to `xd://mcp__agentsview_get_usage_summary` — once per fleet kind, summing the results (`agent: "omp"` always; add `agent: "hermes"` if Hermes workers ran):
   ```json
   {"from": "<goal.created date, YYYY-MM-DD>", "to": "<goal.completed date, YYYY-MM-DD>", "agent": "omp"}
   ```
3. Record totals and the per-day breakdown in `<ledger>/reports/report.md`.
4. Append a `cost.reported` event to `<ledger>/events.jsonl`.
5. Include this caveat verbatim:

> Cost figures cover the goal's time window filtered to the fleet's agent kinds; the window may include unrelated agent activity, and worktree cwds may register as separate projects, so totals are an upper bound on the goal's true cost.

## Notifications (gateway)

Out-of-band delivery of `needs-human` escalations and goal completion to the user's messaging platforms, via the local Hermes gateway — **no LLM, no agent turn**, just credential reuse:

```bash
hermes send -t <notify_target> "orchestrate/<goal>: ESCALATION needs-human — <summary> (ctl tab: herdr session attach <goal>)"
```

- `notify_target` comes from the formula's `[vars]` (e.g. `slack:C0C9JFJG943`, `telegram`, `discord:#ops`); **empty means off** — the default. `notify_on` gates what is sent: `escalations` (needs-human only), `all` (plus completion), `none`.
- Run it from plain bash (the ctl or lead handling the escalation); never spin an agent turn for a notification.

## Archive procedure

1. Move the ledger: `.orchestrate/<goal-slug>/` → `~/.omp/orchestration-archive/<project-slug>/<goal-slug>-<YYYYMMDD>/`.
2. Append a `goal.archived` event (payload `archive_path`) to `events.jsonl` before the move, and update `ledger.json` (`goal.status = "archived"`).
3. Write a one-line completion note into the agents vault at `Agents/OMP/Projects/<Project>/` (see the agents-vault skill):

```
<goal-slug> completed <YYYY-MM-DD> — archive: ~/.omp/orchestration-archive/<project-slug>/<goal-slug>-<YYYYMMDD>/ — transcripts: AgentsView (search_sessions)
```

AgentsView keeps the transcripts; the archive keeps the ledger, briefs, and reports.

## Escalation grammar + handling matrix

First line of any escalation, verbatim:

```
ESCALATION <type>: <one-line summary>
```

| Type | Intended recipient | Expected response | Ledger event |
|---|---|---|---|
| `block` | Lead (or `<goal>-ctl` for cross-milestone) | Resolve the external dependency or re-route | `escalation.raised` / `escalation.resolved` |
| `question` | Lead (or `<goal>-ctl`) | Decision back to the worker | `escalation.raised` / `escalation.resolved` |
| `done` | Lead | Dispatch independent verification | `escalation.raised` + `task.verification` |
| `needs-human` | Lead → user | User approval/direction in the tab | `escalation.raised` / `escalation.resolved` |

Channel discipline: **send** by default — write JSON args to `xd://intercom`, e.g. `{"action":"send","to":"<goal>-<mN>-lead","message":"ESCALATION <type>: <summary>"}` (or `to` = `<goal>-ctl` for cross-milestone matters) **and** append to `events.jsonl` (durable). Use `ask` (`{"action":"ask",...}`) only when truly blocked on the answer — it blocks up to 10 min, and only one pending `ask` may be outstanding at a time, against live targets only. Delivered messages wake idle recipients.

## Resume / reconciliation procedure

On re-entry (ledger exists), reconcile before creating anything. **Never duplicate live objects.**

1. Read `<ledger>/ledger.json` — the recorded desired state.
2. Verify the session is alive: `herdr --session <goal> session list --json`. If the server is down but the session was saved (`~/.config/herdr/sessions/<goal>/session.json` exists), relaunch it with the detached launcher from the SKILL.md bootstrap — herdr restores the recorded workspaces and tabs (pane processes respawn as plain shells; agents are gone) — then continue with step 3.
3. For each recorded object, verify liveness: `workspace list` for workspaces, `tab get` for tabs, `agent get <name>` for agents, and filesystem existence for worktrees.
4. Diff desired vs existing; create only the missing objects (session, workspace, tab, agent, worktree) — recording fresh ids in the ledger.
5. For each task not `done`: compare the stored `brief_sha` against `briefs/<task-id>.md`. Unchanged brief → re-dispatch is safe; changed brief → update the brief and re-dispatch.
6. Mark lost workers' tasks `failed`, then re-dispatch them (fresh worktree if the old one is gone or dirty beyond repair).
7. Append reconciliation outcomes to `events.jsonl` and continue the flow from the ledger's current statuses.
