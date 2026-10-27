---
name: orchestrate
description: "Goal-oriented orchestration across real OMP sessions in herdr: bootstrap a dedicated herdr session per goal, milestone workspaces with coordinator and worker tabs, a shared .orchestrate/ ledger, formulas, bounded convergence with oracle escalation, independent verification, health patrol, idempotent resume, and cost reporting via AgentsView. Use when the user wants to orchestrate a goal, feature, or project as a multi-agent fleet across herdr sessions/workspaces/tabs, mentions goal sessions, milestone workspaces, orchestration ledgers or formulas, or asks to resume or inspect an orchestration. Not for in-process subagent delegation - task and /vibe cover that."
alwaysApply: false
---

# orchestrate (goal-oriented fleet in herdr)

## Concept

A **goal** runs as a dedicated herdr **session**; milestones are herdr **workspaces**; workers are OMP agents in **tabs** within their milestone workspace, each in its own **git worktree**. All coordination state lives in a durable **ledger** under `.orchestrate/<goal>/` in the project repo. Behavior is parameterized by a **formula** (TOML). Cross-session messaging goes over **intercom**; cost reporting and archaeology go through **AgentsView**.

The fleet is a layered hierarchy with exactly one integration point per milestone: the origin agent bootstraps and hands off; the goal controller owns the ledger and the milestone fan-out; each milestone lead owns its tasks and merges; workers converge inside isolated worktrees; verifiers judge results with fresh eyes; a no-LLM patrol watches for staleness. Every layer is a real, interactive OMP session — the user can click into any tab and talk to it directly at any time.

