---
description: "Cross-session agent communication with the intercom plugin: messaging other live OMP sessions, send vs ask, aliasing, when to prefer subagents/herdr/vault"
alwaysApply: false
---

# Intercom (cross-session messaging)

The `intercom` tool (pi-intercom plugin) passes messages between separate, live OMP sessions on this machine — the channel `task` subagents and `agent://` cannot cross, since those are process-local. Address peers by `/alias` name, session ID, or the short ID from `intercom({ action: "list" })`. A delivered message wakes an idle recipient as a new turn; every inbound message embeds a reply hint (`action: "reply", replyTo: ...`) — use it so the sender's `ask` resolves.

## Use it when

- Coordinating with another live session the user is running: planner ↔ worker across terminals, asking a peer session a question, reporting findings into an executing session.
- You are a delegated worker in one session and need a decision from the session that dispatched you.

## Don't use it when

- The peer is a subagent of this session — use `task` / `write agent://<id>`.
- The note must outlive the session or be pulled on demand — write to the agents vault (`/skill:agents-vault`); intercom is live coordination, not a durable record.
- You can proceed independently — don't interrupt another session for trivia.
- Spawning or monitoring worker tabs — herdr owns lifecycle (`/skill:orchestrate`); intercom owns the messages between live sessions (and can open a herdr pane via `openProjectPaneIfMissing`).

## Discipline

- `/alias <slug>` before participating, so peers can target this session by name instead of a generated fallback.
- Prefer `send` (fire-and-forget). `ask` blocks this turn up to 10 minutes — only when genuinely blocked on the answer; one pending `ask` at a time.
- Messages must be self-contained: the peer shares none of this conversation. Name exact files, symbols, and decisions.
- Treat replies from other sessions like any agent output — verify before building on them.
- `handover` summarizes this session and transfers its remaining work to a peer; `pending` lists unresolved inbound asks.
