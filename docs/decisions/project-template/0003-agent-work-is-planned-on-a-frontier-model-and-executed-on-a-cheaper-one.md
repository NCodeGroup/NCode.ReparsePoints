# 0003. Agent work is planned on a frontier model and executed step by step on a cheaper one

- **Status:** Accepted
- **Date:** 2026-10-31

## Context

An agent-driven change has two halves with opposite needs. Planning (reading the code paths, settling the design,
deciding what each file must say) is a few turns that need deep reasoning. Execution (read, edit, build, test, fix) is
tens of tool turns per change, each resending a growing context, and is most of the token volume. Running both halves
on the strongest model spends its premium rate on typing; running both on a cheaper model spends nothing on the design.

A cheaper model follows a precise instruction well and a vague one badly. When a step leaves a decision open, it
improvises (creates the function the plan assumed, reshapes an interface, edits a file the plan never named) and still
reports success.

## Decision

A frontier model plans, re-plans and orchestrates; a cheaper model executes one verified step at a time; any step that
needs a decision goes back to the frontier model.

| Role | Commands and agents | Model |
| --- | --- | --- |
| Plan, re-plan, orchestrate | `/plan-*`, `/replan-step`, `/orchestrate-plan`, the planner and orchestrator agents | Claude Opus |
| Execute | `/execute-step`, the `plan-executor` agent, the implementer agent | Claude Sonnet, or the local model in the Hybrid agents |
| Review | `/review-plan-diff`, the reviewer agent | Claude Sonnet |

The rules:

- `PLAN.md` is the contract. It holds the Goal, Context for the executor, Decisions, Out of scope, numbered steps that
  name exact files, each with a `- Done when:` PowerShell command that exits 0 only when the step is done, and a Review
  checklist. The executor sees only `PLAN.md` and the files it opens, so every design decision is made in the plan.
- The executor never redesigns. When a step needs a decision the plan did not make, a file it does not list, or the
  plan contradicts the code, the executor reverts its partial edits, marks the step `[?]` with an `- Escalation:` line,
  and stops.
- Re-planning runs on the frontier model. It diagnoses the step, rewrites or splits it, records any redesign under
  Decisions, and resets it to `[ ]`. After two re-plans of the same step, the loop stops and asks the person.
- The coordinator verifies. It runs each step's Done-when command itself before marking the step `[x]` and committing
  `Plan step N: <title>`, staging only the files the step lists; an executor's report of success is not the check.
- Review is part of the loop. The reviewer compares the diff with the plan, rates every deviation from a step's text at
  least should-fix, because a deviation means the executor improvised instead of escalating, and appends fixes as new
  steps. A clean review records the reviewed commit on a `Reviewed:` line, and `/ship-plan` lands only that work.
- The workflow is the same in every tool. Claude Code, Copilot Chat and Copilot CLI share `PLAN.md` and nothing else,
  so any of them can plan, execute, re-plan or review the same plan.

The commands, agents and executor are template-owned files. A change to the workflow is made in the template and
arrives by a template update; a project's own rule goes in `AGENTS.md` or a file it lists, which every agent loads.

## Options considered

- The frontier model for everything. Rejected: most tokens are in execution, which would run at the premium rate.
- A cheaper model for everything. Rejected: the design would be improvised turn by turn, and the conventions applied
  only as well as that model infers them.
- One-pass plan and implement, as built-in plan modes do. Rejected as the main flow: the implementer carries the whole
  planning conversation, runs without a per-step check, and has no path back to the planner.
- A frontier planner with a cheaper, escalating executor (chosen).

## Consequences

- Most tokens run at the executor's rate; the frontier model is spent on the plan, a short check per step, and
  re-plans.
- Plan precision is the lever. Every escalation is a round trip and a sign that a step was underspecified.
- An improvised step that passes its own check is caught only by review, so a change is not done until the review is
  clean.
- Model names are literal. When a tool renames or retires a model, the template's agents move with a template update.

## References

- `.github/instructions/project-template.instructions.md`, Plan-then-execute
- [ADR-0001](0001-conventions-and-lessons-live-in-the-repository.md): conventions and lessons live in the repository.
- [ADR-0002](0002-commits-are-attributed-to-people-not-agents.md): commits are attributed to people, not agents.
