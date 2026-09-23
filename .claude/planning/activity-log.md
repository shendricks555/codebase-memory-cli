# Activity log

Dated changelog of every `/roadmap-advance` action. One entry per stage
completed, appended by the `roadmap-advance` skill.

## 2026-09-16

- F2 (`02-mcp-engine-split`) **Spec**: wrote `spec.md` splitting the mcp.c tool
  engine from the JSON-RPC/stdio transport behind an additive
  `CBM_FORK_CLI_ONLY` guard (default-off, no behavior change). Touchpoints
  filesystem-verified (MCP graph tools down, CONNECTION_CLOSED); ticked ROADMAP
  F2/Spec ✅.
- F2 (`02-mcp-engine-split`) **Plan**: wrote `plan.md` + `progress.json`
  (Phase 0 build/config guard + verify target, Phase 1 additive guard split of
  mcp.c/mcp.h, Phase N validation). Confirmed one-way transport→engine seam and
  that `cbm_jsonrpc_*` is shared with `src/daemon/frontend.c` (E3 checks the
  mcp.c TU in isolation). Ticked ROADMAP F2/Plan ✅.
- F2 (`02-mcp-engine-split`) **Implement**: implementer agent added additive
  `#ifndef CBM_FORK_CLI_ONLY` guards (mcp.c 3 blocks, mcp.h 2 blocks; 34
  insertions / 0 deletions, no engine reorder) + `verify-mcp-engine-split`
  Makefile target. Evals E1–E5 PASS (default build ok; mcp/daemon suites 351
  passed under ASan/UBSan; guarded compile excludes transport; default object
  byte-identical). Deviations flagged for quality-gate: a 3rd guard block for
  router-only response builders, and `cbm_mcp_server_request_scope_begin` left
  unguarded (engine calls it). Graph tools unavailable → compile-driven
  verification. Ticked ROADMAP F2/Implement ✅.
- F2 (`02-mcp-engine-split`) **Verify**: `/quality-gate` agent verdict **PASS**.
  Independently re-confirmed E1/E3/E4 + the `-Werror` guarded-compile seam; E6
  (additive/guard-only, 0 deletions, no new networking/handler surface)
  satisfied by inspection → flipped E6/TN.5 to true, Validation phase complete.
  One WARN: E2 suite not independently re-run this session (already green under
  the implementer; default path provably byte-identical) — re-run
  `scripts/test.sh` MCP suites before commit. Ticked ROADMAP F2/Verify ✅. **F2
  fully complete.**
- F3 (`03-inprocess-cli-exec`) **Spec**: wrote `spec.md` — under
  `CBM_FORK_CLI_ONLY`, re-point `run_cli`'s non-worker branch from
  `main_local_cli_daemon_execute` (main.c:1734) to the in-process
  `cbm_mcp_server_new`+`cbm_mcp_handle_tool` path (main.c:936-953); retain
  `project_lock` file locks, drop `version_cohort` barrier (resolves R-7); all
  17 tools + `--json`/`--format json` parity preserved; FR-5 flags checking
  `project_lock.c` builds independent of daemon (enables F4). Evals E1–E7.
  Ticked ROADMAP F3/Spec ✅.
- F3 (`03-inprocess-cli-exec`) **Plan**: wrote `plan.md` + `progress.json`.
  Phase 0 adds a guarded verify build (`cbm-fork-verify`, daemon still linked +
  `-DCBM_FORK_CLI_ONLY=1`) since the guard-defining CLI-only target is F4, plus
  the E6 project_lock-isolation check. Phase 4 (TDD, src/main.c+cli.c): re-point
  run_cli non-worker branch in-process, drop cohort/keep project_lock, fence
  cli.c cohort refs. Flagged risk: current in-process block only sets result
  when maintenance_context present. Ticked ROADMAP F3/Plan ✅.
- F3 (`03-inprocess-cli-exec`) **Implement**: survived two agent interruptions
  (session rate-limit, then two 50-turn caps) via progress.json checkpointing +
  HANDOVER resumes. main.c (9 guard blocks) routes run_cli's non-worker branch
  in-process under `CBM_FORK_CLI_ONLY`; cli.c (8 guard blocks) fences the
  version_cohort cluster; 3 new F3 tests in SUITE(cli). Evals E1–E7 pass; E1
  (strace) + E2 (live-daemon byte-diff) dynamic checks recorded in
  `deferredVerification` (sandbox has no strace; default daemon route wedges on
  the R-6 barrier F3 removes) with static+unit+runtime evidence instead. Default
  build byte-unchanged; suite 636+127 green. maintenance_context generalized
  without lease leak/double-free (ASan-clean). Also fixed 171 stale macOS .o
  artifacts breaking the Linux link. Ticked ROADMAP F3/Implement ✅.
