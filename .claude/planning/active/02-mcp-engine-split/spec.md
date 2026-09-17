# Feature: Split MCP tool engine from stdio/JSON-RPC transport

> **Verification note:** the `codebase-memory-mcp` graph tools were unavailable
> this session (`CONNECTION_CLOSED` — the same wedged daemon layer this fork
> removes, per RESEARCH R-6). Per [[mcp-usage]] step 8 this spec's touchpoints
> were **filesystem-verified** (grep over `src/mcp/`, `src/`, `Makefile.cbm`),
> not graph-verified. Re-confirm symbol references with `search_graph`/
> `trace_path` at plan time if the server is back up.

## Objective

Make the reusable **tool engine** in `src/mcp/mcp.c` compilable and linkable
**without** the MCP JSON-RPC/stdio **transport**, so a later CLI-only build
target (F4) can drop the transport while keeping every tool handler. This
feature only makes the two *separable*; it removes nothing from any shipped
binary and changes no runtime behavior. Separation is expressed with an
additive `CBM_FORK_CLI_ONLY` compile guard so the default upstream build is
untouched and `git pull` stays low-conflict.

## User Scenarios

- **S1 (upstream build unchanged).** Given the repo, When a developer builds
  the default binary (`make -f Makefile.cbm cbm`) with `CBM_FORK_CLI_ONLY`
  **undefined**, Then the binary is functionally equivalent to today: the MCP
  stdio server, JSON-RPC parsing, and `initialize`/`tools/list`/`tools/call`
  router are all present and behave identically.
- **S2 (engine builds without transport).** Given `CBM_FORK_CLI_ONLY` is
  **defined**, When the mcp translation unit(s) are compiled, Then the tool
  engine (`TOOLS[]`, every `handle_*` handler, `cbm_mcp_handle_tool`, the arg
  helpers, `cbm_mcp_tool_input_schema`, `cbm_mcp_server_new/free`) compiles and
  its symbols resolve, while the transport symbols (`cbm_jsonrpc_*`,
  `cbm_mcp_server_run`, `cbm_mcp_read_message`, the method router) are excluded
  from that compilation.
- **S3 (indexing dependency preserved).** Given either guard state, When the
  build links, Then `src/mcp/index_supervisor.*` remains compiled and available
  (it is included by `src/cli/cli.c:27` and `src/main.c:35` and is not part of
  the transport).
- **S4 (minimal merge footprint).** Given upstream later changes `mcp.c`, When
  a maintainer runs `git pull`, Then the fork's split (guard blocks and/or a
  new transport translation unit) produces a small, localized conflict surface
  rather than a wholesale reordering of `mcp.c`.

## Functional Requirements

- **FR-1 (S1).** With `CBM_FORK_CLI_ONLY` undefined, the default build must
  compile and link the transport exactly as today — no source is reordered or
  behaviorally altered on the default path. (Traces: S1.)
- **FR-2 (S2, engine).** The following must build and link with the transport
  guarded out: `TOOLS[]` (mcp.c:465) and `TOOL_COUNT` (mcp.c:753); all
  `handle_*` tool handlers; `cbm_mcp_handle_tool` (mcp.c:17344);
  `cbm_mcp_get_string_arg`/`_int_arg`/`_bool_arg`/`_tool_name`/`_arguments`
  (mcp.c:1423/1578/1593 + mcp.h:101/104); `cbm_mcp_tool_input_schema`
  (mcp.c:988); `cbm_mcp_server_new` (mcp.c:1697) and `cbm_mcp_server_free`
  (mcp.c:1864). (Traces: S2.)
- **FR-3 (S2, transport).** The following must be isolated behind
  `CBM_FORK_CLI_ONLY` (guard block or separate TU) so they are excluded when
  the guard is defined and present when it is not: `cbm_jsonrpc_parse`/
  `_request_free`/`_format_response`/`_format_error` (mcp.c:227-333); the
  method router for `initialize`/`tools/list`/`tools/call` (mcp.c:17656-17687);
  `cbm_mcp_read_message` (mcp.c:17852); `cbm_mcp_server_run` (mcp.c:18015).
  (Traces: S2.)
