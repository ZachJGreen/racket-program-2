# Expression factors

## User prompt

`$pstack:poteto-mode Implement parsing for identifiers, literals, parentheses, and the not operator.`

The user supplied poteto-mode skill instructions in a separate message.

## Grounding and plan

The grammar defines identifier, numeric/boolean/string literal, parenthesized,
and recursive not factors. The scanner classifies words as identifiers and
preserves literal lexemes. The parser already owns local cursor and diagnostics.
The worktree was clean on parse-declarations; created parse-expression-factors.

1. Inspect factor grammar, context rules, and parser ownership.
2. Compare one shared parser engine with separate expression/cursor modules.
3. Delegate source changes while independently adding expression tests.
4. Update design notes and run all tests.
5. Independently review context handling, recursion, and diagnostics.

The AST and entry point were blocking decisions. One worker owns parser.rkt;
the parent owns tests and notes. Writes are disjoint; parser state stays local.
One worker is the smallest safe implementation decomposition.

## Clarification and decisions

Asked whether bare not should remain an identifier under contextual rules or
require an operand. Stated the default of treating it as an identifier unless
a factor-start follows. Boolean words become literals in expression positions.
Proceed with that default unless the user redirects it.

Add parse-expression as a complete-token-list entry point. Preserve parse-program
through one private shared engine. Add identifier-expression(name),
literal-expression(type value), unary-expression(operator operand). Literals
retain raw strings; bool-literal values preserve yes/no/maybe. Parentheses
return their inner AST. Do not add binary operators or statement parsing.

Model the Domain uses explicit expression variants. Laziness Protocol keeps
cursor and diagnostic ownership in one file. Test Behavior, Not Implementation
checks scanner-to-expression ASTs and observable syntax errors.

## Revisions

An initial note patch used a nonexistent context line and failed atomically;
reapplied against the actual section headings. Corrected an extra parenthesis
in the test draft before execution. No files under docs/ are changed.

## Verification

`racket -l raco -- test tests` passes all 76 tests. This includes previous
scanner/declaration/routine coverage and new expression AST, contextual words,
literal spellings, grouping, recursive not, full-input consumption, invalid
factors, line/EOF errors, and public input validation. `git diff --check` passes.
Racket used approved escalation for the Snap launcher restriction.
Independent static review found no concrete issues or source-comment findings.
