import { existsSync, readFileSync } from "node:fs";
import { homedir } from "node:os";
import { dirname, extname, join, resolve } from "node:path";

/**
 * OMP port of Impeccable's design-detector hook (upstream: Claude PostToolUse).
 *
 * Fires after `edit`/`write` on UI files, but only inside projects that opted
 * into Impeccable (`.impeccable/` at or above the edited file — created by
 * `/skill:impeccable init`). Pipes a Claude-shaped PostToolUse payload into
 * the plugin-installed engine (`omp plugin install impeccable@impeccable`)
 * and surfaces its findings to the model as additional context.
 *
 * Upstream also runs a full-rule Stop deep pass via Claude's Stop hook loop;
 * this port covers the per-edit pass only.
 *
 * Kill switches:
 *   - `IMPECCABLE_HOOK_DISABLED` in the environment (also honored by the engine)
 *   - `hook.enabled: false` in the project's `.impeccable/config(.local).json`
 *   - no `.impeccable/` at or above the edited file (not an Impeccable project)
 *   - `IMPECCABLE_PLUGIN_DIR` env var to relocate the plugin install
 */

const PLUGIN_DIR =
  process.env["IMPECCABLE_PLUGIN_DIR"] ?? join(homedir(), ".omp", "plugins", "node_modules", "impeccable");
const LAUNCHER = join(PLUGIN_DIR, "skills", "impeccable", "scripts", "impeccable");

/** Static extension allowlist the engine's per-edit pass also gates on. */
const UI_EXTENSIONS: Record<string, true> = {
  ".html": true,
  ".htm": true,
  ".css": true,
  ".scss": true,
  ".sass": true,
  ".less": true,
  ".jsx": true,
  ".tsx": true,
  ".js": true,
  ".ts": true,
  ".vue": true,
  ".svelte": true,
  ".astro": true,
  ".blade.php": true,
};
const EDIT_TOOLS: Record<string, true> = { edit: true, write: true };
const PER_EDIT_TIMEOUT_MS = 5000;

interface ToolResultEvent {
  toolName?: unknown;
  input?: unknown;
  isError?: unknown;
}

interface HookContext {
  cwd?: unknown;
  sessionManager?: { getSessionFile?: () => unknown };
}

interface PiApi {
  on(
    event: "tool_result",
    handler: (event: ToolResultEvent, ctx: HookContext) => Promise<{ additionalContext?: string } | void>,
  ): void;
}

function readJson(file: string): Record<string, unknown> | null {
  if (!existsSync(file)) return null;
  try {
    const parsed: unknown = JSON.parse(readFileSync(file, "utf8"));
    return typeof parsed === "object" && parsed !== null ? (parsed as Record<string, unknown>) : null;
  } catch {
    return null;
  }
}

/**
 * Nearest ancestor of `file` with an `.impeccable/` dir, or null when the edit
 * is not inside an Impeccable project. `hook.enabled: false` in that project's
 * config disables the hook for it.
 */
function findProjectRoot(file: string): string | null {
  let dir = dirname(file);
  for (;;) {
    if (existsSync(join(dir, ".impeccable"))) {
      const shared = readJson(join(dir, ".impeccable", "config.json"));
      const local = readJson(join(dir, ".impeccable", "config.local.json"));
      const hook = (local?.["hook"] ?? shared?.["hook"]) as Record<string, unknown> | undefined;
      if (hook?.["enabled"] === false) return null;
      return dir;
    }
    const parent = dirname(dir);
    if (parent === dir) return null;
    dir = parent;
  }
}

function firstString(...values: unknown[]): string | null {
  for (const value of values) {
    if (typeof value === "string" && value.length > 0) return value;
  }
  return null;
}

function sessionId(ctx: HookContext): string {
  try {
    const file = ctx.sessionManager?.getSessionFile?.();
    return typeof file === "string" && file.length > 0 ? file : "omp";
  } catch {
    return "omp";
  }
}

/** Claude/Codex/Grok stdout shape plus the flat Cursor/GitHub variants. */
function extractContext(stdout: string): string | null {
  let parsed: unknown;
  try {
    parsed = JSON.parse(stdout);
  } catch {
    return null;
  }
  if (typeof parsed !== "object" || parsed === null) return null;
  const root = parsed as Record<string, unknown>;
  const hookSpecific = root["hookSpecificOutput"];
  if (typeof hookSpecific === "object" && hookSpecific !== null) {
    const nested = (hookSpecific as Record<string, unknown>)["additionalContext"];
    if (typeof nested === "string" && nested.trim().length > 0) return nested;
  }
  const flat = firstString(root["additionalContext"], root["additional_context"]);
  return flat !== null && flat.trim().length > 0 ? flat : null;
}

async function runDetector(
  projectRoot: string,
  filePath: string,
  toolName: string,
  session: string,
): Promise<string | null> {
  // A missing launcher (plugin not installed) is a silent no-op,
  // same as upstream's guarded hook manifests.
  if (!existsSync(LAUNCHER)) return null;
  const payload = JSON.stringify({
    session_id: session,
    cwd: projectRoot,
    hook_event_name: "PostToolUse",
    tool_name: toolName === "write" ? "Write" : "Edit",
    tool_input: { file_path: filePath },
  });
  let proc: Bun.Subprocess;
  try {
    proc = Bun.spawn([LAUNCHER, "hook"], {
      cwd: projectRoot,
      stdin: "pipe",
      stdout: "pipe",
      stderr: "pipe",
      timeout: PER_EDIT_TIMEOUT_MS,
      env: { ...process.env, IMPECCABLE_HOOK_HARNESS: "claude" },
    });
  } catch {
    return null;
  }
  try {
    await proc.stdin.write(payload);
    await proc.stdin.end();
    const stdout = await new Response(proc.stdout).text();
    const code = await proc.exited;
    return code === 0 ? extractContext(stdout) : null;
  } catch {
    return null;
  }
}

export default function impeccableDesignHook(pi: PiApi): void {
  pi.on("tool_result", async (event, ctx) => {
    const toolName = typeof event.toolName === "string" ? event.toolName : "";
    if (!(toolName in EDIT_TOOLS) || event.isError === true) return;
    const input = typeof event.input === "object" && event.input !== null ? (event.input as Record<string, unknown>) : {};
    const rawPath = firstString(input["path"], input["file_path"], input["filePath"]);
    if (rawPath === null) return;
    const cwd = typeof ctx.cwd === "string" && ctx.cwd.length > 0 ? ctx.cwd : process.cwd();
    const filePath = resolve(cwd, rawPath);
    const ext = filePath.toLowerCase().endsWith(".blade.php") ? ".blade.php" : extname(filePath).toLowerCase();
    if (!(ext in UI_EXTENSIONS)) return;
    const projectRoot = findProjectRoot(filePath);
    if (projectRoot === null) return;
    const findings = await runDetector(projectRoot, filePath, toolName, sessionId(ctx));
    if (findings === null) return;
    return { additionalContext: findings };
  });
}