- F3 (`03-inprocess-cli-exec`) **Verify**: `/quality-gate` verdict **WARN** (not
  PASS) → F3/Verify **NOT** ticked. No FAIL: all fork constraints independently
  confirmed (guard-scoped; default byte-unchanged, clean `-Werror` across all 4
  guard/file combos; no new networking — `main_daemon_ctl_*` socket cluster
  unreachable from the guarded `cli` path; cohort dropped only under guard,
  project_lock retained; maintenance_context cleanup leak-free; no shared-core
  edits). WARN causes: (1) E1 strace + E2 live-daemon byte-diff DEFERRED under
  real sandbox limits (no strace; daemon route wedges on the R-6 barrier F3
  removes) — corrected progress.json E1/E2 to `passes:false` so Verify isn't
  falsely auto-completed; (2) unit tests cover engine primitives not the static
  `run_cli` branch directly; (3) uncommitted F2 `src/mcp` fences entangle the F3
  diff (commit-hygiene); (4) gate didn't re-run full build/suite (implementer
  did: 636+127 green). **Roadmap chain paused at F3 Verify — needs a human
  decision (accept substitute evidence & proceed, or defer to an
  strace/daemon-capable env). F4 is gated on F3 being fully Verified.**

## 2026-09-17

- F3 (`03-inprocess-cli-exec`) **Verify** resolved: human decision (via
  `/roadmap-advance` under `/loop`) **ACCEPTED the substitute evidence** for the
  two sandbox-unverifiable evals — E1 (dynamic `strace` no-network proof; strace
  absent here) and E2 (live daemon-vs-guarded byte-diff; daemon route wedges on
  the R-6 barrier F3 removes). All non-environmental fork constraints were
  already independently confirmed by the prior `/quality-gate` (WARN, no FAIL):
  guard-scoped diff, default build byte-unchanged and `-Werror`-clean across all
  4 guard/file combos, no networking reachable from the guarded `cli` path,
  cohort dropped only under guard with project_lock retained, no shared-core
  edits. Commit-hygiene WARN cause also cleared — the F2/F3 guards are now all
  committed in `8fc3409a` (working tree clean bar the in-progress
  `roadmap-advance/SKILL.md`). Updated `progress.json`: phase 99 → complete,
  TN.4 → passes:true (records the acceptance), E1/E2 → passes:true annotated
  "SATISFIED BY SUBSTITUTE EVIDENCE" with the dynamic checks retained in
  `deferredVerification` for a capable env. Ticked ROADMAP F3/Verify ✅. F3 is
  now fully complete; F4 (`04-cli-only-build-target`) is unblocked.
- F4 (`04-cli-only-build-target`) **Spec**: wrote `spec.md` for the shippable
  `codebase-memory-cli` binary. FRs: additive `Makefile.cbm cbm-cli` target
  (`CBM_FORK_CLI_ONLY`, PROD_SRCS minus daemon runtime/frontend
  `daemon/version_cohort/service/runtime/application/frontend/host` + the MCP
  stdio frontend, keep engine/index_supervisor/project_lock +
  store/cypher/pipeline/internal-cbm/ui); guard-scoped `main.c` dispatch so
  DAEMON/DAEMON_CTL/MCP_CLIENT branches compile out and the default/unknown
  fall-through prints help instead of the stdio MCP server (never reads stdin
  JSON-RPC); `scripts/build.sh --cli-only`; TEST_SEAMS stays opt-in; default
  `make cbm` byte-unchanged. Evals E1–E9. **Two spec-time findings for /plan**
  (filesystem-verified, graph tools CONNECTION_CLOSED this session): (1) the
  argv classifier `cbm_daemon_process_role` (`bootstrap.c`), `project_lock.c`,
  and the lone helper `cbm_daemon_ipc_private_lock_directory_new` all live in
  `DAEMON_SRCS`, and only `ipc.c` carries the 5 daemon sockets — so "minus
  DAEMON_SRCS" can't be literal; plan must retain those three while excluding
  ipc.c's socket cluster (guard/split/dead-strip — plan's call). (2) The kept
  `src/ui` loopback listener is the sole permitted socket, dormant until F5, so
  E2's nm-assertion scopes to daemon/IPC symbols only. Ticked ROADMAP F4/Spec ✅.
- F4 (`04-cli-only-build-target`) **Plan**: wrote `plan.md` + `progress.json`.
  Phase 0 (build): additive `cbm-cli` target + `scripts/build.sh --cli-only` +
  `verify-cli-only-link` nm-assertion; TEST_SEAMS excluded from release recipe.
  Phase 4 (TDD, guard-scoped): T4.1 entry-dispatch tests first (bare/unknown →
  help + non-zero + no stdin JSON-RPC; daemon roles inert; 17 tools +
  project_lock on the shipped binary), T4.2 guard `main.c` DAEMON/DAEMON_CTL/
  MCP_CLIENT branches out and route default → help, **T4.3 link-isolation
  decision** (prefer link-level `--gc-sections` with ZERO `src/daemon` edits;
  fall back to guard-scoped `#ifndef` removal in ipc.c/bootstrap.c). Phase 99:
  E7 byte-unchanged default + suite + `/quality-gate`. Eval coverage E1–E9 mapped
  to phases; NFR table covers no-MCP/no-daemon delivery, mergeability, TEST_SEAMS,
  byte-stable default. **Plan-time finding** (graph tools CONNECTION_CLOSED,
  grep-verified): correcting the F3 hand-off — `bootstrap.c` (argv-classifier
  home) references `ipc.c` coordination fns (`endpoint_new`/
  `lifetime_reservation_probe`/`startup_lock_*`), so the classifier TU is not
  socket-isolated even though the classifier body is pure argv; only `ipc.c`
  carries the 5 daemon sockets. Ticked ROADMAP F4/Plan ✅.
