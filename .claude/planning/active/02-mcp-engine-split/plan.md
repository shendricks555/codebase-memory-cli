# Plan: Split MCP tool engine from stdio/JSON-RPC transport

Derived from `spec.md`. Feature F2, depends on F1 (✅/✅).

> **Verification note:** graph tools were down this session (`CONNECTION_CLOSED`);
> paths and line numbers below are filesystem-verified via grep, not
> graph-verified. Re-confirm at implement time if the server returns.

## Overview

Make `src/mcp/mcp.c`'s **tool engine** compilable without the **JSON-RPC/stdio
transport**, gated by an additive, default-off `CBM_FORK_CLI_ONLY` macro. No
default-build behavior change; this only makes the two *separable* so F4 can
drop the transport.

**Seam confirmed:** transport (`cbm_jsonrpc_*` mcp.c:227-333; the router
`cbm_mcp_server_handle` incl. `initialize`/`tools/list`/`tools/call` at
mcp.c:17656-17687 and its protocol helpers; `cbm_mcp_read_message` mcp.c:17852;
`cbm_mcp_server_run` mcp.c:18015) calls **into** the engine
(`cbm_mcp_handle_tool` mcp.c:17344), never the reverse — so fencing the
transport out cannot break the engine. Note `cbm_jsonrpc_*` is *also* used by
`src/daemon/frontend.c`; the daemon is a separate removal target (F3/F4) and
compiles/links independently of this guard, so E3 verifies the **mcp.c TU in
isolation**, not a full CLI-only link.

**Strategy:** `#ifndef CBM_FORK_CLI_ONLY … #endif` guard blocks around the two
contiguous transport regions (and their public decls in `mcp.h`), NOT a
code-moving extraction — lowest merge churn per spec FR-5. (Extraction into
`src/mcp/transport.c` stays a documented future option.)

**Taxonomy exception:** the phase taxonomy says "never add a phase for
`src/mcp`". That rule forbids *extending* removal targets with new features;
F2's entire purpose is the fork's removal prep — additive compile guards inside
`mcp.c`, adding no handler/IPC/listener. Phase 1 therefore intentionally edits
`src/mcp/`, additively and guard-only, and this is called out for the
quality-gate so it isn't flagged as boundary violation.

## Eval Coverage

| Eval | Phase | Verification method |
|---|---|---|
| E1 default build compiles+links (guard undefined) | N | `make -f Makefile.cbm cbm` exits 0 |
| E2 default MCP behavior unchanged (suite green) | N | `scripts/test.sh` incl. `tests/test_mcp.c` |
| E3 engine compiles with `-DCBM_FORK_CLI_ONLY=1`, transport excluded | 0 (harness) → N (assert) | compile `src/mcp/mcp.c` TU with guard; `nm` shows engine symbols defined, transport symbols absent |
| E4 `index_supervisor` present in both guard states | N | `nm`/link check for `index_supervisor` symbols |
| E5 default artifact functionally identical pre/post | N | symbol-table + behavior diff of default `cbm` before vs. after (build-id/timestamp tolerated) |
| E6 `mcp.c` diff additive/localized (no engine reorder) | N | reviewer inspection at `/quality-gate` |

## NFR Impact

| NFR | Impact | Mitigation |
|---|---|---|
| Upstream-mergeability (mcp.c is large + upstream-active) | Highest-risk feature | Guard blocks only around 2 contiguous regions; zero engine-code movement; guard `mcp.h` decls with the same macro |
| No network / no behavior change | None on default path | Guard is default-off; E5 asserts functional identity |
| TEST_SEAMS discipline | None | No test-only code added to release path |
| Shared core (foundation/store/cypher/pipeline/internal-cbm) | Untouched | Only `src/mcp/` + `Makefile.cbm` edited |

## Phase 0 — Build/config (`Makefile.cbm`)

No test phase. Establishes the guard + a verification harness; default build unchanged.

- **T0.1** Document the `CBM_FORK_CLI_ONLY` macro contract in `Makefile.cbm`
  near `MCP_SRCS` (Makefile.cbm:329): default-undefined = full upstream build;
  defined = transport excluded from the mcp engine TU. No change to `PROD_SRCS`
  / default `cbm` target.
