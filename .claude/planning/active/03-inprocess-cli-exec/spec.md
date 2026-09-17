# Feature: Daemon-free in-process CLI tool execution

> **Verification note:** graph tools were down this session
> (`CONNECTION_CLOSED`); touchpoints below are **filesystem-verified**
> (grep/Read over `src/main.c`, `src/cli/cli.c`, `src/daemon/`), not
> graph-verified. Re-confirm callers with `trace_path` at plan time if the
> server returns. Depends on F2 (✅) — the split engine is what runs in-process.

## Objective

Under `CBM_FORK_CLI_ONLY`, make `codebase-memory-mcp cli <tool> …` execute the
tool **in-process** as a one-shot — open the store, run the tool through the
F2-split engine (`cbm_mcp_server_new` + `cbm_mcp_handle_tool`), print the
result, exit — with **no coordination daemon and no Unix-domain socket**. This
is the functional heart of the fork: it removes the entire daemon/cohort
startup-wedge failure class (RESEARCH R-6) while keeping every tool's output
byte-identical to the daemon-routed result. The default build (guard undefined)
still routes through the daemon and is unchanged. Removing the daemon **sources
from the link line** is F4; F3 only changes the execution path.

## User Scenarios

- **S1 (in-process query).** Given `CBM_FORK_CLI_ONLY` is defined, When a user
  runs `codebase-memory-mcp cli <read-only tool> --format json`, Then the tool
  runs in the same process with no daemon started and no socket opened, and
  prints the same JSON a daemon-routed run would.
- **S2 (in-process mutation with locking).** Given the guard is defined, When a
  user runs a mutating tool (e.g. `index_repository`) concurrently with another
  invocation on the same project, Then per-project graph-mutation **file**
  locking (`project_lock`) still serializes the writers — no corruption — with
  no daemon and no cohort admission barrier involved.
- **S3 (no cohort barrier).** Given the guard is defined, When any `cli`
  invocation starts, Then the `version_cohort` admission barrier is **not**
  engaged, so a stale/dead cohort lock can never wedge startup (R-6 class gone).
- **S4 (machine-contract output preserved).** Given the guard is defined, When
  an external agent invokes with `--json` (raw MCP envelope) or per-tool
  `--format json`, Then the output shape/framing is exactly as today — the
  contract agents consume is unchanged.
- **S5 (all tools reachable).** Given the guard is defined, When any of the 17
  tools is invoked via `cli`, Then it resolves and returns results behaviorally
  identical to the daemon-routed path.
- **S6 (default build unchanged).** Given `CBM_FORK_CLI_ONLY` is **undefined**,
  When the default binary runs `cli <tool>`, Then it routes through
  `main_local_cli_daemon_execute` exactly as upstream does today.

## Functional Requirements

- **FR-1 (S1, S6).** Under the guard, `run_cli` (src/main.c:792) must execute
  the non-`index_worker` branch (currently src/main.c:933-934 →
  `main_local_cli_daemon_execute`, src/main.c:1734) via the **in-process**
  engine path instead (`cbm_mcp_server_new` + `cbm_mcp_handle_tool`, the
  primitives already used at src/main.c:936-953). With the guard undefined the
  daemon route is retained byte-for-byte. (Traces: S1, S6.)
- **FR-2 (S1, S5).** The in-process path must generalize beyond the current
  `index_worker`/`maintenance_context`-only shape so **every** `cli <tool>`
  (all 17) runs and returns a result, with `cbm_mcp_server_set_background_tasks`
  set false (no MCP-session background work in a one-shot). (Traces: S1, S5.)
- **FR-3 (S2).** Per-project graph-mutation file locking
  (`src/daemon/project_lock.c` — pure `flock`/file locks, no socket) is
  **retained** for mutating tools under the guard, wired through the existing
  mutation-guard hooks (`cbm_mcp_server_set_project_mutation_guard` /
  `_try_guard`, src/main.c:944-947). (Traces: S2.)
- **FR-4 (S3) — resolves R-7.** The `version_cohort` admission barrier
  (`src/daemon/version_cohort.*`, constructed at src/main.c:2755, referenced in
  src/cli/cli.c) is **dropped** for the single-process guarded path: not
  constructed, acquired, or required. Retain `project_lock`, drop `cohort`.
  (Traces: S3.)
- **FR-5 (dependency isolation for F4).** Confirm `project_lock.c` compiles/links
  **without** the rest of `src/daemon/` (no dependence on `version_cohort`,
  `ipc`, `frontend`, `host`) so F4 can keep it while dropping the daemon. If it
  is entangled, record exactly what must be untangled (spec-time finding for
  the plan). (Traces: S2, enables F4.)
