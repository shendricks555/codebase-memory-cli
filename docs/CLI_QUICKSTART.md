# Codebase Memory CLI — Quickstart

Quick reference for building and running the CLI to generate a code graph.
For the full step-by-step walkthrough with diagram, see
[CLI_BUILD_RUN_GUIDE.md](./CLI_BUILD_RUN_GUIDE.md).

## 1. Start the Dev Container

This project uses a `.devcontainer` with Docker Compose.

1. Open the project in JetBrains Rider — it should detect
   `.devcontainer/devcontainer.json` and prompt to reopen in container.
2. Ensure a `.env.devcontainer` file exists at the project root (referenced
   by `env_file`), since the compose file requires it to start.
3. Once inside the container, your workspace is mounted at `/workspace`.

## 2. Identify the Build Entry Point

Given the project uses `go.mod`, this is a Go-based CLI. Look for:

- A `main.go` or `cmd/` directory (e.g., `cmd/codebase-memory-cli/main.go`)
- A `Makefile` or `justfile` that defines a `build` target

## 3. Build

If a `Makefile` exists:

```bash
make build
```

Otherwise, build directly with Go:

```bash
go build -o bin/codebase-memory-cli ./cmd/...
```

## 4. Run the CLI

Run with `--help` to discover available subcommands:

```bash
./bin/codebase-memory-cli --help
```

## 5. Generate a Code Graph

Look for a subcommand like `graph`, `scan`, or `index`. Typical invocation:

```bash
./bin/codebase-memory-cli graph --src ./src --output graph.json
```

or

```bash
./bin/codebase-memory-cli index ./src
```

## Notes

- Exact subcommand names depend on this project's CLI implementation
  (e.g., Cobra) — confirm via `--help`.
- Check `main.go`, `cmd/root.go`, and the root `Makefile`/`README.md` to
  pin down exact commands if `--help` output is ambiguous.

