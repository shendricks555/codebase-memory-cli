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
   - State, for each acceptance criterion, how red is shown first, or mark it `TDD-BYPASS` with a reason.

Do not write implementation code until the specification is finalized.

## TDD Directive (pragmatic, bypassable)
- **Default:** write the test first. It must fail for the stated reason (red), then you add the smallest change that makes it pass (green), then you refactor with the tests still green. Record the red and green commands and their results.
- **Verification-only work** (the behaviour already exists): show red on purpose. Run the test against a negative control, such as the unguarded binary or a fake that breaks the contract, before you run it against the real target.
- **Bug fixes:** always start with a failing regression test, with no exceptions unless one of the bypass cases below applies.
- **Bypass is allowed** when test-first would add undue friction, for example: an OOM or signal path with no release seam; a non-deterministic race; a pure build, doc or script-plumbing change; or a test that would need a new seam or a shared-core edit. When you bypass, write `TDD-BYPASS: <reason> — <substitute evidence>` in the plan/progress record, and prefer substitute evidence (negative control, repeated runs, manual check).
- Never weaken an invariant, add a test seam to release builds, or edit shared core just to make test-first possible.
