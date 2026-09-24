# 02 — `residual-mcp-surface-audit`

**Milestone:** 02 of 06 | **Status:** PENDING | **New** (closes roadmap debt D-2 and D-3)

## 1. Objective & Rationale
**This milestone removes the last MCP JSON-RPC path a user could reach.** Today
`src/ui/http_server.c:1800` sends `/rpc` bodies to `cbm_mcp_server_handle`, which is the MCP
router. The front end calls `/rpc` from `graph-ui/src/api/rpc.ts`. It runs *before* the UI command
(03) so that `/rpc` never ships in any fork build. Once it is done, no channel (stdin, HTTP, argv)
accepts or answers MCP JSON-RPC.

## 2. Architectural Scope
- **Modify (guarded):** `src/ui/http_server.c`. Under `CBM_FORK_CLI_ONLY`, drop the `/rpc` route (and `/rpc` in the path check at ~1827). Any UI view that needs tool data gets a plain read-only `/api/<view>` route that calls the engine (`cbm_mcp_handle_tool`) through a fork-owned bridge (e.g. `src/cli/ui_tool_bridge.c`). The response is a plain JSON view, never a JSON-RPC envelope.
- **Modify:** `graph-ui/src/api/rpc.ts` and its callers switch to the `/api/*` routes. Keep this change small and isolated, since it affects upstream merges; use a build-time switch if practical.
- **Modify:** `cli-only.mk` compiles `src/mcp/mcp.c` with `-DCBM_FORK_CLI_ONLY=1` for `cbm-cli`, so the router and transport are fenced out.
- **Modify (guarded):** `src/cli/agent_clients.c`, `src/cli/agent_profiles.c`, `src/cli/cli.c`. Under `CBM_FORK_CLI_ONLY`, the `install`/agent-setup paths must never write `mcpServers`, `.mcp.json` or any other MCP server registration into Copilot, Claude, VS Code, JetBrains or other client configs. `install` either writes CLI-only integration files (Copilot instructions/prompt snippets that call `codebase-memory-cli cli ...`, planned in 05) or is compiled out. `uninstall` may still *remove* stale upstream MCP entries.
- **Modify:** `cli-only.mk` narrows or justifies `-Wno-unused-function -Wno-unused-variable` (D-3).
- **Extend:** `verify-cli-only-link` asserts that `cbm_mcp_server_handle`, `cbm_mcp_server_run`, `cbm_jsonrpc_*` and the strings `"jsonrpc"`, `"tools/list"`, `"initialize"`, `"protocolVersion"` are absent.
- **Untouched:** shared core.

## 3. Boundary & Guard Constraints
- The default upstream build is unchanged (G4). All C changes sit inside `CBM_FORK_CLI_ONLY`.
- No new listener. The `/api/*` routes are read-only views; mutations (index, delete) stay CLI-only unless 03's spec justifies exposing them.

## 4. Contract Expectations
- The UI shows the same graph data as before, through `/api/*`.
- Any request to `/rpc`, or any JSON-RPC body sent to any route → 404/400, never a JSON-RPC response.

## 5. Pre-conditions
01 COMPLETED.

## 6. Acceptance & Verification Gates
| Eval | Check |
|---|---|
| M1 | `nm` + `strings` on `codebase-memory-cli` (and the with-UI variant): no router, transport or JSON-RPC protocol symbols or strings |
| M2 | `tests/test_ui.c` / `test_httpd.c`: `/rpc` → 404; a JSON-RPC `initialize`/`tools/list`/`tools/call` POST to every route is rejected |
| M3 | Front end: `graph-ui` tests (`npm test` in `graph-ui/`, offline) pass; `grep -rn "/rpc" graph-ui/src` → none |
| M4 | Each TU linked into `cbm-cli` has its `src/mcp`/`src/daemon` includes classified as engine-only (list attached to progress.json) |
| M5 | Warning suppressions removed, or each remaining one justified |
| M6 | Test: run `install`/agent setup under a temp `HOME` with fixture configs for every supported client. Afterwards, `grep -r "mcpServers\|\"mcp\"\|\.mcp.json\|codebase-memory-mcp"` across that `HOME` → no new or changed MCP entries |
| M7 | `--help` and every command's help/output contain no instruction to configure an MCP server |

Policy note (decided 2026-09-24): the audit is **protocol-only**. Internal code and file names
containing "mcp" (e.g. `src/mcp/mcp.c`, `cbm_mcp_handle_tool`) are acceptable. The MCP protocol,
server, transport and client-config writing are not.
Plus the standard gates G1–G9.

## 7. Sub-Agent Execution Readiness
✅ Ready for `/roadmap-goal` once 01 is COMPLETED.
