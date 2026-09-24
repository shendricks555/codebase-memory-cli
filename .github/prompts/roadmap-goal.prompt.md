---
name: roadmap-goal
description: "Orchestrate sequential end-to-end delivery of roadmap feature folders across 3 distinct sub-agent sessions."
argument-hint: "Target feature folder path (e.g. planning/features/01-...) or 'next'/'all'"
---

# Milestone Orchestrator: /roadmap-goal

You are the Lead Project Orchestrator responsible for executing roadmap features for codebase-memory-cli.

Target Input:
{{input}}

## 1. Orchestration Protocol
Progress through three distinct, sequential sub-agent sessions for the target feature folder:

SESSION 1: SPEC & PLAN
- Reads summary.md
- Generates spec.md (Technical Spec, CLI Contract, Data Structures)
- Generates plan.md (Atomic Task Checklist <150 LOC each)

SESSION 2: BUILD
- Implements C code incrementally per plan.md, test-first (red → green) unless a task is marked TDD-BYPASS
- Wraps fork logic in #ifdef CBM_FORK_CLI_ONLY
- Enforces 0 leaks, 0 network calls, clean build

SESSION 3: VERIFY & REVIEW
- Executes scripts/test.sh & ASan/UBSan sanitizers
- Runs CLI smoke tests with --format json
- Conducts 6-Axis Staff Review (includes test discipline)
- Updates summary.md & ROADMAP.md to COMPLETED

## 2. Detailed Session Procedures

### Sub-Agent Session 1: Specification & Planning
- Input: Read planning/features/NN-<slug>/summary.md.
- Actions:
  1. Write spec.md into the feature folder (C prototypes, CLI flags, memory lifecycle, error tables).
  2. Write plan.md into the feature folder (numbered atomic tasks <150 LOC each with verification commands).
- Exit Gate: spec.md and plan.md saved in the feature folder.

### Sub-Agent Session 2: Incremental Build
- Input: Read spec.md and plan.md from the feature folder.
- Actions:
  1. Implement tasks in order: write or extend the failing test first, confirm red, then implement to green. Record red and green (or TDD-BYPASS) in progress.json.
  2. Enforce pure C rules (malloc/free pairing, #ifdef CBM_FORK_CLI_ONLY guards, zero socket calls).
  3. Compile check after each slice: scripts/build.sh or ninja -C build/c.
- Exit Gate: All planned tasks implemented with zero compiler warnings (-Wall -Wextra -Werror).

### Sub-Agent Session 3: Verification, Review & Sign-Off
- Input: Code changes and acceptance criteria in summary.md.
- Actions:
  1. Run Sanitizer & Test Suites: scripts/test.sh --suites <relevant_suites>. Verify zero leaks and zero UB.
  2. Run CLI Contract Smoke Test: build/c/codebase-memory-cli cli <tool_name> --format json. Verify stdout is pure JSON.
  3. Conduct 6-Axis Review (Memory Safety, File Locks, Portability, Error Resilience, C Style, Test Discipline).
  4. Update Status: Mark checklist items in summary.md and set milestone to COMPLETED in planning/ROADMAP.md.
- Exit Gate: All tests green under ASan/UBSan and review marked approved.

## 3. Operational Directives
- Sequential Guard: Never begin Session 2 before Session 1 produces a valid spec.md and plan.md. Never mark a feature complete without Session 3 passing with sanitizers enabled.
- Context Isolation: When switching between sub-agent sessions, summarize artifacts clearly to maintain clean reasoning state.

## TDD Directive (pragmatic, bypassable)
- **Default:** write the test first. It must fail for the stated reason (red), then you add the smallest change that makes it pass (green), then you refactor with the tests still green. Record the red and green commands and their results.
- **Verification-only work** (the behaviour already exists): show red on purpose. Run the test against a negative control, such as the unguarded binary or a fake that breaks the contract, before you run it against the real target.
- **Bug fixes:** always start with a failing regression test, with no exceptions unless one of the bypass cases below applies.
- **Bypass is allowed** when test-first would add undue friction, for example: an OOM or signal path with no release seam; a non-deterministic race; a pure build, doc or script-plumbing change; or a test that would need a new seam or a shared-core edit. When you bypass, write `TDD-BYPASS: <reason> — <substitute evidence>` in the plan/progress record, and prefer substitute evidence (negative control, repeated runs, manual check).
- Never weaken an invariant, add a test seam to release builds, or edit shared core just to make test-first possible.
