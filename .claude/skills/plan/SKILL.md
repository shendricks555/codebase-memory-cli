---
name: plan
description: Turn a spec.md into a phased plan.md and progress.json for this repo's build/store/pipeline/cypher/cli layering.
arguments: [feature]
argument-hint: "[feature folder]"
disable-model-invocation: true
---

# /plan

Run this inline (no agent dispatch), Opus-tier preferred.

## Gates

- STOP and send back to `/spec` if the spec lacks an Evals section.
- Just-in-time gate: do not plan feature N until every earlier roadmap
  feature is fully Implemented **and** Verified (check
  `.claude/planning/active/ROADMAP.md`).

## Required context

Read the feature's `spec.md`, [[architecture]], [[testing]], and
[[pipeline-passes]] if the feature touches indexing. Per [[mcp-usage]], call
`get_architecture` and `search_graph` for every module/file the spec's CLI
Contract or Data Model implies, so phases reference real paths, not guessed
ones.

## Phase taxonomy

| Phase | Focus | Tests? | Module | Include when |
|---|---|---|---|---|
| 0 | Build/config | No | root/Makefile.cbm | New build flag, target, or dependency |
| 1 | Store/schema | Structural | `src/store` | New graph schema/storage shape |
| 2 | Pipeline/indexing | TDD | `src/pipeline`, `internal/cbm` | New extraction/pass |
| 3 | Cypher/query | TDD | `src/cypher` | New or changed query translation |
| 4 | CLI subcommand | TDD | `src/cli` | Any user-facing behavior (nearly always) |
| 5 | Packaging | No | `pkg/`, `install.sh` | Distribution-affecting change |
| N | Validation | N/A | — | Always — final phase, runs full quality-gate |

Include only the phases the feature actually requires; never include a phase
for `src/mcp`/`src/daemon`/`src/ui` — those are removal targets (see
[[architecture]]).

## Output

`plan.md`: Overview, Eval Coverage table (every spec eval -> phase +
verification method), NFR Impact table, per-phase Tasks with explicit file
paths. `progress.json` from `.claude/templates/progress-template.json`,
phases/tasks filled in to match.

## Rules

- TDD phases always pair a test-writing task before the implementation task.
- Explicit file paths are mandatory in every task.
- Never plan a spec's "Future Enhancements" items — those are out of scope by
  definition.
- Minimize planned diff footprint in `src/foundation`, `src/store`,
  `src/cypher`, `src/pipeline`, `internal/cbm` per the upstream-mergeability
  constraint — prefer additive tasks over rewriting tasks there.
