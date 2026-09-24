# 04 — `no-network-hardening`

**Milestone:** 04 of 06 | **Status:** PENDING | **Carries over:** old F6 (closes debt D-1 and D-4)

## 1. Objective & Rationale
This milestone turns "no network" into a guarantee that can be audited, and that the company can
sign off against its policy. Today the binary does a GitHub update check, and
`scripts/security-network.sh` both tolerates `api.github.com:443` and watches only `connect()`.

## 2. Architectural Scope
- **Modify (guarded):** the update-check call site(s) (find them with `grep -rn "api.github.com" src`). Under `CBM_FORK_CLI_ONLY` they are compiled out, not just made to return early.
- **Modify:** `scripts/security-network.sh` adds a fork mode that fails on any `connect()` and on any `socket()`/`bind()`/`listen()` other than AF_INET 127.0.0.1 during `ui`. On macOS use `dtruss` or a documented equivalent; on Linux use `strace -f -e trace=network`.
- **Modify:** `scripts/security-allowlist.txt` keeps only the loopback-v4 UI entry for the fork profile (the upstream entries go in a separate profile rather than being deleted).
- **Modify:** `scripts/security-network-source-audit.py` gains a fork profile.
- **Add:** `security-cli` target in `cli-only.mk`, which runs strings, network, source-audit, UI and vendored checks against `codebase-memory-cli`.
- **Untouched:** shared core.

## 3. Boundary & Guard Constraints
- No egress of any kind; no AF_UNIX sockets; the only listener is the loopback UI.
- `nm` check: `getaddrinfo`, `gethostbyname`, `connect` and TLS/HTTP-client symbols are absent. Any exception must be justified, e.g. a libc symbol that is referenced but never reached.

## 4. CLI / Contract Expectations
No change for users. `--version` and every other command make no network lookup.

## 5. Pre-conditions
03 COMPLETED (the final linked surface is known). N2 applies to the with-UI binary only; the plain binary must show zero socket syscalls.

## 6. Acceptance & Verification Gates
| Eval | Check |
|---|---|
| N1 | Dynamic trace of `index_repository`, `search_graph`, `query_graph`, `trace_path`, `--version`, `--help`: zero network syscalls (closes F3 E1) |
| N2 | Dynamic trace of `ui`: exactly one `bind` to 127.0.0.1 and no `connect` |
| N3 | Strings/nm: no `api.github.com`, no resolver/TLS client symbols |
| N4 | Negative test: temporarily injecting a `connect()` makes `security-cli` FAIL (the audit must be able to fail) |
| N5 | `make -f Makefile.cbm security-cli` PASS; upstream `make security` still PASS on the default build |
| N6 | Runs with the network namespace cut off (`unshare -n`, or sandbox-exec deny network): every command still succeeds |
Plus the standard gates G1–G9.

## 7. Sub-Agent Execution Readiness
✅ Ready for `/roadmap-goal` once 03 is COMPLETED. The spec must say which host can run the
dynamic tracing (Linux devcontainer recommended); substitute evidence is **not** acceptable here.
