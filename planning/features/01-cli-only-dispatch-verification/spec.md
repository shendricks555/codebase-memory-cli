# Spec — 01 `cli-only-dispatch-verification`

**Milestone:** 01 of 06 | **Status:** SPEC DRAFT | **Base commit:** `82dd58c5` | **Byte-diff base (E7):** `e038fec5`
**Inputs:** `summary.md`, `planning/ROADMAP.md` §3–§5, `cli-only.mk`, `src/main.c`, `src/cli/cli.c`

This milestone is a **verification milestone**. It adds automated, repeatable evidence for behaviour
that already exists in `build/c/codebase-memory-cli`. Today that behaviour has only been checked by
the manual smoke loop at the end of `verify-cli-only-link`. It changes no product behaviour
unless a test finds a defect (§2.4).

---

## 1. CLI Command & Interface Contract

### 1.1 Binary under test
`build/c/codebase-memory-cli`, built by `make -f Makefile.cbm cbm-cli` (`-DCBM_FORK_CLI_ONLY=1`,
test seams filtered out, section GC). The tests exercise **the shipped artifact**, not a
test-runner re-link. Only this binary proves the release dispatch.

### 1.2 Entry-dispatch contract (asserted, not changed)

| # | argv | stdin | Expected stdout | Expected stderr | Exit | Side effects |
|---|---|---|---|---|---|---|
| D1 | *(none)* | closed (`/dev/null`) and, separately, a pipe holding a JSON-RPC `initialize` frame that is never closed | empty; never contains `"jsonrpc"` | usage/help text (non-empty, contains `cli`) | **2** | none |
| D2 | `frobnicate` (unknown token) | as D1 | as D1 | help | **2** | none |
| D3 | `--help` / `-h` | closed | help (stdout **or** stderr, recorded as observed) | — | **0** (record the observed code; assert it is stable) | none |
| D4 | `--cbm-daemon-internal` | as D1 | no `"jsonrpc"` | help or refusal | **2** | no child process, no socket |
| D5 | `daemon status`, `daemon stop`, `daemon start` | closed | no `"jsonrpc"` | help or refusal | **2** | none |
| D6 | MCP-shaped argv upstream accepts (`--stdio`, `mcp`, `serve`, `--ui=true`) | JSON-RPC frame | no `"jsonrpc"` | help or refusal | **2** | none |
| D7 | index-worker / hook role argv recognised by `cbm_daemon_process_role()` (enumerate from `src/daemon/bootstrap.c`, e.g. the hidden worker flag and `hook …`) | closed | no `"jsonrpc"` | help or refusal | **2** | none |
| D8 | `cli <tool> --format json [args]` for each of the 17 tools (§1.3) | closed | one JSON document (yyjson-parseable) | optional progress lines | 0 on success, 1 on a tool-level error (the envelope is still valid JSON) | only the `CBM_CACHE_DIR` DB and `project_lock` files |
| D9 | `cli nosuchtool --format json` | closed | JSON error envelope | — | non-zero (record the observed code; must not be 0) | none |

"Never reads stdin" (E3) is asserted **behaviourally**. D1/D2/D4–D7 are run with stdin connected to
a pipe whose write end stays open. If the process read stdin it would block. Instead it must exit
within **5 s** (the harness kills it with `SIGKILL` and marks FAIL on timeout).

### 1.3 The 17 tools (from `TOOLS[]`, `src/mcp/mcp.c:471`)
`index_repository, search_graph, query_graph, trace_path, get_code_snippet, get_file_outline,
get_graph_schema, compare_graphs, get_architecture, search_code, list_projects, delete_project,
index_status, check_index_coverage, detect_changes, manage_adr, ingest_traces`.

The harness hard-codes this list **and** cross-checks the count against
`cli --help`/tool listing output if one exists. If `TOOLS[]` changes, the test fails loudly
instead of silently skipping tools. Each tool is invoked against a fixture repo that has just been
indexed (§3.3), with the minimal arguments its schema requires. The table lives in the harness as
`{tool, args_json}` rows. **Pass criterion:** stdout parses as JSON, and the document is not an
`unknown tool` error (the string `unknown tool`, case-insensitive, does not appear).
Tool-level errors such as "symbol not found" count as valid envelopes.

