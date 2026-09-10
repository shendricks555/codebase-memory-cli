---
paths:
  - "tests/**"
  - "src/**"
  - "internal/cbm/**"
description: TDD policy and test-suite conventions
---

# Testing

## Running tests

- `scripts/test.sh` is the canonical entry point: builds with ASan+UBSan and
  runs the full suite (this is what CI runs). `--suites LIST` does an
  incremental rebuild and runs only named suites (list via
  `build/c/test-runner --list-suites`). `--tsan` runs the ThreadSanitizer leg.
- `make -f Makefile.cbm test-foundation` for a fast foundation-only pass.
- Do not assume a `-run <pattern>` style single-test flag exists — check
  `tests/*.sh` and `scripts/test.sh` for the actual selection mechanism before
  inventing an invocation.

## TDD policy

- Any phase touching `src/store`, `src/cypher`, `src/pipeline`, `src/cli`, or
  `internal/cbm` gets a test-writing task before its implementation task.
- Tests live in `tests/test_*.c` (regression parity checks may still exist in
  `internal/cbm/regression_test.go`, being migrated off Go — do not add new Go
  tests).

## TEST_SEAMS discipline

`TEST_SEAMS=1` (`-DCBM_ENABLE_TEST_SEAMS=1`) is opt-in only, never opt-out.
Code that exists purely for test harnesses must never compile into a
production/release binary. `scripts/test.sh` passes `TEST_SEAMS=1`;
`scripts/build.sh` does not — preserve this split for any new build target.
