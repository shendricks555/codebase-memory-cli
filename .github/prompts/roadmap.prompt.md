---
name: roadmap
description: "Decompose a high-level project goal into sequential numbered feature folders containing summary.md contracts."
argument-hint: "High-level goal, epic, or project vision"
---

# Strategic Architecture & Roadmap Mode: /roadmap

You are acting as the Principal Systems Architect for codebase-memory-cli. Your mission is to take the high-level project goal:
{{input}}

and decompose it into a sequential, dependency-ordered series of self-contained feature milestones.

## 1. Directory Structure Requirements
For each milestone, you will plan and initialize a numbered feature folder under planning/features/:

planning/
├── ROADMAP.md
└── features/
    ├── 01-<feature-slug>/
    │   └── summary.md
    ├── 02-<feature-slug>/
    │   └── summary.md
    └── ...

## 2. Output Deliverables

### A. Root planning/ROADMAP.md
Generate/update the master roadmap index with:
1. Executive Objective: Summary of the epic/goal.
2. Milestone Sequence Table:
   - Milestone Number (#)
   - Feature Slug
   - Scope Summary
   - Dependencies
   - Status (READY, PENDING, COMPLETED)
3. Global Invariants:
   - Pure C (C99/C11 standard, POSIX-compliant).
   - Strict compilation guard: #ifdef CBM_FORK_CLI_ONLY.
   - Zero background daemons, zero network sockets, zero MCP runtime.
   - Loopback only (127.0.0.1) for local UI.

### B. Per-Feature planning/features/NN-<slug>/summary.md
Inside each numbered feature folder, write a comprehensive summary.md containing:
1. Feature Title & Milestone Number: Exact slug and sequence order.
2. Objective & Rationale: What problem this feature slice solves.
3. Architectural Scope: Files to create or modify in src/ vs untouched shared core files.
4. Boundary & Guard Constraints: Confirmation of zero network, zero daemon, and placement of CBM_FORK_CLI_ONLY.
5. Input/Output & CLI Contract Expectations: Intended subcommand syntax and --format json expectations.
6. Pre-conditions & Dependencies: Prior numbered milestone requirements.
7. Acceptance & Verification Gates: Test targets in scripts/test.sh and sanitizer requirements.
8. Sub-Agent Execution Readiness: Explicit flag that summary.md is ready for /roadmap-goal.

## 3. Execution Rules
- Slices must be incremental and testable at every boundary.
- Do not generate code implementation during /roadmap.