### 1.4 Harness interface (new, test-only)
```
build/c/test-cli-only [--bin PATH] [--suite dispatch] [--only D1,D8,...] [--keep-tmp] [--verbose]
```
- Exit 0 = all cases pass; 1 = one or more failures; 2 = harness usage/setup error.
- Output: one line per case, `ok|FAIL <id> <desc> (rc=N, ms=M)`, then a summary line. With
  `--format json` (optional, for G9 evidence) it emits
  `{"suite":"cli_only_dispatch","cases":[{"id","pass","rc","ms","detail"}],"passed":N,"failed":M}`.

Make targets (in `cli-only.mk`, additive, not prerequisites of any default target):
- `test-cli-only`: depends on `cbm-cli`, builds and runs the harness. Covers E3, E4, E5, E6.
- `verify-default-bytes BASE=<sha>`: runs `scripts/fork/verify-default-bytes.sh`. Covers E7 and the
  reusable G4 helper.

---

## 2. Architecture & Scope

### 2.1 Files

| Action | Path | Purpose |
|---|---|---|
| **Create** | `tests/cli_only/{harness.c,harness.h,suite_dispatch.c,main.c}` | Reusable black-box harness + dispatch suite: spawns the binary with `posix_spawn`, isolates env, enforces timeouts, validates JSON with vendored yyjson, scans the temp tree for artifacts |
| **Create** | `scripts/fork/verify-default-bytes.sh` | E7/G4: builds `codebase-memory-mcp` at `BASE` (in a `git worktree` under `$TMPDIR`) and at `HEAD` with the guard undefined, then diffs `.text`/`.rodata` |
| **Modify** | `cli-only.mk` | Add `test-cli-only`, `verify-default-bytes`, harness build rule (`$(BUILD_DIR)/test-cli-only`) |
| **Modify** | `scripts/test.sh` | Add one fork step after Step 5e: `=== Step F1: CLI-only dispatch (fork) ===` → `make -f Makefile.cbm test-cli-only`. Skipped only with `--suites` (same as the other prod-binary steps) |
| **Create** | `planning/features/01-cli-only-dispatch-verification/progress.json` | G9 evidence |
| **Conditional** | `src/main.c`, `src/cli/cli.c` | Only if a case fails, only inside existing `#ifdef CBM_FORK_CLI_ONLY` blocks (§2.4) |

**Why a separate harness instead of `tests/test_cli.c` in `test-runner`:** `test-runner` links the
*unguarded* `src/main.c`/`src/cli/cli.c` from `PROD_SRCS` with TEST_SEAMS=1. Assertions there
would test the wrong binary. A standalone executable that spawns the real
`codebase-memory-cli` keeps `ALL_TEST_SRCS` and `Makefile.cbm` untouched, so the upstream diff
stays small. The harness is compiled with the test sanitizer flags (ASan+UBSan). The binary under
test keeps its release flags (G3 covers the sanitizer run of shared code through `test-runner`).

**Long-term role (decided):** the standalone harness is the fork's permanent black-box test
bed for every later milestone, not something written only for 01. Structure it so later milestones
can extend it without touching earlier suites:
- `tests/cli_only/harness.{c,h}`: the reusable core. Spawn with a timeout, isolate the env and temp
  root, scan for artifacts, validate JSON, check for leftover descendants, report results.
- `tests/cli_only/suite_dispatch.c`: this milestone's cases (D*, E6).
- Later suites plug in as `suite_<name>.c` and are registered in one static table:
  `suite_mcp_surface` (02: `/rpc` gone, no `mcpServers` writes), `suite_ui_loopback` (03:
  bind is 127.0.0.1 only), `suite_no_network` (04), `suite_quickstart` (05). 06
  `fork-acceptance` runs all of them.
- `--suite NAME[,NAME]` selects suites, and `--only` selects cases. `--format json` output carries
  a `suite` field so G9 evidence can be pulled straight from it.
- The harness depends only on POSIX plus vendored yyjson/sqlite3. It never links product objects,
  so it keeps working as the product's link set shrinks in 02–04.

(Supersedes any single-file naming.)

**Optional sanitizer variant:** `test-cli-only CLI_ONLY_SANITIZE=1` builds a second copy,
`build/c/codebase-memory-cli-asan`, with `CFLAGS_TEST` minus the seam define, and runs the same
harness against it. This is required for G3 ("0 sanitizer reports" on the guarded dispatch path).

