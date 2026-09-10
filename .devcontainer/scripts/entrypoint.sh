#!/bin/bash
set -e

GIT_PORT="${GIT_DAEMON_PORT:-47418}"
PROJECT_NAME="${PROJECT_NAME:-myproject}"

# =============================================================================
# Shell Configuration Setup (handles volume-mounted home directory)
# =============================================================================
# Volume mounts can wipe out configs copied during Docker build.
# Copy from /etc/skel backup if missing.

echo "Setting up shell configuration..."

mkdir -p "$HOME/.config"

if [ ! -f "$HOME/.zshrc" ]; then
    if [ -f /etc/skel/.zshrc ]; then
        cp /etc/skel/.zshrc "$HOME/.zshrc"
        echo "  Copied .zshrc from template"
    fi
fi

if [ ! -f "$HOME/.config/starship.toml" ]; then
    if [ -f /etc/skel/.config/starship.toml ]; then
        cp /etc/skel/.config/starship.toml "$HOME/.config/starship.toml"
        echo "  Copied starship.toml from template"
    fi
fi

# =============================================================================
# Git daemon
# =============================================================================
echo "Starting git-daemon on port $GIT_PORT..."
git daemon --reuseaddr --base-path=/ \
    --export-all --enable=receive-pack \
    --listen=0.0.0.0 --port=$GIT_PORT \
    --detach

# Health check - verify git-daemon is running
sleep 1
if nc -z localhost $GIT_PORT 2>/dev/null; then
    echo "git-daemon is running on port $GIT_PORT"
else
    echo "git-daemon failed to start"
    exit 1
fi

# =============================================================================
# Startup banner
# =============================================================================
echo ""
echo "========================================================================"
echo "  CLAUDE CODE DEV CONTAINER (C)"
echo "========================================================================"
echo ""
echo "  Services:"
echo "    Git Daemon: localhost:$GIT_PORT"
echo ""
echo "  Toolchain:"
echo "    $(gcc --version | head -1)"
echo "    $(clang --version | head -1)"
echo "    $(cmake --version | head -1)"
echo ""
echo "  Run: claude --dangerously-skip-permissions"
echo "  Or:  c (alias)"
echo ""
echo "========================================================================"
echo ""

# Execute the command passed to the container (default: zsh)
exec "$@"
