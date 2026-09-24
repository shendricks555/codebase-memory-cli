# 01 — `cli-only-dispatch-verification`

**Milestone:** 01 of 06 | **Status:** READY | **Carries over:** old F4 (`04-cli-only-build-target`, recoverable via `git show 4c69055f:.claude/planning/active/04-cli-only-build-target/`)

## 1. Objective & Rationale
The CLI-only binary builds and links cleanly (old F4 Phase 0, T4.2–T4.4). Its entry-dispatch
behaviour, though, has only been checked with manual smoke runs. This milestone replaces those runs
with automated, repeatable evidence. Without it, every later milestone would sit on unproven
dispatch.

## 2. Architectural Scope
- **Modify:** `tests/test_cli.c` (or add `tests/test_main_dispatch.c` and register it in `Makefile.cbm`/`scripts/test.sh`).
- **Possibly modify:** `cli-only.mk` (a test-harness target that builds the guarded binary for the tests).
- **Code changes in `src/`:** only if a test exposes a defect, and then only inside the existing `CBM_FORK_CLI_ONLY` blocks in `src/main.c` and `src/cli/cli.c`.
- **Untouched:** `src/foundation`, `src/store`, `src/cypher`, `src/pipeline`, `internal/cbm`, `src/daemon/*`.

## 3. Boundary & Guard Constraints
- No new networking. The tests must assert that no socket, cohort or `*.sock` artifacts appear under a temporary `HOME`/`TMPDIR`.
- Any fix stays inside the existing `#ifdef CBM_FORK_CLI_ONLY` fences. The `#else` branches stay byte-identical.

## 4. CLI Contract Expectations
- `codebase-memory-cli` with no arguments, or with an unknown token → prints help to stderr and exits with code 2. It never reads JSON-RPC from stdin.
- `codebase-memory-cli --cbm-daemon-internal` and `codebase-memory-cli daemon status` → help or a refusal, exit code 2, no process spawned.
- `codebase-memory-cli cli <tool> --format json` → valid JSON for all 17 tools. None of them returns `unknown tool`.

## 5. Pre-conditions
Old F1–F3 complete; `cbm-cli` and `verify-cli-only-link` currently PASS.

## 6. Acceptance & Verification Gates
| Eval | Check |
|---|---|
| E3 | Automated: bare and unknown argv → help, rc 2; closed stdin is never read (test under a timeout) |
| E4 | Automated: daemon/daemon-ctl/MCP argv shapes are inert; no artifacts created |
| E5 | Automated: all 17 tools return parseable JSON (validate with yyjson in the test) |
| E6 | Automated: two concurrent `index_repository` runs on one repo are serialized and the DB passes `PRAGMA integrity_check` |
| E7 | `codebase-memory-mcp` `.text`/`.rodata` identical to base `e038fec5` with the guard undefined (the script is saved as a reusable G4 helper) |
| E9 | `/review` PASS |
Plus the standard gates G1–G9 (ROADMAP §5); `scripts/test.sh` is green under ASan + UBSan.

## 7. Sub-Agent Execution Readiness
✅ **READY for `/roadmap-goal`.**
