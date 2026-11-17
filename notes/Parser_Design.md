# Program, declaration, expression, and statement parser

## Usage

```racket
(require "src/scanner.rkt" "src/parser.rkt")
(parse-program (scan "program Demo { decl x, y as int; }"))
; (program "Demo" (list (var-declaration '("x" "y") 'int)) '())
```

`parse-program` takes the existing scanner token list. It returns a transparent
`program` structure with the program name string, ordered declarations, and
ordered statements. Each `var-declaration` contains a nonempty ordered list of name strings
and a type symbol, one of `int`, `real`, `bool`, or `string`.

`routine-declaration` contains `name`, `parameters`, `return-type`, `declarations`,
and `statements`. Each parameter is a `formal-parameter` with a name string and
type symbol. Each routine owns its nested declarations and statements rather
than flattening them into the enclosing program.

## Shape

`src/parser.rkt` owns parsing and all declaration structures.
It imports only `token.rkt`; the caller connects it to `scan`. The scanner and tokens are
unchanged. The parser consumes the entire list in this order.

1. An identifier token with the exact value `program`.
2. Any identifier token as the program name.
3. A `left-brace` token.
4. Zero or more variable declarations.
5. Zero or more routine declarations.
6. Zero or more statements.
7. A `right-brace` token.

Each declaration matches `decl identifier-list as type ;`. Identifier lists
contain at least one identifier, with commas separating subsequent names.
Types use the four exact lowercase spellings. Both `decl` and `as` are checked
by identifier token type and lexeme. Comments and supported whitespace may
separate any tokens. Names and declarations retain their source order.

Routines match `routine name(parameters) returns type { declarations statements }`.
Parameters are empty or a comma-separated list of `name:type` pairs; each
parameter requires its own type. Return types use the same four type spellings.
Routines have no semicolon terminator. A semicolon after a routine's closing
brace is an empty statement in the enclosing block.

Program and routine blocks share one recursive block parser. Every block parses
variable declarations first and routine declarations second. A variable after
a routine is a syntax error. Nested routines use the same rules at each depth.
For example, `routine Outer(x:int) returns bool { routine Inner() returns int {} }`
produces an Outer node containing an Inner node, without moving either node to
another block.

No tokens may remain after the program's closing brace. Bare nested blocks are
rejected rather than skipped.
Empty declaration and statement lists remain valid. The user explicitly chose
to preserve `{}` acceptance even though the grammar's statement list requires
at least one semicolon-terminated statement. The complete grammar is not yet implemented.
Duplicate declarations and name/type semantics are not checked by parsing.

Keyword recognition belongs in the parser. Names such as `program` and `decl`
remain legal because the scanner emits them as identifiers. This also permits
`decl as as int;` and variable names matching the four data type spellings.

Syntax errors include `Syntax error on line N` and an expected-token description.
A mismatching token supplies its line. At unexpected EOF, the parser uses the
last consumed token's line, or 1 if the list is empty. Actual EOF position is
unavailable because the scanner omits EOF tokens and discards trailing comments
and whitespace.

## Statements

The parser recognizes these statement nodes in programs and routines.

| Source | AST |
| --- | --- |
| `expression => name;` | `assignment-statement(expression target)` |
| `yield expression;` | `yield-statement(expression)` |
| `invoke name(arguments);` or `invoke name(arguments) => target;` | `invoke-statement(name arguments target)` |
| `choose [condition] match {...} otherwise {...};` | `choose-statement(condition match-statements otherwise-statements)` |
| `loop until [condition] do {...};` | `loop-statement(condition statements)` |
| `;` | `empty-statement()` |

Assignment targets are identifier strings. Each statement consumes exactly one
terminating semicolon. Every additional standalone semicolon produces another
empty statement. Statements retain source order and follow all declarations;
declarations cannot appear after statements. Expressions reuse the existing
precedence rules and stop before assignment or statement delimiters.

`yield` is contextual. A leading `yield` is a keyword when no assignment token
appears before the next semicolon, brace, or EOF. Otherwise the statement is
parsed as an assignment, allowing `yield=>x;`, `yield+1=>x;`, and
`yield and x=>y;`. Expressions cannot contain assignment, so this bounded
lookahead needs no exception-based backtracking. Strings and comments cannot
confuse it because the scanner already tokenizes strings and removes comments.

Assignment lookahead distinguishes leading `routine` names from declaration
forms, both at block entry and after earlier statements. `routine+1=>y;` is
valid, while actual declarations still must precede statements and variables
precede routines. The specific context rule keeps `decl` as a keyword at a
statement or declaration-block start, so `decl=>x;` is rejected. Other positions
still permit it as a name, for example `1=>decl;`, `yield decl;`, `(decl)=>x;`,
or `1+decl=>x;`.

