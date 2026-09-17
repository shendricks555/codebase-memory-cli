# Roadmap: CLI-only, no-MCP, no-network codebase-memory

**Created:** 2026-09-16 | **Goal:** Ship a separate compiled `codebase-memory-cli` binary with MCP + coordination daemon removed, no outbound network, localhost graph-UI kept, driven from GitHub Copilot via CLI invocation.

## Vision

A company that forbids MCP servers and network dev tools can build this fork from source and run
a single local binary that delivers the same tree-sitter code-graph intelligence as upstream —
`search_graph`, `trace_path`, `get_architecture`, Cypher `query_graph`, `get_code_snippet`,
`index_repository`, and the rest — entirely through one-shot CLI subcommands with `--json` output.
No MCP JSON-RPC. No coordination daemon, no Unix-domain sockets, no cross-session ownership. The
only listener is the opt-in, on-demand graph-viz UI bound to `127.0.0.1`. GitHub Copilot (VS Code,
Visual Studio, JetBrains/IntelliJ, Android Studio) uses it by invoking the CLI as commands, not as
an MCP server. The fork stays upstream-mergeable: all removal is behind an additive
`CBM_FORK_CLI_ONLY` compile guard, and the shared core (`foundation/store/cypher/pipeline/
internal-cbm`) is left untouched so `git pull` keeps absorbing language/pipeline improvements.

## Features (strictly sequential)

| # | Feature | Folder | Spec | Plan | Implement | Verify |
|---|---------|--------|------|------|-----------|--------|
| 1 | Fork framing & doc correction | `01-fork-framing-docs` | — | — | ✅ | ✅ |
| 2 | Split MCP tool engine from stdio/JSON-RPC transport | `02-mcp-engine-split` | ✅ | ✅ | ✅ | ✅ |
| 3 | Daemon-free in-process CLI tool execution | `03-inprocess-cli-exec` | ✅ | ✅ | ✅ | ⬜ |
| 4 | CLI-only build target & entry dispatch (guarded) | `04-cli-only-build-target` | ⬜ | ⬜ | ⬜ | ⬜ |
| 5 | On-demand localhost graph-UI subcommand (daemon-free) | `05-loopback-ui-subcommand` | ⬜ | ⬜ | ⬜ | ⬜ |
| 6 | No-network hardening & guarantee | `06-no-network-hardening` | ⬜ | ⬜ | ⬜ | ⬜ |
| 7 | Copilot (no-MCP) CLI integration + build/run quickstart | `07-copilot-cli-and-quickstart` | ⬜ | ⬜ | ⬜ | ⬜ |

> **Progress note (2026-09-16):** F1 was executed directly (docs-only, no code change), so `/spec`
> and `/plan` were skipped for it (shown as `—`). F2–F6 are code features and should go through
> `/spec → /plan → /implement → /quality-gate`. Done in F1: added the "About this fork" section to
> `README.md`; corrected `docs/CLI_QUICKSTART.md` and `docs/CLI_BUILD_RUN_GUIDE.md` from the stale
> Go/Cobra instructions to the real pure-C11 build. **Next: F2 (split the MCP tool engine).**

## Research

See `RESEARCH.md`. Headlines: coupling into the removal targets is confined to `src/main.c` +
`src/cli/cli.c` (small blast radius); `src/mcp/mcp.c` must be **split** (keep the tool engine, drop
the stdio transport), not deleted; the `cli <tool>` path already exists but routes through the
daemon and must be re-pointed in-process; Copilot's native tool protocol is MCP, so the no-MCP
integration is command invocation by design; and the current dev-container MCP failure is the very
daemon-coordination layer this fork removes.

## Deferred across the roadmap

- Packaging/distribution of the fork binary (Homebrew/npm/release archives) — reuse or fork
  `scripts/package-release.sh` later; not needed to build+run from source.
- A native VS Code extension / JetBrains plugin wrapper for Copilot (beyond command snippets) — only
  if F7's command-invocation ergonomics prove insufficient.
- Migrating remaining Go parity tests (`internal/cbm/regression_test.go`) — upstream concern.
