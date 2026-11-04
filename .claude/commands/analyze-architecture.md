---
description: "Deep analysis of a codebase or subsystem, written to ANALYSIS.md"
argument-hint: "[Question to answer or area to analyze]"
model: opus
effort: high
disable-model-invocation: true
---
Analyze the following and write your findings to `ANALYSIS.md` in the repository root. Change no other file.

$ARGUMENTS

Work like a senior engineer joining the project:

1. Read the entry points, core modules and the code paths relevant to the question. Read code instead of guessing from names.
2. Explain how it works: components, responsibilities, data flow and key types. Back every claim with a file and symbol reference.
3. Identify strengths, weaknesses, risks and technical debt, each with evidence and an estimate of impact.
4. Separate facts verified in code from inferences. Label the inferences.
5. Rank recommendations by value for effort. For each one worth doing, add a one-line follow-up request naming the template to use, for example `plan-refactor: split OrderService into …`.

Structure `ANALYSIS.md` as: Summary (five lines), How it works, Findings (table: finding, evidence, impact), Recommendations, Open questions.