Yield statements are syntactically accepted at program level as well as within
routines. The parser performs no variable resolution or return-type checks.

Invoke statements accept empty parentheses or a comma-separated list of full
expressions. Arguments preserve source order, literal spelling, and the existing
precedence rules. Each argument is required after a comma; trailing commas and
omitted delimiters are errors. For example, `invoke f();` has no arguments and
`invoke f(x, (a+b)*c);` has two expression arguments.

The callee is any identifier, including a contextual word such as `invoke` or
`yield`. The exact token prefix `invoke`, identifier, left parenthesis selects
call parsing, regardless of a later assignment arrow. Without that prefix,
`invoke` can still be an identifier in assignments such as `invoke=>x;` or
`invoke+1=>x;`. Under this rule `invoke and(x)=>y;` is a captured call to `and`,
while `invoke and x=>y;` remains an ordinary assignment expression.
There is no routine lookup or argument-count/type checking.

After the closing parenthesis, an optional `=> identifier` captures the result.
The invoke node's target is the identifier string, or `#f` when capture is absent.
The shared statement parser still consumes the terminating semicolon. This
explicitly requested extension matches the sample programs' captured calls,
although the read-only grammar document omits that suffix. Existing invoke
constructor callers now supply the third target field.
Calls remain statements rather than expression factors, so neither `f()` nor
`invoke f()` may appear inside an argument expression.

## Control flow

Choose statements require `choose [expression] match {statements}` and may
include `otherwise {statements}` before their terminating semicolon. The AST
stores the condition, ordered match statements, and optional otherwise
statements. An absent otherwise branch is `#f`; an explicitly empty branch is
`'()`. A semicolon between match and otherwise is invalid because it ends the
choose statement before the optional branch.

Loops require `loop until [expression] do {statements};`. The AST stores the
until condition unchanged and the ordered body statements. The parser performs
no evaluation or condition type checking.

Both constructs may nest recursively in program, routine, or control-flow
bodies. Their braces contain statements only; variable and routine declarations
are rejected there. A shared statement-list parser handles these bodies and
the statement portion of program/routine blocks. Empty bodies remain accepted
under the existing empty-block preference.

Each nested statement consumes its own semicolon, and the complete enclosing
choose or loop statement consumes one additional semicolon. Contextual words
are matched only in their header positions. Conditions and body expressions
may use names such as `choose`, `match`, `otherwise`, `loop`, `until`, and `do`.
Leading choose/loop names are still valid assignment expressions when bounded
lookahead finds an assignment before a brace or statement boundary. Body
assignments cannot influence that decision because lookahead stops at braces.

## Expression factors

`parse-expression` accepts a scanner token list and consumes one complete
expression using the grammar's precedence levels.

```racket
(parse-expression (scan "not (maybe)"))
; (unary-expression 'not (literal-expression 'bool-literal "maybe"))
```

Expression nodes are `identifier-expression(name)`, `literal-expression(type value)`,
`unary-expression(operator operand)`, and `binary-expression(operator left right)`.
Literal types are `int-literal`,
`real-literal`, `string-literal`, and `bool-literal`. Values preserve exact
scanner lexemes, including zeros and backtick delimiters. The three boolean
spellings `yes`, `no`, and `maybe` remain distinct strings. They are interpreted
as literals in expression positions, while declaration names remain unrestricted
identifier tokens. Matching is case-sensitive.

Parentheses require one enclosed expression and return its AST without an
extra grouping node. Unary `not` recursively consumes a factor. Its operator
interpretation has priority only when the rest of the expression parses.
Otherwise it is retried as an identifier. Thus `not`, `(not)`, and the operand
in `not not` may name identifiers. `not and x` means identifier `not` combined
with `x` through `and`, while `not and or x` keeps the valid unary interpretation
and means `(not and) or x`. A started but incomplete operand such as `not (`
still raises a syntax error. There is no expression type checking.

Invoke statements are parsed as described above; calls are not expression factors.
Extra tokens after a standalone expression are rejected. Both parsing entry
points share one private engine for token validation, cursor operations,
line-aware errors, and EOF checks. Program and routine bodies integrate the
supported statements with the same expression parser.

From highest to lowest precedence, the grammar defines these levels.

| Level | Operators |
| --- | --- |
| Factor | Parentheses and recursive unary `not` |
| Term | `*`, `/`, `and` |
| Simple expression | `+`, `-`, `or`, `~` |
| Expression | `==`, `/=`, `<`, `<=`, `>`, `>=` |

Term and simple-expression productions recurse on their right operand, so
same-level chains are right associative. For example, `a-b-c` means `a-(b-c)`.
Parentheses override this grouping. Expressions permit at most one comparison
at each unparenthesized level; `a<b<c` is rejected while `(a<b)<c` is syntactically
valid. No operand type checking or evaluation is performed.

