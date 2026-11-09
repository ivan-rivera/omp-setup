---
name: orca-phase
description: "Plan and run one approved phase of pull requests with Orca: one supervisor, parallel worktree lanes, stacked PRs, contracts, merge and human gates, and event-driven workers. Use when the user asks to plan, launch, supervise, resume, or inspect a multi-PR phase in Orca, including phases spanning repositories. Do not use for ordinary in-process subagents, a generic Orca handoff, or Herdr/First Mate fleets."
alwaysApply: false
---

# Orca phase

One phase is a user-approved PR plan executed by one Orca supervisor. A PR is the tracking unit; a lane is one repository, one child worktree and one worker agent, with its PRs shipped in order. Plan in the user's chat, hand off after approval, then supervise from the phase workspace. Do not replace Orca workers with in-process agents.

## Authority and prerequisites

- No worktree, Run, task, gate, file, branch, agent, external label, or other orchestration state is created or changed before the user explicitly approves the complete draft. Read-only source and repository inspection is allowed; do not fetch or modify refs during planning. If local `origin/<default>` is stale or missing, say so and use read-only remote evidence or ask the user how to proceed.
- The launcher creates the phase only after approval. The supervisor is the user's sole execution contact; workers communicate through Orca with the supervisor. Internal Orca messages and workspace-card updates are allowed. No agent merges or approves a PR, posts an external comment or message, changes an external label, or independently asserts a human gate is done. Opening and updating the authorized PRs and branches is allowed.
- Use the Orca executable selected by `ORCA_CLI_COMMAND`, otherwise `orca-dev` in an `ORCA_DEV_REPO_ROOT` dev session, `orca-ide` on Linux outside Orca, otherwise `orca`. Use the same executable throughout; do not silently switch builds. Load `skills get orchestration` and `skills get orca-cli`; load their named references for DAGs, messaging, placement and recovery, and consult the selected executable's `--help` for flags. Never guess unsupported behavior. If the CLI or required runtime is unavailable, report the error and stop.
- This workflow uses one execution host: the phase plan's absolute path must be readable by the supervisor and every worker, even across repositories. Resolve repository selectors, default branches, GitHub remotes and access before launch. Parent links across repositories are Orca lineage, not Git ancestry.
- Orca and the phase plan are coordination authorities; Git and GitHub remain authoritative for branches, PRs and checks. Do not create a separate ledger, watcher, polling loop, review server or First Mate/Herdr fleet. Existing archives are not migration input or deletion targets.

## Plan in chat

1. Read the named source items and their acceptance criteria. For each proposed PR inspect `origin/<default>` and record repository, base SHA, touched or new paths and `file:line` evidence; identify uncertainty rather than inventing files. Keep work and PR size within the repository's rules or obtain the user's explicit exception.
2. Group PRs that touch the same files into the same repository lane; take the transitive closure of overlaps. A lane is placement, not a task. Record owned paths, including anticipated new files. Raise uncertain overlaps before dispatch; file ownership is not a substitute for interface dependencies.
3. Classify every dependency. `P<n> (stacked)` is allowed only on the immediately preceding PR in the same lane, and releases when that primary task succeeds. Every cross-lane or cross-repo PR dependency is `P<n> (merged)`. A dependency on a deployed change additionally needs a human deployment gate. Gates may depend on PR merges or other gates. Reject missing IDs, inconsistent repositories, duplicate IDs, impossible lane order and cycles across PRs and gates. Record shared interfaces as contracts with one owner PR and named consumers.
4. Present a complete draft in chat: lanes and file evidence, each PR's change and observable acceptance, dependencies and gates, contracts, critical path, findings and genuine questions. Keep worker solutions open; the plan is an execution contract, not a worked implementation. Do not write a draft file or create resources. Wait for an explicit yes to this draft; revise and ask again after material changes.

## Plan format

After approval the launcher writes `.orca-phase/plan.md` in the phase worktree, with this structure and concrete values (not placeholders):

```markdown
---
document: <document name>
phase: <phase name>
home: <home repository and default branch>
source: <source location and named items>
agent: <Orca agent id>
max-parallel: <positive integer>
status: approved
---

## Rules
<phase constraints overriding worker defaults, without overriding the authority rules above>

## Contracts
### C1: <interface>
Owner: P1
Consumers: P2
<observable interface and compatibility obligations>

## Lane {#L1}
Repo: <exact repository identity, default branch and inspected base SHA>
Files: <paths and file:line evidence>

### PR {#P1}
Change: <scope>
Done when: <observable acceptance, validation and review evidence>
Depends on: none

### PR {#P2}
Change: <scope>
Done when: <acceptance>
Depends on: P1 (stacked), G1

## Gate {#G1}
Title: <human action or deployment>
Owner: <human or supervisor for a verified merge>
Done when: <condition>
Depends on: P1 (merged)

## Changes
<append dated approved scope/order decisions and recovery identity; initially none>
```

