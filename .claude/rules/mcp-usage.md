---
paths:
  - "**"
description: Mandatory use of the codebase-memory-mcp server for codebase navigation
---

# Mandatory codebase-memory-mcp usage

This session has the `codebase-memory-mcp` MCP server available. It is the
**required first tool** for any structural code discovery in this repo — use
it instead of, or before, grep/Explore-style text search whenever the
question is "where is X defined," "what calls Y," "how do these modules
relate," or "what does this part of the architecture look like."

This applies to every skill and agent in `.claude/` that touches code
understanding: `/spec`, `/plan`, `/implement` (the `implementer` agent),
`/quality-gate` (the `quality-gate` agent), and `/roadmap`.

## Required workflow

1. `list_projects` — confirm this repo is indexed before anything else.
   `index_repository` only if it isn't indexed yet, or to force freshness
   after a large external change (e.g. a fresh `git pull` from upstream).
2. `get_architecture` — orient on module structure before proposing a plan
   phase or touching an unfamiliar area.
3. `search_graph` — find symbols/definitions structurally (preferred over
   grep for anything that is code, not prose).
4. `trace_path` — find callers/callees before changing a function's
   signature or behavior, so blast radius is known up front.
5. `get_code_snippet` — pull exact source for a located symbol instead of
   re-reading whole files when only one definition is needed.
6. `query_graph` — for multi-hop structural questions (e.g. "which pipeline
   passes call into `internal/cbm` extractors").
7. `check_index_coverage` — for any path a spec/plan/quality-gate report
   cites, and for any negative or exhaustive claim ("nothing else calls
   this") before stating it as fact. Coverage is best-effort, never proof of
   completeness — say so if coverage is partial.
8. Fall back to `search_code` or filesystem grep only for literal/non-code
   text (comments, strings, docs, build scripts) or when graph coverage is
   insufficient — and say explicitly when you've fallen back and why.

## Enforcement

- `implementer.md` and `quality-gate.md` must list the `mcp__codebase-memory-mcp__*`
  tools in their `tools:` frontmatter alongside Read/Grep/Glob — they are not
  optional extras.
- Before an implementer agent reports a phase's blast radius, or a
  quality-gate agent reports an architecture-boundary finding, it must have
  called `trace_path` and/or `search_graph` for the symbols involved, not
  relied on grep alone. If the MCP server is unavailable or unindexed for
  some reason, say so explicitly rather than silently falling back.
