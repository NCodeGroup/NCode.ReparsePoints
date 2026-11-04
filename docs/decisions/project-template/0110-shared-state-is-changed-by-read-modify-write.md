# 0110. Stored state is changed by a read-modify-write that loses no concurrent write

- **Status:** Accepted
- **Date:** 2026-10-31

## Context

A common write pattern computes a new value from an earlier read and then replaces the stored value. When the store
reads the row again just before saving, the concurrency token guards only the time between that second read and the
save, not the time since the caller's first read. A write that lands between the two reads is overwritten:

- two requests that each append an item to a stored list both succeed, and one item is lost;
- a background poll that records "last checked" writes back a copy of what it read, erasing an approval that landed in
  between;
- two approvals of the same pending request both succeed, and both trigger their side effects.

Passing the caller's concurrency token down fixes the overwrite but makes every caller write its own re-read and retry
loop, and the one that forgets still overwrites.

## Decision

A stored value that concurrent requests change is changed only through one read-modify-write operation that applies
the caller's function to the value as stored, and reads again when its write loses a race.

1. One operation. The store or service exposes `UpdateAsync(id, Func<TState, TState?> update, cancellationToken)`. It
   reads the current value in a unit of work and returns `false` without calling `update` when the item is missing or
   no longer modifiable. Otherwise it calls `update` with the stored value. When `update` returns `null`, nothing is
   written and the call returns `false`. When it returns a value, the call saves it under the concurrency token of that
   read and returns `true`.
2. Retry on a lost race. A `StoreConcurrencyException`
   ([ADR-0109](0109-a-lost-concurrency-race-is-a-store-neutral-exception.md)) opens a new unit of work, reads again,
   and calls `update` again, up to a small fixed number of attempts (three). After the last lost attempt the exception
   propagates.
3. The function is pure. Because it may run several times, `update` decides from its argument only and has no side
   effects. Side effects (notifications, messages) happen after the call, and only when it returned `true`.
4. Preconditions are checked on the stored value. A writer that requires a state ("only a pending request can be
   approved", "add the item only if absent") checks it inside `update` and returns `null` when it does not hold. The
   result `true` therefore means "this call made the change", which callers use to decide whether they own its side
   effects.

## Options considered

- Pass the caller's concurrency token. Rejected: every caller repeats the retry loop.
- A retry in each caller. Rejected: every writer repeats the loop and its precondition check, and one that forgets
  either overwrites a concurrent write.
- Merge members in the store. Rejected: the store cannot know whether a caller appended to a list, decided a status, or
  recorded a time, so a generic merge keeps the wrong value.
- Pessimistic locking. Rejected as a default: it holds locks across a request and does not work the same on every
  provider.

## Consequences

- No concurrent write to a value is lost; each change is applied to the stored state under its own token.
- Each change costs a read and one write per attempt; a change the stored state does not need writes nothing.
- Exactly one of two competing decisions wins, and only the winner runs its side effects.
- A writer that may drop its change after exhausting attempts (a best-effort "last seen" timestamp) catches the
  exception explicitly and documents why.

## References

- [ADR-0108](0108-persisted-documents-are-versioned-and-additive.md): persisted JSON documents keep unknown members
  across a rewrite.
- [ADR-0109](0109-a-lost-concurrency-race-is-a-store-neutral-exception.md): a lost concurrency race surfaces as a
  store-neutral exception.
- [ADR-0125](0125-a-write-that-loses-a-race-is-answered-412.md): an API write that loses a race is answered 412.
