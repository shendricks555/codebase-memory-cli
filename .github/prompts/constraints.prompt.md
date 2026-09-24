---
name: constraints
description: "Audit and enforce project constraints (zero network, pure C, memory caps, CLI-only)."
argument-hint: "File or component to audit"
---

# Constraints Mode: /constraints

Audit the target against the architectural constraints of `codebase-memory-cli`:
`{{input}}`

## Invariant Audit Matrix:
| Constraint | Pass/Fail | Check |
|---|---|---|
| **No Network** | [ ] | Zero calls to `socket()`, `connect()`, `curl`, `http`, or DNS resolution. |
| **No MCP Daemon** | [ ] | Zero usage of Unix domain sockets (`AF_UNIX`) for background IPC. |
| **Compile Guarded** | [ ] | Fork-specific logic is guarded behind `#ifdef CBM_FORK_CLI_ONLY`. |
| **RAM Budget** | [ ] | Respects in-memory graph allocations and releases memory after one-shot run. |
| **Strict JSON Contract** | [ ] | CLI `--format json` emits schema-compliant JSON without banner spam on stdout. |
| **Loopback UI Only** | [ ] | UI server (if enabled) binds exclusively to `127.0.0.1`. |

List all violations and provide exact remediation patches.