### 2.2 Untouched
`src/foundation/`, `src/store/`, `src/cypher/`, `src/pipeline/`, `internal/cbm/`, `src/daemon/*`,
`src/mcp/*`, `src/ui/*`, `Makefile.cbm` (the existing `include cli-only.mk` line is enough),
and all `#else`/`#ifndef` branches in `main.c`/`cli.c`.

### 2.3 Guard compliance
- The harness and scripts are not compiled into any product binary, so no guard is needed.
- `verify-default-bytes.sh` builds with `CBM_FORK_CLI_ONLY` **undefined**. It proves that the
  guarded edits in `main.c`/`cli.c` (and any fix from §2.4) leave `codebase-memory-mcp`
  `.text`/`.rodata` identical to `e038fec5`.
- The G7 check greps `git diff 82dd58c5 -- src/` for changes outside `CBM_FORK_CLI_ONLY` fences
  and fails if it finds any.

### 2.4 Defect-fix policy
If a case fails, the fix goes inside an existing `#ifdef CBM_FORK_CLI_ONLY` block in `src/main.c`
or `src/cli/cli.c`, is recorded in `progress.json` with the failing case ID, and must keep E7
green. A fix needed anywhere else stops the milestone: record it as blocked and ask a human.

### 2.5 Network / daemon confirmation
- The harness opens **no** sockets. It uses only `posix_spawn`, pipes, `waitpid`, and filesystem
  scans.
- Each case runs with a scrubbed environment: `HOME`, `TMPDIR`, `XDG_*`, and `CBM_CACHE_DIR` all
  point inside one fresh `mkdtemp` root. `PATH` is the minimal system path. No proxy vars.
- Artifact assertion after **every** case: a recursive walk of the temp root (and a before/after
  snapshot of `/tmp` entries matching `cbm*`/`*.sock`) finds **no** `S_ISSOCK` entries, no
  `*.sock`, and nothing whose name contains `cohort`, `daemon`, or `startup_lock`. Allowed:
  project DB files, `project_lock` lock files, WAL/SHM.
- No process is spawned (D4–D7): the harness runs the binary in its own process group. After it
  exits, `kill(-pgid, 0)` must return `ESRCH`, meaning no surviving descendants.
- The dynamic no-egress proof (strace/dtruss) is **out of scope** here. It belongs to 04 (D-1).

---

## 3. Data Structures & Memory Ownership

```c
typedef struct {
    const char *id;          /* "D1".. static literal */
    const char *desc;        /* static literal */
    const char *const *argv; /* NULL-terminated, static; argv[0] filled at spawn */
    int stdin_mode;          /* STDIN_DEVNULL | STDIN_OPEN_PIPE_WITH_FRAME */
    int expect_rc;           /* -1 = "any non-zero" */
    unsigned timeout_ms;     /* default 5000; E6 index cases 120000 */
    unsigned flags;          /* EXPECT_JSON_STDOUT | FORBID_JSONRPC | EXPECT_HELP */
} dispatch_case_t;

typedef struct {
    int rc;                  /* exit code, or 128+sig */
    bool timed_out;
    char *out; size_t out_len;   /* heap, owned by result */
    char *err; size_t err_len;   /* heap, owned by result */
    unsigned elapsed_ms;
} spawn_result_t;

void spawn_result_free(spawn_result_t *r); /* frees out/err, zeroes struct; idempotent */
```

- **Capture buffers:** grow geometrically from 4 KiB up to a hard 16 MiB cap per stream. The
  overflow check happens before each `realloc` (`if (cap > SIZE_MAX/2 || cap*2 > CAP_MAX)`). If the
  cap is hit, the harness stops reading, kills the child, and fails the case with `output too large`.
- **Reading:** `poll()` on the stdout/stderr pipes with a monotonic deadline, so neither pipe can
  deadlock. Every pipe FD is `O_CLOEXEC` and closed on every path (single `cleanup:` label per
  function).
- **Temp root:** `char root[PATH_MAX]` from `mkdtemp`. It is removed recursively with `nftw(FTW_DEPTH|FTW_PHYS)`
  at exit unless `--keep-tmp` is set. Paths are built with `snprintf` and the return is checked for
  truncation.
- **yyjson:** each `yyjson_read` doc is `yyjson_doc_free`d right after validation. No doc outlives a
  case.
