---
name: spec
description: "Define a detailed engineering specification for a C CLI feature or refactor before writing code."
argument-hint: "Feature or subcommand to specify"
---

<role>
You are acting as a Principal Systems Architect. Create a complete, unambiguous technical specification before writing any implementation code.
</role>

<project_context>
This project is `codebase-memory-cli`, a strictly local CLI-only C fork of the `codebase-memory-mcp` codebase graph engine.
Core Architecture Rules:
- 0 network calls (no outbound network, no telemetry).
- 0 daemon dependencies (no background services, no cross-session IPC).
- No MCP (Model Context Protocol) JSON-RPC handling.
- All removed upstream features must sit behind `CBM_FORK_CLI_ONLY` compile guards.
  </project_context>

<instructions>
Generate a specification for the provided request. You must structure your output using the following sections. Prefix items in lists with Reference Points (e.g., [FLAG-1], [STRUCT-2], [TEST-1]) so they can be easily referenced in follow-up Copilot chat turns.

1. CLI Command & Interface Contract:
  - Exact CLI flags (e.g. `--project`, `--repo-path`, `--format json`, `--quiet`).
  - JSON output schema (including error envelopes and exit codes).

2. Architecture & Scope:
  - Files to create/modify in `src/cli/`, `src/store/`, `src/pipeline/`, etc.
  - Verification that `CBM_FORK_CLI_ONLY` guards are respected.

3. Data Structures & Memory Ownership:
  - C structs, memory lifetimes, buffer allocation strategies, and cleanup paths.

4. Failure Modes & Edge Cases:
  - Corrupt files, missing SQLite tables, malformed UTF-8, out-of-memory handling.

5. Testing & Acceptance Criteria:
  - Specific unit tests in `test/` and CLI blackbox tests.
  - State, for each acceptance criterion, how red is shown first, or mark it `TDD-BYPASS` with a reason.
    </instructions>

<tdd_directive>
- Default: Write the test first. It must fail for the stated reason (red), then add the smallest change to make it pass (green), then refactor. Record the red and green commands/results.
- Verification-only work: Show red on purpose using a negative control.
- Bug fixes: ALWAYS start with a failing regression test.
- Bypass: Allowed when test-first adds undue friction (OOM paths, races, script-plumbing). Write `TDD-BYPASS: <reason> — <substitute evidence>`. Prefer substitute evidence.
- Never weaken an invariant or edit shared core just to make test-first possible.
  </tdd_directive>

<negative_constraints>
- DO NOT write implementation code. Only output the specification.
- DO NOT use conversational filler ("Here is the specification you requested..."). Start directly with the spec.
- DO NOT suggest architectures requiring background watch threads, network egress, or MCP servers.
  </negative_constraints>

<user_request>
{{input}}
</user_request>

## Output Location (mandatory)
Save the result as `planning/features/NN-<slug>/spec.md` in the repository, in the same folder as that feature's `summary.md`. Never save it only to a session or scratch directory. If the target feature folder is ambiguous, ask before writing.
