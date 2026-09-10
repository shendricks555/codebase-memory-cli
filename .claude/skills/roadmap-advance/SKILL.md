---
name: roadmap-advance
description: Resume the roadmap and execute exactly one next stage (spec/plan/implement/verify) for the first incomplete feature. Safe to call repeatedly or from /loop.
arguments: [status]
argument-hint: "[status]"
disable-model-invocation: true
---

# /roadmap-advance

The single entry point for continuing roadmap work across sessions. Files are
ground truth — never trust the cached `ROADMAP.md` table without reconciling
it against actual files first.

## Stage-state derivation (recompute every invocation)

| Stage | ✅ when |
|---|---|
| Spec | `spec.md` exists |
| Plan | `plan.md` **and** `progress.json` exist |
| Implement | every non-Validation phase's tasks are all `passes: true` and the suite is green (per [[testing]]) |
| Verify | Validation phase complete **and** every eval `passes: true` **and** last `/quality-gate` run was PASS |

`HANDOVER.md` present in a feature folder means that stage is mid-flight —
resume from it (pass its content into the relevant skill/agent), delete it
once consumed, and fold any durable content into `progress.json` notes.

## Behavior

1. Read `.claude/planning/active/ROADMAP.md`.
2. Reconcile the stage table against actual files (per the table above) for
   every feature in sequence.
3. If invoked with `status`: print the reconciled table and **stop** — take
   no further action.
4. Otherwise: find the first feature with the first incomplete stage, in
   roadmap order. Execute **exactly that one stage**, dispatching to the
   matching skill (`/spec`, `/plan`, `/implement`, `/quality-gate`).
5. Tick the corresponding `ROADMAP.md` cell, delete any consumed
   `HANDOVER.md`, and append one line to `.claude/planning/activity-log.md`
   under today's date heading describing what was done.
6. Stop. **Never chain multiple stages or features in one invocation.**

## Loop mode

Safe to drive from `/loop` for unattended progress. Real stopping conditions
— do not keep looping past these, surface to the user instead:

- All features show ✅ across every stage.
- Unresolvable ambiguity in a spec/plan that needs a human decision.
- The same quality-gate finding recurs on a second consecutive attempt at the
  same stage (stuck-loop breaker, mirrors the one in
  `.claude/agents/implementer.md`).
- An NFR that cannot be met as specified.
- A stage would require a destructive git operation (force-push, hard reset,
  branch deletion) — always escalate to the user for these, never perform
  them autonomously.
