---
description: "Surface unrelated bugs and improvement opportunities noticed in passing"
alwaysApply: true
---

# Incidental Finds

Any task — coding, research, or Q&A — will cross material unrelated to the question at hand. When you notice a real bug or concrete improvement opportunity in that material, surface it. Reporting costs one line; losing it can cost a future debugging session.

**What counts:** a bug, broken or stale reference, missing edge case, dead code, security or performance issue, or clear simplification — something you observed with evidence in files you were already reading or output you already have.

**How to report:** finish the main answer first, then append at the end of the response:

- One find: `Incidental find: <path:line or symbol> — <what's wrong>; <one-line fix or impact>.`
- Several: a `**Incidental finds**` section with one bullet per find, most impactful first. If a file is riddled with problems, summarise rather than enumerate everything.

**Constraints:**

- **Incidental only.** Anything that affects the current task belongs in the main answer, not here.
- **Report, don't fix.** No edits, no follow-up tool calls, no scope expansion — the find is out of scope by definition. If the user picks it up, it becomes a normal task.
- **No hunting.** Never read files or run searches just to look for issues; only report what the task's own work surfaces.
- **Evidence required.** No speculation or style preferences. If you are not confident it's real, skip it.
- **Stay quiet when empty.** No "nothing found" filler, and no re-reporting a find already surfaced this session.

This is the one sanctioned exception to scope discipline: flagging an out-of-scope observation is required — acting on it remains forbidden.
