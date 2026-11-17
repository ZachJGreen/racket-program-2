# Assignment, yield, and empty statements

## User prompt

`$pstack:poteto-mode Implement assignment statements, yield statements, and empty statements.`

The user supplied poteto-mode skill instructions in a separate message.

## Clarification

Asked whether to keep existing empty-block acceptance or enforce the grammar's
nonempty statement-list production. The user answered "Keep accepting empty blocks".
Preserve `{}` with an empty statement list; each explicit semicolon is an
empty-statement node.

## Grounding and plan

The grammar defines expression => identifier, yield expression, and an empty
statement, each terminated by the statement-list semicolon. The parser already
shares expression and declaration parsing through a local cursor. Preserve
earlier uncommitted work on branch `parse-basic-statements`.

1. Compare direct statement fields with a body-wrapper AST.
2. Delegate the parser source while independently migrating callers and tests.
3. Update parser design notes and run every test suite.
4. Independently review semicolons, block ownership, contextual yield, and lines.

AST shape and body grammar were the blocking decisions. One worker owns
src/parser.rkt; the parent owns tests, constructor migrations, and notes. Writes
are disjoint and parser state stays local. One source worker is the smallest
safe decomposition.

## Implementation decisions

Add statement lists to program and routine-declaration. Add assignment-statement
with expression/target, yield-statement with expression, and empty-statement.
Keep variables then routines then statements in each shared block parser. Return
both body lists to the program/routine constructors. No compatibility constructors.

A structural source scanner migrated 26 existing constructor calls, skipping
strings and quoted token data. Removed obsolete rejection tests for newly
supported statements and clarified that a semicolon after a routine is an empty
statement of the enclosing block.

Leading yield uses bounded token lookahead for assignment before semicolon,
brace, or EOF. Expressions cannot contain assignment, so this distinguishes
contextual yield names without exception backtracking. Reuse expression grammar
and line errors. Root-level yield is accepted syntactically; variable resolution,
return-type checking, control flow, and calls remain outside scope.

Model the Domain uses explicit statement variants. Laziness Protocol reuses
existing expression parsing and shared blocks. Test Behavior, Not Implementation
checks exact statement trees and observable syntax diagnostics.

## Failures and revisions

Closing a stale reviewer ID from the previous task failed because it no longer
existed; proceeded with fresh reviewers. The first full test run found an extra
closing parenthesis in the new statement test fixture. Corrected it and reran
the entire suite.

## Verification

`racket -l raco -- test tests` passes all 101 tests. New tests cover precedence,
yield, empty statements, ordering, nested block ownership, semicolon boundaries,
contextual names, comments and strings, invalid statement forms, and error lines.
Racket used approved escalation for the Snap launcher restriction. No files
under the read-only docs directory were changed.

## Review revision

Independent review found that declaration dispatch still treated leading decl
and routine names as reserved words, rejecting otherwise valid assignments.
Added initial/subsequent-position cases in programs and routines; the targeted
statement suite reproduced two failures out of 15 cases. A fresh source worker
applies the existing bounded assignment lookahead to both declaration loops and
the late-declaration guard. This preserves declaration ordering while permitting
contextual assignment source names.

After that fix, `racket -l raco -- test tests` passes all 103 tests.
`git diff --check` passes and docs/ is untouched.
Fresh independent static review found no concrete bugs in the revised dispatch.
