# Choose and loop statements

## User prompt

`$pstack:poteto-mode Implement choose/match/otherwise statements and loop/until/do statements.`

The user supplied poteto-mode skill instructions in a separate message.

## Grounding and plan

The grammar defines choose with a bracketed condition, mandatory match body,
optional otherwise body, and a final semicolon supplied by the statement list.
Loop uses until, a bracketed condition, do, and a statement body. These bodies
do not permit declarations. The existing parser owns statements and expressions
through one local cursor. Preserve earlier uncommitted work on new branch
`parse-control-flow`.

1. Inspect grammar, context rules, and shared statement consumption.
2. Compare dedicated control nodes with a generic tagged control representation.
3. Delegate parser edits while independently adding integration tests and notes.
4. Run the full suite and review nesting, keywords, semicolons, and lines.

AST shape and statement-only block boundaries were the blocking decisions.
One worker owns src/parser.rkt; the parent owns tests and notes. Writes are
disjoint and parser state stays local. One source worker is the smallest safe unit.

## Decisions

Add choose-statement(condition match-statements otherwise-statements) with #f
for an absent otherwise and an empty list for a present empty branch. Add
loop-statement(condition statements), preserving the until condition unchanged.
Use a shared statement-list parser and a statements-only brace helper; existing
program/routine declaration blocks reuse only the list helper. Each complete
control statement and each child statement consumes its own semicolon.

Preserve user-approved empty-block acceptance across control-flow bodies.
Guard contextual choose/loop dispatch with existing assignment lookahead that
stops at braces. Match/until/do/otherwise remain identifiers outside header
positions. Preserve expression precedence and error-line conventions.

Model the Domain uses dedicated variants and recursive body lists. Laziness
Protocol reuses statement parsing. Test Behavior, Not Implementation checks
exact nested ASTs, optional-branch presence, malformed headers, and diagnostics.

## Revisions

Replaced obsolete control-flow rejection fixtures with invalid bare-block cases.
The new fixture's syntax check found one excess closing parenthesis; corrected
it before full test execution. A design-note patch used an incomplete context
line and failed atomically; reapplied it against actual section headings.
No files under docs/ were changed.

## Verification

`racket -l raco -- test tests` passes all 127 tests. The syntax-only fixture
check also passes after the correction above. `git diff --check` passes.
Coverage includes optional otherwise presence, empty bodies, nested controls,
routine integration, all contextual words, expression precedence, comments,
missing headers/delimiters/semicolons, rejected declarations, and token/EOF lines.
Racket used approved escalation for its Snap launcher restriction.
Independent static review found no concrete bugs in the scoped changes.
