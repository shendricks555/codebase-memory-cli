#!/bin/bash
# Initialize workspace inside container
# /workspace IS the project root - no subdirectory needed
#
# SECURITY MODEL:
#   - Container has NO GitHub access
#   - Code is pushed FROM host machine TO container via git-daemon
#   - This script just prepares the repo to receive those pushes

set -euo pipefail

cd /workspace

if [ -d ".git" ]; then
    echo "Repository already exists at /workspace"

    # Ensure git config is set
    git config receive.denyCurrentBranch updateInstead

    if [ -z "$(git config user.email 2>/dev/null)" ]; then
        git config user.email "claude@container.local"
        git config user.name "Claude (Container)"
    fi

    echo "Repository configuration verified"
else
    echo "Initializing git repository at /workspace..."
    git init

    # Configure git for the container
    git config user.email "claude@container.local"
    git config user.name "Claude (Container)"

    # Allow pushes to this non-bare repo (updates working directory)
    git config receive.denyCurrentBranch updateInstead

    echo "Empty repository created"
    echo ""
    echo "Push code from host with: git push container <branch>"
fi

# Report detected build system (no auto-build — first build can be slow/noisy)
if [ -x "scripts/build.sh" ]; then
    echo "Detected scripts/build.sh — run it to build the project"
elif [ -f "CMakeLists.txt" ]; then
    echo "Detected CMakeLists.txt — build with: cmake -B build && cmake --build build"
elif [ -f "Makefile" ] || [ -f "makefile" ]; then
    echo "Detected Makefile — build with: make"
fi

# Verify toolchain
echo ""
echo "Environment:"
gcc --version | head -1
clang --version | head -1
cmake --version | head -1

echo ""
echo "Workspace ready at: /workspace"
