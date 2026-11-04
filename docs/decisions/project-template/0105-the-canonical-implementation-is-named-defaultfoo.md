# 0105. The single canonical implementation of an interface is named DefaultFoo

- **Status:** Accepted
- **Date:** 2026-10-31

## Context

Most service interfaces have exactly one built-in implementation that callers resolve through dependency injection and
never name directly. Without a rule, each author names it differently (`FooImpl`, `FooService`, `ConcreteFoo`, `Foo`),
and the choice is a recurring bikeshed.

## Decision

The single canonical implementation of an `IFoo` that callers resolve through DI and never name directly is named
`DefaultFoo`: strip the `I`, prepend `Default` (`IOrderPricer` to `DefaultOrderPricer`, `IInvoiceRenderer` to
`DefaultInvoiceRenderer`). This is the ASP.NET Core idiom (`DefaultHttpContextFactory`, `DefaultProblemDetailsWriter`).
It keeps the bare concept name free, separates interface from implementation at a glance, and signals a replaceable
default.

The implementation is `internal` and is reached only through the interface, whether the interface itself is public or
internal.

Three carve-outs, each for a class that is not "the one canonical DI implementation":

1. An implementation that is one of several variants, or is defined by how it works, is named for what makes it
   specific: `CreditCardPaymentHandler` and `BankTransferPaymentHandler` are two `IPaymentHandler`s selected at
   runtime, not a default.
2. An implementation of a framework interface follows the framework's naming pattern: an
   `IValidateOptions<SmtpOptions>` is `SmtpOptionsValidator`.
3. A public data, message, model, or result type that callers construct and name directly keeps the bare concept name
   (`Order`, `InvoiceRequest`) even when it implements an interface.

## Options considered

- `FooImpl`, `FooService`, `ConcreteFoo`. Rejected: noisier, and `Service` collides with genuine service nouns.
- The interface name without the `I`. Rejected: it takes the clean concept name a consumer might want for their own
  replacement, and reads ambiguously at a call site.
- `DefaultFoo` (chosen). Matches the platform, signals replaceability, and keeps the concept name free.

## Consequences

- A reader pairs any `IFoo` with its `DefaultFoo` at a glance and knows the type is an internal default reached
  through the interface.
- A `Default*` name is a claim of "the one canonical implementation", so variants, framework adapters, and types callers
  construct by hand deliberately do not use it.

## References

- [ADR-0103](0103-behavior-is-a-service-a-strategy-collection-or-a-mediator.md): the service shape this naming applies
  to.
