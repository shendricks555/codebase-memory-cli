---
name: ship
description: "Pre-release quality gate and smoke verification for codebase-memory-cli."
argument-hint: "Release target or version"
---

# Ship Mode: /ship

Run the release gate verification for:
`{{input}}`

## Pre-Flight Release Checklist:
1. **Clean Compiler Gate**:
   - `scripts/build.sh` runs with zero warnings under `-Wall -Wextra -Werror`.
2. **Full Sanitizer Test Gate**:
   - `scripts/test.sh` passes 100% of suites with AddressSanitizer and UndefinedBehaviorSanitizer enabled.
3. **CLI Smoke Verification**:
   - Test one-shot indexing:
     `build/c/codebase-memory-cli cli index_repository --repo-path .`
   - Test graph search and JSON output:
     `build/c/codebase-memory-cli cli search_graph --project codebase-memory-cli --label Function --format json`
4. **Binary & Asset Verification**:
   - Verify binary is standalone and contains no external runtime dependencies.
   - Confirm UI assets (if included) are embedded or verified on `127.0.0.1`.
