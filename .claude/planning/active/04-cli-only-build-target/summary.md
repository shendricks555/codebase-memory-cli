# Feature summary: CLI-only build target & entry dispatch (guarded)
**Sequence:** 004 | **Depends on:** F3 | **Spans:** build, main

## Behavior
Produces the actual shippable artifact: a `codebase-memory-cli` binary that does not link the
coordination daemon or the MCP stdio frontend, and whose entry dispatch never starts an MCP server.
A bare or unrecognized invocation prints CLI help instead of speaking JSON-RPC on stdio.

## Functional Requirements (high level)
- Add a `Makefile.cbm` target (e.g. `cbm-cli` → `build/c/codebase-memory-cli`) that defines
  `CBM_FORK_CLI_ONLY` and builds from `PROD_SRCS` **minus** `DAEMON_SRCS` and the MCP stdio-frontend
  sources, **plus** the retained tool engine, `index_supervisor`, and `project_lock` — keeping
  `store/cypher/pipeline/internal-cbm/ui`.
- Under the guard, edit `main.c`'s role classifier (`cbm_daemon_process_role`) and the `main` switch
  so DAEMON / DAEMON_CTL / MCP-stdio (`MCP_CLIENT`) branches are compiled out; the default/unknown
  path prints `--help`, not the MCP server.
- Add `scripts/build.sh --cli-only` (and document that the fork's default build is CLI-only).
- Preserve the `TEST_SEAMS=1` opt-in-only pattern; the CLI-only release build must not compile test
  seams.
- Keep the default upstream target (`make -f Makefile.cbm cbm`) byte-for-byte unchanged.

## NFR impact
- Delivers the "no MCP, no daemon" property at the binary level; no socket-capable code is linked
  except the loopback UI (added in F5).
- Upstream-mergeability: new target is additive; `main.c` edits are guard-scoped.

## Research pointers
- R-2, R-3 (dispatch default + guard), plus the build-var findings (`PROD_SRCS` L507, `DAEMON_SRCS`
  L332, `MCP_SRCS` L329 in `Makefile.cbm`).

## Deferred
- The loopback UI starter (F5) and the audited no-network guarantee (F6) build on this target.
