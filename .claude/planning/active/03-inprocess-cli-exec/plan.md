# Plan: Daemon-free in-process CLI tool execution

Derived from `spec.md`. Feature F3, depends on F2 (✅ fully complete).

> **Verification note:** graph tools down this session (`CONNECTION_CLOSED`);
> paths/line numbers filesystem-verified via grep/Read, not graph-verified.
> Re-confirm `run_cli` callers/`project_lock` deps with `trace_path` at
> implement time if the server returns.

## Overview

Under `CBM_FORK_CLI_ONLY`, re-point `run_cli`'s non-worker branch (src/main.c:
933-934, today → `main_local_cli_daemon_execute` at src/main.c:1734) to the
**in-process** engine path already present for the index worker (src/main.c:
936-953: `cbm_mcp_server_new` + `cbm_mcp_handle_tool`, background tasks off,
mutation-guard hooks). Retain `project_lock` (file locks), drop `version_cohort`
(admission barrier) under the guard. Default build (guard undefined) unchanged.

**Sequencing dependency (drives Phase 0):** the CLI-only build *target* that
defines the guard is F4. To exercise F3's guarded path now, we build the
**existing** source set with `-DCBM_FORK_CLI_ONLY=1` (daemon still linked, just
bypassed by `run_cli`). That is a valid verification binary; F4 later drops the
daemon from the link line. Mirrors F2's `verify-mcp-engine-split` pattern.

**Scope guard:** edits confined to `src/main.c` + `src/cli/cli.c` + `Makefile.cbm`
(verify target) + `tests/`. No shared-core edits. No new socket/listener.

## Eval Coverage

| Eval | Phase | Verification method |
|---|---|---|
| E1 no socket/daemon on guarded path | 4 (test) → N | `scripts/security-network.sh`-style `strace -e trace=network` on the guarded binary; assert no `socket/connect/bind/listen` |
| E2 output parity guarded vs daemon | 4 (test) → N | diff `--json` + `--format json` over a fixed tool+repo corpus, both guard states |
| E3 all 17 tools reachable in-process | 4 (test) → N | invoke each tool via guarded `cli`, assert non-error envelope |
| E4 mutation locking retained | 4 (test) → N | two concurrent guarded `index_repository` on one project; serialized, no corruption (extend `tests/test_cli.c` / mutation-guard suite) |
| E5 no cohort barrier under guard | 4 → N | seam/symbol check: `version_cohort` manager not constructed on guarded path |
| E6 `project_lock.c` builds without rest of daemon | 0 | compile/link `project_lock.o` against only its real deps; record for F4 |
| E7 default build unchanged | N | `make -f Makefile.cbm cbm` + suite green; guard-undefined path still daemon-routed |

## NFR Impact

| NFR | Impact | Mitigation |
|---|---|---|
| Removes R-6 daemon/cohort startup-wedge class | Positive | cohort barrier not engaged under guard (FR-4) |
| Latency: one-shot store open vs warm daemon | Slight per-invocation cost | acceptable for CLI; note for indexing loops; measure in E2 timing if cheap |
| Mergeability | main.c/cli.c are fork-owned edges (not shared core) | guard-scoped `#ifdef` blocks; no core edits |
| No-network | Must add zero net primitives | E1 asserts none on guarded path |

## Phase 0 — Build/config + dependency isolation (`Makefile.cbm`)

No test-writing task (build harness only).

- **T0.1** Add a guarded verification build (e.g. `cbm-fork-verify`): links the
  current source set with `-DCBM_FORK_CLI_ONLY=1` (daemon still linked, guard
  active) → a runnable binary that takes the in-process `run_cli` branch. NOT a
  default/prod target; not in `PROD_SRCS`; no TEST_SEAMS in a release variant.
- **T0.2 (E6 / FR-5)** Add a check that compiles/links `src/daemon/project_lock.c`
  against only its actual dependencies (foundation + its own header), proving it
  does **not** pull in `version_cohort`/`ipc`/`frontend`/`host`. Record the
  result (and any entanglement) as an explicit F4 hand-off note in
  `progress.json`.

## Phase 4 — CLI in-process execution (`src/main.c`, `src/cli/cli.c`) — TDD

Per testing rule (`src/cli` touched), tests precede implementation.

- **T4.1 (test)** Extend `tests/test_cli.c` (and/or the mutation-guard suite)
  with: (a) output-parity fixtures for `--json` and `--format json` (E2), (b) a
  concurrent-mutation serialization test via `project_lock` (E4), (c) an
  all-tools-reachable smoke over the 17 tool names (E3). Tests target the
  guarded build/seam.
- **T4.2 (impl)** In `run_cli` (src/main.c:792), under `#ifdef
  CBM_FORK_CLI_ONLY` take the in-process branch for the **non-worker** case:
  generalize the existing worker-only block (src/main.c:936-960) so any `cli
  <tool>` runs via `cbm_mcp_server_new`+`cbm_mcp_handle_tool` with
  `cbm_mcp_server_set_background_tasks(false)` and the mutation-guard hooks
  (src/main.c:944-947) wired for mutating tools. Guard-undefined path keeps
  `main_local_cli_daemon_execute` (src/main.c:1734) verbatim. (FR-1, FR-2, FR-8)
- **T4.3 (impl)** Under the guard, do **not** construct/acquire the
  `version_cohort` manager (src/main.c:2755) or require its lease; keep
  `project_lock` manager (src/main.c:2753-2754) active. Fence the cohort refs in
  `src/cli/cli.c` (includes + activation logic, cli.c:19,197-199,…) behind the
  guard so the guarded build neither needs nor engages the barrier. (FR-3, FR-4)
- **T4.4 (impl)** Ensure `index_repository` under the guard drives
  `index_supervisor` directly in-process, not a daemon job. (FR-8)
- **T4.5 (verify)** Confirm no `socket()/connect()/bind()/listen()` reachable on
  the guarded path (grep the guarded compilation units + E1 strace). (FR-6)

## Phase N — Validation

- **TN.1** Default build green + guard-undefined path still daemon-routed:
  `make -f Makefile.cbm cbm` + `scripts/test.sh` (E7).
- **TN.2** Guarded verification binary: E1 (no net syscalls), E2 (parity), E3
  (17 tools), E4 (lock), E5 (no cohort).
- **TN.3** E6 project_lock isolation result recorded for F4.
- **TN.4** `/quality-gate`: guard-scoped diff, no new socket/listener, cohort
  dropped only under guard, default path byte-unchanged.

## Rollback

Guarded `#ifdef` blocks are additive to the default path; reverting the branch
restores upstream `run_cli`. No schema/data migration.

## Open risks (for implementer)

- The current in-process block only assigns `result` when `maintenance_context`
  is set (src/main.c:951-953). Generalizing to all `cli` tools must handle the
  no-maintenance-context case without leaking the mutation lease or skipping
  `cbm_mcp_server_free`. Cover in T4.1 tests.
- `project_lock.c` living under `src/daemon/` (a removal target) is intentional
  for F3 (daemon still linked); FR-5/E6 is the gate that F4 can keep it alone.
