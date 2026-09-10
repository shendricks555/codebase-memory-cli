---
name: implement
description: Dispatch the implementer agent to execute the active feature's plan.md phases.
arguments: [feature]
argument-hint: "[feature folder]"
allowed-tools: [Read, Agent]
---

# /implement

This skill only reads and dispatches — it does not edit directly.

## Locate the active feature

- Roadmap mode: first feature in `.claude/planning/active/ROADMAP.md` whose
  Implement column isn't checked.
- Standalone mode: newest feature folder under `.claude/planning/active/`
  that has both `plan.md` and `progress.json`.
- If `HANDOVER.md` exists in that folder, this is a resume — pass its
  content to the implementer explicitly.

## Dispatch

Launch the `implementer` agent (see `.claude/agents/implementer.md`) with:
the feature folder path, `spec.md`, `plan.md`, `progress.json`, and
`HANDOVER.md` contents if present. Remind it that codebase-memory-mcp use is
mandatory per [[mcp-usage]] before it edits anything.

## Context-budget rule

The implementer writes `HANDOVER.md` and stops cleanly when its own context
headroom runs low (rough outer bound: ~200k tokens) rather than degrading
mid-phase. That's expected, not a failure — `/implement` or
`/roadmap-advance` picks it back up next invocation.

## Report back

After the agent returns, report to the user: phases completed this run, eval
status (`passes` counts), build/test results, any NFR measurements taken,
and blockers (including the stuck-loop-breaker case, if hit).
