# Roadmap research

Findings that inform roadmap sequencing or feature scoping, tagged with a verification status.
Populated by `/roadmap` on 2026-09-16.

> Note: the `codebase-memory-mcp` MCP graph tools were unavailable this session
> (CONNECTION_CLOSED — the dev-container daemon was wedged on stale coordination state), so these
> findings are **filesystem-verified** via exploration, not graph-verified. Re-confirm with
> `search_graph`/`trace_path` once the MCP server is back up.

<!-- R-1: Copilot's native external-tool mechanism is MCP (verified) -->
**R-1 (verified).** GitHub Copilot connects to external tools like this via MCP (today: an
`.mcp.json` entry; README integration matrix covers Copilot CLI, VS Code Copilot, JetBrains, etc.).
A no-MCP fork **cannot** register as a Copilot MCP server. The realistic no-MCP path is Copilot's
agent/chat/terminal invoking `codebase-memory-cli cli --json <tool> --format json` as shell
commands. Product decision needed on per-IDE ergonomics (F7).

<!-- R-2: CLI tool logic lives in mcp.c and routes through the daemon (verified) -->
**R-2 (verified).** All 17 tools are implemented inside `src/mcp/mcp.c`, dispatched by
`cbm_mcp_handle_tool` (mcp.c:17264). The `cli <tool>` path (`run_cli`, main.c:792) default-routes
through the daemon via `main_local_cli_daemon_execute` (main.c:1734). Both `src/mcp` and
`src/daemon` are removal targets → **split** mcp.c (keep engine, drop the `cbm_jsonrpc_*` /
`cbm_mcp_server_run` / `tools/call` stdio transport at mcp.c:227-333, :17675) and **bypass** the
daemon by re-pointing `run_cli` at the existing in-process path (`cbm_mcp_server_new` +
`cbm_mcp_handle_tool`, main.c:936-953). `index_supervisor.*` must be retained.

<!-- R-3: coupling confined to main.c + cli.c (verified) -->
**R-3 (verified).** Nothing in `foundation/store/cypher/pipeline/internal-cbm/watcher/discover/
semantic` includes any `mcp/`, `daemon/`, or `ui/` header. All coupling into the removal targets is
in `src/main.c` and `src/cli/cli.c` (plus `client_adapter.c`/`hook_augment.c`, which pull
`mcp/mcp.h` only for the tool schema). → small blast radius. Use an additive `CBM_FORK_CLI_ONLY`
compile guard to keep the shared core untouched for upstream mergeability.

<!-- R-4: existing CLI docs are factually wrong (verified) -->
**R-4 (verified).** `docs/CLI_QUICKSTART.md` and `docs/CLI_BUILD_RUN_GUIDE.md` describe a **Go/Cobra**
project (`go build`, `cmd/`, `go.mod`); the codebase was rewritten to **pure C11** at upstream
v0.5.0. They actively mislead and must be corrected (F1).

<!-- R-5: no-network audit is close but not strict (verified) -->
**R-5 (verified).** `scripts/security-network.sh` runs the binary under `strace -e trace=connect`
but *tolerates* an `api.github.com:443` update-check and only watches `connect()`. The binary
performs a GitHub update check. The fork must disable that egress and tighten the audit: forbid
443/GitHub, assert no `socket()/bind()/listen()` except the sanctioned loopback UI, and prune the
now-dead AF_UNIX/daemon `NETWORK:` entries from `scripts/security-allowlist.txt` (F6).

<!-- R-6: current MCP failure is the daemon layer the fork removes (verified live) -->
**R-6 (verified live).** The dev-container MCP server was failing with
`version_cohort.claimed_unheld … CBM daemon could not start within 30000 ms` — stale coordination
state (dead pid 1705's socket + cohort locks) in `/tmp/cbm-daemon-1000` after a container restart.
This is exactly the daemon/admission-barrier layer the fork deletes; the CLI-only binary has no such
failure mode. Immediate dev-container remediation (`rm -rf /tmp/cbm-daemon-1000` + web reinstall) is
tracked outside this roadmap.

<!-- R-7: local locking decision when the daemon is gone (unverified) -->
**R-7 (unverified — spec-time decision).** `cli.c`/`main.c` depend on daemon `project_lock` and
`version_cohort` for local coordination. Decide which to retain for single-process CLI: **retain**
per-project graph-mutation file locking (`src/daemon/project_lock.c` — pure file locks, no socket),
**drop** the cohort admission barrier (`version_cohort`). Confirm no other survivor needs the
dropped symbols (F3).