Durability is the design center: the ledger (not any agent's memory) is the source of truth, every escalation is both messaged and logged, and every create is idempotent against the ledger. Any layer can die and be re-entered — resume reads the ledger, reconciles against live herdr state, and continues without duplicating work.

Every layer reads this same skill, different section:

| Role | Job (one line) | Read |
|---|---|---|
| **Origin agent** | Goal intake, suitability gate, bootstrap, hand off — never babysit | Origin: bootstrap |
| **Goal controller** (`ctl`) | Owns the ledger; milestones, leads, escalations, integration, cost, archive, teardown | Goal controller |
| **Milestone lead** (`mN-lead`) | Decompose into tasks, spawn workers + worktrees, verify, merge into the milestone branch | Milestone lead |
| **Worker** (`mN-<task>`) | Bounded convergence loop inside its worktree; typed escalations | Worker |
| **Verifier** | Fresh task subagent, no implementation context; runs acceptance commands; PASS or FAIL | Verification |
| **Health patrol** | Plain shell loop appending heartbeats — no LLM, zero tokens | Health patrol |

## Gate

```bash
command -v herdr
```

The canonical flow works from **any** OMP session — it targets a named session by `--session <goal>`, not the current one. Only the in-session variant additionally requires `HERDR_ENV=1`. If `herdr` is missing, stop and tell the user to install it before orchestrating; do not attempt to drive herdr through any other mechanism.

## Goal intake

- Take the goal from the prompt, or from a referenced file — **read the file fully** before planning; never plan from its name.
- Clarify in bounded batches: at most 5 questions, then restate what you have and proceed. Do not interrogate; a charter you restate is cheaper than a questionnaire.
- Restate the goal as a **charter**: objective, scope, non-goals, constraints, acceptance criteria. Acceptance criteria must be executable checks or commands — the verifier will run them verbatim. The charter becomes `goal.md`.
- Before planning, check for prior work:
  - `.orchestrate/` in the project repo — a resumable goal (see Non-canonical flows → resume).
  - `~/.omp/orchestration-archive/` — prior completed goals on this project.
  - AgentsView (`xd://mcp__agentsview_search_sessions`) — prior sessions on this project worth mining for context.
- A resumable ledger beats a fresh bootstrap: offer resume first if one exists.

## Suitability gate

Orchestrating a fleet is expensive: **every tab is a full OMP session with its own token burn.** Never fan out work one session should just do.

| Situation | Recommendation |
|---|---|
| Multiple milestones | Canonical fleet |
| ≥3 genuinely parallel tasks | Canonical fleet |
| Expected duration well beyond one session (hours) | Canonical fleet |
| User explicitly wants the fleet | Canonical fleet |
| Single milestone, <3 parallel tasks, one session's worth of work | Single OMP session, or in-process subagents (`/vibe`, `task`) |
| Already inside a herdr session | In-session variant (Non-canonical flows) |

When recommending the fleet, state both in your reply: the fan-out rationale (which table row fired) and the cost warning. When recommending against, name the lighter alternative explicitly (`/vibe`, in-process `task`, or the in-session variant). Ambiguity here wastes either tokens or the user's time.

Get **explicit user confirmation** before bootstrapping the fleet — never spawn sessions, worktrees, or tabs on an implied yes.

## Formula

A **formula** is a reusable orchestration method: an agent-interpreted TOML file of steps, vars, and policies — the plan skeleton the controller expands into milestones and tasks. Resolution order:

1. Explicit path given by the user.
2. `<repo>/.orchestrate/formulas/*.toml`.
3. Skill default: `formulas/default.toml` (skill-relative path).

Reserved control step ids have fixed semantics: `clarify` → `charter` → `launch` → `execute` → `verify` → `integrate` → `report` → `archive`. Any other step id is a **work step**, mapped at plan time to a milestone (kind=milestone, or a step other steps depend on) or to a task inside `execute`. Vars expand as `{{name}}` in text fields; conditions (`==`, `!=`, truthiness, `!` negation) are evaluated at plan time by the interpreting agent.

Full spec — fields, condition grammar, policies — is the **Formula spec** section of `reference.md`. The default formula pre-authorizes exactly one oracle escalation path (see Milestone lead).

## Topology and naming

```
Warp tab (attached via ~/.warp/tab_configs/orch_<goal>.toml)
└─ herdr session <goal-slug>            (headless server)
   ├─ workspace "[ctl] <goal-title>"    (controller space)
   │  ├─ tab/agent `ctl`                (goal coordinator, OMP; intercom alias <goal>-ctl)
   │  └─ tab `patrol`                   (health patrol: plain shell loop, NO LLM)
   ├─ workspace "[m1] <milestone-title>"
   │  ├─ tab/agent `m1-lead`            (milestone coordinator; alias <goal>-m1-lead)
   │  ├─ tab/agent `m1-<task-slug>`     (worker, OMP, cwd = its own worktree; alias <goal>-m1-<task>)
   │  └─ ...
   └─ workspace "[m2] ..."
```

| Object | Convention |
|---|---|
| Session | `<goal-slug>` (kebab-case) |
| Workspace label | `[ctl] <goal-title>` / `[mN] <milestone-title>` |
| Tab label | the agent name |
| Agent name | `[a-z][a-z0-9_-]{0,31}`, unique among live agents in the session |
| intercom alias | `<goal>-ctl`, `<goal>-m1-lead`, `<goal>-m1-<task>` — machine-global among live OMP sessions, so the goal prefix prevents collisions |

**Single milestone**: no `[ctl]` workspace — the goal coordinator IS the m1 lead (one workspace: lead tab, patrol tab, worker tabs).

The Warp tab config (`~/.warp/tab_configs/orch_<goal>.toml`, snake_case stem — kebab `-` becomes `_`) is the user's window onto the fleet: it attaches a terminal running `herdr session attach <goal>`. The `warp://` scheme cannot run commands directly — tab configs are the mechanism. Template: **Warp tab config** in `reference.md`.

The user can type into **any** tab, workers included — a feature, not interference. Coordinators re-check `herdr agent get` before prompting a worker; if the user redirected it, read the pane before acting.

## Ledger

`.orchestrate/<goal-slug>/` in the project repo (gitignored):

```
goal.md          charter: objective, scope, non-goals, constraints, acceptance, formula, links
ledger.json      machine state (full schema in reference.md)
events.jsonl     append-only event log, one JSON object per line
heartbeats.jsonl patrol snapshots: {"ts": "...", "agents": {"<name>": "<state>", ...}}
briefs/          <task-id>.md — the exact dispatched briefs (resume compares brief_sha)
reports/         worker reports, verifier verdicts, final report.md
```

- Append `.orchestrate/` to the project's `.gitignore` if missing.
- Workers live in worktrees → share the ledger by **absolute path**; state the absolute ledger path in every brief (e.g. `/abs/path/to/<repo>/.orchestrate/<goal-slug>/`). A relative path resolves differently inside each worktree — it will silently point at nothing.
- Memory backends with per-project scoping tag memories by session cwd: fleet sessions in ephemeral worktrees write memories under worktree-path tags that nothing will ever recall once the worktree is pruned — write-only noise, not a coordination channel. Never rely on agent memory for fleet state; the ledger is the durable record.
- `briefs/` holds the exact dispatched text; resume compares `brief_sha` to detect a re-dispatch with changed content.
- `reports/` is write-per-worker: each worker writes only `reports/<task-id>.md`; the lead writes verifier verdicts; the ctl writes `report.md`.
- Status vocab — goal/milestone: `planning|active|blocked|done|failed|archived`; task: `pending|dispatched|in_progress|verifying|done|failed|oracle|needs_human`.
- Event types: `goal.created`, `milestone.created`, `task.created`, `task.dispatched`, `task.iteration`, `task.verification`, `escalation.raised`, `escalation.resolved`, `oracle.consulted`, `worker.nudged`, `heartbeat.stale`, `cost.reported`, `goal.completed`, `goal.archived`.
- **Idempotency/resume**: on re-entry read `ledger.json` first; before ANY create (session/workspace/tab/agent/worktree) check the ledger AND the live object; reconcile missing objects (mark task failed → re-dispatch); never duplicate.
- Full schema: **Ledger schema** section of `reference.md`.

## Origin: bootstrap

The origin agent bootstraps once and hands off — it does not babysit. You are building the skeleton (session, controller, patrol) and transferring ownership to `ctl`.

1. Derive the goal slug from the charter title; init the ledger: `goal.md`, `ledger.json`, `events.jsonl` with a `goal.created` event.
2. Ensure `.orchestrate/` is gitignored.
3. Start the headless session in its own OS session and poll until it answers:

```bash
python3 -c "import subprocess; subprocess.Popen(['herdr','--session','<goal>','server'], start_new_session=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)"
# socket: ~/.config/herdr/sessions/<goal>/herdr.sock
# poll: herdr --session <goal> workspace list  (until it answers)
```

`start_new_session=True` (POSIX setsid) is load-bearing: a plain `nohup herdr ... &` leaves the server in your tool-shell's process group, and when that shell reaps a long-running job it SIGTERMs the whole group — killing the goal session mid-flight (verified the hard way). The detached server is immune to tool-shell job cleanup.

4. Create the controller workspace (root tab hosts `ctl`):

```bash
herdr --session <goal> workspace create --label "[ctl] <title>" --cwd <repo> --no-focus
# JSON: .result.workspace.workspace_id, .result.tab.tab_id, .result.root_pane.pane_id
```

5. Start the controller and alias it:

```bash
herdr --session <goal> agent start ctl --kind omp --pane <pane-id> --timeout 60000
herdr --session <goal> pane run <pane-id> "/alias <goal>-ctl"
```

6. Create the `patrol` tab and start the heartbeat script (template in reference.md — write it to `<ledger>/patrol.sh`, then run the bare path; never inline the loop through `pane run`):

```bash
herdr --session <goal> tab create --workspace <ws-id> --cwd <repo> --label patrol --no-focus
chmod +x <ledger>/patrol.sh
herdr --session <goal> pane run <patrol-pane-id> "<ledger>/patrol.sh"
```

7. Write the Warp tab config `~/.warp/tab_configs/orch_<goal>.toml` (template in reference.md) and `open "warp://tab_config/orch_<goal>"`. Do this **after** the controller workspace exists — `herdr session attach` onto an empty session creates its own initial workspace, which leaves a stray. No-Warp/non-macOS fallback: tell the user to run `herdr session attach <goal>`.

8. Dispatch the goal-controller brief (template in reference.md):

```bash
herdr --session <goal> agent prompt ctl "<brief>" --wait --timeout 300000
```

9. Record the handoff in events.jsonl and report to the user: tab config name, ctl alias, ledger path, resume command.

**Single milestone**: dispatch the combined controller+lead brief to `ctl` instead — no separate lead.

## Goal controller

You own the ledger and the milestone fan-out. Loop, never busy-waiting:

1. **Read the ledger** (`ledger.json` + recent `events.jsonl`) — it is the source of truth, not your memory of the conversation. Apply the idempotency rule from Ledger before every create.
2. **Plan milestones** from the formula: map control steps and work steps to milestones (`kind=milestone` or a step other steps depend on), expand `{{var}}`, evaluate conditions at plan time.
3. **Create milestone workspaces + leads** using the same command patterns as bootstrap: `workspace create --label "[mN] <title>" --no-focus`, `agent start mN-lead --kind omp --pane <pane-id>`, alias `<goal>-mN-lead` via `pane run`. Log `milestone.created`.
4. **Dispatch lead briefs** (`agent prompt mN-lead "<brief>" --wait --timeout 900000`–`1800000` for code work); save each to `briefs/`. Briefs must be self-contained: milestone charter, decomposition hints, acceptance criteria, ledger absolute path, naming conventions.
5. **Monitor on a cadence** between your own work: `intercom pending`, `heartbeats.jsonl`, `herdr --session <goal> agent list`. Never busy-wait. Run long waits in bounded chunks — `agent wait <name> --timeout 240000`, re-check, repeat — because tool-shell jobs get reaped around the five-minute mark; a reaped wait is harmless (the prompt was already delivered) as long as the server was launched detached: inspect with `agent get`/`agent read`, never blindly resubmit. A blocked agent rejects input (`agent_blocked`) — read the pane, surface the dialog to the user, never blind-approve.
6. **Handle escalations** (types in Escalations): `block` — resolve external dependencies and cross-milestone conflicts yourself; `question` — decide and answer; `needs-human` — surface in chat AND the ctl tab (the user is human-in-the-loop there; they type into your tab). Resolve and log `escalation.resolved`.
7. **Staleness protocol** (from patrol heartbeats): nudge the worker via intercom `send` (log `worker.nudged`) → re-dispatch the brief → escalate.
8. **Completion**: integrate milestone branches into the target branch; write the cost report (Cost reporting); archive (Completion and archive); user-confirmed teardown — prune merged worktrees (`git worktree remove`), close goal-created workspaces, remove the Warp tab config, then `herdr --session <goal> session stop <goal>` and `herdr session delete <goal>` as the **FINAL** action. This is the one sanctioned exception to never stopping a server: it is the goal's own session, at end of life, after explicit user confirmation. Write the final report (`reports/report.md`) and log `goal.completed` / `goal.archived`.

## Milestone lead

1. **Decompose** the milestone into tasks with **disjoint scopes** (split by files/directories, not just features — each worker gets its own worktree, but collisions still cost merge pain). Keep at most `max_parallel_workers_per_milestone` in flight; log `task.created` per task.
2. Per task — create the worktree (NEVER inside the main working tree; convention `<repo>/../<repo-name>-orchestrations/<goal>/<task-slug>/`), tab, agent, alias:

```bash
git worktree add <path> -b orch/<goal>/<task> [<base>]
herdr --session <goal> tab create --workspace <milestone-ws> --cwd <worktree> --label <task-slug> --no-focus
herdr --session <goal> agent start <task-slug> --kind omp --pane <pane-id>
herdr --session <goal> pane run <pane-id> "/alias <goal>-m1-<task>"
```

3. **Dispatch task briefs** in parallel (`agent prompt <name> "<brief>" --wait --timeout 900000`–`1800000`); save each to `briefs/<task-id>.md`; log `task.dispatched`. Before prompting, check `herdr agent get <name>` in case the user redirected the worker.
4. On a `done` escalation or worker settle: read the worker's report, then spawn the **VERIFIER** — a task subagent given the task brief + acceptance criteria + worktree path ONLY, never the worker's transcript or report (see Verification).
5. FAIL verdict → dispatch a convergence iteration to the worker with the verifier's findings attached.
6. After `max_iterations` failed iterations → **oracle consult**: a task subagent with model `@oracle` (the harness's user-gated top-tier role), given task brief + iteration history + current diff; it returns a diagnosis. The goal owner pre-authorized exactly this one path by launching with the default formula — the formula can disable it (`oracle_on_exhaustion=false`). Log `oracle.consulted`. The worker gets `oracle_retries` (default 1) more attempt with the diagnosis.
7. Still failing → escalate `needs-human` to `<goal>-ctl`.
8. **Merge** verified task branches into the milestone branch. The lead is the **one place per milestone that mutates shared repo state** — never let two actors merge concurrently.
9. **Report** to ctl (intercom `send` to `<goal>-ctl` + events.jsonl append); `git worktree remove <path>` after merge.

## Worker

Run the bounded convergence loop inside your worktree:

1. Each iteration: implement → run the acceptance commands → fix. Log a **task.iteration** event per attempt (what you tried, what failed). Acceptance criteria are executable checks — run them, never eyeball.
2. Stop at `max_iterations` and escalate `block` with the failure summary (which checks fail, what you tried).
3. Commit to your task branch (`orch/<goal>/<task>`); stay **strictly inside your worktree** — never touch the main tree, other worktrees, or the ledger outside your report/events.
4. Write your report to `<ledger>/reports/<task-id>.md` (absolute ledger path from the brief): summary, changes, evidence, open questions.
5. Escalate typed when done, blocked, or needing a decision — first line of the message:

```
ESCALATION <type>: <one-line summary>
```

6. `done` means "request verification" — the verifier decides, not you.
7. You may spawn in-process subagents freely (`task`, `/vibe`) — they are yours, not the fleet's.

## Verification

The verifier is a **fresh task subagent with no implementation context**: it gets the task brief, the acceptance criteria, and the worktree path only. It runs the acceptance commands itself in the worktree and returns a verdict — **PASS** or **FAIL** plus findings — logged as a `task.verification` event. Independence is the point: never hand the verifier the worker's transcript or report, and never let the worker pick its own verifier inputs.

The lead owns verification: on PASS, mark the task `done` and proceed to merge; on FAIL, feed the findings back to the worker as the next convergence iteration (see Milestone lead). A verifier verdict is evidence, not a formality — a PASS with weak findings deserves a read before merging.

Verifier brief contents — nothing more:

- The task brief (from `briefs/<task-id>.md`) and its acceptance criteria.
- The absolute worktree path and the task branch name.
- Instruction to run the acceptance commands itself in the worktree, inspect the diff, and return a verdict: `PASS` or `FAIL` plus findings (what failed, evidence, minimal fix hints).

Never include: the worker's report, its iteration history, or any framing that suggests the expected verdict.

## Escalations

Grammar — first line `ESCALATION <type>: <one-line summary>`. Types:

| Type | Meaning |
|---|---|
| `block` | External dependency needed |
| `question` | Decision needed |
| `done` | Task complete — request verification |
| `needs-human` | User approval/direction required |

Channel: intercom `send` to the lead's alias (or `<goal>-ctl` for cross-milestone matters) **AND** an append to `events.jsonl` (durable) — log `escalation.raised`. Use `ask` only when truly blocked on the answer — it blocks up to 10 minutes, one pending `ask` at a time, live targets only. Delivered messages wake idle recipients.

Routing summary:

| From → To | Alias |
|---|---|
| Worker → its lead | `<goal>-mN-lead` |
| Lead → controller | `<goal>-ctl` |
| Any → controller (cross-milestone) | `<goal>-ctl` |
| Controller → user | surface in chat AND the ctl tab |

Handling matrix: **Escalation handling** section of `reference.md`. Discipline: keep messages self-contained (the recipient shares none of your conversation), and treat replies from other sessions like any agent output — verify before building on them.

## Health patrol

A plain pane labeled `patrol` in the controller workspace, started with `herdr pane run`: a bounded shell loop appending `{"ts":...,"agents":{name:state,...}}` to `heartbeats.jsonl` every `interval_s` (default 120); exits when `<ledger>/STOP` exists or after a max duration. **No LLM, zero token cost.** Loop script: **Health patrol loop** in `reference.md`.

Staleness ladder — a task in_progress with no state change for `stale_after_s` (default 1800): lead **nudges** the worker (intercom `send`; log `worker.nudged`) → **re-dispatches** the brief → **escalates**. Log `heartbeat.stale` when the ladder starts.

Operating notes:

- Single-milestone goals: the patrol pane lives in the m1 workspace (there is no `[ctl]` workspace); the lead reads it.
- To stop the patrol, `touch <ledger>/STOP` — the loop exits on its next tick; never kill the pane.
- Heartbeats are snapshots, not commands: no agent reacts to them except the coordinator reading `heartbeats.jsonl` on its cadence.

## Cost reporting

On completion, the ctl queries the AgentsView MCP `get_usage_summary` (write JSON args to `xd://mcp__agentsview_get_usage_summary`; filter date range = the goal window from ledger timestamps, agent=omp) and writes the numbers plus the caveat — the window may include unrelated OMP activity; worktree cwds may register as separate projects — into `report.md` and the ledger. Procedure: **Cost reporting** section of `reference.md`. If the MCP is unavailable, state "cost unavailable" — **never fabricate numbers**. Log `cost.reported`.

## Completion and archive

Archive moves `.orchestrate/<goal>/` to `~/.omp/orchestration-archive/<project-slug>/<goal-slug>-<YYYYMMDD>/` and writes a one-line completion note + archive path into the agents vault at `Agents/OMP/Projects/<Project>/` (see the agents-vault skill). AgentsView keeps the transcripts. Procedure: **Completion and archive** section of `reference.md`.

## Non-canonical flows

- **(a) In-session**: already inside a herdr session (requires `HERDR_ENV=1`); the current agent becomes the orchestrator of worker tabs in the CURRENT workspace — no new session, but ledger + worktrees + convergence + verifier + typed escalations all still apply.
- **(b) Multi-objective**: several objectives → several workspaces in the CURRENT session, each with a lead + workers; the current agent coordinates (no ctl).
- **(c) Resume**: ledger exists → reconcile + continue. Procedure: **Resume** section of `reference.md`.
- **(d) Already a layer**: you received a brief → jump to your role's section above and follow it exactly; the ledger paths and aliases in the brief are authoritative.

When in doubt which flow applies: canonical fleet unless you are already inside a herdr session.

## herdr cheatsheet

All commands carry the `--session <goal>` global flag prefix — the server start itself takes `--session <goal>` as its global flag too; every later command targets that named server. Omitting the prefix risks hitting the wrong session; never do it.

Error contract: CLI server errors are JSON on stderr with exit 1; syntax errors exit 2. Parse IDs from the JSON responses only. An agent name dies with its agent and is reusable after.

| Command | Purpose | Key flags / JSON path |
|---|---|---|
| `python3 -c "import subprocess; subprocess.Popen(['herdr','--session','<goal>','server'], start_new_session=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)"` | Start headless goal session, detached from your shell's process group (mandatory — a reaped tool-shell job SIGTERMs its whole group) | socket `~/.config/herdr/sessions/<goal>/herdr.sock`; poll `workspace list` |
| `herdr --session <goal> workspace create --label "[mN] <title>" --cwd <repo> --no-focus` | Create workspace (includes root tab + pane — use for the lead) | `.result.workspace.workspace_id`, `.result.tab.tab_id`, `.result.root_pane.pane_id` |
| `herdr --session <goal> tab create --workspace <ws-id> --cwd <path> --label <label> --no-focus` | Create worker tab | `.result.tab.tab_id`, `.result.root_pane.pane_id` |
| `herdr --session <goal> agent start <name> --kind omp --pane <pane-id> [--timeout 60000]` | Start OMP in a pane; returns once ready | name `[a-z][a-z0-9_-]{0,31}` |
| `herdr --session <goal> pane run <pane-id> "/alias <goal>-m1-lead"` | Alias a fresh OMP (text + Enter in one call) | — |
| `herdr --session <goal> agent prompt <name> "<brief>" --wait --timeout <ms>` | Dispatch work | 900000–1800000 for code tasks; blocked agent rejects input (`agent_blocked`) — read it first |
| `herdr --session <goal> agent list` | Dashboard of live agents + states | `.result.agents[]` — each entry: `agent` (kind), `agent_status` (lifecycle state), `pane_id`, `tab_id`, `workspace_id`, `cwd`; `name` present only when started/renamed via `agent start`/`agent rename` |
| `herdr --session <goal> agent read <name> --source recent-unwrapped --lines 200` | Recent output | — |
| `herdr --session <goal> agent wait <name> --timeout <ms>` | Block on one agent | — |
| `herdr session attach <goal>` | User attaches manually (no-Warp fallback) | — |
| `herdr --session <goal> session stop <goal>` / `herdr session delete <goal>` | Teardown, FINAL action, user-confirmed | `session stop` takes the session NAME as its positional arg — the `--session` prefix flags which server context, the positional names the session to stop; the one sanctioned exception |

Agent states: `working` | `idle`/`done` | `blocked` (approval dialog — surface to the user, never blind-approve) | `unknown` (inspect before acting).

## intercom quick reference

Invoke the intercom tool by writing JSON args to the device path `xd://intercom`, e.g. `{"action":"send","to":"<goal>-m1-lead","message":"..."}`. Actions:

| Action | Use |
|---|---|
| `send` | Fire-and-forget message to an alias/session ID/short ID |
| `ask` | Blocks up to 10 min; one pending ask at a time; live targets only |
| `reply` | Answer using the embedded reply hint |
| `pending` | List unresolved inbound asks |
| `list` | name/cwd/model/status/herdr location of live sessions |
| `handover` | Summarize this session and transfer remaining work to a peer |

Alias discipline:

- Every fleet session aliases with the goal prefix (`<goal>-ctl`, `<goal>-m1-lead`, `<goal>-m1-<task>`) before participating — aliases are machine-global among live OMP sessions, so the prefix prevents cross-goal collisions.
- Address by alias first; session ID or short ID (from `list`) when an alias is absent.
- Messages must be self-contained: the peer shares none of your conversation. Name exact files, symbols, and decisions.
- Prefer `send` (fire-and-forget); `ask` only when genuinely blocked on the answer — it blocks this turn up to 10 minutes and allows one pending `ask` at a time, live targets only.
- Delivered messages wake idle recipients; `list` shows name/cwd/model/status/herdr location.

Defer to `rule://intercom` for policy.

## Hard rules
Non-negotiable. Violations lose sessions, corrupt shared state, or burn tokens silently.

- Never run bare `herdr` — it launches the TUI.
- Never stop the CURRENT session's server; the only exception is the goal's own session at end-of-life teardown, after explicit user confirmation.
- Parse IDs from JSON responses only — never from labels or order.
- Never busy-wait; poll between your own work.
- Never blind-approve a blocked agent's dialog — surface it to the user.
- One place per milestone mutates shared repo state: the lead, after verification.
- Workers never touch anything outside their worktree.
- Verify worker claims before building on them — run the checks, read the diff.
- Never duplicate creates: check the ledger AND the live object first (idempotency, see Ledger).
- Never fabricate cost numbers — "cost unavailable" is a valid answer (Cost reporting).
- The origin agent does not babysit: after handoff, the goal controller owns the goal.
