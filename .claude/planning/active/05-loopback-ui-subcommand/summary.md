# Feature summary: On-demand localhost graph-UI subcommand (daemon-free)
**Sequence:** 005 | **Depends on:** F4 | **Spans:** ui, cli, main, build

## Behavior
Restores the graph-viz UI for the fork by starting it directly from the CLI for a single local
session, since the daemon that used to own it is gone. The UI binds `127.0.0.1` only and refuses any
non-loopback address, satisfying the CLAUDE.md "localhost-only UI is allowed" carve-out.

## Functional Requirements (high level)
- Add a CLI subcommand `codebase-memory-cli ui [--port N]` (and/or `--serve-ui`) that runs, in-process:
  `cbm_http_server_new(port)` → configure (index executor → in-process indexer; watcher optional;
  mutation guard; readiness) → `cbm_http_server_run`, mirroring `src/daemon/host.c:328-340`.
- Hard-refuse binding anything but a loopback address; keep the existing CORS/Host loopback
  enforcement in `src/ui/http_server.c`. Default port 9749.
- Keep `scripts/build.sh --with-ui` asset bundling (`cbm-with-ui`-style) working for the CLI target;
  `src/ui` has no dependency on `src/daemon`, so it ports cleanly.
- Clean start/stop lifecycle for a single session (Ctrl-C stops the server; no shared ownership).

## NFR impact
- The one intentional listener in the fork; must remain loopback-only and is audited by F6.
- Upstream-mergeability: UI module unchanged; the starter is new fork code in `cli.c`/`main.c`.

## Research pointers
- R-3 (ui has no daemon dependency; daemon→ui only), and the UI bind/port findings
  (`src/ui/httpd.c` 127.0.0.1:9749, `http_server.h` API surface).

## Deferred
- Any auth/token scheme beyond loopback + readiness secret — not required for local single-user use.
