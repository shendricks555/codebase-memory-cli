# Feature: CLI-only build target & entry dispatch (guarded)

> **Verification note:** the `codebase-memory-mcp` graph tools were **down this
> session** (`CONNECTION_CLOSED`), so every touchpoint below is
> **filesystem-verified** (grep/Read over `Makefile.cbm`, `src/main.c`,
> `src/daemon/bootstrap.c`, `src/daemon/ipc.c`, `scripts/build.sh`), not
> graph-verified. Re-confirm callers with `trace_path`/`search_graph` at plan
> time if the server returns. Depends on **F2 (✅)** (split engine) and **F3
> (✅)** (in-process guarded `run_cli`); this feature removes the daemon sources
> from the link line and flips top-level dispatch, which F3 explicitly deferred.

## Objective

Produce the fork's actual shippable artifact: a **`codebase-memory-cli`** binary
built with `CBM_FORK_CLI_ONLY` defined that (a) does **not link** the
coordination daemon runtime or the MCP stdio frontend, and (b) whose entry
dispatch **never starts an MCP server** — a bare or unrecognized invocation
prints CLI help instead of speaking JSON-RPC on stdio. F3 made the guarded
`cli <tool>` path run in-process; F4 makes the guard real at the build/link and
top-level-dispatch level and ships it as a distinct binary. The upstream default
target (`make -f Makefile.cbm cbm`) stays **byte-for-byte unchanged**.

## User Scenarios

- **S1 (shippable no-daemon binary).** Given the fork's build target, When a
  developer runs `scripts/build.sh --cli-only` (or `make -f Makefile.cbm
  cbm-cli`), Then it produces `build/c/codebase-memory-cli` with
  `CBM_FORK_CLI_ONLY` defined, and that binary links **none** of the daemon
  runtime/frontend sources (`daemon.c`, `version_cohort.c`, `service.c`,
  `runtime.c`, `application.c`, `frontend.c`, `host.c`) and **no** daemon-IPC
  socket code.
- **S2 (bare invocation prints help, not JSON-RPC).** Given the CLI-only binary,
  When it is run with no arguments or an unrecognized top-level token, Then it
  prints CLI usage/help and exits **without** opening stdin as a JSON-RPC
  transport and **without** starting any MCP server.
- **S3 (daemon / daemon-ctl roles compiled out).** Given the CLI-only binary,
  When it is invoked with the internal daemon grammar (`--cbm-daemon-internal`)
  or the `daemon` control subcommand, Then no daemon is started and no daemon
  control socket is contacted — those role branches are compiled out under the
  guard and fall through to help/refusal.
- **S4 (tools still work in-process).** Given the CLI-only binary, When any of
  the 17 tools is invoked via `codebase-memory-cli cli <tool>`, Then it runs
  in-process exactly as F3 established, with per-project `project_lock`
  serialization retained.
- **S5 (default upstream binary unchanged).** Given `CBM_FORK_CLI_ONLY` is
  **undefined**, When `make -f Makefile.cbm cbm` builds `codebase-memory-mcp`,
  Then that artifact is byte-for-byte identical to pre-F4 (new target is purely
  additive; `main.c` edits are guard-scoped).
- **S6 (release build has no test seams).** Given the CLI-only **release**
  build, When it is compiled, Then `CBM_ENABLE_TEST_SEAMS` is **not** defined —
  test-only code never enters the shipped binary.

## Functional Requirements

- **FR-1 (S1).** Add an additive `Makefile.cbm` target `cbm-cli` →
  `build/c/codebase-memory-cli` that defines `CBM_FORK_CLI_ONLY` and builds from
  a CLI-only source set: `PROD_SRCS` **minus** the daemon runtime/frontend
  sources (`daemon.c`, `version_cohort.c`, `service.c`, `runtime.c`,
  `application.c`, `frontend.c`, `host.c`) and the MCP stdio-frontend path,
  **plus** the retained tool engine (`MCP_SRCS`: engine of `mcp.c`,
  `index_supervisor.c`, `compact_out.c`), and **keeping**
  `store/cypher/pipeline/internal-cbm/discover/watcher/git/ui`. The target must
  **not** be a prerequisite of any default/prod target. (Traces: S1.)
