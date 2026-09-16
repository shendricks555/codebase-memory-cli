# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Fork purpose

This is a fork of upstream `codebase-memory-mcp`. The goal of this fork is to produce a **separate binary** that has all MCP protocol handling and the coordination daemon removed, so the resulting tool satisfies "no MCP servers" AI policies at companies that ship this internally. The local, localhost-only graph-viz UI (`src/ui/`) is explicitly **kept** — it is not remote networking or MCP, and it's how people see the code graph. Two constraints drive every change here:

1. **Keep upstream mergeable.** We must be able to run `git pull` from upstream on an ongoing basis to absorb language/grammar/pipeline improvements. Prefer changes that are additive or isolated (new build target, compile-time guards, deletion at the edges) over changes that rewrite shared core files (`src/foundation`, `src/store`, `src/cypher`, `src/pipeline`, `internal/cbm`). Touching a file that upstream actively changes increases future merge-conflict risk — minimize the diff footprint in those areas.
2. **No MCP, no daemon; localhost-only UI is allowed.** The shipped binary must not speak MCP JSON-RPC and must not run the multi-client coordination daemon (Unix-domain socket IPC, cross-session ownership). That means `src/mcp/` and `src/daemon/` are the removal targets — not `src/cli/` (local one-shot commands, already network-free upstream, see below) and not `src/ui/`. `src/ui/` may run its graph-viz HTTP server bound to `localhost` only, started on-demand by the CLI itself (not by a shared daemon, since the daemon is removed) and never listening on a non-loopback interface or requiring inbound connections from other hosts.

When in doubt about whether a change belongs in this fork vs. upstream: behavior changes that only strip MCP/daemon and adapt the UI to run without the daemon belong here; general indexing/parsing/language improvements should go upstream and be pulled in.

## Commands

```bash
scripts/build.sh              # standard release build -> build/c/codebase-memory-mcp
scripts/build.sh --with-ui    # bundles the graph-viz UI (src/ui/) into the fork binary — kept in this fork, unlike MCP/daemon
scripts/test.sh               # build with ASan+UBSan and run the full C test suite
scripts/lint.sh               # clang-tidy, cppcheck, clang-format — must pass before committing
make -f Makefile.cbm test           # build + run all tests (ASan + UBSan)
make -f Makefile.cbm test-foundation # foundation tests only (fast)
make -f Makefile.cbm cbm            # production binary
make -f Makefile.cbm security       # 8-layer security audit (static allow-list, string scan, network-egress test, fuzz, etc.)
```

Run a single test file/case: the suite is plain C test binaries under `tests/`; grep `tests/*.sh` and `scripts/test.sh` for how individual `test_*.c` files are selected/filtered before adding a new invocation pattern — don't assume a `-run` style flag exists without checking.

`git config core.hooksPath scripts/hooks` activates the pre-commit security checks (run once after cloning).

## Architecture

Pure C11 codebase (rewritten from Go at upstream v0.5.0 — **do not submit Go code**, only C). No language runtime, no external services; everything (tree-sitter grammars, SQLite, JSON) is vendored and compiled into the binary.

```
src/
  foundation/   arena allocator, hash table, string utils, platform compat — core, shared, low-conflict-risk to touch
  store/        SQLite graph storage (WAL mode, FTS5)
  cypher/       Cypher query -> SQL translation
  pipeline/     multi-pass indexing pipeline (pass_*.c: definitions, calls, usages, HTTP-route extraction, infra-scan)
  discover/     file discovery with gitignore support
  watcher/      git-based background auto-sync
  cli/          local one-shot CLI subcommands (install/update/uninstall/config) — no daemon, no persistent listener
  mcp/          MCP server: JSON-RPC 2.0 over stdio, tool handlers  <- REMOVAL TARGET for this fork
  daemon/       shared coordination daemon: Unix-domain socket IPC, session registration, watcher/indexing ownership  <- REMOVAL TARGET
  ui/           graph-visualization HTTP server (first-party httpd, served at localhost:9749)  <- KEPT: localhost-only, started on-demand by cli, not by the (removed) daemon
internal/cbm/   language registry, tree-sitter AST extraction, vendored grammars (162 languages)
vendored/       sqlite3, yyjson, mimalloc, xxhash, tre, nomic — all vendored, no network fetch at build/run time
graph-ui/       React/Three.js frontend for the graph UI — kept, bundled via scripts/build.sh --with-ui
```

Key upstream behaviors to know when deciding what to strip:

- **Coordination daemon** (`src/daemon/`): one per-account daemon is shared across all MCP-speaking clients (Claude Code, Codex, OpenCode, etc.). It owns watchers, shared indexing jobs, and the optional UI, coordinated via a Unix-domain socket (`src/daemon/ipc.c`) plus a crash-safe OS admission barrier so all active CBM processes agree on version/build/cache-root. `cli` mode is the one path upstream already keeps out of daemon/socket coordination — it runs one command locally and only touches the OS admission barrier and per-project graph-mutation locks. That makes `src/cli/` + `src/pipeline/` + `src/store/` + `internal/cbm/` the natural core to build this fork's binary from.
- **MCP server** (`src/mcp/`): JSON-RPC 2.0 over stdio exposing indexing/query tools (search, trace, architecture, Cypher queries, ADR management, etc.) to MCP clients. This fork's binary should expose equivalent functionality only via direct CLI subcommands (see `src/cli/cli.c`), not JSON-RPC.
- **UI** (`src/ui/`): serves the bundled graph-viz frontend over HTTP on `localhost:9749`. Upstream has the daemon own it so concurrent sessions don't start duplicate servers; since this fork removes the daemon, the fork's `cli` must instead start/stop the UI server itself for a single local session (e.g. a `codebase-memory-mcp ui` or `--serve-ui` subcommand) and must refuse to bind anything but a loopback address.
- Infra-language support (Dockerfile/K8s/Kustomize) follows an "infra-pass" pattern in `src/pipeline/pass_infrascan.c` + `internal/cbm/extract_k8s.c` reusing the tree-sitter YAML grammar rather than adding new grammars — relevant only if extending indexing, not to the MCP-removal work.

## Language/extraction workflow (upstream feature work, not fork-specific)

1. Grammar/AST node config lives in `internal/cbm/lang_specs.c`; extraction in `internal/cbm/extract_*.c`.
2. Pipeline passes (call resolution, usage tracking, HTTP-route linking) live in `src/pipeline/`.
3. Regression tests: `tests/test_extraction.c`, `tests/test_pipeline.c`; legacy parity checks in `internal/cbm/regression_test.go` (being migrated off Go).

## Test seams

`TEST_SEAMS=1` (`-DCBM_ENABLE_TEST_SEAMS=1`) is opt-in only, never opt-out — code that exists purely for test harnesses (e.g. forcing an orphan process for the watchdog to reap) must never compile into a production/release binary. `scripts/test.sh` passes `TEST_SEAMS=1`; `scripts/build.sh` does not. Preserve this pattern for the fork build target.
