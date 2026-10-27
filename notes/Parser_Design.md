# Program and declaration parser

## Usage

```racket
(require "src/scanner.rkt" "src/parser.rkt")
(parse-program (scan "program Demo { decl x, y as int; }"))
; (program "Demo" (list (var-declaration '("x" "y") 'int)))
```

`parse-program` takes the existing scanner token list. It returns a transparent
`program` structure with the program name string and an ordered declarations
list. Each `var-declaration` contains a nonempty ordered list of name strings
and a type symbol, one of `int`, `real`, `bool`, or `string`.

`routine-declaration` contains `name`, `parameters`, `return-type`, and
`declarations`. Each parameter is a `formal-parameter` with a name string and
type symbol. Each routine owns its nested declarations rather than flattening
them into the enclosing program.

## Shape

`src/parser.rkt` owns parsing and all declaration structures.
It imports only `token.rkt`; the caller connects it to `scan`. The scanner and tokens are
unchanged. The parser consumes the entire list in this order.

1. An identifier token with the exact value `program`.
2. Any identifier token as the program name.
3. A `left-brace` token.
4. Zero or more variable declarations.
5. Zero or more routine declarations.
6. A `right-brace` token.

Each declaration matches `decl identifier-list as type ;`. Identifier lists
contain at least one identifier, with commas separating subsequent names.
Types use the four exact lowercase spellings. Both `decl` and `as` are checked
by identifier token type and lexeme. Comments and supported whitespace may
separate any tokens. Names and declarations retain their source order.

Routines match `routine name(parameters) returns type { declarations }`.
Parameters are empty or a comma-separated list of `name:type` pairs; each
parameter requires its own type. Return types use the same four type spellings.
There is no semicolon after a routine's closing brace.

Program and routine blocks share one recursive block parser. Every block parses
variable declarations first and routine declarations second. A variable after
a routine is a syntax error. Nested routines use the same rules at each depth.
For example, `routine Outer(x:int) returns bool { routine Inner() returns int {} }`
produces an Outer node containing an Inner node, without moving either node to
another block.

No tokens may remain after the program's closing brace. Statements and bare
nested blocks are rejected rather than skipped. Empty declaration lists remain valid
for this incremental parser; the complete program grammar is not yet implemented.
Duplicate declarations and name/type semantics are not checked by parsing.

Keyword recognition belongs in the parser. Names such as `program` and `decl`
remain legal because the scanner emits them as identifiers. This also permits
`decl as as int;` and variable names matching the four data type spellings.

Syntax errors include `Syntax error on line N` and an expected-token description.
A mismatching token supplies its line. At unexpected EOF, the parser uses the
last consumed token's line, or 1 if the list is empty. Actual EOF position is
unavailable because the scanner omits EOF tokens and discards trailing comments
and whitespace.

## Synthesis decision

Two independent designs compared a local token cursor with pure list threading.
Both expose `parse-program` and the same result. The local cursor was selected
to keep checked consumption steps readable without threading multiple
return values through each step. State is private to one parse call.

For variable declarations, two independent designs compared grouped declaration
nodes with flattened per-name binding nodes. Grouped `var-declaration` nodes
preserve the grammar's declaration boundaries without repeating the type for
each name. Private identifier-list, type, and declaration parsers reuse the
existing cursor. The `program` constructor now takes both name and declarations;
existing callers are migrated without a compatibility constructor.

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

Model the Domain gives parsed programs a structure. Laziness Protocol keeps one
parsing entry point and no scanner wrapper. Test Behavior, Not Implementation
checks results and errors through direct scanner-to-parser composition.

## Verification

```sh
racket -l raco -- test tests
```