PR and gate IDs are unique within the phase. A plan may have multiple lanes, PRs, contracts and gates. `status` is `draft` in the chat draft and `approved` only after the user's explicit yes; the first on-disk copy is approved. A gate's `Depends on` means the supervisor cannot resolve it before those conditions are satisfied. Every gate must name at least one dependent PR or be an explicit phase-completion gate. A gate with no dependent PR uses a clearly titled gate-anchor task; it is bookkeeping, not a PR. `## Changes` records approved changes and recovery identifiers, not a second copy of live Orca status.

## Launch and hand off

1. Discover the home repo and matching document worktree by exact repository, parent and display name. If several match, or an existing worktree's ownership is unclear, ask instead of reusing or altering it. Create the document worktree if absent, then create the phase worktree under it; use `--setup skip` and display names `<document>` and `<document> · <phase>`. Do not request an agent for the document. Repo default tabs can still appear; do not close or take over existing sessions without proof and permission.
2. Before writing the plan, resolve `git rev-parse --git-path info/exclude` from the phase worktree and add the exact `/.orca-phase/` entry only if absent, preserving all existing contents. This Git exclude file is shared by linked worktrees of that repository; never remove a pre-existing entry. Write the approved plan in the phase worktree and verify Git ignores it.
3. Launch the selected agent in that worktree with `orca agent launch`, passing a short prompt containing the absolute path to this skill and the absolute plan path, and instructing it to read both and execute the supervisor section. Select the executable as above. Rename the launched tab `Supervisor` using the receipt's actual chat or terminal identity and the appropriate Orca command; do not assume chat has a terminal handle. If launch outcome is unknown, use the documented operation-id recovery; never launch a duplicate.
4. Give the user the phase workspace and supervisor handle, then stop. Do not run the phase from the launcher. The plan stays in the phase worktree and is lost if that worktree is removed.

## Supervisor: start and schedule

Read the approved plan and version-matched Orca guides. Refuse an unapproved or invalid plan. On a fresh phase, create exactly one Run with objective `<document> · <phase>`; record its exact Run ID and phase-worktree identity in `## Changes`. On resume, use that ID and `run-use`, not a new Run. If creation or handoff was interrupted, inspect Orca and recover the original operation before creating anything; ambiguity or evidence of another live supervisor requires user direction.

Create one **primary** Orca task per PR in dependency order, using `P<n>: <title>` as `--task-title`. The self-contained spec contains the worker brief below, that PR's section, lane, Rules, and current Contracts, plus the absolute plan path. Convert only a same-lane previous PR's `stacked` link into `--deps` containing its actual Orca task ID. Create a task's gates immediately after that task, before starting any worker: one gate per blocked task for each merged prerequisite or G ID, with both the target PR ID and prerequisite ID in the question. If multiple PRs depend on one condition, resolve each corresponding gate. For a phase-completion G with no dependent PR create a `G<n>: gate anchor` task and attach its gate; complete that bookkeeping task only after the gate resolves. Record exact Run and task/gate/dispatch identities as recovery hints in the plan or obtain them from Orca; Orca's current state wins over hints.

Do not dispatch until all initial tasks and gates have been created and reconciled. Orca's `run-create` does not schedule workers. On every wake, reconcile the Run, handled/unhandled mail, tasks, all gates and worker liveness; process the whole delivered batch. Select ready tasks only after checking their actual stacked dependencies, gates, lane availability and current plan. Keep at most `max-parallel` lanes busy; a lane with a running or uncertain worker is busy. Start each lane's first PR with `worker-start --task ... --worktree new-child`, its repo if different, name, display name and `--keep-open`. Keep repository setup policy for worker worktrees unless the approved Rules override it. For later PRs, use the exact existing lane worktree and the settled, proven reusable worker handle with `worker-start --task ... --worktree ... --terminal ...`; do not pass new-worktree flags. Follow the receipt and version-matched guide if a chat surface or handle cannot be reused; never invent a terminal handle. Tell the user which gates need their action, then end the turn. Orca wakes the supervisor for orchestration mail; never poll or run watch scripts.

An accepted launch or prompt is not proof that the worker's turn started. Follow the start receipt and inspect an unproven start without resending the prompt. If onboarding, trust or permission UI blocks it, tell the user what needs attention; do not change their settings to clear it. Reconcile the original dispatch after the UI is resolved. Do not infer exit or create a second worker from silence.

A task's successful `worker_done` means PR ready for human review, not merged. It releases the next stacked task, not a merge gate. A failed task does not satisfy dependencies. A finished local worker may receive a `send` that creates a follow-up task; title and associate it with the same P ID. The one-task-per-PR rule means one **primary** task; review and late-answer follow-ups and gate anchors are the only additional bookkeeping tasks.

## Supervisor: messages and user loop

Workers use `ask` for decisions and end their turn; they must not report `worker_done` with an unanswered ask. A discovered dependency is `DEPENDENCY P<n> → P<m>: <need> · evidence <file:line> · blocking yes|no`. Handle it according to affected task state:

