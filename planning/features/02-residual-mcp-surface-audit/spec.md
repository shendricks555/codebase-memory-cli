# Spec 02 — `residual-mcp-surface-audit`

**Milestone:** 02 of 06 | **Source:** `summary.md` (this folder), `planning/ROADMAP.md` D-2, D-3, D-5 | **Policy:** protocol-only (internal "mcp" names allowed)

Nothing here adds a CLI flag. The work removes the last MCP JSON-RPC paths from fork builds, and
nothing else. The default upstream build (`make -f Makefile.cbm cbm`) must behave exactly as it
does today. Every C change sits inside `CBM_FORK_CLI_ONLY`.

---

## 1. CLI Command & Interface Contract

### 1.1 CLI surface
- **[CLI-1]** No new commands and no new flags.
- **[CLI-2]** In `codebase-memory-cli`, `install` prints one JSON error and exits non-zero. The
  error is `{"error":"install is not available in the CLI-only build; see docs (milestone 05)"}`
  and the command writes no files. Milestone 05 adds the CLI-only replacement. This spec does not
  add a stub writer.
- **[CLI-3]** `uninstall` stays available, and it may only **remove** existing
  `codebase-memory-mcp` entries. It must not add or rewrite any other key.
- **[CLI-4]** `--help`, each command's help text and all command output must not tell the user to
  configure, register or run an MCP server (M7). Help text only changes inside guarded blocks.

### 1.2 HTTP view routes (only in builds that link `src/ui`)
All three routes are **GET-only**, read-only and protected in the same way as today's `/api/*`
(Host check and existing readiness check). Each route calls
`cbm_mcp_handle_tool(srv->mcp, <fixed tool>, <args built server-side>)` and replies with the
tool's **unwrapped** JSON text, never a JSON-RPC envelope.

| Ref | Route | Query params (required *) | Engine tool | Fixed server-side args |
|---|---|---|---|---|
| **[API-1]** | `GET /api/projects` | `limit`, `offset` (ints) | `list_projects` | `format:"json"`, `detail:"stats"` |
| **[API-2]** | `GET /api/schema` | `project`*, `limit`, `offset` | `get_graph_schema` | `format:"json"` |
| **[API-3]** | `GET /api/snippet` | `project`*, `qualified_name`* | `get_code_snippet` | `format:"json"`, `source_mode:"full"` |

- **[API-4]** Success is `200` with `Content-Type: application/json`. The body is the tool payload
  exactly as the UI parses it today: `ProjectPage`, `SchemaPage` or `SnippetResult`.
- **[API-5]** Errors use `{"error":"<message>"}` with status 400 (bad or missing param), 404
  (unknown route) or 500 (engine failure). No response contains a `jsonrpc`, `id` or `result`
  wrapper.
- **[API-6]** `/rpc` is removed. Any method sent to `/rpc` returns 404. A request body is never
  parsed as JSON-RPC on any route.

### 1.3 Front end
- **[FE-1]** `graph-ui/src/api/rpc.ts` is replaced by `graph-ui/src/api/views.ts`, which exports
  `getProjects(limit, offset)`, `getSchema(project, limit, offset)` and
  `getSnippet(project, qualifiedName)`. Each function uses `fetch` with GET and
  `encodeURIComponent` on the query values. It throws `ViewError(status, message)` when the
  response is not ok.
- **[FE-2]** `useProjects.ts` and `NodeDetailPanel.tsx` call these functions, with the same
  pagination logic and the same rendered data. There is no build-time switch. The UI bundle is
  shared, and the upstream `/rpc` route still exists in the default build, but the new `/api/*`
  routes are **unguarded additions** in `http_server.c` (see [ARCH-2]), so one bundle works on
  both builds.

---

## 2. Architecture & Minimal Blast Radius