- **FR-6 (S1, S3).** Under the guard, a `cli` invocation must open **no**
  Unix-domain socket and start **no** daemon process — verified by the absence
  of `socket()`/`connect()`/`bind()`/`listen()` on the guarded path. (Traces:
  S1, S3.)
- **FR-7 (S4).** `--json` (raw MCP envelope) and per-tool `--format json` output
  must be byte-identical to the pre-change daemon-routed output for the same
  inputs. (Traces: S4.)
- **FR-8 (S1).** `index_repository` under the guard drives indexing via
  `index_supervisor` directly (in-process), not a daemon-owned job. (Traces:
  S1.)

## CLI Contract

No new subcommand or flag — same `cli <tool>` surface, different execution
backing under the guard.

| Invocation | Output shape | Exit code | Failure behavior |
|---|---|---|---|
| `cli <tool> --format json` (guard defined) | identical JSON to daemon route | 0 on success | tool error → same error envelope/exit as today; no daemon-connect error path |
| `cli <tool> --json` (guard defined) | identical raw MCP envelope | 0 | as today |
| `cli index_repository` (guard defined) | same result; in-process supervisor | 0 | project-lock contention serialized, not failed |
| `cli <tool>` (guard **undefined**) | unchanged (daemon-routed) | unchanged | unchanged |

## Data Model

No schema change. Store open/lifetime becomes per-invocation (one-shot open →
run → close) instead of daemon-warm; graph shape and on-disk format unchanged.

## Constraints

- Pure C11; edits **guard-scoped** to `src/main.c` and `src/cli/cli.c` only —
  do not touch `foundation/store/cypher/pipeline/internal-cbm` (mergeability).
- Add **no** `socket()`/`bind()`/`listen()`/`accept()`/`connect()` and no new
  server loop (architecture removal-target rule).
- Default build (guard undefined) must remain byte-for-byte upstream behavior.
- `project_lock` retained; `version_cohort` dropped **only** under the guard —
  the default path keeps both.
- Latency: one-shot store open per invocation replaces a warm daemon; acceptable
  for CLI, note for indexing-heavy loops (NFR, not a blocker).
- TEST_SEAMS stays opt-in; no test-only code in the release path.

## Success Criteria

- [ ] Guarded `cli <tool>` runs in-process, no daemon/socket, all 17 tools
      reachable (FR-1, FR-2, FR-5, FR-6).
- [ ] Guarded output for `--json` / `--format json` byte-identical to daemon
      route for a fixed corpus (FR-7).
- [ ] Concurrent mutating invocations serialized by `project_lock`; no cohort
      barrier engaged (FR-3, FR-4).
- [ ] `project_lock.c` shown to build independent of the rest of `daemon/`, or
      the entanglement documented for F4 (FR-5).
- [ ] Default build unchanged (FR-1 guard-undefined path) (S6).

## Evals (Smoke Tests)

| ID | Eval | Type | Verified by |
|---|---|---|---|
| E1 | Guarded `cli <tool>` runs in-process with no socket/daemon | integration | run guarded binary under `strace -e trace=network` (or the repo's `scripts/security-network.sh` harness); assert no `socket()/connect()/bind()/listen()` |
| E2 | Output parity: guarded vs. daemon route byte-identical | integration | diff `--json` and `--format json` output for a fixed tool+repo corpus across both guard states |
| E3 | All 17 tools reachable in-process | integration | invoke each tool name via guarded `cli`, assert non-error envelope |
| E4 | Mutation locking retained (concurrent writers serialized) | integration | two concurrent guarded `index_repository` runs on one project → no corruption, serialized via `project_lock` (extend `tests/test_cli.c` / mutation-guard test) |
| E5 | No cohort barrier on guarded path | unit/criteria | assert `version_cohort` manager not constructed under the guard (symbol/trace or a seam check) |
| E6 | `project_lock.c` builds without rest of daemon | integration | compile/link `project_lock.o` against only its real deps; record result for F4 |
| E7 | Default build unchanged | integration | `make -f Makefile.cbm cbm` + suite green; guard-undefined `run_cli` still daemon-routed |

## Out of Scope

- Removing daemon sources from the link line / flipping top-level dispatch — F4.
- The CLI-only build target and entry guard — F4.
- Loopback UI subcommand — F5. No-network audit tightening — F6.

## Future Enhancements

- Optional store-open caching for tight indexing loops if per-invocation open
  latency proves painful (measure first; not needed for correctness).
