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
