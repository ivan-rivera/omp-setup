---
name: skill-creator
description: "Create new OMP skills, modify existing skills, and optimize skill triggering. Use when the user wants to create a skill from scratch, edit or improve an existing skill, turn a workflow into a reusable skill, or optimize a skill's description for better triggering accuracy."
alwaysApply: false
---

# Skill Creator

Create new skills and iteratively improve them.

The core loop: decide what it should do → interview → draft → test → evaluate → improve → repeat.

Figure out where the user is in this process and help them progress. Maybe they want to build from scratch. Maybe they already have a draft. Maybe they want to turn something from this conversation into a skill ("turn this into a skill"). Be flexible.

## Communicating

Match the user's level. Don't assume jargon familiarity — if in doubt, briefly explain terms. Some users are seasoned engineers, some are exploring for the first time. Read context cues.

---

## Creating a Skill

### 1. Capture Intent

If the conversation already contains a workflow the user wants to capture, extract answers from the history first — tools used, sequence of steps, corrections made, input/output formats. The user fills gaps and confirms.

Ask:
1. What should this skill enable the agent to do?
2. When should it trigger? (user phrases, file types, contexts)
3. What's the expected output format?
4. Should we set up test prompts to verify it works?

### 2. Interview and Research

Proactively ask about edge cases, input/output formats, example scenarios, success criteria, and dependencies. Don't jump to drafting until this is solid.

Check available MCPs and tools — if useful for research (searching docs, finding similar patterns), do it. Come prepared with context to reduce burden on the user.

### 3. Write the SKILL.md

#### Skill Anatomy

```
skill-name/
├── SKILL.md              # Required — instructions
├── scripts/              # Executable code for deterministic tasks
├── references/           # Docs loaded into context as needed
└── assets/               # Templates, icons, fonts used in output
```

#### Progressive Disclosure

Skills use a three-level loading system:
1. **Metadata** (name + description) — always in context (~100 words)
2. **SKILL.md body** — in context when skill triggers (<500 lines ideal)
3. **Bundled resources** — loaded on demand via `skill://skill-name/path` (unlimited size)

Keep SKILL.md under 500 lines. If approaching this limit, break content into reference files with clear pointers about when to read them.

For large reference files (>300 lines), include a table of contents.

#### Domain Organization

When a skill supports multiple domains/frameworks, organize by variant:
```
cloud-deploy/
├── SKILL.md (workflow + selection logic)
└── references/
    ├── aws.md
    ├── gcp.md
    └── azure.md
```
The agent reads only the relevant reference file.

#### Frontmatter

```yaml
---
name: skill-name
description: "When to trigger and what it does"
globs: ["*.ext"]          # omit if not file-scoped
alwaysApply: false        # true only if always-active
---
```

**The `description` is the primary triggering mechanism.** Include both what the skill does AND specific contexts for when to use it. Be slightly "pushy" — models tend to undertrigger skills. Instead of:

> "Format database migrations"

Write:

> "Format and validate database migrations. Use whenever the user mentions migrations, schema changes, ALTER TABLE, database versioning, or asks about data model changes, even if they don't explicitly say 'migration'."

#### Writing the Body

- **Imperative form.** "Do X", "Ask the user Y" — not "This skill does X".
- **Explain the why.** Instead of heavy-handed MUSTs, explain reasoning so the agent understands the intent and can adapt to edge cases. If you find yourself writing ALWAYS or NEVER in all caps, reframe with reasoning.
- **Include examples.** Show input/output pairs:
  ```markdown
  ## Commit message format
  **Example 1:**
  Input: Added user authentication with JWT tokens
  Output: feat(auth): implement JWT-based authentication
  ```
- **Define output formats** with templates when structure matters.
- **Keep it lean.** Remove things that aren't pulling their weight. Every instruction should earn its place.
- **Don't overfit.** Write for general use, not just the examples you tested with.

### 4. Test the Skill

Come up with 2-3 realistic test prompts — the kind of thing a real user would actually say. Share them: "Here are a few test cases I'd like to try. Do these look right, or do you want to add more?"

Run each test by spawning a task with the skill loaded (via `autoloadSkills` on a test agent or by starting a session with the skill active).

Evaluate results with the user:
- **Qualitative:** does the output match expectations? What's wrong?
- **Quantitative:** if the skill has objectively verifiable outputs, check them programmatically

### 5. Improve

After reviewing test results:

1. **Generalize from feedback.** The skill will be used many times across many prompts. Don't overfit to test cases — if there's a stubborn issue, try different metaphors or patterns rather than adding rigid constraints.
2. **Keep the prompt lean.** Read test transcripts, not just outputs. If the skill makes the agent waste time on unproductive steps, remove those instructions.
3. **Look for repeated work.** If all test cases independently wrote similar helper scripts, bundle that script in `scripts/` and reference it from the skill.
4. **Rerun tests** after improvements. Compare with previous iteration. Repeat until the user is happy or feedback is all positive.

### 6. Validate

After finalising:
- [ ] Directory exists at the correct path
- [ ] SKILL.md has valid YAML frontmatter with `name` and `description`
- [ ] `name` in frontmatter matches directory name
- [ ] Description is specific and "pushy" enough for reliable triggering
- [ ] Skill body is under 500 lines (use references/ for overflow)
- [ ] No placeholder content — everything is functional
- [ ] Test: `/skill:<name>` appears in OMP's skill listing

### 7. Register

If the skill should be discoverable via OMP tips, add an entry to `harness/rules/omp-tips.md` in the custom skills table.

---

## Improving an Existing Skill

When the user wants to improve a skill:

1. Read the current SKILL.md and understand what it does
2. Ask what's not working or what they want changed
3. If test prompts exist, rerun them to establish a baseline
4. Apply improvements following the same principles (generalize, keep lean, explain why)
5. Rerun tests and compare

---

## Description Optimization

The description is the primary trigger. To optimize it:

1. Generate 15-20 test queries — a mix of should-trigger (8-10) and should-not-trigger (8-10)
2. Make queries realistic and detailed, not abstract. Include file paths, personal context, casual speech, typos
3. For should-not-trigger, focus on near-misses — queries that share keywords but need something different. "Write a fibonacci function" as a negative for a PDF skill is too easy
4. Review the query set with the user
5. Test each query against the current description — does the model invoke the skill appropriately?
6. Revise the description based on failures and retest

---

## Common Mistakes

- **Too broad**: a skill that tries to cover "all testing" — narrow to a specific workflow
- **Too verbose**: instruction paragraphs that could be bullet points
- **Duplicating rules**: style guides belong in rules, not skills
- **Missing constraints**: without boundaries, the agent will over-deliver
- **Weak description**: vague descriptions cause undertriggering — be specific and pushy
- **Overfit instructions**: rigid MUSTs that work for test cases but break on real usage
