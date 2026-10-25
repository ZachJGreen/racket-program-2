# Token design

## Problem

The repository has a grammar and sample programs but no existing Racket
implementation. Establish one shared token representation within the requested
scaffold scope.

## Usage

```racket
(require "src/token.rkt")
(define name (token 'identifier "count" 3))
(define literal (token 'int-literal 42 4))
(token-line name)
(token-value literal)
```

These imports are relative to a caller at the project root.

## Shape

`src/token.rkt` owns `(struct token (type value line) #:transparent)` and
exports `(struct-out token)`: the constructor, predicate, accessors, and struct
metadata. The immutable record holds data without conversion or shared state.
`info.rkt` declares package metadata and the base dependency.

The interface exposes the three requested fields directly. There is no
processing complexity to hide yet; wrappers would add indirection.

## Synthesis decision

Two independent sketches compared a flat root layout and a `src/` layout
with exported contracts. Use the `src/` layout for source ownership and the
plain struct export from the flat candidate for the smaller API. Both reviewers
used the inherited model, so this comparison has no model diversity.

## Tradeoffs accepted

- Accept constructor conventions in exchange for avoiding an unrequested value policy.
- Accept a public representation in exchange for direct construction and inspection.

## Alternatives considered

A flat root module gives equally simple imports but mixes source and package
metadata. Exported contracts enforce categories and line numbers, but the
proposed string-only value contract chooses a literal representation too early.
Lexer, parser, and command-line stubs would expose unimplemented interfaces.

## Open questions and risks

Should future lexer values retain source lexemes or contain decoded literals?
That decision can be made with the lexer requirements.

## Next implementation step

Define and export the token record, then verify construction, field access,
structural equality, and immutability through a separate importing caller.
