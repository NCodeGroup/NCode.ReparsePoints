---
description: "Compare options for a technical decision and record it as an ADR"
argument-hint: "The decision to make, with known options or constraints"
agent: agent
model: "Claude Opus 5.5 (copilot)"
---
Help me make this decision and record it as an architecture decision record (ADR):

${input:details:The decision to make, with known options or constraints}

1. Restate the decision, the forces behind it (requirements, constraints, quality goals), and how we will know later that it was right.
2. Identify two to four realistic options, including "do nothing" where relevant. Research each against this codebase: what it touches, what it costs to build and run, and what it locks us into.
3. Compare the options in a table across the forces. Be concrete: name files, libraries, versions and numbers.
4. Recommend one option and explain why the others lose. State the risks of the recommendation and how to reduce them.
5. If weighing the forces needs my input, ask before writing.
6. Read the decisions this one touches first: the repository's own in `docs/decisions/`, and the project template's in `docs/decisions/project-template/`. When the recommendation goes against one, say so; the new ADR supersedes it.
7. Write the ADR as `docs/decisions/NNNN-<slug>.md` (the next number above the highest record numbered 1000 or more in that folder, or 1000 for the first; numbers below 1000 are the project template's), with the sections of `docs/decisions/0000-template.md`, and add a row for it to the index in `docs/decisions/README.md`. A repository that keeps decisions elsewhere writes it there, in its own format. Never write in `docs/decisions/project-template/`, which the template owns; an ADR that overrides one of the template's says so on a `Supersedes: project-template ADR-NNNN` line, and you remind me to list the override in `AGENTS.md`. Change no other file.
