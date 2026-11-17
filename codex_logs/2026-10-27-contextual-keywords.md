# Contextual keywords

## User prompt

`$pstack:poteto-mode Make keywords behave as identifiers when the context rules allow it.`

The user supplied poteto-mode skill instructions in a separate message.

## Grounding and plan

The scanner already emits all words as identifier tokens. Most grammar-specific
keyword positions are already implemented in the parser. Audit confirmed match,
until, do, returns, and program behavior. Existing one-token not lookahead
rejects valid expressions such as not and x and not or x. It must preserve valid
operator interpretations such as not and or x while permitting identifier fallback.
Create branch `contextual-keywords`, preserving earlier uncommitted work.

1. Audit documented contexts and reproduce actual failures.
2. Compare expression continuations with ordered candidate outcomes.
3. Delegate the parser fix while independently adding contextual-role tests.
4. Update design notes and run the full suite.
5. Independently review syntax choices and line-error preservation.

Expression choice and the explicit decl exception were the blocking decisions.
One worker owns parser.rkt; the parent owns tests and notes. Writes are disjoint
and parsing state remains local. One source worker is the smallest safe unit.

## Decisions

Follow the specific context rule that decl remains a keyword at statement and
declaration-block starts. Earlier broad assignment demotion contradicted that
rule. Reject decl=>x and leading decl+1=>x, but keep targets, parameters, yield
operands, parenthesized factors, and later operands named decl valid. Migrate
the old tests to allowed positions. Leave routine demotion intact.

Prefer unary not only when its expression continuation succeeds; otherwise
retry that word as an identifier. Use expression-local continuations, narrow
private syntax failures, and cursor checkpoints. Never catch arbitrary runtime
or contract exceptions as grammar alternatives. Preserve the furthest syntax
diagnostic when both alternatives fail. No scanner/AST changes, keyword
blacklist, symbol table, or boolean-literal policy changes.

Model the Domain keeps explicit syntax alternatives. Laziness Protocol keeps
the shared parser and existing grammar/AST. Test Behavior, Not Implementation
uses complete ASTs, all spelling/name positions, documented contexts, and errors.

## Failures and revisions

Probes reproduced not and x, not or x, not and or, and not not and x failures.
The first regression fixture had extra closing parentheses; corrected them.
The corrected targeted suite reproduced three failing cases, including the
line diagnostic after an unsuccessful keyword interpretation. No docs/ edits.

## Verification

`racket -l raco -- test tests` passes all 140 tests after adding regressions for
allowed decl positions and mixed not roles in one expression. The first full
run passed 138 tests; the final run includes both additional cases. Checks cover
all 23 spelling/name positions, documented header roles, structural decl rules,
operator-priority fallback, nested expression boundaries, and source lines.
`git diff --check` passes; docs/ is untouched. Racket used approved escalation
for the Snap launcher restriction; the worker's unprivileged launch was blocked.
Independent static review found no concrete correctness bugs. It suggested
pinning expected-token wording as additional diagnostic coverage; retained
line-based assertions because the documented error contract requires source
lines rather than exact message wording.
