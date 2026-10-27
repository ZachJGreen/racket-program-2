# Program shell parser

## User prompt

`$pstack:poteto-mode Implement parsing for the program name, opening brace, and closing brace. Connect it to the token stream.`

The user supplied poteto-mode skill instructions in a separate message.

## Grounding and plan

The scanner returns token lists, classifies all words as identifiers, and does
not emit EOF. The grammar starts a program with the word program, an identifier,
and braces around declarations and statements. The requested iteration covers
only that shell. Preserve prior uncommitted scanner work on new branch
`parse-program-shell`.

1. Ground scanner ownership and context rules.
2. Compare local cursor and pure list-threaded parser designs.
3. Delegate the new parser module while independently writing tests and notes.
4. Run the scanner and parser suites and review the new module.

The parser contract and result shape were the blocking decisions. One worker
owns src/parser.rkt; the parent owns tests and notes. Writes are disjoint and
parser cursor state is local to each call. One parser worker is the smallest
safe implementation decomposition.

## Decisions

Export parse-program and transparent program(name). Compose directly with scan;
do not add a source wrapper or change token/scanner APIs. Recognize program by
identifier type and exact lexeme. Permit contextual words as names. Require
both braces, reject nonempty bodies for now, and reject trailing tokens.

Compared two independent designs. Selected a local checked token cursor over
threading remaining lists and last-line values through every expectation.
Syntax errors use offending token lines; EOF uses the last consumed line or1
because no actual EOF position is available from the scanner.

Model the Domain defines the program structure. Laziness Protocol keeps one
parse entry point. Test Behavior, Not Implementation checks scanner integration,
program results, and syntax diagnostics. No changes are made under docs/.

## Verification and revisions

Corrected excess closing parentheses in the new test draft before execution.
`racket -l raco -- test tests/scanner-test.rkt tests/parser-test.rkt` passes all
43 tests. Tests cover scanner composition, direct token lists, contextual names,
comments and line endings, wrong or missing shell components, unsupported body
contents, trailing input, EOF diagnostics, and invalid parser input types.
`git diff --check` passes and docs/ is untouched. Racket used approved escalation
for the Snap launcher restriction.
Independent static review found no concrete bugs or source-comment issues.
