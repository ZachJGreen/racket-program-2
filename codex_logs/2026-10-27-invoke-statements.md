# Invoke statements

## User prompt

`$pstack:poteto-mode Implement invoke statements with and without arguments.`

The user supplied poteto-mode skill instructions in a separate message.

## Grounding and clarification

The grammar defines invoke identifier followed by empty or comma-separated
expression arguments. The statement list supplies the semicolon. Samples also
show result-capture syntax absent from the grammar. Asked whether to include
capture; stated the default of standalone calls for this task.

Preserve prior uncommitted work on branch `parse-invoke-statements`.

## Plan and decisions

1. Compare a dedicated invoke statement node with a generic call-expression.
2. Delegate parser changes while independently adding tests and notes.
3. Run all scanner/parser suites and independently review delimiter handling.

The grammar and AST shape were the blocking decisions. One worker owns
src/parser.rkt; the parent owns tests and notes. Writes are disjoint and parser
state stays local. One implementation worker is the smallest safe unit.

Both designs favor invoke-statement(name arguments) with an ordered list of
existing expression nodes. Parse parentheses and comma-separated expressions
with existing precedence and cursor diagnostics. The shared statement parser
consumes one semicolon. Guard contextual invoke with bounded assignment
lookahead, preserving invoke=>x and invoke+1=>x assignments.

Model the Domain adds a dedicated statement variant. Laziness Protocol reuses
expression parsing instead of introducing call expressions. Test Behavior,
Not Implementation checks complete source-to-AST results and error lines.
No scanner, program/routine AST changes, semantic routine lookup, arity checks,
or expression calls are introduced.

## Revisions

The agent limit required closing completed reviewers before fresh design work.
Removed obsolete rejection tests for valid invoke statements; retained coverage
for unsupported bare calls and control flow. Added empty/single/multiple args,
precedence, nested bodies, contextual words, comments, malformed delimiters,
statement boundaries, and EOF/line diagnostics. The docs directory is untouched.

## Verification

`racket -l raco -- test tests` passes all 113 tests. `git diff --check` passes.
The scanner and existing AST shapes are unchanged; invokes add one statement
variant. Racket used approved escalation for its Snap launcher restriction.
Proceeding with the stated standalone-call default in the absence of a reply
to the optional result-capture question.
Independent static review found no concrete bugs in the scoped changes.

## Follow-up investigation prompt

`$pstack:poteto-mode It seems like the Demo, the ScopeCheck, and the first 3 testfiles would have the same issue where the invoke line would lead to an unintended failure. The parser is only treating invoke as a call when no '=>' appears before the semicolon. check me on that.`

The user supplied poteto-mode instructions again. This is a code investigation;
no implementation changes or new branch are needed.

Throughput checkpoint: n/a, read-only investigation.

## Follow-up evidence

Ran the real parser against the fenced source extracted from Demo.md and
ScopeCheck.md, plus Testfile-1.txt through Testfile-3.txt. All five fail at the
captured invoke. Parser-source lines are Demo 17, ScopeCheck 16, Testfile-1 18,
Testfile-2 18, and Testfile-3 17. The diagnostic is expected expression boundary,
found identifier followed by the callee name. Markdown heading/fence lines are
excluded from the two documented examples' source line counts.

The assignment-ahead? guard sees the capture arrow and bypasses invoke parsing.
Assignment parsing then treats invoke as an identifier expression and rejects
the following callee identifier. Its expected-assign step is never reached.

In a second run, removed only captured-invoke result suffixes in memory. All
five then parse; ScopeCheck has two captures and the other files one each.
No sample or source files were changed. This applied Prove It Works through
direct execution rather than assuming the guard alone proved the failure.

Testfile-4 and Testfile-5 also contain captured invokes but fail earlier: a
missing declaration semicolon at line 7 and an unterminated string at line 25,
respectively. These were inspected only to distinguish their first failures.

A how explainer independently confirmed that removing the guard is insufficient:
invoke parsing and its AST currently store no capture target, and the shared
semicolon expectation would reject the arrow. Grammar.md's call production
omits capture syntax even though the examples use it. No parser fix was made.

## Follow-up implementation prompt

Treat invoke as a call when it's followed by an identifier and a beginning parenthesis. Then, it can take an optional '=>' identifier. Also Update the invoke test that asserts calls stay standalone

## Follow-up implementation

Created branch `invoke-result-capture`, preserving earlier uncommitted work.
Call recognition now uses the three-token invoke/identifier/left-parenthesis
prefix instead of assignment-ahead?. After actual arguments, parse an optional
assignment arrow and identifier target. Invoke nodes now contain name,
arguments, and target; absent capture is #f. Migrated 19 existing invoke AST
constructor calls in tests to the new arity without compatibility constructors.

Updated the standalone-call test to accept captured calls while retaining
rejection of calls as expression factors. Added prefix-priority coverage,
contextual names, capture target validation, comments, semicolon ownership,
and error lines. Demo, ScopeCheck, and the first three testfiles are permanent
regressions, read and parsed unmodified through the real scanner/parser.
Updated the writable parser design note; no docs/ or sample files changed.

`racket -l raco -- test tests` passes all 144 tests. Racket execution used
approved escalation for the Snap launcher restriction.
`git diff --check` passes. Independent static review found no defects in the
prefix dispatch, optional target parsing, or constructor migrations.