| Ref | File | Change | Why it must change |
|---|---|---|---|
| **[ARCH-1]** | `src/ui/http_server.c` | Wrap `handle_rpc`, `rpc_is_allowed_for_ui` and the `/rpc` dispatch branch (~1966) in `#ifndef CBM_FORK_CLI_ONLY`. Use the same guard to drop the `strcmp(path,"/rpc")` clause in `route_is_protected` (~1827). | This is the D-2 call site and the only UI caller of `cbm_mcp_server_handle`. |
| **[ARCH-2]** | `src/ui/http_server.c` | Add three static handlers, `handle_view_projects`, `handle_view_schema` and `handle_view_snippet`, plus one static helper `view_reply_tool(c, srv, tool, args_json)` that unwraps `content[0].text`. These are **unguarded** so upstream and fork serve the same bundle. They are additive and use only the existing `cbm_mcp_handle_tool` and yyjson. | Keeping the handlers in the same TU avoids a new bridge file and header. `srv->mcp` is private to this TU. The `src/cli/ui_tool_bridge.c` that `summary.md` suggests is rejected under YAGNI. |
| **[ARCH-3]** | `graph-ui/src/api/views.ts` (new), `rpc.ts` (delete), `hooks/useProjects.ts`, `components/NodeDetailPanel.tsx`, and their `*.test.tsx` | Implement [FE-1] and [FE-2]. | The front end is the `/rpc` client. |
| **[ARCH-4]** | `src/cli/cli.c` | Under `#ifdef CBM_FORK_CLI_ONLY`, `cbm_cmd_install` returns the [CLI-2] error before it touches the filesystem. Guard the MCP-registration help strings for [CLI-4]. | This is the D-5 entry point. Guarding the entry point is enough to make every writer below it unreachable, with no edits to the writers. |
| **[ARCH-5]** | `src/cli/agent_clients.c`, `src/cli/agent_profiles.c` | **No edits expected.** They become unreachable through [ARCH-4], and section GC removes them. Edit them only if `uninstall` shares a code path that *writes* (for example a rewrite-on-remove that adds keys). If so, guard that write branch only. | Keeps the diff small. |
| **[ARCH-6]** | `cli-only.mk` | (a) Add `src/mcp/mcp.c` and `src/ui/http_server.c` to the guarded-edge TUs. Compile them with `-DCBM_FORK_CLI_ONLY=1` into separate objects, and `filter-out` both from `CLI_ONLY_REST_SRCS`. (b) Update the header comment so it no longer says "mcp.c stays unguarded". (c) Resolve D-3 per [ARCH-7]. | `mcp.c` already fences the router and transport behind the guard (F2). Today it is compiled without that guard. |
| **[ARCH-7]** | `cli-only.mk` | Try removing `-Wno-unused-function -Wno-unused-variable`. If `main.c`/`cli.c` fail, keep the flags **only** on the TUs that fail. Add a comment for each one that lists the guarded-out helpers causing it. Do not wrap upstream helpers. | D-3. The flags are justified when removing them would mean edits across ~20 upstream helpers. |
| **[ARCH-8]** | `cli-only.mk` `verify-cli-only-link` | Add `cbm_mcp_server_handle` and `cbm_jsonrpc_` to `CLI_ONLY_FORBIDDEN_PREFIXES`. Add a `strings` check that fails if any of `"jsonrpc"`, `"tools/list"`, `"protocolVersion"` or `"notifications/initialized"` appear. Run the same checks on the with-UI variant as soon as 03 creates it. Until then, run them on `cbm-cli` only. | M1. `"initialize"` is **not** a strings token, because it matches innocent text (for example "uninitialized"). Instead it is covered by the `protocolVersion` token plus the symbol check. |
| **[ARCH-9]** | `tests/test_ui.c` (or `test_httpd.c`, whichever already drives `http_server.c` handlers) and a new `cli-only.mk` target, `test-cli-only-ui` | See §5. | M2 needs a guarded compile of the HTTP server. |
| **[ARCH-10]** | `tests/test_cli_only_install.sh` (new), wired into `test-cli-only` | See §5. | M6. |

**Untouched:** `src/foundation`, `src/store`, `src/cypher`, `src/pipeline`, `internal/cbm`,
`src/daemon`, `src/mcp/mcp.h`.