- Not started: add an agreed contract to the plan; workers reread it at startup. Add a gate for a real wait before dispatch. Orca cannot attach a gate to an active supervised dispatch.
- Running: send the affected worker the decision or a safe-stop instruction. A send is delivered after its current turn, not an immediate interrupt. Wait for safe acknowledgement before changing its branch or assuming it stopped. Use `@all` only when all live workers are affected.
- Scope or order changes: ask the user first, then append the approved decision to `## Changes`. Existing task specs and dependency edges cannot be assumed editable: stop safely, reconcile, then cancel/recreate affected undispatched work or use a linked follow-up, preserving P IDs and history. Do not dispatch replacement work until its gates and dependencies are correct.

Reply to worker asks by message ID. If a reply is refused with `dispatch_inactive`, use Orca `send` to the original dispatch with the answer and associate the resulting follow-up with the same P ID; inspect the receipt. Do not claim the original task reopened. Never consume another agent's inbox or poll it.

- **`comments on #N`:** find the P ID and lane. When the lane is settled and safe, start a linked follow-up on its proven reusable agent; have it read and address the review, then rebase and verify later PRs in stack order. If the lane is active, queue the request and coordinate a safe point first. Never post a review response or comment.
- **`#N merged`:** verify the exact PR with `gh pr view` and require `MERGED`; never rely solely on the user's assertion for merge gates. Record the observed merge and SHA. Before releasing affected work, coordinate each affected lane at a safe point, fetch its current default, update its necessary branches and PR bases, and verify the result as described below. Resolve all corresponding `P<n> merged` gates only after the affected work is ready to use the merged code. Then schedule ready tasks.
- **`G<n> done`:** accept the user's word for the human action, provided its recorded prerequisites are satisfied; resolve each matching gate. Do not check or assert a human deployment yourself.
- **`status`:** give one line per P ID: lane, work/PR/CI state, PR URL, blockers and follow-up if any. Distinguish task completion from PR merge.

Orca does not promise a GitHub CI or merge wake. A worker that sees pending or unavailable CI asks the supervisor and ends its turn; the supervisor requests a user-triggered recheck when appropriate. Never pretend pending, missing or unknown checks are green, and never leave an unanswered ask while reporting done.

## Stacks, recovery and cleanup

A worker starts a PR branch from the freshly fetched repository default or, for an unmerged stack, the immediately previous PR branch. Its PR targets that same base. Record each PR's head SHA and actual base branch/SHA in the task result. If the previous PR merged before the next branch starts, start from the refreshed default instead.

For a merge or review update, do not rebase an active lane or blindly run one `rebase --onto` on the top branch. Identify the old base and head of **each** remaining PR from evidence, then update branches in stack order: the first remaining branch onto the refreshed default, each later branch onto its updated predecessor. Verify each PR's base and diff; retarget where needed, then push using `--force-with-lease` against the observed remote head. Stop and ask on conflicts, missing old tips, unexpected remote changes, or unproven ancestry. Do not resolve downstream merge gates or schedule dependent work until the relevant lane is ready.

Use Orca's recovery reference for failed or unknown starts, exact request replay, retained workers, guarded stops and retries. Silence, a timeout or unverifiable liveness never proves exit. Do not start another supervisor or worker, reset state, or reuse an uncertain resource. The version-matched three-failed-start breaker requires user direction; never route around it. Before any deletion prove identity, ownership, clean checkout, no live/uncertain worker, and that all lane PRs are merged. Remove the lane through `worktree rm --delete-branch`; inspect the receipt and delete only its proven merged leftover local branches, without force. If anything is unclear, ask. Mark the phase workspace completed only when every PR is merged and every phase-completion gate is resolved. Leave the phase and document worktrees for the user to remove.

## Worker brief — include in every PR task

- Follow repository `AGENTS.md`, PR template, approved Rules and the PR's acceptance criteria. Read the absolute plan path and current Contracts at startup; report a missing or inconsistent plan to the supervisor before changing code. Implement only this PR's scope; do not merge, approve, post external comments/messages, change external labels, or decide a human gate.
- Own one branch for this PR, based and targeted as described in Stacks. Check the previous PR's current state and base before branching. Update the lane's Orca card at meaningful checkpoints using `worktree set --worktree current`; keep it factual.
- Validate the changed behavior and report concrete test/review evidence. Open the PR with the authorized base; report PR URL, head SHA, base branch/SHA, and CI evidence for that exact head. A PR is ready only when its requested checks are green for that SHA. Missing, pending, failed or unobservable checks are not green: ask the supervisor and end the turn, without `worker_done` until resolved. Do not silently waive missing CI.
- Send questions and discovered dependencies only to the supervisor with Orca `ask`, then end the turn; await the answer. Do not report done with an unanswered ask. Once the PR is open and CI is green, send the injected dispatch's `worker_done` with outcome succeeded and the PR URL, exact head SHA, base and evidence. Report failures honestly rather than settling as success.
