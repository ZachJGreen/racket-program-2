# Scanner whitespace restriction

## User prompt

`$pstack:poteto-mode Skip only spaces and tabs. Any weird whitespace should throw the unsupported character error. Make tests to reflect that and note it in the scanner design.`

The user also supplied poteto-mode instructions and the current project rules.

## Decisions

Use branch `restrict-scanner-whitespace`. Preserve the existing scanner work
from the prior iteration. Keep LF, CR, and CRLF as explicit line breaks.
Replace general whitespace acceptance with ASCII space and horizontal tab.
The existing token shape, scanner interface, and local state are unchanged.
Delegate the source predicate edit; the parent owns tests and design notes.
No files under `docs/` are changed.

## Verification and revisions

Added public-behavior tests for space and tab separation and rejection of
vertical tab, form feed, next-line, non-breaking space, Ogham space,
em space, Unicode line and paragraph separators, narrow non-breaking space,
and ideographic space. Check errors both at input start and after CRLF.
The new tests initially failed because no exception was raised.
Racket execution and branch creation require sandbox escalation.

After the predicate change, `racket -l raco -- test tests/scanner-test.rkt`
passes all 11 tests. `git diff --check` passes. The `docs/` directory is untouched.
Laziness Protocol kept the fix to the existing whitespace predicate.
Test Behavior, Not Implementation guided public scanner error assertions.
Prove It Works required running the tests before reporting completion.
