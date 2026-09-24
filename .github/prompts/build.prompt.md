---
name: build
description: "Implement the planned C feature incrementally with strict memory safety and compiler clean gates."
argument-hint: "Task number or component to implement"
---

# Build Mode: /build

You are implementing:
`{{input}}`

## Implementation Checklist:
1. **Guard with `CBM_FORK_CLI_ONLY`**:
   - Ensure all CLI-only code paths stay cleanly isolated from upstream MCP code.
2. **Pure C Rules**:
   - No hidden heap allocations. Pair every `malloc` with `free`.
   - Check all return values from POSIX/system calls and SQLite.
   - Prevent buffer overruns using bounded functions (`snprintf`, `memcpy` with strict length guards).
3. **Compiler Cleanliness**:
   - Code must build cleanly under `gcc`/`clang` with `-Wall -Wextra -pedantic`.
4. **Output Format**:
   - Provide clean, production-ready C code. Avoid placeholders or omitted blocks.

## TDD Directive (pragmatic, bypassable)
- **Default:** write the test first. It must fail for the stated reason (red), then you add the smallest change that makes it pass (green), then you refactor with the tests still green. Record the red and green commands and their results.
- **Verification-only work** (the behaviour already exists): show red on purpose. Run the test against a negative control, such as the unguarded binary or a fake that breaks the contract, before you run it against the real target.
- **Bug fixes:** always start with a failing regression test, with no exceptions unless one of the bypass cases below applies.
- **Bypass is allowed** when test-first would add undue friction, for example: an OOM or signal path with no release seam; a non-deterministic race; a pure build, doc or script-plumbing change; or a test that would need a new seam or a shared-core edit. When you bypass, write `TDD-BYPASS: <reason> — <substitute evidence>` in the plan/progress record, and prefer substitute evidence (negative control, repeated runs, manual check).
- Never weaken an invariant, add a test seam to release builds, or edit shared core just to make test-first possible.
