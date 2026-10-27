# Routine declarations and nested blocks

## User prompt

`$pstack:poteto-mode Implement routine declarations, parameters, return types, and nested declaration blocks.`

The user supplied poteto-mode skill instructions in a separate message.

## Grounding and plan

The grammar places variables before routines in each declaration block. A
routine has a name, empty or comma-separated typed parameters, returns plus
one of the four types, and a nested declaration block. Unlike variables,
routine declarations have no semicolon terminator. Existing parser ownership
is a local token cursor with line-aware expectations. Preserve earlier
uncommitted work on branch `parse-routine-declarations`.

1. Inspect grammar, context rules, parser, and nesting example.
2. Compare existing mixed lists with a separate declaration-block AST wrapper.
3. Delegate parser changes while independently adding routine integration tests.
4. Update parser design notes and run all scanner/parser tests.
5. Independently review nesting, declaration order, signature syntax, and lines.

The AST and shared block contract were blocking decisions. One worker owns
src/parser.rkt; the parent owns tests and notes. Writes are disjoint and parser
state stays local. One implementation worker is the smallest safe unit.

## Decisions

Retain program(name declarations) and var-declaration. Add routine-declaration
with name, ordered formal parameters, return type, and own declarations. Add
formal-parameter(name type). Use a shared recursive brace/block parser for
programs and routines. Parse variables then routines at every depth.

Model the Domain represents nesting with routine-owned declaration trees.
Laziness Protocol keeps ordered lists rather than adding an AST wrapper.
Test Behavior, Not Implementation checks complete source-to-AST results and
syntax diagnostics. No statement parsing, semantic scope checks, or duplicate
checks are added. Empty declaration-only bodies remain an incremental subset.

## Test revisions

Removed the obsolete assertion that a valid empty routine must be rejected.
Added a dedicated routine test module for return types, formal parameters,
deep nesting and siblings, contextual words, comments, invalid signatures,
block delimiters, declaration ordering, EOF/line diagnostics, and unsupported
statements. The docs directory is untouched.

## Verification

`racket -l raco -- test tests` passes all 63 tests across scanner, general parser,
and routine parser suites. `git diff --check` passes. Tests retain exact AST
expectations across nested and sibling blocks and exercise malformed parameters,
return types, declaration order, braces, and token/EOF line diagnostics.
Racket used approved escalation for the Snap launcher restriction. The worker
also verified that the module loads. No implementation deviations were needed.
Independent static review found no concrete defects or source-comment issues.
