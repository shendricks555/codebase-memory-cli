# Feature summary: Split MCP tool engine from stdio/JSON-RPC transport
**Sequence:** 002 | **Depends on:** F1 | **Spans:** mcp, build

## Behavior
Separates the reusable **tool engine** in `src/mcp/mcp.c` from the **MCP protocol transport** so the
engine can compile and link without the JSON-RPC/stdio server. No behavior change to the default
upstream build; this is preparation that makes a daemon-free, MCP-stdio-free CLI possible.

## Functional Requirements (high level)
- Keep as the engine: `TOOLS[]`, all `handle_*` tool handlers, `cbm_mcp_handle_tool` (mcp.c:17264),
  `cbm_mcp_get_*_arg` helpers, `cbm_mcp_tool_input_schema`, `cbm_mcp_server_new/free`.
- Isolate as transport (behind `CBM_FORK_CLI_ONLY`, or in a separate translation unit): `cbm_jsonrpc_*`
  (mcp.c:227-333), `cbm_mcp_server_run`, `cbm_mcp_read_message`, the `tools/list` / `tools/call`
  method router (mcp.c:17675), and MCP `initialize`/negotiation.
- Retain `src/mcp/index_supervisor.*` (indexing depends on it; included by `cli.c:27`, `main.c:35`).
- Ensure the default build (`make -f Makefile.cbm cbm`) still compiles the transport and is
  unchanged; the split must be a no-op for upstream.

## Functional Requirements (high level) — acceptance
- With the transport compiled out (guard defined), the tool engine still builds and `cbm_mcp_handle_tool`
  resolves; with the guard undefined, the binary is byte-for-byte equivalent to today.

## NFR impact
- Upstream-mergeability: `mcp.c` is large and upstream-active — prefer guard blocks / a new TU over
  reordering existing code to keep the merge diff minimal. This is the highest merge-risk feature;
  keep edits surgical.
- No network/behavior change yet.

## Research pointers
- R-2 (tools live in mcp.c; transport is the MCP-only part to drop).
- R-3 (compile-guard strategy for mergeability).

## Deferred
- Actually removing the transport from a shipped binary happens via the build target in F4; here it
  only becomes *separable*.
