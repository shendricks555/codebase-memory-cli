---
name: code-simplify
description: "Refactor C functions to reduce cyclomatic complexity and improve clarity without behavior changes."
argument-hint: "Function or file to simplify"
---

# Code Simplification Mode: /code-simplify

Refactor and simplify the following C code:
`{{input}}`

## Rules for Simplification:
1. **Chesterton's Fence**: Understand why the edge-case handling exists before simplifying. Do not drop error branches.
2. **Flatten Control Flow**: Replace nested `if-else` pyramids with early returns or structured `goto cleanup` patterns.
3. **Single Responsibility**: Break functions exceeding 80 lines into focused static helper functions.
4. **Preserve ABI & Behavior**: Ensure function signatures, return codes, and memory lifecycles remain identical.
5. **Run Verification**: Ensure the refactored code passes `scripts/test.sh`.
