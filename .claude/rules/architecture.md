---
paths:
  - "src/**"
  - "internal/cbm/**"
description: Module boundaries and the fork's removal-target constraint
---

# Architecture

This fork strips MCP protocol handling, the coordination daemon, and networking
from upstream `codebase-memory-mcp`, producing a local, no-network CLI binary.
See `/workspace/CLAUDE.md` for the full rationale before touching anything here.

## Layering

```
src/foundation  -> arena/hash/string/platform primitives, no upward deps
src/store       -> SQLite graph storage, depends only on foundation
src/cypher      -> Cypher -> SQL translation, depends on store + foundation
src/pipeline    -> indexing passes, depends on store + cypher + foundation + internal/cbm
src/cli         -> one-shot local subcommands, the only entry point for this fork's binary
```

`internal/cbm/` (language registry, tree-sitter extraction, vendored grammars) sits
alongside `src/pipeline` and is consumed by it.

## Removal targets — do not extend

`src/mcp/`, `src/daemon/`, and `src/ui/` are being deleted from this fork's build,
not maintained. Never:
- add a new tool handler under `src/mcp/`
- add IPC, socket, or session-coordination logic under `src/daemon/`
- add or extend an HTTP server under `src/ui/`
- introduce `socket()`, `bind()`, `listen()`, `accept()`, or any HTTP/JSON-RPC
  server loop anywhere in code that ships in this fork's binary target

Equivalent functionality belongs in `src/cli/cli.c` as a new subcommand instead.

## Upstream-mergeability constraint

`src/foundation`, `src/store`, `src/cypher`, `src/pipeline`, and `internal/cbm`
are actively developed upstream. Minimize diff footprint there — prefer
compile-time guards or additive changes over rewrites. Behavior changes that
only strip MCP/daemon/UI/networking belong in this fork; general
indexing/parsing/language improvements belong upstream and get pulled in via
`git pull`.
