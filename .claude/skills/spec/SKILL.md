---
name: spec
description: Turn a feature description into a spec.md with scenarios, functional requirements, CLI contract, and evals decided up front.
arguments: [description]
argument-hint: "<feature description>"
disable-model-invocation: true
---

# /spec

Run this inline (no agent dispatch) on the current session model. Prefer
Opus-tier for spec work — requirements quality compounds through plan and
implement.

## Required context

Read `/workspace/CLAUDE.md`, [[architecture]], and [[mcp-usage]] first. Per
[[mcp-usage]], use `get_architecture` and `search_graph` to confirm the
feature's touchpoints actually exist as described before writing FRs against
them — do not spec against assumed structure.

## Output

Write `spec.md` (in the active feature folder under
`.claude/planning/active/###-feature-slug/`, or a new numbered folder if this
is a standalone spec) with this exact section order:

```
# Feature: <Name>

## Objective

## User Scenarios
(Given/When/Then)

## Functional Requirements
(FR-N, each traces to a scenario and vice versa)

## CLI Contract
| Invocation | Output shape | Exit code | Failure behavior |

## Data Model
| ... |

## Constraints

## Success Criteria
- [ ] ...

## Evals (Smoke Tests)
| ID | Eval | Type (unit\|integration\|performance\|criteria) | Verified by |

## Out of Scope

## Future Enhancements
```

## Rules

- Technology-agnostic: describe WHAT, not HOW — implementation choices belong
  in `/plan`.
- Every FR traces to a scenario; every scenario has at least one FR.
- **Evals are decided here, never deferred to plan.** If you can't state how
  a requirement will be verified, the requirement isn't ready.
- `CLI Contract` invocations are CLI subcommand forms (`cbm <subcommand>
  [flags]`) — never an MCP tool call, JSON-RPC method, or network endpoint.
  This fork exposes functionality only via `src/cli/cli.c` subcommands.
- A trivial feature (single flag, single subcommand tweak) gets an
  abbreviated spec — skip sections that don't apply, don't pad them.
- If a requirement would require `src/mcp/`, `src/daemon/`, or `src/ui/` to
  grow, or a socket/HTTP listener to be added, stop and say so — it doesn't
  belong on this fork's spec at all (see [[architecture]]).
