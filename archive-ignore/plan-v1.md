# Plan — 01 `cli-only-dispatch-verification` (lean)

Source: `../planning/features/01-cli-only-dispatch-verification/spec.md`. Base `82dd58c5`. A standalone black-box harness in `tests/cli_only/` spawns
the shipped `build/c/codebase-memory-cli`. `scripts/fork/verify-default-bytes.sh` covers E7.

## Friction budget (overrides the spec where they differ)
- **One cheap red per eval, not per case.** The unguarded `codebase-memory-mcp` is the natural
  negative control for E3/E4. Three tiny fake binaries (sleep, bad JSON, `*.sock` creator), kept
  as shell one-liners, cover the harness itself. No red runs are written per case.
- **Red/green evidence** is one line per eval in `progress.json`: command plus rc. No transcripts.
- **Dropped:** the `--format json` harness output, the `CLI_ONLY_SANITIZE` second binary (the
  harness itself builds with ASan; shared code is already sanitized by `test-runner`), and the
  cross-check of the tool count against help.
- **Trimmed:** E6 runs 3×, not 5×. D10–D12 (corrupt DB etc.) shrink to a single D10 truncated-DB
  case. Missing-table and unwritable-cache cases are deferred to 04, where hardening lives.
- **Target runtime** for `make test-cli-only`: under 60 s. The target fails if it passes 120 s.
- Any assertion that turns out flaky is downgraded to TDD-BYPASS with a note. It is never retried
  in a loop.

## Resolved decisions
Q1 `--help`: record the current rc and assert it stays stable. Q2: lock acquire blocks with a
deadline, so both concurrent index runs must succeed and the integrity check must return `ok`.
Q3: E7 may mask only the documented build-identity range, logged.

## Tasks
| # | Task | Files | Test-first | Verify |
|---|---|---|---|---|
| T1 | Harness core: spawn in its own pgid, poll capture (16 MiB cap), deadline plus SIGKILL, isolated temp HOME/TMPDIR/CBM_CACHE_DIR, cleanup, JSON/jsonrpc/artifact/descendant checks, `--bin/--only/--keep-tmp` | `tests/cli_only/harness.{c,h}`, `main.c`, `../cli-only.mk` (`test-cli-only`) | Red: the three fakes are each reported FAIL; `printf '{}'` → ok | `make -f Makefile.cbm test-cli-only` builds |
| T2 | E3 + E4: D1–D7 table (roles from `bootstrap.c`), artifact and descendant checks after each case | `suite_dispatch.c` | Red: `--bin build/c/codebase-memory-mcp` fails D1 | green on the CLI binary |
| T3 | E5: fixture (copy + git init + index), D8 ×17 tool table, D9, D10 | `suite_dispatch.c` | Red: a bogus tool name in the table → FAIL (then removed) | 17/17 green |
| T4 | E6: 2 concurrent index runs ×3, `integrity_check`, third run succeeds, one SIGKILL-then-rerun | `suite_dispatch.c` | TDD-BYPASS (race is non-deterministic); substitute: 3× runs | green |
| T5 | E7 script + `verify-default-bytes` target | `scripts/fork/verify-default-bytes.sh`, `../cli-only.mk` | Red: a 1-byte unguarded edit in a scratch worktree → FAIL | PASS vs `e038fec5` |
| T6 | *(conditional)* fix defects found by T2–T4, only inside existing `CBM_FORK_CLI_ONLY` blocks | `../src/main.c`, `src/cli/cli.c` | The failing case already exists | case green + E7 |
| T7 | Step F1 in `../scripts/test.sh`; gates G1–G9 + `/review`; `progress.json`; ROADMAP row | `../scripts/test.sh`, `planning/…` | TDD-BYPASS: plumbing | full `../scripts/test.sh` green |

Order: T1→T2→T3→T4→T6→T7; T5 is independent after T1.
Not touched: shared core, `../src/daemon`, `src/mcp`, `src/ui`, `Makefile.cbm`.
