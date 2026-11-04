---
description: "In-depth review of a branch, pull request or folder"
argument-hint: "[Branch, commit range, PR number or path to review]"
model: sonnet
effort: high
disable-model-invocation: true
---
Review this change in depth:

$ARGUMENTS

1. Work out the intent first: read the PR description, commit messages or linked issue. If there are none, infer the intent from the code and say so.
2. Read the full diff, and the changed files in full where surrounding context matters.
3. Check correctness: logic errors, unhandled errors, edge cases (empty, null, large, concurrent), off-by-one errors, resource leaks.
4. Check fit: does it follow the codebase's existing patterns, naming, error handling and tests? Is anything duplicated that already exists?
5. Check risk: security, performance, backward compatibility of public APIs and stored data, migrations, configuration.
6. Run the tests and linters the project uses.
7. Report findings as a table — severity (blocker, should-fix, nit), file and line, problem, suggested fix — followed by a short verdict. Only report issues you can point to in the code; leave out style preferences the codebase doesn't follow.

Change no files. If I ask for fixes afterwards, use the handoff-plan template to turn the blockers and should-fixes into `PLAN.md` steps.