**Guard verification [GUARD-1]:** in `git diff`, every *removal* or *behaviour change* in `.c`
files sits inside `#ifdef`/`#ifndef CBM_FORK_CLI_ONLY`. The only unguarded C change is the
additive handler code in [ARCH-2]. `make -f Makefile.cbm cbm` still builds with zero warnings,
and on that default build `/rpc` still answers as it does upstream.

**Engine-only include audit [AUDIT-1] (M4):** for each TU linked into `cbm-cli`, list each
`#include` of `src/mcp/*` or `src/daemon/*` and the symbols it uses. Mark each one as
`engine` (for example `cbm_mcp_handle_tool` or `cbm_mcp_server_new`), `lock`, `classifier` or
`FORBIDDEN`. Attach the list to `plan.md`. Any `FORBIDDEN` entry blocks completion.

---

## 3. Data Structures & Memory Ownership

- **[MEM-1]** No new structs.
- **[MEM-2]** Arguments JSON is built with a `yyjson_mut_doc`. String query values go in through
  `yyjson_mut_strcpy`, never by string concatenation, so no user input is ever spliced into JSON
  text. The document is serialized with `yyjson_mut_write`, which returns a heap `char*`.
  Cleanup: `free(args)` and `yyjson_mut_doc_free(doc)` on every exit path.
- **[MEM-3]** `cbm_mcp_handle_tool` returns a heap `char*` owned by the caller. It is parsed with
  `yyjson_read`, and the handler replies with the borrowed `content[0].text` string. Cleanup order:
  `cbm_http_replyf` → `yyjson_doc_free` → `free(result)`. If the result has no `content` wrapper,
  the whole `result` is sent as-is (this matches the `rpc.ts` fallback).
- **[MEM-4]** Query params are decoded into fixed stack buffers with the existing httpd
  query/url-decode helper. `project` and `qualified_name` are limited to 4096 bytes. Integers are
  parsed with `strtol`, with an end-pointer check and a range of `0 ≤ v ≤ INT_MAX`.
- **[MEM-5]** No new global state. `srv->mcp` keeps its current lifetime (created at
  `http_server.c:2086` and freed in the existing server teardown).

---

## 4. Failure Modes & Edge Cases

| Ref | Case | Behaviour |
|---|---|---|
| **[FAIL-1]** | A required param is missing or empty (`project`, `qualified_name`) | 400 `{"error":"missing <name>"}`; the engine is not called |
| **[FAIL-2]** | A param exceeds its buffer, or an int is malformed or negative | 400; no truncation is passed through |
| **[FAIL-3]** | OOM in the yyjson mut doc or write | 500 `{"error":"out of memory"}`; everything allocated so far is freed |
| **[FAIL-4]** | The engine returns NULL | 500 `{"error":"tool failed"}` |
| **[FAIL-5]** | The engine result is not valid JSON, or `content[0].text` is not a string | 500; nothing is echoed back from the raw result |
| **[FAIL-6]** | Unknown project, or no DB for the project | The engine's own JSON error text is passed through with a **200** status, as the UI expects today. It is never wrapped in JSON-RPC. |
| **[FAIL-7]** | POST, PUT or DELETE sent to the three view routes | 405, or the existing router's not-found (404), whichever the dispatcher already produces. The body is never read. |
| **[FAIL-8]** | A JSON-RPC body (`initialize`, `tools/list`, `tools/call`) POSTed to `/rpc`, `/`, `/api/*` or any unknown path | 404, or 400/405 from existing routes. The response must not contain `"jsonrpc"`. |
| **[FAIL-9]** | `install` is run in `codebase-memory-cli` with an existing `$HOME` holding client configs | Exit ≠ 0 with the [CLI-2] JSON. The mtimes and contents of every file under `$HOME` are unchanged. |
| **[FAIL-10]** | `uninstall` runs when there is no upstream entry | Exit 0, no file is written or created |

---

## 5. Testing & Acceptance Criteria

Run all tests offline. TDD is the default. Each test below starts **red** on the current tree.

