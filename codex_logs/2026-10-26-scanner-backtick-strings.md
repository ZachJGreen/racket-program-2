# Scanner backtick strings

## User prompt

`$pstack:poteto-mode Add recognition for strings enclosed in backticks.`

The user supplied poteto-mode skill instructions in a separate message.

## Grounding and decisions

The grammar specifies backtick-delimited strings but does not define escapes
or multiline behavior. The existing scanner preserves exact lexeme strings.
Created branch `add-scanner-backtick-strings`, preserving prior uncommitted work.

Asked whether to allow multiline strings or restrict strings to one line.
Stated the default of allowing multiline strings with literal backslashes.
Proceed using that default unless the user redirects it.

Use existing token records with type `string-literal`, full source lexeme
including backticks, and opening line. Empty strings are valid. The next
backtick closes the string. Backslashes have no escape meaning. Whitespace
inside strings is literal data; strict outer whitespace rules remain intact.
Count LF, CR, and CRLF once each. Unterminated strings report their opening line.

## Work plan and design

1. Inspect the scanner and grammar.
2. Compare a local string scan loop with a helper returning end position/line.
3. Add failing public-behavior tests.
4. Delegate the scanner edit while the parent owns tests and design notes.
5. Run tests and independently inspect delimiter and line tracking behavior.

The interface and value convention were the blocking decisions. Both designs
favored the inline loop for its single caller. One worker owns scanner code;
the parent owns independent test expectations and notes. Writes are disjoint,
and scanner state stays local. This is the smallest safe decomposition.

Model the Domain uses local string position/current-line state and the existing
token shape. Laziness Protocol avoids a single-caller helper boundary.
Test Behavior, Not Implementation drives the public scan function.

## Verification and revisions

Before implementation, five of 27 tests failed as expected because backticks
were unsupported and the unterminated-string diagnostic was missing. Tests
cover empty strings, full lexemes, literal contents, backslashes, adjacent
tokens, multiline tracking, and opening-line diagnostics. The docs directory
is read-only and is not changed.

After implementation, `racket -l raco -- test tests/scanner-test.rkt` passes
all 29 tests. `git diff --check` passes and `docs/` remains untouched.
Racket execution used approved escalation for the Snap launcher restriction.
Independent static review found no concrete bugs or source-comment issues.
