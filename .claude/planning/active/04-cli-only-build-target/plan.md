# Plan: CLI-only build target & entry dispatch (guarded)

> **Context note:** graph tools were down this session (`CONNECTION_CLOSED`);
> paths/reference-graph below are **filesystem-verified** (grep/Read), not
> graph-verified. Re-confirm the daemon reference graph with
> `trace_path`/`query_graph` at implement time if the server returns. Builds on
> **F2 (✅)** split engine and **F3 (✅)** in-process `run_cli`.

## Overview

F4 turns the `CBM_FORK_CLI_ONLY` guard (behavioral since F3) into a **shippable
binary**: a new additive `Makefile.cbm` target `cbm-cli` →
`build/c/codebase-memory-cli` that links the CLI-only source set and whose entry
dispatch prints help instead of ever starting an MCP stdio server. The upstream
default target (`make -f Makefile.cbm cbm`) stays byte-for-byte unchanged; all
`src/main.c` edits are guard-scoped and the new target/build.sh flag are purely
additive.

### Plan-time finding (link isolation is the crux — correcting the F3 hand-off)

F3's hand-off said "retain the self-contained `ipc` helper + endpoint type
alongside `project_lock`." Reality is more entangled (grep-verified):

- Only `src/daemon/ipc.c` carries the 5 daemon sockets;
  `bootstrap.c`/`project_lock.c`/`frontend.c` carry **zero**.
- But the argv classifier `cbm_daemon_process_role` **lives in `bootstrap.c`**,
  and `bootstrap.c` *also* references `ipc.c` coordination functions
  (`cbm_daemon_ipc_endpoint_new`, `_lifetime_reservation_probe`,
  `_startup_lock_try_acquire/_release/_prepare_handoff` — bootstrap.c:247–778).
  The classifier itself (bootstrap.c:135–205) is **pure argv** (only local
  statics), but its TU drags those ipc references.
- `project_lock.c` genuinely needs one ipc symbol:
  `cbm_daemon_ipc_private_lock_directory_new` + the endpoint type.

So "PROD_SRCS minus DAEMON_SRCS" cannot be literal, and naively linking
`bootstrap.o`+`ipc.o` pulls the socket cluster. **T4.3 is an explicit
link-isolation decision** with a preference order and the E2 nm-assertion as the
arbiter — not an assumption baked into the plan.

## Eval Coverage

| Eval | Phase | Verification method |
|---|---|---|
| E1 CLI-only target builds & links | 0 | `make -f Makefile.cbm cbm-cli` + `scripts/build.sh --cli-only` exit 0; ELF/Mach-O executable |
| E2 no daemon runtime/frontend or daemon-IPC socket linked | 0 (+4 enables) | `verify-cli-only-link` nm-assertion: daemon-runtime/frontend + ipc socket symbols absent; only `src/ui` loopback listener may carry `socket/bind/listen` |
| E3 bare/unknown prints help, no JSON-RPC | 4 | entry-dispatch test + runtime run under timeout; no stdin read / MCP handshake |
| E4 daemon/daemon-ctl/mcp roles inert | 4 | run those argv shapes against `cbm-cli`; no process/socket/cohort artifacts |
| E5 17 tools reachable in-process | 4 | invoke each via `cbm-cli cli <tool> --json` (reuses F3 evidence on the shipped binary) |
| E6 project_lock retained & serializing | 4 | two concurrent `cbm-cli cli index_repository` → serialized, no corruption |
| E7 default build byte-unchanged | 99 | `nm`/objdump `.text/.rodata` diff of `codebase-memory-mcp` pre/post, guard undefined |
| E8 release build has no test seams | 0 | grep the `cbm-cli` recipe CFLAGS for absence of `CBM_ENABLE_TEST_SEAMS`; nm-check `*_test_seam*` absent |
| E9 /quality-gate | 99 | reviewer: guard-scoped `main.c` diff, additive target, no shared-core edits, no new networking |

## NFR Impact

| NFR | Impact | Mitigation |
|---|---|---|
| No-MCP / no-daemon (binary level) | **Delivered** by F4 — the shipped binary links neither the daemon runtime nor the MCP stdio frontend and never reads stdin as JSON-RPC | E1/E2/E3/E4 |
| No-network | daemon-IPC sockets excluded; only dormant loopback UI remains (started in F5, audited in F6) | E2 scopes nm-assertion to daemon/IPC symbols; UI stays dormant |
| Upstream-mergeability | new `cbm-cli` target + `--cli-only` flag additive; `main.c` guard-scoped; **prefer** link-level isolation (gc-sections) over editing `src/daemon/*` to keep footprint near-zero | T4.3 preference order; no `foundation/store/cypher/pipeline/internal-cbm` edits |
| TEST_SEAMS discipline | release `cbm-cli` must not compile seams | E8; recipe omits `TEST_SEAMS=1` |
| Default artifact stability | `make cbm` byte-for-byte unchanged | E7 |

## Phases

### Phase 0 — Build/config (no tests)

- **T0.1** Add additive phony target `cbm-cli` → `$(BUILD_DIR)/codebase-memory-cli`
  in `Makefile.cbm` (add to `.PHONY` line ~775): compiles the CLI-only source
  set with `-DCBM_FORK_CLI_ONLY=1`, **not** a prerequisite of any default/prod
  target. Source set = `PROD_SRCS` minus daemon runtime/frontend
  (`daemon.c`, `version_cohort.c`, `service.c`, `runtime.c`, `application.c`,
  `frontend.c`, `host.c`), **retaining** `bootstrap.c` (classifier),
  `project_lock.c`, and `ipc.c` (for the lock-dir helper — socket exclusion
  handled by T4.3), plus `MCP_SRCS` engine + `store/cypher/pipeline/internal-cbm/
  discover/watcher/git/ui`. File: `Makefile.cbm`.
