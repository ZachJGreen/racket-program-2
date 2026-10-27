# Scanner numeric literals

## User prompt

`$pstack:poteto-mode Add recognition for integer and real number literals.`

The user supplied poteto-mode skill instructions in a separate message.

## Grounding and plan

The grammar defines digit sequences for integers and digit sequences on both
sides of a decimal point for reals. The scanner already owns indexed scanning,
raw string token values, ASCII identifiers, operators, and line tracking.
The prior operator iteration remains uncommitted; preserve its changes while
creating branch `add-scanner-numeric-literals` for this iteration.

1. Inspect the grammar and scanner.
2. Compare a reusable digit-run helper with a whole/fraction state machine.
3. Add public scanner tests and confirm they fail before implementation.
4. Delegate the source edit; the parent owns tests and design notes.
5. Run all scanner tests and inspect the final diff.

Blocking first steps were the grammar, value representation, and numeric token
types. One source owner and independent test ownership keep writes disjoint.
Scanner state remains local. One worker is the smallest safe implementation
unit for this module.

## Decisions

Emit `int-literal` and `real-literal` with exact source strings. Accept ASCII
digits, require digits on both sides of the decimal point, and leave signs as
operators. Keep existing unsupported-character errors for invalid dots. Digits
stop before letters; token adjacency is for a later parser to validate.
No exponent notation, string parsing, or numeric conversion is introduced.

Both design candidates favored a reusable digit-run helper for the fixed forms.
Model the Domain represents a literal by its source bounds and token kind.
Laziness Protocol avoids a separate numeric state machine.
Test Behavior, Not Implementation guides exact token and error assertions.

## Tests and revisions

Removed the obsolete expectation that `123` is unsupported. Added integer,
real, spelling preservation, signs/operators, identifier boundaries, newline,
malformed decimal, and non-ASCII digit cases. Before implementation, five of
the 22 tests failed because ASCII digits were unsupported, as expected.
The docs directory is read-only and is not changed.

After implementation, `racket -l raco -- test tests/scanner-test.rkt` passes
all 22 tests. `git diff --check` passes. Racket ran with approved escalation
because its Snap launcher cannot start within the sandbox. The public scanner
API and strict whitespace behavior are unchanged.
Independent static review found no blocking correctness or comment issues.
