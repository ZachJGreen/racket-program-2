# Test consolidation and testfile coverage

## User prompt

`$pstack:poteto-mode combine all of the parser tests together and all the scanner tests together. Also, add tests for the testfiles as well.`

The user supplied poteto-mode skill instructions in a separate message.

## Plan and decisions

Created branch `consolidate-test-suites`, preserving prior uncommitted work.
The existing suite passed all 144 cases before the move.

1. Inspect test helpers and classify cases by scanner/parser ownership.
2. Script a source-preserving consolidation with a case-equivalence check.
3. Run the two merged suites before removing seven redundant files.
4. Add explicit scanner and parser-pipeline expectations for all five testfiles.
5. Run all tests and independently review coverage and fixture outcomes.

The target is exactly two test modules with shared local helpers, rather than
an aggregator retaining the old files. The scanner-only keyword case moves out
of the contextual parser module. A syntax reader extracts each case, changing
only expression helper call names where necessary. The migration backs up all
original files and compares the normalized syntax-datum multiset before and
after. It preserved all 144 original forms: 109 parser cases and 35 scanner cases.
The merged pair then passed all 144 tests before fixture edits and file removal.

Model the Domain groups suites by the scanner/parser boundary. Laziness Protocol
shares repeated helper definitions and removes old modules. Test Behavior,
Not Implementation checks token boundaries, AST results, and actual fixture
diagnostics without changing parser/scanner production code.

The blocking work was the baseline and case-preservation check. The parent
owns the deterministic migration; a read-only fixture audit runs independently.
There are no parallel writers. This is the smallest safe decomposition.

## Fixture expectations

Testfiles 1–3 scan and parse. Assert program names, captured invoke targets, and
argument order, including the intentionally swapped arguments in Testfile 3.
Scanner tests also pin first and last token line numbers. Testfile 4 scans but
has a missing declaration semicolon, reported at routine on line 7. Testfile 5
ends inside a string opened on line 25; assert the scanner error in both scanner
and full-pipeline checks. The fixtures and read-only docs directory stay unchanged.
Demo and ScopeCheck coverage remains in the parser suite without duplicating
the first three testfiles' dedicated cases.

## Failures and revisions

Closed completed agents after encountering the agent limit. The Snap launcher
could not see the host /tmp migration script; ran it through stdin instead.
The migration script is at /tmp/consolidate-racket-tests.rkt in the host, and
original test backups are in Snap's private temporary directory reported by it.
The production modules were not edited in this iteration.

## Verification

After adding five fixture cases per suite, `racket -l raco -- test tests` passes
all 154 tests. Exactly parser-test.rkt and scanner-test.rkt remain under tests/.
`git diff --check` passes. No docs/ or tests_text/ changes. Racket used approved
escalation for the Snap launcher restriction.
Independent static review found no concrete bugs or coverage loss in the merged
suites or fixture assertions.