- **FR-2 (S1, S4) — retained daemon-adjacent code.** The CLI-only binary must
  still link the code F3 proved it needs: the pure-argv classifier
  `cbm_daemon_process_role` (`src/daemon/bootstrap.c`, **zero** socket calls),
  `src/daemon/project_lock.c` (pure file locks, **zero** socket calls), and the
  single helper `cbm_daemon_ipc_private_lock_directory_new` + its endpoint type
  (from `src/daemon/ipc.c`) — **without** linking `ipc.c`'s socket-bearing
  daemon-IPC functions. The mechanism to retain that one helper while excluding
  the 5 socket calls in the same TU (guard the socket functions under
  `CBM_FORK_CLI_ONLY`, split `ipc.c`, or dead-strip) is a **/plan** decision;
  the requirement is that no daemon-IPC socket symbol is reachable/linked.
  (Traces: S1, S4.)
- **FR-3 (S2).** Under the guard, `main.c`'s role dispatch must treat the
  default/unknown fall-through (today `cbm_daemon_process_role` returns
  `CBM_DAEMON_PROCESS_MCP_CLIENT`, run via `cbm_daemon_frontend_mcp_run`,
  `src/main.c:3295`) as a **help/usage print**, never as an MCP stdio server.
  No stdin JSON-RPC read loop is entered on any path of the CLI-only binary.
  (Traces: S2.)
- **FR-4 (S3).** Under the guard, the `CBM_DAEMON_PROCESS_DAEMON`,
  `CBM_DAEMON_PROCESS_DAEMON_CTL`, and `CBM_DAEMON_PROCESS_MCP_CLIENT` dispatch
  branches in `main.c` (e.g. the `daemon`-ctl cluster at `src/main.c:3130` and
  the MCP-stdio run at `src/main.c:3295`) are compiled out; reaching those
  role tokens prints help/refusal instead. (Traces: S3.)
- **FR-5 (S1).** Add `scripts/build.sh --cli-only` that builds the `cbm-cli`
  target through the same canonical path as `--with-ui`, and document that the
  **fork's default build is CLI-only**. (Traces: S1.)
- **FR-6 (S5).** All `main.c` and `Makefile.cbm` edits are **guard-scoped /
  additive**: with `CBM_FORK_CLI_ONLY` undefined, `codebase-memory-mcp` from
  `make -f Makefile.cbm cbm` is byte-for-byte identical to pre-F4. No
  shared-core (`foundation/store/cypher/pipeline/internal-cbm`) edits. (Traces:
  S5.)
- **FR-7 (S6).** The CLI-only **release** target must not pass
  `TEST_SEAMS=1`/`-DCBM_ENABLE_TEST_SEAMS=1` (mirrors `scripts/build.sh` vs.
  `scripts/test.sh`). (Traces: S6.)
- **FR-8 (S1, architecture).** The only socket-capable code permitted in the
  CLI-only binary is `src/ui/`'s **loopback** graph-viz listener, which stays
  **dormant** in F4 (its on-demand starter subcommand is F5). No daemon /
  coordination / JSON-RPC listener is linked or reachable. (Traces: S1.)

## CLI Contract

Binary name under the guard is `codebase-memory-cli`. Tool surface is F3's
`cli <tool>`; F4 changes the *default/entry* behavior.

| Invocation | Output shape | Exit code | Failure behavior |
|---|---|---|---|
| `codebase-memory-cli` (no args) | CLI usage/help text on stderr | non-zero (no subcommand) | never opens stdin JSON-RPC; never starts MCP server |
| `codebase-memory-cli <unknown-token>` | CLI usage/help | non-zero | help, not JSON-RPC |
| `codebase-memory-cli --help` / `--version` | help / version | 0 | as upstream `STATELESS` |
| `codebase-memory-cli cli <tool> [--json\|--format json]` | identical to F3 in-process result | 0 on success | F3 behavior (tool error envelope; project-lock contention serialized) |
| `codebase-memory-cli daemon …` / `--cbm-daemon-internal` | help / refusal | non-zero | daemon roles compiled out; no daemon started, no ctl socket |
| default `codebase-memory-mcp` (guard undefined) | unchanged | unchanged | unchanged (daemon-routed) |

## Data Model

No schema or on-disk format change. This feature is build-graph + entry-dispatch
only.

## Constraints

- Pure C11. `main.c` edits **guard-scoped** under `CBM_FORK_CLI_ONLY`; the new
  `Makefile.cbm` target and `scripts/build.sh --cli-only` are **additive**. Any
  edit to `src/daemon/ipc.c`/`bootstrap.c` must be a guard-scoped **removal**
  (compile socket code out under the guard), never new IPC/socket surface —
  `src/daemon/` is a removal target (see architecture.md), so keep the footprint
  minimal and guarded for upstream-mergeability.
