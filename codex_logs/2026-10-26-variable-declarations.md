# Variable declarations

## User prompt

`$pstack:poteto-mode Implement variable declarations, identifier lists, and the four data types from the grammar.`

The user supplied poteto-mode skill instructions in a separate message.

## Grounding and plan

The grammar defines `decl identifier-list as type ;` and the exact types int,
real, bool, and string. The parser already owns a local checked token cursor;
the scanner emits contextual words and type spellings as identifiers. Preserve
all earlier uncommitted work on branch `parse-variable-declarations`.

1. Inspect grammar, context rules, existing parser, and callers.
2. Compare grouped declaration nodes with flattened variable bindings.
3. Delegate parser implementation while migrating callers and writing tests.
4. Update parser design notes and run scanner/parser tests.
5. Independently review list grammar, type validation, and source-line errors.

The AST shape and grammar were the blocking decisions. One worker owns the
parser source; the parent owns independent tests and notes. Writes are disjoint
and all parser state stays local. One parser worker is the smallest safe unit.

## Decisions

Use grouped `var-declaration(names type)` nodes inside `program(name declarations)`.
Names are ordered nonempty lists of strings. Types are validated spellings,
converted to the symbols int, real, bool, and string. Parse zero or more
declarations before the closing brace; preserve names and declaration order.
Context words and type spellings remain valid names, including `decl as as int;`.
Required commas, as, types, and semicolons use existing line-aware diagnostics.
Duplicate/scope/type semantics, routines, and statements are out of scope.

Model the Domain preserves declaration grouping. Laziness Protocol keeps the
local parser cursor and scanner interface. Test Behavior, Not Implementation
drives complete source strings and checks AST values or syntax errors.
Migrate all program constructors to the new arity with no compatibility API.
No files under docs/ are changed.

## Failures and revisions

The initial design-note patch failed to match one line; reapplied it using the
actual text. No source changes were lost.

## Verification

`racket -l raco -- test tests/scanner-test.rkt tests/parser-test.rkt` passes all
52 tests. Coverage includes every type, ordered multi-name lists, contextual
names, comments, empty declarations, malformed separators/delimiters, invalid
type spellings, EOF, and offending-token line numbers. `git diff --check`
passes. The scanner and docs/ are unchanged by this iteration. Racket used
approved escalation for its Snap launcher restriction.
Independent static review found no concrete correctness or source-comment issues.
