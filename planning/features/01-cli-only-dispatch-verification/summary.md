# 01 — `cli-only-dispatch-verification`

**Milestone:** 01 of 06 | **Status:** COMPLETED | **Carries over:** old F4 (`04-cli-only-build-target`)

## 1. Objective
The CLI-only binary built and linked cleanly, but its entry dispatch had only been checked by hand.
This milestone adds a repeatable smoke test, so later milestones build on dispatch that has been shown to work.

## 2. Scope
- **Added:** `tests/test_cli_only_smoke.sh`, plus the `test-cli-only` target in `cli-only.mk`.
- **`src/` changes:** none needed. A defect fix would be allowed only inside existing
  `CBM_FORK_CLI_ONLY` blocks in `src/main.c` / `src/cli/cli.c`.
- **Untouched:** shared core, `src/daemon/*`, `src/mcp/*`, `Makefile.cbm`.

## 3. Checks
| Eval | Check | Result |
|---|---|---|
| E3 | Bare and unknown argv → help, rc 2, and no hang when stdin is held open | ✅ |
| E4 | Daemon, daemon-ctl, MCP-shaped and worker argv are inert. Hooks are fail-open. No socket or daemon artifacts appear | ✅ |
| E5 | All 17 tools return one JSON document via `cli --json` | ✅ |
| E6 | Concurrent `index_repository` runs serialize, and the DB passes `integrity_check` | ✅ |
| Link | `make -f Makefile.cbm verify-cli-only-link` | ✅ |

Dropped as out of proportion: the E7 byte-for-byte comparison of the default build, the formal
gate and evidence records, and the full-suite run (no `src/` changed).
