# Feature summary: Copilot (no-MCP) CLI integration + build/run quickstart
**Sequence:** 007 | **Depends on:** F4, F6 | **Spans:** cli, docs

## Behavior
Makes the finished binary easy to adopt: documents and provides the **no-MCP** way to drive it from
GitHub Copilot across VS Code, Visual Studio, JetBrains/IntelliJ, and Android Studio, and delivers
the definitive source→build→run local-dev quickstart now that the binary and its subcommands exist.

## Functional Requirements (high level)
- Provide Copilot-via-CLI recipes: Copilot agent/chat/terminal invoking
  `codebase-memory-cli cli --json <tool> --format json` as commands. Include a thin wrapper script,
  ready-to-drop task/prompt snippets, and per-IDE notes (VS Code, Visual Studio, JetBrains,
  Android Studio).
- State plainly that Copilot's native external-tool protocol **is** MCP, so this integration is
  command invocation by design — no `.mcp.json`, no MCP server. Do not imply a seamless tool-protocol
  hookup that the no-MCP policy forbids.
- Finalize the real build/run quickstart in `README.md` + `docs/` (replacing the F1 placeholders):
  clone → `scripts/build.sh --cli-only [--with-ui]` → `codebase-memory-cli --help` →
  `cli --json index_repository` / `search_graph` → optional `ui`. Verified, copy-pasteable commands.
- Document the common query tools with example CLI invocations and JSON output shapes.

## NFR impact
- Usability/adoption is the headline; correctness of documented commands must be verified against the
  built binary (no aspirational commands).
- Honesty: the MCP caveat is a hard requirement, not a footnote.

## Research pointers
- R-1 (Copilot↔tool is normally MCP; no-MCP path is command invocation).
- R-4 (final quickstart supersedes the corrected-but-placeholder F1 docs).

## Deferred
- A native VS Code extension / JetBrains plugin wrapper (beyond command snippets) — only if the
  command-invocation ergonomics prove insufficient (roadmap-level deferred item).
