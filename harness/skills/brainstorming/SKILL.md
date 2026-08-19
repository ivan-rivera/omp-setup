---
name: brainstorming
description: "Collaborative idea exploration before implementation. Use when the user is starting a new feature, project, or significant change and needs to think through the approach before writing code. Also use when the user says 'let's brainstorm', 'how should we approach this', 'what are our options', or wants to explore design alternatives."
alwaysApply: false
---

# Brainstorming

Turn ideas into designs through collaborative dialogue. Never jump to implementation without understanding the problem and getting approval.

## Step 1: Classify Scope

Before your first question, classify the request and say it out loud so the user can override:

- **Spike** — feasibility question ("can we...", "is it possible..."). Output is an answer, not kept code. Present the question and probe plan in 2-3 sentences, get a nod, investigate cheaply, report a recommendation. Anything built is throwaway.
- **Bounded** — well-scoped change to existing code: a new flag, an endpoint, a one-file fix. The flow you're changing must already exist in the repo. Ask clarifying questions, present a short design in chat, get approval, then implement. No spec document.
- **Architectural** — new project, new subsystem, restructured interfaces. Follow the full process below.

When in doubt, take the heavier path. Hidden complexity discovered mid-task upgrades the path — stop, say so, step up. Nothing downgrades mid-task.

## Step 2: Understand

- Check the current project state (files, docs, recent commits) before asking questions.
- Assess scope first: if the request describes multiple independent subsystems, flag it. Help decompose into sub-projects before diving into details.
- Ask questions **one at a time**. Prefer multiple choice when possible.
- Focus on: purpose, constraints, success criteria, edge cases.

## Step 3: Explore Approaches (Bounded: skip to Step 4)

- Propose 2-3 approaches with trade-offs.
- Lead with your recommendation and explain why.
- Apply YAGNI ruthlessly — remove unnecessary features from every approach.

## Step 4: Present Design

- **Bounded**: a few sentences to a short paragraph in chat. Approach, files touched, testing.
- **Architectural**: present in sections scaled to complexity. Ask after each section if it looks right.
- Cover: architecture, components, data flow, error handling, testing.

## Step 5: Approval Gate

**Present the design and STOP.** Do not start implementation in the same message. Wait for an explicit yes. This gate applies to every path — spike, bounded, and architectural. A simple task means a short design, not no design.

## Step 6: After Approval

- **Spike**: report findings as a recommendation. Label anything built as throwaway.
- **Bounded**: implement directly. No plan document.
- **Architectural**: write a design spec if the complexity warrants it, then create an implementation plan with checkpoints.

## Design Principles

- **Isolation and clarity**: break the system into units with one clear purpose, well-defined interfaces, independently testable.
- **Existing codebases**: explore current structure first. Follow existing patterns. Improve code you're working in, but don't propose unrelated refactoring.
- **Smaller units are better**: if a file is growing large, it's probably doing too much. Smaller units are easier to reason about and less error-prone to edit.

## Red Flags

| Thought | Reality |
|---------|---------|
| "Too simple for a design" | Simple means a short design, not no design |
| "I'll start while they read it" | The gate is the approval, not the design's length |
| "I understand this kind of app" | Bounded measures the repo, not your familiarity |
| "It grew, but I'm almost done" | Hidden complexity upgrades the path. Stop and say so |
