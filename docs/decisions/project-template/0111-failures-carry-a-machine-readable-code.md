# 0111. A failure that callers act on carries a machine-readable code

- **Status:** Accepted
- **Date:** 2026-10-31

## Context

Validation and processing failures are often reported only as message text: an exception message, a `FailureReason`
string, a joined list of errors. A caller that needs to tell one failure from another (to choose a response, a retry,
a user-facing message, or a metric attribute) can do so only by matching the text. Text is written for people and
changes with wording, so a caller that matches it breaks silently.

The tempting workaround, re-checking the input in the caller to learn which rule failed, duplicates the validation and
drifts from it.

## Decision

A failure that callers act on carries a machine-readable code, set where the failure is detected.

1. Codes are set at detection. The component that detects a failure names its code; callers neither re-check the input
   nor parse messages.
2. Codes are stable snake_case strings, defined as `public const string` members of one static class per component
   (`ValidationFailureCodes.Expired = "expired"`) and compared ordinally. A string vocabulary lets an extension point
   (a custom validator, a plug-in rule) name a code of its own and lets the code cross a wire unchanged. An `enum` is
   used instead only when the set is closed by the operation's contract and never crosses a process boundary.
3. The failure carries the code beside the human text. A result type exposes `FailureCode` (null when successful) and
   `FailureReason`; an exception exposes `FailureCode` as an `init` property with a documented default for the generic
   case. When several rules fail, the first recorded code wins, and every reason stays in the message.
4. A layer above passes codes through. A higher layer that has its own vocabulary aliases the codes it shares
   (`public const string Expired = ValidationFailureCodes.Expired;`) and passes a lower layer's code through
   unchanged, rather than keeping a mapping table that loses codes it does not list.
5. Messages are for people and never contain secrets or the rejected input when that input is sensitive. A code is a
   constant, so it never carries input either.

HTTP APIs carry the code in the problem details response (an extension member such as `"code"`), so clients branch on
it rather than on `title` or `detail`.

## Options considered

- Match message text. Rejected: breaks silently when wording changes.
- Re-check in the caller. Rejected: duplicates validation and drifts from it.
- Report which rule failed instead of why. Rejected: one rule can fail for distinct reasons (expired, not yet valid,
  malformed), and the caller needs the reason.
- Report every failure's code. Rejected: a caller acts on one outcome; the message keeps every reason.

## Consequences

- Callers branch on `FailureCode`, log `FailureReason`, and can use the code as a bounded metric attribute
  ([ADR-0113](0113-metrics-have-one-owner-per-signal-and-bounded-dimensions.md)).
- Every new failure path names a code; a custom extension names its own.
- Code that acts on why something failed reads the code, never the text.

## References

- [RFC 9457, Problem Details for HTTP APIs](https://www.rfc-editor.org/rfc/rfc9457)
- [ADR-0113](0113-metrics-have-one-owner-per-signal-and-bounded-dimensions.md): metrics have one owner per signal and
  only bounded dimensions.
