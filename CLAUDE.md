# CLAUDE.md

## Mission

This repository is a fork of upstream `codebase-memory-mcp`.

The fork produces a **separate standalone C11 binary** with:

- **No MCP protocol/server**
- **No coordination daemon**
- **No Unix-domain-socket IPC**
- **No cross-session/shared daemon ownership**
- **No non-loopback network listener**
- The existing **localhost-only graph UI is kept**

The fork must remain easy to merge from upstream. Prefer small, isolated, additive changes over rewrites of shared upstream code.

---

## Non-negotiable constraints

### 1. C only

- This repository is C11.
- **Do not add Go code.**
- Do not introduce a new runtime or external service.
- Dependencies are vendored and must remain buildable without network access.

### 2. No MCP

The fork's shipped binary must not:

- implement MCP;
- speak JSON-RPC for MCP;
- expose MCP tool handlers;
- start an MCP server;
- retain a runtime dependency on `src/mcp/`.

`src/mcp/` is a **removal target**.

Equivalent functionality belongs behind direct local CLI commands where appropriate.

### 3. No daemon

The fork's shipped binary must not:

- start the upstream coordination daemon;
- connect to or create its Unix-domain socket;
- perform cross-session daemon coordination;
- depend on daemon-owned watcher/indexing/UI lifecycle;
- retain a runtime dependency on `src/daemon/`.

`src/daemon/` is a **removal target**.

Do not remove `src/cli/` merely because upstream daemon workflows interact with it. The CLI is intentionally part of this fork.

### 4. Localhost-only UI is allowed

`src/ui/` is intentionally retained.

The UI may start a local HTTP server for graph visualization, but:

- it must bind to loopback only (`127.0.0.1` / equivalent loopback binding);
- it must never bind `0.0.0.0`, `::`, or another non-loopback interface;
- it must not require the coordination daemon;
- it should be started/stopped directly by the local CLI/session;
- it must not create a remotely accessible service.

The expected default UI port is `9749` unless the existing implementation/configuration says otherwise.

---

## Fork-vs-upstream rule

Before changing code, decide which category the change belongs to.

### Fork-specific

Keep the change in this fork when it exists only because we removed MCP/daemon support, for example:

- removing MCP entry points;
- removing daemon dependencies;
- adapting CLI lifecycle to replace daemon-owned behavior;
- making the UI start directly from the CLI;
- enforcing loopback-only UI binding;
- fork-specific build targets/guards;
- removing code that is unreachable after MCP/daemon removal.

### Upstream-worthy

General functionality belongs upstream, not in the fork:

- language support;
- tree-sitter extraction;
- indexing improvements;
- graph/storage improvements;
- Cypher behavior;
- pipeline correctness;
- general bug fixes;
- parser/grammar improvements;
- performance improvements unrelated to MCP/daemon removal.

When uncertain, prefer the smallest fork-specific adaptation and avoid changing shared core behavior.

---

## Mergeability is a design constraint

We regularly pull changes from upstream.

Minimize conflicts with upstream by:

- preferring changes at subsystem boundaries;
- adding isolated files/targets where possible;
- using compile-time guards only when they materially reduce duplication;
- deleting MCP/daemon dependencies at the edges rather than rewriting shared implementations;
- avoiding formatting-only changes;
- avoiding unrelated refactors;
- preserving upstream naming, structure, and control flow when practical.

Shared areas that should receive extra scrutiny before modification:

```text
src/foundation/
src/store/
src/cypher/
src/pipeline/
internal/cbm/
```

These are core upstream code. Do not refactor them merely to make the fork cleaner.

If a change can be implemented either by modifying shared core code or by adapting the fork-specific CLI/build boundary, prefer the latter unless there is a concrete correctness reason not to.

---

## Architecture

```text
src/
  foundation/   arena allocator, hash table, string/platform utilities
  store/        SQLite graph storage (WAL, FTS5)
  cypher/       Cypher -> SQL translation
  pipeline/     multi-pass indexing pipeline
  discover/     file discovery + gitignore support
  watcher/      git-based background auto-sync
  cli/          local one-shot CLI commands; retained in this fork
  mcp/          MCP JSON-RPC server                         [REMOVE]
  daemon/       shared coordination daemon + Unix IPC      [REMOVE]
  ui/           localhost graph-visualization HTTP server   [KEEP]

internal/cbm/   language registry, AST extraction, vendored grammars
vendored/       sqlite3, yyjson, mimalloc, xxhash, tre, nomic
graph-ui/       React/Three.js graph UI; bundled with --with-ui
```

### Important upstream behavior

The upstream daemon normally coordinates:

- watchers;
- shared indexing;
- concurrent MCP clients;
- optional UI lifecycle;
- Unix-domain-socket communication;
- process/version/cache-root admission.

That machinery is intentionally absent from this fork.

The upstream CLI path is already the natural local execution boundary: it performs one command locally and does not depend on daemon/socket coordination.

