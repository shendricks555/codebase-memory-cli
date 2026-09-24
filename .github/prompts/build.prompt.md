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
