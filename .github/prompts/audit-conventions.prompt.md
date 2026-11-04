---
description: "Audit the codebase against its instruction files and decision records, and rank the findings"
argument-hint: "Optional - a folder, project or rule set to limit the audit to"
agent: agent
model: "Claude Opus 5.5 (copilot)"
---
Audit this repository against its own conventions and decisions, and report what doesn't follow them:

${input:details:Optional - a folder, project or rule set to limit the audit to}

1. Load the rules: `AGENTS.md` and every instruction file it lists, in full, and the decision records in `docs/decisions/` (the project's own, and the template's in `docs/decisions/project-template/`) that the code in scope touches. They are authoritative; where a project file overrides a template rule, the project's wins. Limit the audit to what the request names, when it names something.
2. Confirm the machine-checked part is green: run the project's gate (the Definition of Done or the build and test commands in `AGENTS.md`). A rule the build already enforces, such as an analyzer or a banned API, needs no manual sweep once it passes; spend the effort on the rules only a review can check.
3. Sweep for each review-only rule with a deterministic search: a script or grep that lists every candidate with its file and line, then read each candidate to judge it. A claim that a whole kind of defect is absent comes from such a listing, never from sampling or memory. In PowerShell, `-match` ignores case; use `-cmatch` when case matters.
4. Check the decision records too: code that contradicts an accepted decision, a decision the code has moved past without a record that supersedes it, and an index in `docs/decisions/README.md` that misses a record.
5. Report the findings ranked — violation, worth fixing, minor or a conscious trade-off — each with its file and line, the rule or decision it touches, and a one-line fix. Say plainly what is clean; when the code follows its conventions, say so and don't invent nits. Note a rule that no longer fits the code as a candidate for an instruction or decision change, not as a code defect.

Change no files. If I ask for fixes afterwards, use the handoff-plan template to turn the violations and the findings worth fixing into `PLAN.md` steps.