Therefore, the fork should generally preserve:

```text
cli -> pipeline -> store/foundation/internal-cbm
```

while removing:

```text
MCP -> daemon
MCP -> daemon IPC
daemon -> UI lifecycle
daemon -> shared watcher/index ownership
```

Do not introduce a new daemon-like abstraction to replace the removed daemon.

---

## Required workflow for code changes

When implementing a task:

1. **Inspect before editing.**
   - Find the existing entry point and callers.
   - Trace the relevant lifecycle through the code.
   - Check tests/build targets before inventing new mechanisms.

2. **Classify the change.**
   - Fork-specific removal/adaptation?
   - Or general upstream functionality?

3. **Choose the smallest integration point.**
   - Prefer CLI/build boundaries.
   - Avoid modifying shared core code unless necessary.

4. **Preserve upstream behavior outside the fork boundary.**
   - Do not opportunistically refactor.
   - Do not "clean up" unrelated code.

5. **Check for residual dependencies.**
   After MCP/daemon removal work, search for:
   - `src/mcp`
   - `src/daemon`
   - daemon IPC/socket APIs
   - MCP/JSON-RPC entry points
   - daemon startup/shutdown calls
   - UI paths that still assume daemon ownership

6. **Test the narrowest relevant seam first.**
   Then run broader tests when the change affects shared infrastructure or release behavior.

7. **Before declaring completion, verify the shipped build.**
   The release binary must not accidentally compile in or reach MCP/daemon code.

---

## Build and test commands

```bash
scripts/build.sh
# standard release build

scripts/build.sh --with-ui
# release build with graph-viz UI bundled

scripts/test.sh
# ASan + UBSan + full C test suite

scripts/lint.sh
# clang-tidy, cppcheck, clang-format

make -f Makefile.cbm test
# all tests with ASan + UBSan

make -f Makefile.cbm test-foundation
# foundation tests only

make -f Makefile.cbm cbm
# production binary

make -f Makefile.cbm security
# security audit: static allow-list, string scan,
# network-egress test, fuzzing, etc.
```

Run a single test only after inspecting how the repository selects tests:

```text
tests/*.sh
scripts/test.sh
```

Do not assume a `-run`, `--filter`, or similar test selector exists.

After cloning, enable the repository's pre-commit checks:

```bash
git config core.hooksPath scripts/hooks
```

---

## Security / networking invariant

For production builds, verify that:

- MCP code is absent;
- daemon code is absent;
- no Unix-domain daemon socket is created or contacted;
- no non-loopback listener is opened;
- the UI, when enabled, binds only to loopback;
- test-only seams are not compiled into release builds.

Do not weaken these invariants to make a test or implementation easier.

---

## Test seams

`TEST_SEAMS=1` / `-DCBM_ENABLE_TEST_SEAMS=1` is **opt-in**.

Production builds must not contain test-only seams.

Examples include mechanisms that deliberately create unusual process states so watchdog/reaper behavior can be tested.

Expected build behavior:

```text
scripts/test.sh     -> TEST_SEAMS=1
scripts/build.sh    -> TEST_SEAMS disabled
```

Preserve this distinction for new test-only code.

---

## Language / extraction work

This is generally upstream feature work, not fork-specific work.

Relevant locations:

```text
internal/cbm/lang_specs.c       grammar/AST node configuration
internal/cbm/extract_*.c       AST extraction
src/pipeline/                  pipeline passes
tests/test_extraction.c        extraction regression tests
tests/test_pipeline.c          pipeline regression tests
internal/cbm/regression_test.go legacy parity tests being migrated off Go
```

Do not add Go code to this fork.

Infra-language support such as Docker/Kubernetes/Kustomize uses the existing infra-pass pattern:

```text
src/pipeline/pass_infrascan.c
internal/cbm/extract_k8s.c
```

and reuses the tree-sitter YAML grammar rather than introducing unnecessary new grammars.

---

## Decision rules

When deciding what to do, use these rules in order:

1. **Does this preserve the no-MCP/no-daemon invariant?**
2. **Does it preserve localhost-only UI behavior?**
3. **Can it be implemented without modifying shared upstream core?**
4. **If shared core must change, is the change minimal and upstream-compatible?**
5. **Is the change actually fork-specific, or should it be upstream?**
6. **Are tests covering the changed boundary?**

If two implementations are functionally equivalent, prefer the one with the smaller upstream diff and fewer new abstractions.

---

## Definition of done

A change is complete when:

- the requested behavior works;
- the relevant tests pass;
- release builds do not include unintended MCP/daemon behavior;
- localhost-only networking remains enforced;
- test seams remain test-only;
- no unrelated refactoring was introduced;
- the resulting diff remains straightforward to merge with upstream.

Do not declare success based solely on compilation if the change affects security boundaries, process lifecycle, networking, MCP removal, or daemon removal.