- **T0.2** Add a verification-only phony target (e.g. `verify-mcp-engine-split`)
  that compiles `src/mcp/mcp.c` to an object with `-DCBM_FORK_CLI_ONLY=1` plus
  the normal include flags, and runs `nm` assertions: engine symbols
  (`cbm_mcp_handle_tool`, `cbm_mcp_server_new`, `cbm_mcp_tool_input_schema`,
  `cbm_mcp_get_string_arg`) present; transport symbols (`cbm_mcp_server_run`,
  `cbm_mcp_read_message`, `cbm_mcp_server_handle`, `cbm_jsonrpc_parse`) absent.
  This target must not run in the default build.
- **T0.3** Confirm `MCP_SRCS` still lists `index_supervisor.c` + `compact_out.c`
  unchanged (Makefile.cbm:329) so E4 holds.

## Phase 1 — MCP engine/transport split (`src/mcp/mcp.c`, `src/mcp/mcp.h`) — taxonomy exception, additive guards only

- **T1.1** Wrap the JSON-RPC region `#ifndef CBM_FORK_CLI_ONLY` … `#endif`:
  `cbm_jsonrpc_parse`/`_request_free`/`_format_response`/`_format_error`
  (mcp.c:227-333).
- **T1.2** Wrap the stdio-transport region behind the same guard:
  `cbm_mcp_server_handle` (the `initialize`/`ping`/`resources`/`prompts`/
  `tools/list`/`tools/call`/`notifications` router, ~mcp.c:17620-17740) and its
  transport-only helpers (`cbm_mcp_jsonrpc_response_prepend_notice`,
  `cbm_mcp_initialize_response_for_profile`, `cbm_mcp_server_request_scope_begin`,
  `cbm_mcp_cancel_request_matches`, `cbm_mcp_server_cancel_active`),
  `cbm_mcp_read_message` (mcp.c:17852), `cbm_mcp_server_run` (mcp.c:18015).
  Implementer enumerates the exact transport-only set; the E3 `nm` gate catches
  any symbol left on the wrong side.
- **T1.3** In `src/mcp/mcp.h`, fence the matching public declarations
  (`cbm_jsonrpc_*` mcp.h:45-52; `cbm_mcp_read_message` mcp.h:203;
  `cbm_mcp_server_run` mcp.h:207) under the same `#ifndef CBM_FORK_CLI_ONLY` so a
  guarded TU sees no decl for an excluded definition, while the default build
  sees them exactly as today. Keep `cbm_jsonrpc_request_t`/`_response_t` types
  available (daemon uses them) unless proven transport-only — default to leaving
  the structs unguarded to avoid breaking `src/daemon/frontend.c` in a mixed
  build.
- **T1.4** Verify the engine references no guarded symbol: `cbm_mcp_handle_tool`
  and all `handle_*` must not call any `cbm_jsonrpc_*`/`cbm_mcp_server_*`
  transport function (seam is one-way; confirm no accidental back-edge).

*No TDD test-writing task:* `src/mcp` is not in the TDD module list
(store/cypher/pipeline/cli/internal-cbm); this phase's verification is
build/symbol-level via Phase 0's harness + Phase N, not a new `test_*.c`.

## Phase N — Validation

- **TN.1** Default build: `make -f Makefile.cbm cbm` exits 0 (E1).
- **TN.2** Full suite green on default build: `scripts/test.sh` incl.
  `tests/test_mcp.c` (E2).
- **TN.3** Run `make -f Makefile.cbm verify-mcp-engine-split`: engine compiles
  with guard, transport symbols absent, engine symbols present (E3); assert
  `index_supervisor` symbols present in both states (E4).
- **TN.4** Functional-identity check: build default `cbm` on a clean checkout
  vs. the branch; diff symbol tables + spot-check MCP behavior; only
  build-id/timestamp differences allowed (E5).
- **TN.5** `/quality-gate`: inspect `mcp.c` diff is guard-only/additive with no
  engine reorder (E6), and confirm the Phase 1 taxonomy exception is guard-only
  and introduces no handler/IPC/listener.

## Rollback

Guard blocks are additive; reverting the branch restores byte-identical
upstream `mcp.c`/`mcp.h`. No schema/data migration.