- **FR-4 (S3).** `src/mcp/index_supervisor.c/.h` must remain in `MCP_SRCS`
  (Makefile.cbm:329) / the build and be unaffected by the guard. (Traces: S3.)
- **FR-5 (S4).** The split must minimize churn to `mcp.c`: prefer additive
  guard delimiters or extracting transport into a new translation unit over
  moving existing engine code around. Public declarations in `src/mcp/mcp.h`
  for guarded transport symbols should not break the default build. (Traces:
  S4.)
- **FR-6 (S1/S2, byte-for-byte).** The default-build artifact must be
  byte-for-byte identical (or, if timestamps/build-id differ, functionally
  identical by symbol table + behavior) to a pre-change default build. The
  guard is the only thing that changes what compiles. (Traces: S1.)

## CLI Contract

Not applicable — this feature adds **no** CLI subcommand and changes no
user-visible invocation. The only "contract" is the build surface:

| Invocation | Output shape | Exit code | Failure behavior |
|---|---|---|---|
| `make -f Makefile.cbm cbm` (guard undefined) | default binary, transport present | 0 | build fails if split broke default path |
| build with `-DCBM_FORK_CLI_ONLY=1` over the mcp engine TU(s) | object files, transport excluded, engine symbols resolvable | 0 | link/compile error if any engine symbol depends on a guarded transport symbol |

## Data Model

Not applicable — no schema, store, or graph-shape change.

## Constraints

- Pure C11 only; no Go. (CLAUDE.md.)
- Do **not** touch `src/foundation`, `src/store`, `src/cypher`, `src/pipeline`,
  `internal/cbm` — shared upstream-active core. Edits confined to `src/mcp/`
  (and `Makefile.cbm` for a new TU / guard plumbing if needed).
- No network, socket, listener, or behavior change introduced by this feature.
- `TEST_SEAMS` stays opt-in; nothing here compiles test-only code into release.
- The guard must be **default-off**: undefined = full upstream behavior.

## Success Criteria

- [ ] Default build (`make -f Makefile.cbm cbm`, guard undefined) succeeds and
      is functionally identical to pre-change (FR-1, FR-6).
- [ ] With `CBM_FORK_CLI_ONLY` defined over the engine TU(s), the engine
      compiles and `cbm_mcp_handle_tool` + all `handle_*` + arg helpers resolve
      with no reference to guarded transport symbols (FR-2, FR-3).
- [ ] `index_supervisor` remains built in both guard states (FR-4).
- [ ] `mcp.c` diff is localized to guard delimiters / a transport-TU
      extraction; no engine code is reordered (FR-5).
- [ ] Existing MCP tests (`tests/test_mcp.c`, Makefile.cbm:568) still pass on
      the default build.

## Evals (Smoke Tests)

| ID | Eval | Type | Verified by |
|---|---|---|---|
| E1 | Default build (guard undefined) compiles + links | integration | `make -f Makefile.cbm cbm` exits 0 |
| E2 | Default binary behavior unchanged: full MCP test suite green | integration | `tests/test_mcp.c` via `scripts/test.sh` |
| E3 | Engine compiles with `-DCBM_FORK_CLI_ONLY=1`, transport excluded | integration | compile the engine TU(s) with the guard defined; assert transport symbols absent (`nm`), engine symbols present |
| E4 | `index_supervisor` present in both guard states | unit | `nm`/link check for `index_supervisor` symbols |
| E5 | Default-build artifact functionally identical pre/post change | criteria | symbol-table + behavioral diff of default binary before vs. after the split (build-id/timestamp diffs tolerated) |
| E6 | `mcp.c` change is additive/localized (no engine reorder) | criteria | reviewer inspection of the `mcp.c` diff at `/quality-gate` |

## Out of Scope

- Actually removing the transport from any shipped binary — that is F4
  (`CBM_FORK_CLI_ONLY` build target & entry dispatch).
- Re-pointing `run_cli` at the in-process engine / dropping the daemon — F3.
- Any new CLI subcommand, UI change, or network hardening — F5/F6/F7.

## Future Enhancements

- Once F4 lands, consider fully relocating transport into `src/mcp/transport.c`
  if the guard-block approach proves noisier to merge than a separate TU.
