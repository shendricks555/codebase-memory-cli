# Feature summary: No-network hardening & guarantee
**Sequence:** 006 | **Depends on:** F4 (F5 for the UI exemption) | **Spans:** cli, scripts/security, build

## Behavior
Turns "no network" from an implicit property into an auditable guarantee. Disables the binary's
GitHub update-check egress and tightens the security audit so the CLI-only build provably makes no
outbound connections and opens no listener except the sanctioned loopback UI. This is the deliverable
that lets the company sign off against its "no MCP / no network" policy.

## Functional Requirements (high level)
- Disable the `api.github.com` update-check in the CLI-only binary (compile it out under
  `CBM_FORK_CLI_ONLY` or make it a no-op).
- Tighten `scripts/security-network.sh`: **forbid** the `:443`/GitHub egress it currently tolerates,
  and extend beyond `connect()` to assert no `socket()` / `bind()` / `listen()` surface except the
  loopback UI listener.
- Prune the now-dead AF_UNIX/daemon `NETWORK:` entries from `scripts/security-allowlist.txt`; keep
  only the loopback-v4 UI entry.
- Add a fork-scoped `make -f Makefile.cbm security` path (or variant) that runs against
  `codebase-memory-cli` and passes with the tightened assertions.
- Confirm `scripts/security-network-source-audit.py` still passes given the removed daemon sockets.

## NFR impact
- Security is the headline NFR here: an explicit, testable no-egress guarantee.
- Upstream-mergeability: security scripts are fork-tunable; keep changes additive where they touch
  shared allowlists (guard/annotate rather than delete upstream-relevant entries if any remain).

## Research pointers
- R-5 (audit tolerates GitHub egress, only watches `connect()`; binary does an update check).
- R-3 (removed sockets live in daemon; loopback UI is the only survivor).

## Deferred
- CI wiring of the fork security gate (beyond local `make security`) — packaging/CI is a deferred
  roadmap item.
