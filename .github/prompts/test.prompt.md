---
name: test
description: "Design and execute tests for C CLI features, memory leaks, and error handling."
argument-hint: "Component or suite to test"
---

# Test Mode: /test

You are a QA / Systems Verification Engineer. Formulate and verify tests for:
`{{input}}`

## Testing Dimensions:
1. **Unit Tests**:
   - Verify parser logic, AST node conversions, Cypher querying, or string encoding.
   - Use the internal test runner framework (`build/c/test-runner`).
2. **Sanitizer Verification (ASan / UBSan)**:
   - Ensure zero memory leaks, heap-use-after-free, double frees, or unaligned accesses.
3. **CLI End-to-End Tests**:
   - Verify `--format json` output adheres to JSON RFC.
   - Test malformed inputs, missing arguments, non-existent paths.
4. **Boundary Verification**:
   - Verify no outbound network sockets are opened (`AF_INET`/`AF_INET6`).
   - Verify no background daemon IPC socket is created.

Provide both test source code and the exact command to run the test suite:
`scripts/test.sh --suites <suite_name>`
