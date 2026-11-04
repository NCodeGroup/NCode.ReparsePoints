# Design: Title of the work

- **Status:** Draft
- **Date:** YYYY-MM-DD
- **Issue:** _the issue that tracks this work_
- **Authors:** _who wrote it_

_Status is one of Draft, Accepted, In progress (phase N of M), Done, or Abandoned. Keep it current: a design document
is a living record of work that spans more than one plan, unlike a plan, which ends when it lands. Write in the
present tense, and claim only what is built; planned work names its issue._

## Summary

_Two or three sentences: what this work delivers and why. List the central decisions by number, each linking to its
section under Decisions._

## Goals and Non-Goals

_Numbered goals (G1, G2, …), each a verifiable outcome. Then the non-goals: what this work deliberately leaves out, so
nobody assumes it._

## Context

_What exists today, what problem it leaves, and the constraints (standards, compatibility, operations, cost) the
design must meet. Link to decision records rather than restating them._

## Design

_The design itself: components, data, flows and interfaces. One diagram where it helps, and enough detail that a plan
can be written from each phase._

## Security Analysis

| Threat | Mitigation | What remains |
| --- | --- | --- |
| _who could do what_ | _the control that stops it_ | _the risk accepted, and why_ |

## Failure Modes

| Failure | Impact | Detection | Response |
| --- | --- | --- | --- |
| _a dependency, input or step that fails_ | _what users or data see_ | _the signal that shows it_ | _what the system or an operator does_ |

## Decisions

_Numbered decisions (D1, D2, …): for each, the options, the choice and why. When the phase that depends on a decision
lands, the decision becomes a record in `docs/decisions/`, and this section links to it._

## Open Questions

_Questions not yet answered, numbered (Q1, Q2, …). When one is answered, keep it and mark it "Decided: ADR-NNNN" with a
link, or "Decided: D3" when the answer is a decision above._

## Rollout and Phases

_The phases, in order. Each phase is shippable on its own, passes the project's full gate, and is one or more plans
with their issues. Say what each phase enables and how it is rolled out (flags, migrations, compatibility windows)._

## References

_Standards, prior art, issues and decision records this design builds on._
