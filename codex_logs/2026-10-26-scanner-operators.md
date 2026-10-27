# Scanner operator recognition

## User prompt

`$pstack:poteto-mode Add recognition for arithmetic, comparison, assignment, and string concatenation operators.`

The user supplied poteto-mode skill instructions in a separate message.

## Grounding and plan

The scanner owns character dispatch and emits existing token records. Grammar
productions specify arithmetic `+ - * /`, comparisons `== /= < <= > >=`,
assignment `=>`, and concatenation `~`. The current worktree was clean on
`add-basic-scanner`; created `add-scanner-operators` for this iteration.

1. Inspect the grammar and existing scanner behavior.
2. Compare separate one/two-character tables with a unified lexeme table.
3. Delegate the scanner edit while the parent owns tests and design notes.
4. Run public scanner behavior tests and inspect the final change.

Blocking first steps were grammar and token-type choices. Tests and scanner
edits have disjoint owners. Scanner state stays local. One implementation worker
is the smallest safe decomposition for the one-module change.

## Decisions

Use immutable single-character and two-character lookup tables, checking the
two-character table first. This keeps the existing scan interface and record
shape. Model the Domain organizes operator recognition as table entries.
Laziness Protocol favors extending existing dispatch rather than rewriting it.
Test Behavior, Not Implementation guides exact token and error expectations.

Treat keywords as identifiers, preserve strict whitespace and newline handling,
and reject lone equals. Numeric/string literals, comments, and logical word
classification are outside the requested scope. The docs directory is untouched.

## Test revisions

Remove obsolete expectations that `a+` and `--comment` must fail, since their
characters now have valid lexical meanings. Add tests for all operators at EOF,
adjacent identifiers, overlapping operators, newline boundaries, incomplete
equals operators, and repeated plus/minus characters.

An initial adjacent-operator expectation was wrong: a `>` immediately followed
by `==` must first consume `>=` under longest matching. Replaced that input
with an unambiguous overlapping sequence and explicit expected tokens. The
worker's early test run saw the initial expectation fail; the final parent run
of `racket -l raco -- test tests/scanner-test.rkt` passes all 16 tests.
`git diff --check` passes and `docs/` has no changes.
Independent static review found no correctness or comment issues. The reviewer's
test attempt hit the Snap sandbox restriction; the parent test run above used
approved escalation and passed.
