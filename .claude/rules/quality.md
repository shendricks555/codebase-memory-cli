---
paths:
  - "**/*.c"
  - "**/*.h"
description: Style, lint, and commit conventions for this repo
---

# Quality

## Tooling

- `scripts/lint.sh` runs, in order: `check-no-test-skips.sh`, then either
  `make lint-ci` (cppcheck + clang-format, CI mode) or full `make lint`
  (clang-tidy + cppcheck + clang-format). Must pass before committing.
- `git config core.hooksPath scripts/hooks` activates pre-commit security
  checks — confirm this is set in any environment doing real commits.
- Formatting is clang-format-driven; do not hand-format against its output.

## Commit conventions

- Conventional-commit-style subject lines (`fix(daemon): ...`,
  `build(devcontainer): ...`) matching recent history (`git log --oneline`).
- Only create commits when the user asks. Prefer new commits over `--amend`.

## Style

- Pure C11, no Go. Do not introduce a language runtime or external service
  dependency — everything vendored (`vendored/`) is compiled in, no network
  fetch at build or run time.
- No comments explaining what code does; only comment non-obvious WHY
  (workarounds, invariants, subtle constraints).
