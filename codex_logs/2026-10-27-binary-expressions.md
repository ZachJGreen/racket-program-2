# Binary expressions

## User prompt

Add arithmetic, logical, comparison, and concatenation expressions using the grammar's precedence rules.

## Decisions

Created branch `parse-binary-expressions`, preserving the earlier uncommitted
factor work. Follow the grammar's right-recursive term and simple-expression
productions literally. Highest to lowest: factor/not, multiply/divide/and,
plus/minus/or/concat, then at most one comparison. This means subtraction and
division chains group to the right. Stated that interpretation in commentary.

Add binary-expression(operator left right) and explicit factor, term,
simple-expression, and expression parsing functions using the existing cursor.
Keep unary not on factor recursion, but parentheses recurse through a complete
expression. Word operators remain contextual identifier tokens. Scanner,
program/declaration ASTs, and statement scope remain unchanged.

## Work and verification

Updated obsolete tests rejecting addition. Added exact AST tests for every
operator, mixed precedence, same-level grouping, parentheses, comparisons,
literal operands, contextual words, malformed expressions, and source lines.
Updated parser design notes. The docs directory remains untouched.

`racket -l raco -- test tests` passes all 88 tests. `git diff --check` passes.
Racket execution used approved escalation for its Snap launcher restriction.
Independent static review found no concrete bugs in the scoped changes.
