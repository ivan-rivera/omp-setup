---
description: "TypeScript style conventions"
globs: ["*.ts", "*.tsx", "*.js", "*.jsx"]
alwaysApply: false
---

# TypeScript Style

- Strict mode (`"strict": true` in tsconfig). No `any` unless explicitly justified.
- Explicit return types on exported functions and public methods.
- `const` by default. `let` only when reassignment is needed. Never `var`.
- Named exports over default exports. One exception: page/route components if the framework requires it.
- Barrel files (`index.ts`) only at package boundaries, not in every directory.
- Prefer `interface` over `type` for object shapes. Use `type` for unions, intersections, and mapped types.
- Prefer `async/await` over `.then()` chains.
- Nullish coalescing (`??`) over `||` for defaults. Optional chaining (`?.`) over nested checks.
- No unused imports or variables — enable the linter rule, don't leave dead code.
- Prefer early returns to reduce nesting. Guard clauses at the top of functions.
- Enums: prefer `as const` objects over TypeScript `enum` unless you need reverse mapping.
