---
name: extension-creator
description: "Guide building custom OMP extensions — TypeScript/JavaScript modules that add tools, commands, shortcuts, event hooks, or custom rendering. Use when the user wants to extend OMP beyond what skills and rules can do, needs to hook into session lifecycle events, wants to register custom tools programmatically, or asks about the OMP extension API."
alwaysApply: false
---

# Extension Creator

Guide building OMP extensions — code modules that hook into OMP's runtime.

## When to Use Extensions vs Skills vs Rules

| Mechanism | Use For | Format |
|-----------|---------|--------|
| **Rule** | Style guides, guardrails, conditional instructions | Markdown + YAML frontmatter |
| **Skill** | Multi-step workflows, decision frameworks | Markdown + YAML frontmatter |
| **Command** | Slash commands with prompt templates | Markdown + YAML frontmatter |
| **Extension** | Runtime hooks, custom tools, programmatic behaviour | TypeScript/JavaScript module |

Extensions are the most powerful and most complex. Use them only when the simpler mechanisms aren't sufficient.

## Process

### 1. Clarify Intent

Ask the user what the extension should do. Common extension types:

| Type | API | Example |
|------|-----|---------|
| Custom tool | `pi.registerTool()` | A tool that queries a private API |
| Slash command | `pi.registerCommand()` | `/deploy` that runs a deploy script |
| Keyboard shortcut | `pi.registerShortcut()` | `Ctrl+Shift+T` to run tests |
| Event hook | `pi.on()` | Log tool calls to an external service |
| Message injection | `pi.on('before_agent_start')` | Inject context at session start |

### 2. Scaffold the Module

Extensions live in:
- `~/.omp/plugins/` — global (all sessions)
- `<cwd>/.omp/extensions/` — project-level (this repo only)

**Module structure:**

```typescript
export default (pi) => {
  // Registration happens here — during module load
  // Do NOT call runtime methods (pi.sendMessage, etc.) here

  pi.registerTool({
    name: "my_tool",
    label: "My Tool",
    description: "What this tool does",
    parameters: pi.zod.object({
      input: pi.zod.string().describe("The input"),
    }),
    async execute(toolCallId, params, onUpdate, ctx, signal) {
      // Tool logic
      return { result: "done" };
    },
  });

  pi.registerCommand("my-command", async (args, ctx) => {
    // Command logic
  });

  pi.registerShortcut("ctrl+shift+x", async (ctx) => {
    // Shortcut handler
  });

  pi.on("session_start", async (event) => {
    // React to events
  });

  return {
    dispose() {
      // Cleanup when extension unloads
    },
  };
};
```

### 3. Available Events

**Session lifecycle:**
- `session_start` — session begins
- `session_switch` — user switches sessions
- `session_branch` — session branches
- `session_compact` — context compacted
- `session_shutdown` — session ending

**Turn events:**
- `input` — user sends a message
- `before_agent_start` — before agent processes input
- `before_provider_request` — before LLM API call
- `after_provider_response` — after LLM API response
- `agent_start` / `agent_end` — agent turn lifecycle

**Tool events:**
- `tool_call` — agent calls a tool
- `tool_result` — tool returns result
- `tool_execution_start` / `tool_execution_end` — tool execution lifecycle
- `tool_approval_requested` — tool needs user approval

**Reliability:**
- `auto_compaction_start` — context auto-compaction triggered
- `auto_retry_start` — automatic retry triggered
- `ttsr_triggered` — time-traveling stream rule fired

### 4. Key Constraints

- **No runtime calls during load.** Register tools, commands, and event handlers during module load. Act from within those handlers, not at the top level.
- **Tool names must be unique.** Conflicts with built-in tools are rejected.
- **Use `pi.zod`** for parameter schemas — it's provided by the runtime.
- **Return a `dispose` function** for cleanup (unsubscribe listeners, close connections).
- **File types:** `.ts`, `.js`, `.json`, `.sh`, `.py` are all supported in the tools directory.

### 5. Test and Activate

After creating the extension:

1. Save to the appropriate directory (`plugins/` or `.omp/extensions/`)
2. Run `/reload-plugins` to activate without restarting OMP
3. Verify registration:
   - Tools: check if the tool appears in the available tools list
   - Commands: try invoking the slash command
   - Shortcuts: press the key combination
   - Events: trigger the event and check for expected behaviour

### 6. Validate

- [ ] Module exports a default function
- [ ] No runtime calls during load
- [ ] All registered names are unique
- [ ] `dispose` function cleans up resources
- [ ] Works after `/reload-plugins`
- [ ] Error handling doesn't crash the session

## Constraints

- Don't build an extension when a rule, skill, or command would suffice
- Don't modify OMP internals — use the public `pi` API only
- Don't block the event loop with synchronous heavy computation
- Keep extensions focused — one extension per concern
