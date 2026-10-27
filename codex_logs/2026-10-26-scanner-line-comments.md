# Scanner line comments

## User prompt

`$pstack:poteto-mode Make the scanner ignore -- comments until the end of the line or file. Ensure tokens have correct line numbers.`

The user supplied poteto-mode skill instructions in a separate message.

## Grounding and plan

The scanner's outer loop already owns CR, LF, and CRLF counting. The nested
string loop owns string contents. Recognize comments only in the outer loop,
before minus operator dispatch. Preserve prior uncommitted work on new branch
`add-scanner-line-comments`.

1. Inspect scanner ownership and existing tests.
2. Compare an inline comment scan with a comment-end helper.
3. Add public-behavior regression tests and observe their failure.
4. Delegate the source edit; the parent owns tests and design notes.
5. Run the full suite and independently review line-number handling.

The blocking decision is to leave comment-ending newlines to existing handling.
One worker owns scanner code; the parent owns independent test expectations and
notes. Writes are disjoint, scanner state stays local, and one source worker
is the smallest safe decomposition.

## Decisions and revisions

Comments start with adjacent minus signs outside strings. Stop scanning their
contents at CR, LF, or EOF, and emit no comment tokens. Comment text may contain
otherwise unsupported characters and backticks. Minus signs separated by spaces
remain operators. Change the previous repeated-minus test accordingly.

Laziness Protocol reuses the existing newline logic instead of duplicating it.
Model the Domain keeps comment cursor state local to the scanner branch.
Test Behavior, Not Implementation checks exact emitted tokens and source lines.

## Verification

Before implementation, the five new comment tests failed as expected. The full
suite had 34 tests. Tests cover EOF, all supported line endings, ignored comment
contents, comment markers in strings, inline and full-line comments, and errors
after a comment. No changes are made under the read-only docs directory.

The two design sketches agreed on preserving outer newline ownership. Chose
the inline comment loop over a single-caller helper to keep the change local.

After implementation, `racket -l raco -- test tests/scanner-test.rkt` passes
all 34 tests. `git diff --check` passes and `docs/` remains untouched. Racket
used approved escalation because its Snap launcher cannot run in the sandbox.
Independent static review found no concrete issues in the scoped addition.
