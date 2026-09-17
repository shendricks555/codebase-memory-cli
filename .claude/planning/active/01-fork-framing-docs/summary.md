# Feature summary: Fork framing & doc correction
**Sequence:** 001 | **Depends on:** none | **Spans:** docs, build

## Behavior
Establishes the honest, correct framing for this fork before any code changes. Fixes the two CLI
docs that currently describe the project as a Go/Cobra app (`docs/CLI_QUICKSTART.md`,
`docs/CLI_BUILD_RUN_GUIDE.md`) — it is pure C11 built via `Makefile.cbm`/`scripts/build.sh`. Adds a
clear "What this fork is and why" section to `README.md`.

## Functional Requirements (high level)
- Rewrite `docs/CLI_QUICKSTART.md` and `docs/CLI_BUILD_RUN_GUIDE.md` to reflect the real pure-C11
  build (`scripts/build.sh`, `make -f Makefile.cbm cbm`) and remove all Go/Cobra/`cmd/`/`go build`
  references.
- Add a fork-purpose section to `README.md`: no MCP, no coordination daemon, no outbound network,
  localhost-only graph UI kept, upstream-mergeable via `git pull`. State who it's for (orgs that
  forbid MCP/network dev tools).
- Note the target binary name (`codebase-memory-cli`) and that CLI is the only interface, as a
  forward reference; mark build/run commands that don't exist yet as "coming in later features" so
  the docs never claim capabilities the binary lacks.

## NFR impact
- Zero binary/behavior change; lowest-risk starting point.
- Upstream-mergeability: touch only fork-owned doc surface; avoid rewriting upstream-heavy README
  sections beyond an additive fork section.

## Research pointers
- R-4 (existing CLI docs are Go/Cobra-wrong).
- R-3 (fork framing: additive `CBM_FORK_CLI_ONLY`, small blast radius) — for the "why it stays
  mergeable" narrative.

## Deferred
- The definitive, verified source→build→run quickstart with real commands lands in F7 once the
  `codebase-memory-cli` binary and its subcommands actually exist.
