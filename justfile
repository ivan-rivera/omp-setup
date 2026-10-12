omp_agent_dir := env("HOME") / ".omp" / "agent"
harness_dir   := justfile_directory() / "harness"
backup_suffix := `date +%Y-%m-%d`
ocr_model     := env_var_or_default("OCR_MODEL", "z-ai/glm-5.3")
ppt_repo    := "https://github.com/hugohe3/ppt-master.git"
ppt_vendor  := justfile_directory() / "vendor" / "ppt-master"
ppt_skill   := harness_dir / "skills" / "ppt-master"
ppt_venv    := env("HOME") / ".local" / "share" / "ppt-master" / "venv"
ppt_python  := env("HOME") / ".local" / "bin" / "python3"

# Show all available targets
help:
    @just --list --unsorted

# Install all dependencies, OMP, plugins, the OCR CLI, PPT Master, and the brag launch-video skills
install: install-deps install-omp install-plugins install-ocr install-ppt-master install-brag

# Install prerequisites (bun, node)
install-deps:
    @echo "Checking bun (requires >= 1.3.14)..."
    @command -v bun >/dev/null 2>&1 \
        && echo "  bun $(bun --version) installed" \
        || { echo "  Installing bun..."; curl -fsSL https://bun.sh/install | bash; }
    @command -v bun >/dev/null 2>&1 && bun --version | awk -F. '{ if ($1 < 1 || ($1 == 1 && $2 < 3) || ($1 == 1 && $2 == 3 && $3 < 14)) { print "  Warning: bun >= 1.3.14 required. Run: bun upgrade"; exit 1 } }'
    @echo "Checking node..."
    @command -v node >/dev/null 2>&1 \
        && echo "  node $(node --version) already installed" \
        || { echo "  Installing node via brew..."; brew install node; }
    @echo "Checking ffmpeg (encodes /skill:brag videos)..."
    @command -v ffmpeg >/dev/null 2>&1 \
        && echo "  ffmpeg already installed" \
        || { echo "  Installing ffmpeg via brew..."; brew install ffmpeg; }

# Install Oh-My-Pi globally via bun
install-omp:
    @echo "Installing Oh-My-Pi..."
    bun install -g @oh-my-pi/pi-coding-agent
    @echo "OMP version: $(omp --version 2>/dev/null || echo 'not found in PATH — restart shell')"

# Install OMP plugins: the impeccable design skill via the pbakaus/impeccable
# marketplace. Loaded by the claude-plugins provider (see harness/config.yml).
install-plugins:
    #!/usr/bin/env bash
    set -euo pipefail
    omp plugin marketplace list 2>/dev/null | grep -q 'pbakaus/impeccable' \
        || omp plugin marketplace add pbakaus/impeccable
    grep -q '"impeccable@impeccable"' "$HOME/.omp/plugins/installed_plugins.json" 2>/dev/null \
        || omp plugin install impeccable@impeccable --scope user
    echo "  impeccable plugin: $(omp plugin list | grep -o 'impeccable@impeccable ([^)]*) ([^)]*)')"

# Update the impeccable plugin to the latest published upstream version
update-impeccable:
    #!/usr/bin/env bash
    set -euo pipefail
    omp plugin marketplace update impeccable
    omp plugin upgrade impeccable@impeccable

# Install/update the OCR (open-code-review) CLI and pin its OpenRouter config.
# Rerunning this target updates the CLI to the latest published version.
install-ocr:
    #!/usr/bin/env bash
    set -euo pipefail
    echo "Installing/updating Open Code Review (ocr)..."
    npm install -g @alibaba-group/open-code-review@latest
    echo "  Installed: $(ocr --version 2>/dev/null | head -1 || true)"
    ocr config set provider openrouter
    ocr config set model "{{ ocr_model }}"
    if [ -n "${OPENROUTER_API_KEY:-}" ]; then
        ocr llm test
    else
        echo "  Warning: OPENROUTER_API_KEY not set — skipped 'ocr llm test' (key is read from the environment at review time)."
    fi
# Install/update the brag launch-video skills from upstream (latent-spaces/brag).
# Fetches skills/brag{,-slim} into gitignored harness/skills/ — this repo carries only the recipe.
# Pass a branch/tag (or commit SHA — falls back to a full fetch) to pin a version: just install-brag v0.4.0
install-brag ref="":
    #!/usr/bin/env bash
    set -euo pipefail
    tmp=$(mktemp -d)
    trap 'rm -rf "$tmp"' EXIT
    git clone --quiet --depth 1 https://github.com/latent-spaces/brag.git "$tmp/brag"
    if [ -n "{{ref}}" ]; then
        [[ "{{ref}}" =~ ^[A-Za-z0-9._/-]+$ ]] || { echo "Invalid ref: {{ref}}" >&2; exit 1; }
        if git -C "$tmp/brag" fetch --quiet --depth 1 origin "{{ref}}"; then
            git -C "$tmp/brag" checkout --quiet FETCH_HEAD
        else
            git -C "$tmp/brag" fetch --quiet --unshallow
            git -C "$tmp/brag" checkout --quiet "{{ref}}"
        fi
    fi
    commit=$(git -C "$tmp/brag" rev-parse --short=12 HEAD)
    # Verify sources, then stage the swap — an abort must never leave neither old nor new.
    [ -d "$tmp/brag/skills/brag" ] && [ -d "$tmp/brag/skills/brag-slim" ] && [ -f "$tmp/brag/LICENSE" ] \
        || { echo "Upstream does not ship skills/brag{,-slim} + LICENSE — aborting, previous install kept." >&2; exit 1; }
    staging="{{ harness_dir }}/skills/.staging-brag"
    rm -rf "$staging"
    mkdir -p "$staging"
    cp -R "$tmp/brag/skills/brag" "$staging/brag"
    cp -R "$tmp/brag/skills/brag-slim" "$staging/brag-slim"
    cp "$tmp/brag/LICENSE" "$staging/brag/LICENSE"
    cp "$tmp/brag/LICENSE" "$staging/brag-slim/LICENSE"
    printf '%s\n' "$commit" | tee "$staging/brag/.upstream-commit" > "$staging/brag-slim/.upstream-commit"
    rm -rf "{{ harness_dir }}/skills/brag" "{{ harness_dir }}/skills/brag-slim"
    mv "$staging/brag" "$staging/brag-slim" "{{ harness_dir }}/skills/"
    rmdir "$staging"
    echo "Installed brag + brag-slim skills at upstream commit $commit → {{ harness_dir }}/skills/ (gitignored)"

# Install/update the PPT Master slide-generation skill: vendor clone, uv venv,
# python3 wrapper, and Python deps. Rerunning pulls the latest upstream.
install-ppt-master:
    #!/usr/bin/env bash
    set -euo pipefail
    echo "Installing/updating PPT Master..."
    command -v uv >/dev/null 2>&1 || brew install uv
    if [ -d "{{ ppt_vendor }}/.git" ]; then
        echo "  Pulling latest upstream..."
        git -C "{{ ppt_vendor }}" pull --ff-only
    else
        echo "  Cloning upstream (one-time, ~260MB)..."
        git clone "{{ ppt_repo }}" "{{ ppt_vendor }}"
    fi
    if [ ! -x "{{ ppt_venv }}/bin/python3" ]; then
        echo "  Creating Python 3.14 venv (uv)..."
        uv python install 3.14
        uv venv --python 3.14 --seed "{{ ppt_venv }}"
    fi
    echo "  Syncing Python dependencies..."
    uv pip install --python "{{ ppt_venv }}/bin/python3" -r "{{ ppt_vendor }}/skills/ppt-master/requirements.txt"
    echo "  Pointing python3 at the PPT Master venv (~/.local/bin/python3)..."
    mkdir -p "$(dirname "{{ ppt_python }}")"
    printf '#!/bin/sh\nexec "%s/bin/python3" "$@"\n' "{{ ppt_venv }}" > "{{ ppt_python }}.tmp"
    mv "{{ ppt_python }}.tmp" "{{ ppt_python }}"
    chmod +x "{{ ppt_python }}"
    ln -sfn ../../vendor/ppt-master/skills/ppt-master "{{ ppt_skill }}"
    echo "  Python: $("{{ ppt_python }}" --version 2>&1)"
    echo "  Skill:  {{ ppt_skill }}"

# Full setup: install everything and symlink harness
setup: install link

# Symlink harness/ to ~/.omp/agent/
link:
    #!/usr/bin/env bash
    set -euo pipefail
    mkdir -p "$(dirname "{{ omp_agent_dir }}")"
    if [ -L "{{ omp_agent_dir }}" ]; then
        current=$(readlink "{{ omp_agent_dir }}")
        if [ "$current" = "{{ harness_dir }}" ]; then
            echo "Already linked: {{ omp_agent_dir }} -> {{ harness_dir }}"
            exit 0
        fi
        echo "Warning: {{ omp_agent_dir }} is a symlink to $current"
        read -p "Overwrite? [y/N] " confirm
        [ "$confirm" = "y" ] || [ "$confirm" = "Y" ] || { echo "Aborted."; exit 1; }
        rm "{{ omp_agent_dir }}"
    elif [ -d "{{ omp_agent_dir }}" ]; then
        backup="{{ omp_agent_dir }}.backup.{{ backup_suffix }}"
        echo "Backing up existing {{ omp_agent_dir }} to $backup"
        mv "{{ omp_agent_dir }}" "$backup"
    fi
    ln -s "{{ harness_dir }}" "{{ omp_agent_dir }}"
    echo "Linked: {{ omp_agent_dir }} -> {{ harness_dir }}"

# Remove symlink and restore backup if one exists
unlink:
    #!/usr/bin/env bash
    set -euo pipefail
    if [ ! -L "{{ omp_agent_dir }}" ]; then
        echo "{{ omp_agent_dir }} is not a symlink — nothing to unlink."
        exit 0
    fi
    rm "{{ omp_agent_dir }}"
    echo "Removed symlink: {{ omp_agent_dir }}"
    latest_backup=$(ls -dt {{ omp_agent_dir }}.backup.* 2>/dev/null | head -1 || true)
    if [ -n "$latest_backup" ]; then
        read -p "Restore backup $latest_backup? [y/N] " confirm
        if [ "$confirm" = "y" ] || [ "$confirm" = "Y" ]; then
            mv "$latest_backup" "{{ omp_agent_dir }}"
            echo "Restored: $latest_backup -> {{ omp_agent_dir }}"
        fi
    fi

# Show current state: symlink, OMP version, plugins
status:
    #!/usr/bin/env bash
    echo "=== Symlink ==="
    if [ -L "{{ omp_agent_dir }}" ]; then
        echo "  {{ omp_agent_dir }} -> $(readlink "{{ omp_agent_dir }}")"
    elif [ -d "{{ omp_agent_dir }}" ]; then
        echo "  {{ omp_agent_dir }} exists (not a symlink)"
    else
        echo "  {{ omp_agent_dir }} does not exist"
    fi
    echo ""
    echo "=== OMP ==="
    if command -v omp >/dev/null 2>&1; then
        echo "  Version: $(omp --version)"
    else
        echo "  Not installed"
    fi
    echo ""
    echo "=== OCR (code review) ==="
    if command -v ocr >/dev/null 2>&1; then
        echo "  Version: $(ocr --version 2>/dev/null | head -1)"
    else
        echo "  Not installed (run: just install-ocr)"
    fi
    echo ""
    echo "=== Environment ==="
    [ -n "${OPENROUTER_API_KEY:-}" ] && echo "  OPENROUTER_API_KEY: set" || echo "  OPENROUTER_API_KEY: NOT SET"
    [ -n "${TAVILY_API_KEY:-}" ]     && echo "  TAVILY_API_KEY: set"     || echo "  TAVILY_API_KEY: NOT SET"

    echo "=== PPT Master ==="
    if [ -f "{{ ppt_skill }}/SKILL.md" ]; then
        echo "  Skill: installed (vendor clone + uv venv + python3 wrapper)"
        echo "  Python: $("{{ ppt_python }}" --version 2>&1 || echo missing)"
    else
        echo "  Not installed (run: just install-ppt-master)"
    fi

# Verify harness structure and OMP config
test:
    #!/usr/bin/env bash
    set -euo pipefail
    ok=true
    fail() { echo "  FAIL: $1"; ok=false; }
    pass() { echo "  OK: $1"; }

    echo "=== Config Files ==="
    for f in config.yml models.yml mcp.json AGENTS.md; do
        [ -f ~/.omp/agent/$f ] && pass "$f" || fail "$f missing"
    done

    echo ""
    echo "=== Agents ==="
    for a in frontend backend architect security qa legal finance researcher content-writer data-generator; do
        [ -f ~/.omp/agent/agents/$a.md ] && pass "$a" || fail "$a missing"
    done

    echo ""
    echo "=== Skills ==="
    for s in brainstorming frontend-design model-scout extension-creator skill-creator ocr-review; do
        [ -f ~/.omp/agent/skills/$s/SKILL.md ] && pass "$s" || fail "$s missing"
    done
    echo ""
    echo "=== Optional Skills (fetched from upstream: just install-brag) ==="
    for s in brag brag-slim; do
        if [ -f ~/.omp/agent/skills/$s/SKILL.md ]; then
            pass "$s ($(cat ~/.omp/agent/skills/$s/.upstream-commit 2>/dev/null || echo '?'))"
        else
            echo "  NOTE: $s not installed (optional — run: just install-brag)"
        fi
    done

    echo ""
    echo "=== PPT Master ==="
    [ -f "{{ ppt_skill }}/SKILL.md" ] && pass "ppt-master skill resolves" || fail "ppt-master skill missing (run: just install-ppt-master)"
    "{{ ppt_python }}" -c 'import sys; sys.exit(0 if sys.version_info >= (3, 10) else 1)' 2>/dev/null \
        && pass "python3 >= 3.10" \
        || fail "python3 >= 3.10 (run: just install-ppt-master)"
    "{{ ppt_python }}" -c 'import pptx, fitz, pathops, uharfbuzz' 2>/dev/null \
        && pass "ppt-master Python deps" \
        || fail "ppt-master Python deps (run: just install-ppt-master)"
    "{{ ppt_python }}" "{{ ppt_skill }}/scripts/attribution_guard.py" >/dev/null 2>&1 \
        && pass "attribution guard (skill unmodified)" \
        || fail "attribution guard — skill must stay unmodified (reinstall: just install-ppt-master)"

    echo ""
    echo "=== Commands ==="
    for c in intro onboard; do
        [ -f ~/.omp/agent/commands/$c.md ] && pass "$c" || fail "$c missing"
    done

    echo ""
    echo "=== Rules ==="
    for r in python-style typescript-style pr-size-limit omp-tips; do
        [ -f ~/.omp/agent/rules/$r.md ] && pass "$r" || fail "$r missing"
    done

    echo ""
    echo "=== OCR (code review) ==="
    command -v ocr >/dev/null 2>&1 && pass "ocr CLI installed" || fail "ocr CLI missing (run: just install-ocr)"

    echo ""
    echo "=== OMP Plugins ==="
    grep -q '"impeccable@impeccable"' "$HOME/.omp/plugins/installed_plugins.json" 2>/dev/null \
        && pass "impeccable plugin" \
        || fail "impeccable plugin missing (run: just install-plugins)"

    echo ""
    echo "=== Hooks ==="
    [ -f ~/.omp/agent/hooks/post/impeccable-design.ts ] \
        && pass "impeccable design detector" \
        || fail "impeccable design detector missing"

    echo ""
    echo "=== OMP Config ==="
    grep -q "disabledProviders" ~/.omp/agent/config.yml && pass "disabledProviders" || fail "disabledProviders missing"
    grep -q "modelRoles" ~/.omp/agent/config.yml && pass "modelRoles" || fail "modelRoles missing"
    grep -q "backend: mnemopi" ~/.omp/agent/config.yml && pass "memory = mnemopi" || fail "memory backend"
    grep -q "openrouter" ~/.omp/agent/models.yml && pass "OpenRouter provider" || fail "OpenRouter missing"
    grep -q "context7" ~/.omp/agent/mcp.json && pass "Context7 MCP" || fail "Context7 missing"
    grep -q "tavily" ~/.omp/agent/mcp.json && pass "Tavily MCP" || fail "Tavily missing"

    echo ""
    $ok && echo "All checks passed." || { echo "Some checks failed."; exit 1; }

# Check required environment variables
check-env:
    #!/usr/bin/env bash
    ok=true
    for var in OPENROUTER_API_KEY TAVILY_API_KEY; do
        if [ -z "${!var:-}" ]; then
            echo "MISSING: $var"
            ok=false
        else
            echo "OK: $var"
        fi
    done
    $ok || { echo ""; echo "Set missing vars in your shell profile (~/.zshrc or ~/.bashrc)."; exit 1; }