Binary AST operators use scanner token symbols for symbolic operators and
`and`/`or` for contextual word operators. `~` uses `concat`. These words remain
identifiers in factor positions. Unary `not` consumes only a factor; a grouped
operand may contain a complete expression.

## Contextual keywords

The scanner returns all word spellings as identifier tokens. Grammar positions
determine their roles; there is no global reserved-word classification or
stateful scanner keyword flag. Every keyword spelling may name a program,
declared variable, routine, formal parameter, callee, or assignment target.

The specific structural positions from the context rules are enforced.

| Word | Keyword position |
| --- | --- |
| `program` | First meaningful token of a program |
| `decl` | Statement or declaration-block start |
| `match` | After the closing choose-condition bracket |
| `until` | Immediately after the loop keyword |
| `do` | After the closing loop-condition bracket |
| `returns` | After routine formal parameters |

Elsewhere these spellings remain ordinary identifier names. Required keyword
positions still reject misspellings and wrong case. Boolean spellings retain
their existing literal preference in expression positions; this parsing step
does not add symbol resolution.

## Synthesis decision

Two independent designs compared a local token cursor with pure list threading.
Both expose `parse-program` and the same result. The local cursor was selected
to keep checked consumption steps readable without threading multiple
return values through each step. State is private to one parse call.

For variable declarations, two independent designs compared grouped declaration
nodes with flattened per-name binding nodes. Grouped `var-declaration` nodes
preserve the grammar's declaration boundaries without repeating the type for
each name. Private identifier-list, type, and declaration parsers reuse the
existing cursor. Declaration grouping remains represented directly in the AST.

For routines, two independent designs compared ordered declaration lists with
a declaration-block wrapper containing separate variable/routine lists. Keep
the existing lists and add recursive routine nodes. The shared block parser
enforces declaration order without changing existing program accessors or
adding a wrapper. Both designs preserve lexical nesting; the selected shape
keeps the public structure smaller.

| Design | Tradeoff |
| --- | --- |
| Local cursor, selected | Local mutation, straightforward checked consumption. |
| List threading | Explicit state flow, additional return values at each step. |

Model the Domain gives parsed programs a structure. Laziness Protocol keeps two
parsing entry points and no scanner wrapper. Test Behavior, Not Implementation
checks results and errors through direct scanner-to-parser composition.

For factors, two independent sketches compared one shared parser engine with
separate expression and cursor modules. Both favored keeping one engine and
two public roots in `parser.rkt`. This preserves one owner for token consumption
and diagnostics without adding a cursor interface between modules.

For statements, two independent sketches compared direct statement fields with
a shared body-wrapper node. Direct fields preserve declaration accessors and
keep statement access simple. The shared block parser returns both ordered
lists. All program and routine constructor callers were migrated to the new
arity without a compatibility constructor.

For invokes, two independent sketches compared a dedicated statement node with
a generic call-expression wrapped as an expression statement. The dedicated node
matches the grammar without broadening expression syntax. Actual-parameter
parsing shares expression consumption, and the existing statement parser keeps
ownership of the terminating semicolon.

For control flow, two independent sketches compared generic tagged control
nodes with dedicated choose and loop nodes. Dedicated nodes express only the
fields each grammar form needs. Statement-list parsing is shared, while the
statements-only brace helper prevents declaration parsing in control bodies.
No scanner or existing AST shape changes are needed.

For contextual `not`, ordered candidate outcomes were compared with expression
continuations. Continuations keep the existing cursor while checking the rest
of the expression before committing to a word's role. A failed unary choice
restores both cursor and last-consumed line before trying the identifier role.
Only private parser syntax failures trigger retry; runtime and contract errors
are not caught as grammar alternatives. If both roles fail, the diagnostic
that reached furthest through the token stream is retained.

## Verification

All parser tests live in `tests/parser-test.rkt`; scanner tests live in
`tests/scanner-test.rkt`. Helpers are shared within each suite. The fixture
tests read the original files from `tests_text/` without modifying them.

| Testfile | Scanner expectation | Parser pipeline expectation |
| --- | --- | --- |
| 1–3 | Complete token stream with original line numbers | Program and captured invoke parse successfully |
| 4 | Complete token stream | Missing declaration semicolon, reported at the next token on line 7 |
| 5 | Unterminated string opened on line 25 | Scanner error propagates before parsing |

Testfile 3's semantic type/argument issues do not prevent syntactic parsing.
Testfile 4 currently lacks its declaration semicolon; the tests record that
grammar error rather than silently repairing the fixture.

```sh
racket -l raco -- test tests
```
