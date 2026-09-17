# Feature summary: Daemon-free in-process CLI tool execution
**Sequence:** 003 | **Depends on:** F2 | **Spans:** cli, main, mcp, store

## Behavior
Makes `codebase-memory-mcp cli <tool> …` run the tool **in-process**, with no coordination daemon
and no Unix-domain socket. Every invocation is a one-shot: open the store, run the tool via the
split engine, print the result, exit. This is the functional heart of the fork.

## Functional Requirements (high level)
- Under `CBM_FORK_CLI_ONLY`, re-point `run_cli`'s default execution from `main_local_cli_daemon_execute`
  (daemon IPC, main.c:1734) to the in-process `cbm_mcp_server_new` + `cbm_mcp_handle_tool` path that
  already exists for `--index-worker` (main.c:936-953).
- Drive `index_repository` via `index_supervisor` directly (no daemon-owned indexing job).
- Local concurrency safety: retain per-project graph-mutation file locking
  (`src/daemon/project_lock.c` — pure file locks, no socket); drop the daemon/cohort admission barrier
  (`version_cohort`) for single-process use (resolve R-7 at spec time).
- Preserve `--json` (raw MCP envelope) and per-tool `--format json` output exactly as today, since
  those are the machine-consumption contract external agents rely on.
- All 17 tools remain reachable and behave identically to their daemon-routed results.

## NFR impact
- Removes the entire class of failures seen in R-6 (stale cohort/socket wedging startup).
- Latency: one-shot open per invocation instead of a warm daemon — acceptable for CLI use; note it
  for indexing-heavy loops.
- Upstream-mergeability: changes are guard-scoped in `main.c`/`cli.c` only.

## Research pointers
- R-2 (in-process path already exists), R-6 (removes daemon failure mode), R-7 (locking decision),
  R-3 (guard scope).

## Deferred
- Dropping the daemon **sources** from the link line and flipping the top-level dispatch is F4; here
  the execution path is changed but the default build still links the daemon.