- Do **not** touch `foundation/store/cypher/pipeline/internal-cbm` (mergeability).
- Add **no** new `socket()/bind()/listen()/accept()/connect()` and no server
  loop; the kept `src/ui` loopback listener is the sole socket-capable code and
  is dormant until F5.
- Default `make -f Makefile.cbm cbm` output must remain byte-for-byte upstream.
- TEST_SEAMS stays opt-in; the CLI-only release build compiles no test seams.
- The CLI-only binary must never read stdin as a JSON-RPC transport on any path.

## Success Criteria

- [ ] `make -f Makefile.cbm cbm-cli` / `scripts/build.sh --cli-only` produces
      `codebase-memory-cli`; it links none of the daemon runtime/frontend
      sources and no daemon-IPC socket symbol (FR-1, FR-2, FR-8).
- [ ] Bare / unknown / daemon-role invocations print help and never start an MCP
      server or read stdin JSON-RPC (FR-3, FR-4, S2, S3).
- [ ] All 17 tools still run in-process via `codebase-memory-cli cli <tool>`
      with `project_lock` retained (FR-2, S4).
- [ ] Default `make -f Makefile.cbm cbm` artifact byte-for-byte unchanged
      (FR-6, S5).
- [ ] CLI-only release build defines no `CBM_ENABLE_TEST_SEAMS` (FR-7, S6).

## Evals (Smoke Tests)

| ID | Eval | Type | Verified by |
|---|---|---|---|
| E1 | CLI-only target builds & links | integration | `make -f Makefile.cbm cbm-cli` (and `scripts/build.sh --cli-only`) exit 0; `build/c/codebase-memory-cli` is an executable ELF/Mach-O |
| E2 | No daemon runtime/frontend or daemon-IPC socket linked | integration | `nm`/link assertion on `codebase-memory-cli`: symbols from `daemon.c/version_cohort.c/service.c/runtime.c/application.c/frontend.c/host.c` absent, and `ipc.c`'s daemon socket cluster absent; only `src/ui` loopback listener may carry `socket/bind/listen` (mirrors `verify-mcp-engine-split` nm pattern) |
| E3 | Bare/unknown invocation prints help, no JSON-RPC | integration | run `codebase-memory-cli` with no args and with an unknown token under a timeout; assert help text, non-zero exit, no stdin read / no MCP handshake emitted |
| E4 | Daemon/daemon-ctl/MCP roles inert | integration | `codebase-memory-cli --cbm-daemon-internal` and `codebase-memory-cli daemon status` start no process and open no socket (no cohort/socket artifacts created); print help/refusal |
| E5 | 17 tools still reachable in-process | integration | invoke each tool via `codebase-memory-cli cli <tool> --json`; assert non-`unknown tool`, no daemon/socket (reuses F3 evidence against the real shipped binary) |
| E6 | `project_lock` retained & serializing | integration | two concurrent `codebase-memory-cli cli index_repository` on one repo → serialized, no corruption |
| E7 | Default build byte-unchanged | criteria | build `codebase-memory-mcp` at pre-F4 vs post-F4 with guard undefined; `nm`/objdump `.text/.rodata` byte-identical (STT_FILE tolerated), suite green |
| E8 | Release build has no test seams | unit/criteria | assert `CBM_ENABLE_TEST_SEAMS` undefined in the `cbm-cli` release compile (grep the target's `CFLAGS`; nm-check any `*_test_seam*` symbol absent) |
| E9 | /quality-gate | criteria | reviewer confirms guard-scoped `main.c` diff, additive target, no shared-core edits, no new networking beyond dormant loopback UI |

## Out of Scope

- The on-demand loopback UI **starter** subcommand (`ui`/`--serve-ui`) — **F5**.
- The audited whole-binary no-network guarantee (`make security` egress test,
  full `strace`) — **F6**.
- Copilot CLI integration + build/run quickstart — **F7**.
- Packaging/distribution of the fork binary (Homebrew/npm/release archives) —
  deferred across the roadmap.

## Future Enhancements

- Once F5/F6 land, make `cbm-cli` (or a renamed default) the target
  `scripts/build.sh` builds with no flag, formalizing "the fork's default build
  is CLI-only."