- **Environment array:** a static `char *envp[16]` of `snprintf`'d stack buffers. Nothing is heap-owned.
- No globals are mutable after `main` parses args. The harness is single-threaded, except in E6,
  which spawns two children and does not create threads.

### 3.3 Fixture
`tests/fixtures/` already holds sample repos. The harness copies a small fixture (a C or Python
repo with ≥2 functions and one call edge) into `<root>/repo`, runs `git init` plus one commit
there (needed by `detect_changes`), and indexes it once with `cli index_repository`. The other 16
tools run against that index.

---

## 4. Failure Modes & Edge Cases

| Case | Expected handling |
|---|---|
| Binary missing / not executable | Harness exits 2 with `binary not found: PATH` |
| Child hangs (e.g. reads stdin) | `SIGKILL` the process group at the deadline → FAIL `timed out` (this is how E3 is detected) |
| Child killed by signal (ASan abort, SEGV) | rc = 128+sig; FAIL; the first 4 KiB of stderr goes into `detail` |
| stdout is JSON plus trailing progress text | FAIL. The contract is exactly one JSON document on stdout; progress belongs on stderr |
| stdout has malformed UTF-8 | yyjson rejects it (default flags, no `ALLOW_INVALID_UNICODE`) → FAIL |
| Empty stdout on a D8 case | FAIL `empty output` |
| Corrupt project DB | Extra case D10: truncate the fixture `.db` to 1 KiB, then run `cli index_status` → valid JSON error envelope, exit ≠ 0, no crash, and the file is not silently deleted |
| Missing SQLite tables | Extra case D11: an empty SQLite file at the project DB path → `cli search_graph` returns a JSON error envelope, not a crash |
| Unwritable `CBM_CACHE_DIR` | Extra case D12: `chmod 0500` cache dir → `cli index_repository` returns a JSON error, exit ≠ 0 |
| OOM | Not injected (no seam in release). The harness itself handles `malloc` failure by marking the case FAIL. The product's OOM path stays covered by the existing unit suites |
| E6 concurrency: lock contention | Two `cli index_repository` children are started back-to-back on the same repo. Assert both exit 0, or exactly one gets a documented "busy/locked" JSON error; neither exits by signal. Then open the DB with vendored sqlite3 and run `PRAGMA integrity_check` == `ok` and `PRAGMA quick_check` == `ok`. Serialization evidence: the `project_lock` lock file exists during the overlap (sampled) and the two runs' `[start,end]` wall-clock intervals of *write phase* do not corrupt the DB. Run it 5 times to catch flakes |
| E6 lock not released | After both children exit, a third `index_repository` must succeed within its timeout |
| Stale lock from a killed run | Extra E6b: `SIGKILL` an indexing child mid-run, then re-run → succeeds (OS lock released on process death) |
| Host `/tmp` noise from other users | The artifact scan only diffs `cbm*`/`*.sock` entries created during the run window, owned by our uid |
| macOS vs Linux | `posix_spawn` + `poll` + `nftw` are POSIX. E7 uses `objdump`/`otool`/`size` via a per-OS branch in the script |

### E7 detail (`scripts/fork/verify-default-bytes.sh`)
1. `git worktree add $TMPDIR/cbm-base <BASE>`, then `make -f Makefile.cbm cbm` in each tree with an
   identical `CC`, `-ffile-prefix-map`, `SOURCE_DATE_EPOCH`, and no ccache.
2. Extract the sections: Linux `objcopy -O binary --only-section=.text/.rodata`; macOS
   `segedit`/`otool -s __TEXT __text` and `__TEXT __const` + `__cstring`.
3. `cmp` each pair. On mismatch, print `nm` symbol diffs. Exit 1.
4. Always remove the worktree (`trap`).
5. **Known risk:** embedded version or build-identity strings may differ between commits. If they
   do, the script masks only the documented identity symbol range and prints what it masked. Any
   other difference is a FAIL. If masking turns out to be needed, it gets a written note in
   `progress.json`.

---

## 5. Testing & Acceptance Criteria

