omp_agent_dir := env("HOME") / ".omp" / "agent"
harness_dir   := justfile_directory() / "harness"
backup_suffix := `date +%Y-%m-%d`

# Show all available targets
help:
    @just --list --unsorted

# Install all dependencies, OMP, and plugins
install: install-deps install-omp install-plugins

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

# Install Oh-My-Pi globally via bun
install-omp:
    @echo "Installing Oh-My-Pi..."
    bun install -g @oh-my-pi/pi-coding-agent
    @echo "OMP version: $(omp --version 2>/dev/null || echo 'not found in PATH — restart shell')"

# Install OMP plugins (populated as needed)
install-plugins:
    @echo "No plugins to install yet."

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
    echo "=== Environment ==="
    [ -n "${OPENROUTER_API_KEY:-}" ] && echo "  OPENROUTER_API_KEY: set" || echo "  OPENROUTER_API_KEY: NOT SET"
    [ -n "${TAVILY_API_KEY:-}" ]     && echo "  TAVILY_API_KEY: set"     || echo "  TAVILY_API_KEY: NOT SET"

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
    for s in brainstorming frontend-design model-scout extension-creator skill-creator; do
        [ -f ~/.omp/agent/skills/$s/SKILL.md ] && pass "$s" || fail "$s missing"
    done

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
