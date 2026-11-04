---
description: "Finish a plan whose work is pushed — retire PLAN.md, fast-forward the default branch, delete the plan's branch"
argument-hint: "Optional extra instructions"
agent: agent
model: "Claude Sonnet 5.5 (copilot)"
---
Finish the plan whose work is already pushed or merged: retire `PLAN.md`, bring the default branch up to date, and delete the plan's branch. Never push, merge, rebase or reset in this command: when a check fails, stop and say what is left to do.

Extra instructions (may be empty): ${input:details:Optional extra instructions}

1. Read the state: run `pwsh -NoProfile -File .template/Get-PlanState.ps1` from the repository root, adding `-Path <folder>` when the plan is in another folder. It fetches `origin` and prints `key: value` lines; `-` means none. Below, `<default branch>` is its `default` value and `<plan's branch>` its `branch` value. When `dirty` is `yes`, stop and list the files `git status --porcelain` prints. When `steps` isn't `-` and its two counts differ, as in `3/5`, stop and list the step headings in `PLAN.md` that don't start with `### [x]`. When `unfiled` is above 0 and the `landing` line's `follow-ups` isn't `none`, stop: the `## Follow-ups` section of `PLAN.md` lists follow-ups that were never filed as issues. List those lines, and say to run ship-plan, which files them, then finish-plan again.
2. Check the work is upstream: the check passed when `landed` is `yes`. The script counts the branch as landed when `HEAD` is on `origin/<default branch>`, or when `gh` or `glab` finds a merged pull request from it whose merge commit is on `origin/<default branch>` and whose head holds `HEAD` or has the same tree, as a squash merge or a merge queue leaves it. When `ahead` isn't `0`, it landed the second way: name the pull request on the `pr` line. When `default` is `-`, stop: there is no `origin` remote. Otherwise — no such pull request, or `pr` is `unknown` because the CLI is missing or failed — show `git log --oneline origin/<default branch>..HEAD` and stop to ask me whether to push those commits first or whether they reached the default branch another way.
3. Retire the plan: delete `PLAN.md` when it exists.
4. Fast-forward the default branch: run `git switch <default branch>`, then `git pull --ff-only`. When either fails, stop and report the error.
5. When the plan's branch is not `-` and not the default branch, delete it with `git branch -d <plan's branch>`. When `-d` refuses, use `git branch -D <plan's branch>` only if step 2 passed or I confirmed the commits reached the default branch. When `origin/<plan's branch>` still exists, say so and leave it: deleting it is a push.
6. Finish with the range `git pull` printed (or "already up to date"), the default branch's commit (`git log --oneline -1`), and the branches deleted.
