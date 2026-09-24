# Spec — 01 `cli-only-dispatch-verification` (trimmed)

**Milestone:** 01 of 06 | **Base commit:** `82dd58c5`

A verification milestone. It adds a repeatable smoke test for behaviour that already exists in
`build/c/codebase-memory-cli` (built by `make -f Makefile.cbm cbm-cli`). Product code changes
only if the smoke test finds a defect, and then only inside existing `#ifdef CBM_FORK_CLI_ONLY`
blocks in `src/main.c` / `src/cli/cli.c`.

## Contract checked
- Non-CLI argv (bare, unknown token, daemon, daemon-ctl, MCP-shaped, index-worker) → help, exit 2,
  never answers JSON-RPC, and never blocks on an open stdin. `--help`/`-h` → exit 0.
- `hook-augment` is fail-open: it must finish and never answer JSON-RPC. Any exit code is accepted.
- `cli --json <tool> <args>` for all 17 tools → one JSON document on stdout, rc 0 or 1, never `unknown tool`.
- Concurrent `index_repository` runs on one repo serialize, and the DB passes `integrity_check`.
- No sockets or daemon/cohort artifacts. The product's own `/tmp/cbm-daemon-<uid>` lock-file
  directory is allowed.

## Files
- `tests/test_cli_only_smoke.sh` (bash + python3 stdlib). All scratch files go under `build/c/`.
- `cli-only.mk`: `test-cli-only` target. It is additive and not a prerequisite of any default target.

## Out of scope
Byte-identity of the default build (E7), sanitizer builds of the CLI binary, damaged-DB cases,
formal gate records. The dynamic no-egress proof belongs to milestone 04.
