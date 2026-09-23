#!/usr/bin/env bash
# gen_compile_commands.sh — regenerate compile_commands.json for IDE tooling
# (CLion, VS Code + clangd, ReSharper C++, etc.). See docs/IDE_SETUP.md.
#
# This project builds via Makefile.cbm, not CMake, so there is no built-in
# compilation database. This script does a `make -n -B` dry run of the
# `cbm` and `test` targets, reassembles the (possibly line-continued) compiler
# invocations, and emits one compile_commands.json entry per source file.
#
# The compiler and the emitted `directory` are not hardcoded:
#   - CC (default: cc) is forwarded to the dry run and used to recognize compile
#     lines, so a clang/gcc toolchain produces a matching database.
#   - `directory` is the repo root of this checkout, so the database is valid
#     regardless of where the repo lives on disk.
#
# Usage:
#   scripts/gen_compile_commands.sh          # uses cc
#   CC=clang scripts/gen_compile_commands.sh # uses clang
set -euo pipefail
cd "$(dirname "$0")/.."

CC="${CC:-cc}" python3 - "$@" <<'EOF'
import json, os, shlex, subprocess

CC = os.environ.get("CC", "cc")
CC_NAME = os.path.basename(CC)
ROOT = os.getcwd()
# Recognize any first token that names a C compiler, so the dry run is matched
# whether the Makefile recipe expands $(CC) or hardcodes `cc`.
COMPILERS = {CC_NAME, "cc", "gcc", "clang"}

def dryrun(target, extra_env=None):
    cmd = ["make", "-f", "Makefile.cbm", "-n", "-B", f"CC={CC}"]
    if extra_env:
        cmd += extra_env
    cmd.append(target)
    out = subprocess.run(cmd, capture_output=True, text=True, cwd=".")
    return out.stdout

def clean(line):
    line = line.rstrip()
    return line[:-1] if line.endswith("\\") else line

def assemble_commands(text):
    commands, current = [], None
    for raw in text.split("\n"):
        if not raw:
            continue
        if raw[0] not in (" ", "\t"):
            if current is not None:
                commands.append(current)
            current = clean(raw)
        elif current is not None:
            current += " " + clean(raw.strip())
    if current is not None:
        commands.append(current)
    return commands

def parse(text):
    entries = []
    for cmdline in assemble_commands(text):
        stripped = cmdline.strip()
        try:
            toks = shlex.split(stripped)
        except ValueError:
            continue
        if not toks or os.path.basename(toks[0]) not in COMPILERS:
            continue
        # Any invocation with .c inputs is a translation unit (covers both
        # separate `-c` compiles and compile-and-link-in-one-step test binaries).
        # Pure link steps list only .o files and so yield no entries.
        files = [t for t in toks if t.endswith(".c")]
        for f in files:
            entries.append({"directory": ROOT, "arguments": toks, "file": f})
    return entries

all_entries, seen = [], set()
for target, env in [("cbm", None), ("test", ["TEST_SEAMS=1"])]:
    for e in parse(dryrun(target, env)):
        if e["file"] not in seen:
            seen.add(e["file"])
            all_entries.append(e)

with open("compile_commands.json", "w") as f:
    json.dump(all_entries, f, indent=2)

print(f"wrote compile_commands.json with {len(all_entries)} entries "
      f"(CC={CC}, directory={ROOT})")
EOF
