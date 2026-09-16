#!/usr/bin/env bash
# gen_compile_commands.sh — regenerate compile_commands.json for IDE tooling
# (Rider/ReSharper C++, CLion, clangd, etc.).
#
# This project builds via Makefile.cbm, not CMake, so there is no built-in
# compilation database. This script does a `make -n -B` dry run of the
# `cbm` and `test` targets, reassembles the (possibly line-continued) cc
# invocations, and emits one compile_commands.json entry per source file.
#
# Usage:
#   scripts/gen_compile_commands.sh
set -euo pipefail
cd "$(dirname "$0")/.."

python3 - "$@" <<'EOF'
import json, shlex, subprocess

def dryrun(target, extra_env=None):
    cmd = ["make", "-f", "Makefile.cbm", "-n", "-B"]
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
        if not stripped.startswith("cc "):
            continue
        try:
            toks = shlex.split(stripped)
        except ValueError:
            continue
        files = [t for t in toks if t.endswith(".c")]
        for f in files:
            entries.append({"directory": "/workspace", "arguments": toks, "file": f})
    return entries

all_entries, seen = [], set()
for target, env in [("cbm", None), ("test", ["TEST_SEAMS=1"])]:
    for e in parse(dryrun(target, env)):
        if e["file"] not in seen:
            seen.add(e["file"])
            all_entries.append(e)

with open("compile_commands.json", "w") as f:
    json.dump(all_entries, f, indent=2)

print(f"wrote compile_commands.json with {len(all_entries)} entries")
EOF