| Ref | Test | Red first (current tree) | Green after | Gate |
|---|---|---|---|---|
| **[TEST-1]** | Extend `verify-cli-only-link` with the [ARCH-8] symbols and strings | Red because `mcp.c` is compiled unguarded and `http_server.c` references `cbm_mcp_server_handle`, so the symbol is present | Symbol and strings absent | M1 |
| **[TEST-2]** | Add `test-cli-only-ui` in `cli-only.mk`. It builds the existing UI test TU(s) with `http_server.c` compiled with `-DCBM_FORK_CLI_ONLY=1`. Cases: `POST /rpc` with a `tools/call` body → 404. A JSON-RPC `initialize`/`tools/list`/`tools/call` POST to `/`, `/rpc`, `/api/projects`, `/api/schema`, `/api/snippet` and `/api/nope` → status ≠ 200 and the body has no `"jsonrpc"`. | Red because `/rpc` returns 200 | Pass | M2 |
| **[TEST-3]** | Same TU, both default and guarded builds: `GET /api/projects` on a fixture store → 200 with a `projects` array. `GET /api/schema?project=<fixture>` → `node_labels`. `GET /api/snippet?...` → `source`. [FAIL-1], [FAIL-2] and [FAIL-7] cases. ASan/UBSan clean via `scripts/test.sh --suites ui`, or the suite that owns `test_ui.c`. | Red because the routes don't exist (404) | Pass | M2, G9 |
| **[TEST-4]** | `graph-ui`: update `useProjects.test.tsx` and `NodeDetailPanel.test.tsx` to mock `fetch` for GET `/api/projects\|schema\|snippet` (with pagination across 2 pages). Add `views.test.ts` for the `encodeURIComponent` and non-ok cases. Run with `npm test` in `graph-ui/`, offline. Also `grep -rn "/rpc\|jsonrpc" graph-ui/src` → empty. | Red because the tests import `views.ts`, which doesn't exist yet | Pass | M3 |
| **[TEST-5]** | `tests/test_cli_only_install.sh`: create a temp `HOME` seeded with fixture configs for every client in `agent_clients.c`. Take a checksum of the tree, then run `codebase-memory-cli install` (both `-y` and default). Expect exit ≠ 0, the [CLI-2] JSON, and an identical checksum. Then seed an upstream `codebase-memory-mcp` entry and run `uninstall`: the entry is removed, and `grep -r 'mcpServers\|"mcp"\|\.mcp\.json\|codebase-memory-mcp'` shows no **new or changed** match compared with the baseline. | Red because `install` currently writes `mcpServers` | Pass | M6, [FAIL-9], [FAIL-10] |
| **[TEST-6]** | Add to `test_cli_only_smoke.sh`: `--help`, `<cmd> --help` for every command, and `install`/`uninstall` output are grepped case-insensitively for `mcp server\|mcpServers\|\.mcp\.json\|claude mcp add`. Expect no match. | Red because help mentions MCP setup | Pass | M7 |
| **[TEST-7]** | Remove the warning flags per [ARCH-7] and build `cbm-cli` with `-Werror` | Red (negative control): removing both flags from both TUs shows exactly which TU fails, and that failure is the justification | Zero warnings; remaining flags justified with comments | M5 |
| **[TEST-8]** | [AUDIT-1] table in `plan.md` | `TDD-BYPASS`: this is a review artefact, not behaviour. The substitute evidence is the table plus [TEST-1]. | No `FORBIDDEN` rows | M4 |
| **[TEST-9]** | Default build regression: `make -f Makefile.cbm cbm` and `scripts/test.sh`. Existing `/rpc` tests on the default build still pass. | n/a (guard check) | Pass, zero warnings | G4, [GUARD-1] |

**Done when:** TEST-1 through TEST-9 are green, and the ROADMAP §5 gates pass (`scripts/build.sh
--cli-only`, `verify-cli-only-link`, `test-cli-only`, `scripts/test.sh`). A diff review must also
confirm [GUARD-1] and that no shared-core file was touched. After that, set the ROADMAP row for
02 to COMPLETED and mark D-2, D-3 and D-5 as closed.