### 5.1 Case → eval mapping
| Eval | Cases | Command |
|---|---|---|
| E3 | D1, D2, D3 (stdin-open-pipe variants under 5 s timeout) | `make -f Makefile.cbm test-cli-only` |
| E4 | D4, D5, D6, D7 + artifact scan + no-descendant check after every case | same |
| E5 | D8 ×17, D9, D10–D12 | same |
| E6 | E6 ×5 iterations, E6b | same |
| E7 | section diff vs `e038fec5` | `make -f Makefile.cbm verify-default-bytes BASE=e038fec5` |
| E9 | quality gate | `/review` on `git diff 82dd58c5` |

### 5.2 Standard gates (ROADMAP §5)
G1 `scripts/build.sh --cli-only` and `make -f Makefile.cbm cbm`, zero warnings · G2
`verify-cli-only-link verify-mcp-engine-split` PASS · G3 full `scripts/test.sh` green, including
new Step F1 and the `CLI_ONLY_SANITIZE=1` run · G4 = E7 · G5 `scripts/lint.sh` clean on the
harness and scripts (shellcheck, if configured) · G6 `make -f Makefile.cbm security` PASS ·
G7 no shared-core or `src/` edits outside the guards · G8 = E9 · G9 `progress.json` records each
eval with its command, output excerpt, and `passes:true`.

### 5.3 Harness self-tests (negative controls)
To show the harness can fail, run it once (manually, recorded in `progress.json`) with:
- `--bin` pointing at `build/c/codebase-memory-mcp` (unguarded). D1 with the open-pipe stdin must
  **FAIL** (blocks or answers JSON-RPC), proving E3 detection works.
- A fake binary (a shell script that `sleep 60`s). Timeout detection must fire.
- A fake binary that prints `{"a":` on stdout. The JSON validator must FAIL it.

### 5.4 TDD workflow (mandatory where practical)
This milestone mostly verifies behaviour that already exists, so "red" has to be shown on purpose
rather than assumed. Every step below records its red and green runs in `progress.json` (command,
rc, output excerpt).

1. **Harness skeleton first, red by construction.** Write `spawn_result_t`, the timeout, and the
   JSON validator before any real cases. Prove each primitive against the §5.3 fakes (sleeper,
   `{"a":` printer, `/bin/false`) and confirm every one FAILs. Then prove a trivial passing fake
   (`printf '{}'`) goes green.
2. **One eval at a time: case → red → green.** For each of E3, E4, E5, E6, in that order:
   - Add that eval's cases.
   - **Red:** run them against the unguarded `codebase-memory-mcp` (or a fake binary that violates
     the contract, where the unguarded binary cannot show the failure, e.g. a fake that creates a
     `*.sock` for E4, or one that skips locking for E6). The cases must fail for the stated reason,
     not for a setup error.
   - **Green:** run them against `codebase-memory-cli`. If they pass straight away, that is
     expected for a verification milestone. Both runs get recorded.
3. **Defects found (§2.4) follow strict TDD.** The failing case goes in first and is committed or
   recorded as red. Then comes the minimal guarded fix, then green, then E7 is re-run to confirm the
   default build is still byte-identical.
4. **E7 script, red first.** Run `verify-default-bytes.sh` against a scratch tree with a deliberate
   unguarded one-byte change to `src/main.c`, and confirm it FAILs. Then run it on the real HEAD and
   confirm it PASSes.
5. **Where TDD is not pragmatic** (it must be justified in `progress.json`): OOM paths (no release
   seam), and E6 true-concurrency races that cannot be forced to fail deterministically. For those,
   use the negative-control fake plus 5× repetition instead of a real red run.
6. **Commit order in `/build`:** test/harness commits come before any fix commit they cover, so a
   reviewer can `git checkout` the test commit and watch it fail.

### 5.5 Done when
Every row in §5.1 and §5.2 passes. `verify-cli-only-link`'s inline smoke loop may stay; it is not
removed in this milestone, to keep the diff small. The roadmap row for 01 becomes COMPLETED and
debt D-1's E2 half is closed by E7.

---

## 6. Open Questions (resolve before `/plan`)
1. **D3 `--help` exit code:** upstream behaviour is 0 or 2. The spec records whatever the code
   does and asserts it stays stable. Confirm that is acceptable, or fix it to 0.
2. **E6 expected outcome:** both runs succeed after waiting on the lock (serialize), or the second
   one fails fast with "busy"? Read `cbm_project_lock_acquire` semantics during `/plan` and pin the
   assertion to them.
3. **E7 masking:** is a masked build-identity range acceptable, or must the bytes match exactly?
