# codebase-memory-cli — Copilot & Agent System Instructions

## Project Identity & Architecture
- **Language**: Pure C (C99/C11 standard, POSIX-compliant) with vendorized C++ AST grammars.
- **Target**: Native standalone CLI executable (`codebase-memory-cli`).
- **Core Philosophy**: Zero background daemons, zero IPC sockets, zero network requests, zero MCP runtime. All operations run as fast, one-shot CLI commands outputting machine-readable JSON or compact trees.
- **Architectural Guard**: Every modification removing or replacing upstream MCP/daemon features MUST be guarded by `#ifdef CBM_FORK_CLI_ONLY` or `#ifndef CBM_FORK_CLI_ONLY`.
- **Shared Codebases (Do Not Break)**: `src/foundation/`, `src/store/`, `src/cypher/`, `src/pipeline/`, and `internal/cbm/` remain upstream-mergeable.

---

## C Coding & Memory Standards
1. **Memory Allocation**:
   - Every `malloc`/`calloc`/`strdup` must have a verifiable `free` path or explicit ownership lifecycle.
   - Never leak file descriptors (`close`) or SQLite handles (`sqlite3_finalize`, `sqlite3_close_v2`).
   - Use RAII-like cleanup macros/patterns where established in `src/foundation/`.
2. **Buffer & String Safety**:
   - Zero use of unsafe functions (`sprintf`, `strcpy`, `strcat`, `gets`). Use `snprintf`, bounded buffers, or foundation dynamic string builders.
   - Guard against integer overflows when computing allocation sizes.
3. **Thread Safety & Locks**:
   - One-shot CLI tools must avoid global mutable state.
   - Project mutations must acquire OS-level project file locks (`cbm_lock_*`).
4. **Error Handling**:
   - Functions returning `int` status must return `0` / `CBM_SUCCESS` on success and descriptive negative error codes on failure.
   - Output structured JSON errors on `stdout`/`stderr` adhering to `--format json` schema.

---

## Build, Run, and Test Workflows
- **Clean Build with Sanitizers (ASan + UBSan)**:
  `scripts/build.sh` or `ninja -C build/c`
- **Run Complete Test Suite**:
  `scripts/test.sh`
- **Run Specific Suite**:
  `scripts/test.sh --suites <suite_name>`
- **Run CLI Binary**:
  `build/c/codebase-memory-cli cli <tool_name> --format json`

---

## Behavioral Rules for Copilot
- **Verification First**: Do not claim a change works until you have checked build logs, compiler warnings (`-Wall -Wextra -Werror`), and test results.
- **Anti-Hallucination**: Check struct definitions and header signatures in `include/` and `src/foundation/` before implementing or calling functions.
- **No Scope Creep**: Keep diffs minimal, focused on the requested CLI subcommands, and strictly conforming to CLI-only invariants.
