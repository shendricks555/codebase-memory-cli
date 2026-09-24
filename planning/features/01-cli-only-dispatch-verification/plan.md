# Plan — 01 `cli-only-dispatch-verification` (trimmed)

**Spec:** spec.md | **Status:** DONE

## Scope (as built)
One smoke script plus one make target. No `src/` changes were needed.

- `tests/test_cli_only_smoke.sh` runs the shipped `build/c/codebase-memory-cli`. It uses `CBM_TEST_BINARY` when set, and keeps all scratch files under `build/c/`.
- `make -f Makefile.cbm test-cli-only` (in `cli-only.mk`) builds `cbm-cli` and runs the script.

## What it checks
| Eval | Check |
|---|---|
| E3/E4 | Bare, unknown, `--cbm-daemon-internal`, `daemon status/stop/start`, `--stdio`, `mcp`, `serve`, `--ui=true` and the exact index-worker argv each exit 2, never print `"jsonrpc"` and print help. They are run with stdin as /dev/null and again with stdin held open on a FIFO, under a 5 s timeout. `--help`/`-h` exit 0. |
| E4 (hooks) | `hook-augment` is fail-open by contract. The check is only that it finishes and never prints `"jsonrpc"`. |
| E5 | Index a two-function C fixture, then run all 17 tools via `cli --json`. Each prints one JSON document, rc is 0 or 1, and there is no `unknown tool`. `nosuchtool` returns a JSON error with rc ≠ 0. |
| E6 | Two concurrent `index_repository` runs, 3×. Both exit 0 and the DB passes `PRAGMA integrity_check`/`quick_check`. |
| Artifacts | No sockets and no `*.sock`, `*daemon*`, `*cohort*` or `*startup_lock*` files under the temp root, and no new sockets in /tmp. |

## Recorded behaviour (not changed)
- Help goes to stdout. Bare and unknown argv exit 2, and `--help` exits 0.
- `cli --json nosuchtool` exits 1. Tool-level errors (e.g. `compare_graphs` on the same project) exit 1 with a valid envelope.
- The product's project-lock dir is `/tmp/cbm-daemon-<uid>` (named in `src/daemon/`). It holds only lock files and is allowed.
- `--format json` is not a real flag. `--json` returns the raw envelope.

## Evidence
- Green: `bash tests/test_cli_only_smoke.sh` → 0 failures, ~10 s.
- Red: a fake binary that reads stdin and prints JSON-RPC fails the inert cases (it times out or answers JSON-RPC).

## Cut from the original plan (deliberately)
C harness, E7 byte-diff script (`verify-default-bytes`), sanitizer binary variant, D10–D12 damaged-DB cases, E6b, `progress.json`, the G1–G9 gate run, and the `scripts/test.sh` step. They were out of proportion to a smoke test and can be revived individually if a later milestone needs them.
