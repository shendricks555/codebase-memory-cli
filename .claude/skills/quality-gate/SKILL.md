---
name: quality-gate
description: Dispatch the quality-gate agent for a report-only adversarial review of a feature.
arguments: [feature]
argument-hint: "[feature folder]"
allowed-tools: [Read, Glob, Agent]
---

# /quality-gate

Report-only. Never edits code — that's what makes it trustworthy as a gate.

## Locate the target feature

Same resolution as `/implement`: roadmap mode uses the first feature whose
Verify column isn't checked; standalone mode uses the newest folder with a
completed Validation phase in `progress.json`.

## Dispatch

Launch the `quality-gate` agent (`.claude/agents/quality-gate.md`) with the
feature folder path, `spec.md`, `plan.md`, `progress.json`, and the current
`git diff` scope for this feature's commits. Remind it that any
architecture/blast-radius finding must be backed by
`search_graph`/`trace_path`/`query_graph`, not grep alone, per [[mcp-usage]].

## Report back

Relay the agent's table and verdict verbatim to the user. If verdict is
WARN or FAIL, do not mark the feature's Verify column checked in
`ROADMAP.md` — that only happens on a clean PASS.
