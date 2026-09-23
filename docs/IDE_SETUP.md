# IDE Setup for C Development

This is a pure **C11** codebase built with `Makefile.cbm` (no CMake, no MSBuild).
Full cross-file navigation and refactoring (rename, extract, find-usages,
go-to-definition, live diagnostics) depend on a **compilation database** —
`compile_commands.json` — that tells the IDE's C/C++ engine exactly how each
translation unit is compiled.

## TL;DR

```bash
make -f Makefile.cbm compile-commands   # (re)generate compile_commands.json
```

Then open the repo in **CLion** or **VS Code + clangd** (see below). The database
is a generated artifact and is **gitignored** — regenerate it after a fresh
clone and whenever the Makefile's compile flags or source set change.

## Which IDE?

### Recommended: CLion, or VS Code + clangd

Both consume `compile_commands.json` directly and give you the full C code model:

- **CLion** — *File → Open* → select `compile_commands.json` → **Open as Project**.
  It auto-detects the repo's `.clang-format` and `.clang-tidy`, so formatting and
  static-analysis diagnostics match the CI linters out of the box. This is the
  JetBrains IDE with a first-class C/C++ engine.
- **VS Code + clangd** — install the *clangd* extension (disable the default
  Microsoft C/C++ IntelliSense to avoid conflicts). clangd finds
  `compile_commands.json` at the repo root automatically and honors
  `.clang-format` / `.clang-tidy`. Free and on par with CLion for
  navigation/refactoring.
- **Neovim / Emacs / any LSP editor** — point the `clangd` language server at the
  repo root; it reads the same database.

### A note on Rider

**Rider is a .NET IDE and has no general-purpose C/C++ language engine** — its
ReSharper C++ support is scoped to Unreal Engine projects and does **not** load a
standalone `compile_commands.json` C project. Opened in Rider, this repo's `.c` /
`.h` files are indexed as plain text, which is why C refactorings never become
available (unlike a Gradle project in Android Studio, which is IntelliJ-based
with full native C/C++ support). Use CLion or VS Code for C work here. Rider is
fine as an editor + git/terminal host, and the bundled run configurations
(Build / Test / Lint) work regardless of the language engine.

## How the compilation database is produced

This project has no CMake, so there is no built-in database. `make compile-commands`
runs `scripts/gen_compile_commands.sh`, which:

1. Does a `make -n -B` **dry run** of the `cbm` and `test` (with `TEST_SEAMS=1`)
   targets.
2. Reassembles the (line-continued) compiler invocations.
3. Emits one entry per `.c` translation unit into `compile_commands.json`.

It is toolchain- and location-independent:

- `CC` is honored — `CC=clang make -f Makefile.cbm compile-commands` produces a
  clang-flavored database; the default is `cc`.
- The emitted `directory` is this checkout's real path, so the database is valid
  wherever the repo lives on disk.

Regenerate whenever compile flags or the set of source files change; a stale
database only affects IDE indexing, never the actual build.

## Shared editor configuration (already in the repo)

These apply in any editor and need no setup:

- **`.editorconfig`** — LF endings, UTF-8, 4-space indent for `*.c`/`*.h`,
  100-column guide, tabs in Makefiles.
- **`.clang-format`** — K&R braces, 4-space, 100-column. Run repo-wide via
  `make -f Makefile.cbm lint-format` (check) or your editor's format-on-save.
- **`.clang-tidy`** — the same all-checks / warnings-as-errors profile CI
  enforces (`make -f Makefile.cbm lint-tidy`). CLion and clangd surface these
  findings inline as you type.
