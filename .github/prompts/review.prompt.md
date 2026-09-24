---
name: review
description: "Perform a 5-axis Staff-level code review on C code before merging."
argument-hint: "Diff, file, or pull request to review"
---

# Review Mode: /review

Perform a Staff Systems Engineer code review on:
`{{input}}`

## 6-Axis Review Framework:
1. **Memory Safety & Leaks**:
   - Are dynamic allocations bounded? Are all cleanup paths reachable during early error exits (`goto cleanup` or return)?
2. **Concurrency & File Locks**:
   - Are SQLite operations and project stores protected against concurrent CLI invocations via file locking?
3. **POSIX & Portability**:
   - Will this compile and execute identically on macOS (arm64/amd64), Linux (amd64/arm64), and Windows (MSVC/MinGW)?
4. **Error Handling & Resilience**:
   - Does it handle filesystem permission errors, missing directories, and invalid UTF-8 without crashing?
5. **Code Clarity & Maintainability**:
   - Is the C style idiomatic, consistent with `src/foundation/`, and free of macro obfuscation?

6. **Test Discipline**:
   - Was each change preceded by a failing test, or does it carry a justified `TDD-BYPASS` with substitute evidence? An unjustified skip is a 🟡 Warning. A bug fix with no regression test is a 🔴 Blocker.

Group findings by severity:
- 🔴 **Blocker**: Memory leak, buffer overflow, architectural violation (network/daemon).
- 🟡 **Warning**: Missing error check, unoptimized traversal, portability issue.
- 🟢 **Nit / Suggestion**: Style, naming, minor comment clarification.

## TDD Directive (pragmatic, bypassable)
- **Default:** write the test first. It must fail for the stated reason (red), then you add the smallest change that makes it pass (green), then you refactor with the tests still green. Record the red and green commands and their results.
- **Verification-only work** (the behaviour already exists): show red on purpose. Run the test against a negative control, such as the unguarded binary or a fake that breaks the contract, before you run it against the real target.
- **Bug fixes:** always start with a failing regression test, with no exceptions unless one of the bypass cases below applies.
- **Bypass is allowed** when test-first would add undue friction, for example: an OOM or signal path with no release seam; a non-deterministic race; a pure build, doc or script-plumbing change; or a test that would need a new seam or a shared-core edit. When you bypass, write `TDD-BYPASS: <reason> — <substitute evidence>` in the plan/progress record, and prefer substitute evidence (negative control, repeated runs, manual check).
- Never weaken an invariant, add a test seam to release builds, or edit shared core just to make test-first possible.
