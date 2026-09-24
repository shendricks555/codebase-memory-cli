---
name: review
description: "Perform a 5-axis Staff-level code review on C code before merging."
argument-hint: "Diff, file, or pull request to review"
---

# Review Mode: /review

Perform a Staff Systems Engineer code review on:
`{{input}}`

## 5-Axis Review Framework:
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

Group findings by severity:
- 🔴 **Blocker**: Memory leak, buffer overflow, architectural violation (network/daemon).
- 🟡 **Warning**: Missing error check, unoptimized traversal, portability issue.
- 🟢 **Nit / Suggestion**: Style, naming, minor comment clarification.