- **T0.2** Add `scripts/build.sh --cli-only` routing to the `cbm-cli` target
  through the canonical clean-build path (parallel to `--with-ui`), and document
  in the usage block that the fork's default build is CLI-only. Ensure the
  release recipe does **not** pass `TEST_SEAMS=1`/`-DCBM_ENABLE_TEST_SEAMS=1`
  (E8). File: `scripts/build.sh`.
- **T0.3** Add `verify-cli-only-link` phony (mirrors `verify-mcp-engine-split`):
  `nm` the linked `codebase-memory-cli` and assert (a) no symbols from the
  dropped daemon runtime/frontend TUs, (b) no `ipc.c` daemon-socket symbols /
  no `socket|bind|listen|accept|connect` **except** those originating in
  `src/ui`, (c) no `*_test_seam*` symbol. Not in default/prod. File:
  `Makefile.cbm`. (Enables E1, E2, E8.)

### Phase 4 — Entry dispatch + link isolation (guard-scoped, TDD)

- **T4.1 (TEST-FIRST)** Extend `tests/test_cli.c` (and/or a small
  `tests/test_main_dispatch.c` if entry-level coverage needs its own harness):
  (a) bare-argv and unknown-token invocations of the CLI-only entry return help
  + non-zero exit and **never** enter a stdin JSON-RPC read loop (E3); (b) the
  `--cbm-daemon-internal` and `daemon`-ctl argv shapes are inert under the guard
  (E4); (c) all-17-tools resolve + `project_lock` serialization re-checked
  against the guarded binary (E5, E6, reusing F3's fixtures). Tests precede impl
  (src/cli touched). File: `tests/test_cli.c`.
- **T4.2** Guard `src/main.c` role dispatch under `#ifdef CBM_FORK_CLI_ONLY`:
  compile out the `CBM_DAEMON_PROCESS_DAEMON`, `_DAEMON_CTL` (ctl cluster
  ~main.c:3130), and `_MCP_CLIENT` stdio-run branches
  (`cbm_daemon_frontend_mcp_run`, main.c:3295); route the default/unknown
  fall-through to a help/usage print. No path of the guarded binary reads stdin
  as JSON-RPC. Keep the guard-undefined `#else` branches byte-identical. File:
  `src/main.c`.
- **T4.3 (link-isolation decision)** Ensure `codebase-memory-cli` links the
  classifier + `cbm_daemon_ipc_private_lock_directory_new` **without** any
  daemon-IPC socket symbol, choosing the **lowest-footprint** mechanism that
  makes `verify-cli-only-link` pass, in preference order:
  1. **Link-level GC (preferred, zero `src/daemon` source edits):** add
     `-ffunction-sections -fdata-sections` (compile) + `--gc-sections` (link)
     **to the `cbm-cli` recipe only**; rely on the guarded `main.c` no longer
     referencing the daemon-IPC/coordination functions so the linker drops them.
     Verify with `nm` that the socket cluster and `bootstrap.c`'s ipc-coordination
     references are actually stripped (they are unreferenced once T4.2 lands).
  2. **Guard-scoped source removal (fallback, F2 precedent):** wrap `ipc.c`'s
     socket-bearing functions (and any now-unused statics) and `bootstrap.c`'s
     ipc-coordination functions in `#ifndef CBM_FORK_CLI_ONLY`, leaving
     `cbm_daemon_process_role` + `cbm_daemon_ipc_private_lock_directory_new`
     unguarded. Minimal, guarded, mergeable.
  3. **Bypass classifier under guard (only if 1–2 insufficient):** under the
     guard, `main.c` does its own minimal CLI-only argv classification and does
     not link `bootstrap.o` at all; `ipc` reduced to the lock-dir helper via (2).
  Record which mechanism was chosen and the nm evidence. Files: `Makefile.cbm`
  and/or `src/daemon/ipc.c`, `src/daemon/bootstrap.c` (guarded, only if 2/3).
- **T4.4** Confirm (static + runtime) no stdin JSON-RPC transport is reachable
  on any `cbm-cli` path and no daemon/socket artifacts are created by a bare or
  tool invocation. File: `src/main.c` (verification task).

### Phase 99 — Validation

- **TN.1** `make -f Makefile.cbm cbm-cli` + `scripts/build.sh --cli-only` exit 0;
  `verify-cli-only-link` PASS (E1, E2, E8).
- **TN.2** Entry-dispatch + tool evals against the shipped binary: E3 (help not
  JSON-RPC), E4 (roles inert), E5 (17 tools), E6 (project_lock serializes).
- **TN.3** E7: default `codebase-memory-mcp` byte-unchanged (nm/objdump diff,
  guard undefined) + full `scripts/test.sh` suite green.
- **TN.4** `/quality-gate` (E9): guard-scoped `main.c` diff, additive target, no
  shared-core edits, no new networking beyond the dormant loopback UI.
  (Left `passes:false` for the implementer; flipped only by the Verify stage.)

## Rules honored

- TDD: Phase 4 pairs T4.1 (tests) before T4.2–T4.3 (impl), per [[testing]]
  (src/cli touched).
- Explicit file paths in every task.
- No `src/foundation/store/cypher/pipeline/internal-cbm` edits.
- No new phase for `src/mcp`/`src/daemon`/`src/ui` growth — the only `src/daemon`
  touches are guard-scoped **removals** (fallback path 2), preferring link-level
  GC that edits no daemon source at all.
- No "Future Enhancements" items planned.
