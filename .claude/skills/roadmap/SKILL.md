---
name: roadmap
description: Turn a product goal into a sequenced ROADMAP.md with per-feature summary.md files (spec/plan/progress are just-in-time, not produced here).
arguments: [goal]
argument-hint: "<product goal>"
disable-model-invocation: true
---

# /roadmap

Run inline, Opus-tier preferred.

## Required context

Read `/workspace/CLAUDE.md` and [[architecture]]. Per [[mcp-usage]], call
`get_architecture` and, for any feature touching existing behavior,
`search_graph`/`trace_path` to confirm the current shape of what's being
extended before sequencing around it.

## Output

Produces **only** `summary.md` per feature folder — never `spec.md`,
`plan.md`, or `progress.json` at roadmap time; those are just-in-time,
produced by `/spec` and `/plan` when a feature's turn comes up. Also writes
`.claude/planning/active/RESEARCH.md` and
`.claude/planning/active/ROADMAP.md`.

`summary.md` format:

```
# Feature summary: <Name>
**Sequence:** ### | **Depends on:** ... | **Spans:** store/cypher/pipeline/cli/build

## Behavior
## Functional Requirements (high level)
## NFR impact
## Research pointers
## Deferred
```

`ROADMAP.md` format:

```
# Roadmap: <Name>
**Created:** <date> | **Goal:** <one line>

## Vision

## Features (strictly sequential)
| # | Feature | Folder | Spec | Plan | Implement | Verify |

## Research

## Deferred across the roadmap
```

Stage cells use ⬜/✅ per stage.

## Rules

- Features are strictly sequential — no parallel-track roadmaps.
- **Never roadmap a feature that would add to `src/mcp/`, `src/daemon/`, or
  `src/ui/`, or that opens a socket/HTTP listener.** Only CLI-surface
  features belong on this fork's roadmap — see [[architecture]]. If the goal
  as stated implies one of these, say so explicitly and propose the CLI
  subcommand equivalent instead.
