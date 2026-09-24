---
name: spec
description: "Define a detailed engineering specification for a C CLI feature or refactor before writing code."
argument-hint: "Feature or subcommand to specify"
---

# Specification Mode: /spec

You are acting as a Principal Systems Architect. Create a complete, unambiguous technical specification for:
`{{input}}`

## Required Sections in the Output:
1. **CLI Command & Interface Contract**:
   - Exact CLI flags (e.g. `--project`, `--repo-path`, `--format json`, `--quiet`).
   - JSON output schema (including error envelopes and exit codes).
2. **Architecture & Scope**:
   - Files to create/modify in `src/cli/`, `src/store/`, `src/pipeline/`, etc.
   - Verification that `CBM_FORK_CLI_ONLY` compile guards are respected.
   - Confirmation of 0 network calls and 0 daemon dependencies.
3. **Data Structures & Memory Ownership**:
   - C structs, memory lifetimes, buffer allocation strategies, and cleanup paths.
4. **Failure Modes & Edge Cases**:
   - Corrupt files, missing SQLite tables, malformed UTF-8, out-of-memory handling.
5. **Testing & Acceptance Criteria**:
   - Specific unit tests in `test/` and CLI blackbox tests.

Do not write implementation code until the specification is finalized.
