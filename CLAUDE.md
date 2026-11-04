@AGENTS.md

## Claude Code

This file comes from the project template, and template updates replace it. Put Claude-specific project instructions in `.claude/rules/<name>.md` instead; Claude Code loads every file there.

- Each plan lives in its own git worktree, so several sessions can work on different plans at once. A planning command (`/plan-feature`, `/handoff-plan`, …) creates `.claude/worktrees/<name>/` on the branch `worktree-<name>` and keeps `PLAN.md` there, untracked; `/orchestrate-plan`, `/execute-step`, `/replan-step` and `/review-plan-diff` move the session into that worktree first. With several plans open, name the one you mean: `/orchestrate-plan <name>`. Once the work is pushed or merged, `/finish-plan` removes the worktree, fast-forwards the default branch and deletes `worktree-<name>`.
- Run Done-when commands and other `PLAN.md` commands with the PowerShell tool, from the root of the plan's worktree.
- Executing a plan: `/orchestrate-plan` delegates each step to the `plan-executor` subagent, verifies it with the step's Done-when command, and re-plans escalations itself.
- Re-planning one escalated or failed step: `/replan-step N`. Reviewing finished work against the plan: `/review-plan-diff`.
- Landing the reviewed plan, as `AGENTS.md`'s Landing section says: `/ship-plan`, then `/finish-plan`. Where every open plan stands, and what to run next: `/continue-plan`.
- Taking issues from plan to landing in one session: `/run-issues #42 #43` or `/run-issues label:bug`. It plans, executes and reviews each issue in its own worktree, opens a draft pull request, answers your review threads, top-level comments and review summaries, and lands it once you merge. It waits up to 24 hours for each merge with nothing to answer; `wait:<hours>` in the request changes that. It runs only when the default branch takes changes through pull requests alone.
- Addressing the comments and discussions on one pull request, from anyone or any bot: `/address-feedback #42`. It judges each open review thread, top-level comment and review summary against the code, plans and executes only the fixes in a worktree, pushes them to the pull request's branch and replies to each item starting with `Autopilot:`; it never merges, resolves a thread or dismisses an alert.
- Doing that round after round until the pull request merges or closes: `/run-feedback #42`. Each round is an `/address-feedback` pass, every five minutes; after a push it comments `/review` when the project runs NCode Review, waits for the bot's review, and recommends the merge after `max-review-rounds` rounds or a pass with nothing to fix. It waits up to 24 hours with nothing to answer; `wait:<hours>` changes that. It never merges, resolves a thread or force-pushes.
