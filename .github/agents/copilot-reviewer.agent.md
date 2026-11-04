---
name: Copilot Reviewer
description: Review the work against PLAN.md and queue fix steps for Claude Sonnet 5.5
argument-hint: Optional base branch or commit to diff against
model: 'Claude Sonnet 5.5 (copilot)'
tools: ['read', 'search', 'edit', 'execute']
handoffs:
  - label: Execute the fix steps
    agent: Copilot Implementer
    prompt: Execute the next unchecked step in PLAN.md.
    send: true
    model: 'Claude Sonnet 5.5 (copilot)'
  - label: Re-plan with the planner
    agent: Copilot Planner
    prompt: Re-plan the remaining work in PLAN.md based on the review findings above.
    send: false
    model: 'Claude Opus 5.5 (copilot)'
  - label: Land the plan
    agent: agent
    prompt: /ship-plan
    send: false
    model: 'Claude Sonnet 5.5 (copilot)'
  - label: Show where the plan stands
    agent: agent
    prompt: /continue-plan
    send: true
    model: 'Claude Sonnet 5.5 (copilot)'
---
Review the changes made while executing `PLAN.md`.

Compare against (may be empty): the base branch or commit in my message, if any
If empty, use `git merge-base HEAD origin/<default>`, where `<default>` is the default branch: what follows `origin/` in the output of `git symbolic-ref --short refs/remotes/origin/HEAD`, or `main` when that fails. Without an `origin` remote, use the parent of the first commit whose message starts with "Plan step" or "Re-plan step". After a renumber step has merged the default branch in, the merge base is the merged commit, so the diff holds only this plan's work.

1. Read `PLAN.md`: Goal, Decisions, Out of scope, Steps and Review checklist.
2. Read the full diff (`git diff <base>` including uncommitted changes) and the changed files in full where context matters.
3. Check every step was done as written: the right files, the right behavior, and no shortcuts such as skipped or weakened tests, swallowed errors, hard-coded values or leftover TODOs. Flag every deviation from the step text as at least should-fix even when its checks pass — creating something the step said already exists, touching files the step doesn't list, or changing an interface — because a deviation means the executor improvised instead of escalating.
4. Check what the Done-when commands can't: edge cases, error handling, security, performance, API compatibility, and each Review checklist item.
5. Run the test suite and the checks listed under Context for the executor, after its `- Prelude:` command, when it has one, dot-sourced in the same PowerShell: `$global:LASTEXITCODE = 0; try { . <prelude> } catch { $_; "prelude failed"; exit 2 }; if (-not $? -or $LASTEXITCODE) { "prelude failed"; exit 2 }; <the command>`, where `<prelude>` is that line's command. When it exits 2 and the output's last line, apart from any exit code your shell adds, is `prelude failed`, the command never ran: stop the review without adding steps or a `Reviewed:` line, show me the prelude's error, and say to fix the `- prelude:` line in the `## Landing` section of `AGENTS.md`, or the script it names, and the plan's `- Prelude:` line.
6. Report findings as a table: severity (blocker, should-fix, nit), file and line, problem, fix.
7. For every blocker and should-fix, append a new step to the end of the Steps section of `PLAN.md`, numbered in sequence and in the same format as the existing steps (`### [ ] N. …` with Files, Change and a Done-when command), so the executor model can fix it. Delete any `Reviewed:` line from `PLAN.md`. Work this plan shouldn't do but someone would plan as its own task, such as a separate defect or gap, goes under a `## Follow-ups` heading at the end of `PLAN.md`, one line each as `<short title>: <what to change, where, and why it matters>`, which `/ship-plan` files as an issue; add the heading when it's missing. A nit, a style preference or an idea for someday goes in your reply, not in `PLAN.md`. Change nothing else in the repository.
8. When the review found no blocker or should-fix, record it: put `Reviewed: <the commit git rev-parse HEAD prints>` on its own line among the lines under the plan's title, after `Issue:`, `Release:` and `Refs:`, replacing any `Reviewed:` line there. `/ship-plan` lands only work that matches the reviewed commit, so any later change needs another review. Then say the plan is done, and give the next command: `/ship-plan`, which lands it as `AGENTS.md`'s Landing section says. When `PLAN.md` has an `Issue:` line, also say that the pull request description gets one `Closes <issue reference>` line per issue on it, one `Refs <issue reference>` line per reference on its `Refs:` line, and a two-to-five-line summary of the plan's steps and Decisions, which `/ship-plan` writes.
9. When the review added fix steps, give the next command instead: `/orchestrate-plan`.
