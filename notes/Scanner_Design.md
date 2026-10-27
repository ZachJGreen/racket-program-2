# Scanner design

## Usage

```racket
(require "src/scanner.rkt")
(scan "name(x);")
```

The result is a list of existing `token` records in source order. Each value
is the exact lexeme string. Lines start at 1. There is no EOF token.

## Shape

`src/scanner.rkt` exports `scan`, which accepts a string. Identifiers match
`[A-Za-z][A-Za-z0-9]*`. The user confirmed ASCII letters and digits.
Keyword spellings remain identifiers, consistent with the context rules.
Only ASCII space and horizontal tab are skipped within a line. LF, CR, and
CRLF each advance the line once. Other whitespace, including vertical tab,
form feed, non-breaking space, and Unicode separators, raises the unsupported
character error. Unsupported characters raise an exception containing the
character and line.

Integer literals match `[0-9]+` and use type `int-literal`. Real literals match
`[0-9]+\.[0-9]+` and use type `real-literal`. Their values are exact source
strings, preserving leading and trailing zeros without numeric conversion.
Signs remain operator tokens. A decimal point requires digits on both sides;
`.5`, `1.`, and repeated decimal points raise the unsupported-character error.
Numbers stop before letters, so `123abc` produces an integer and an identifier.
The scanner does not recognize exponent notation as a numeric literal.

Strings begin and end with backticks and use type `string-literal`. Their
values preserve the full source lexeme, including both delimiters. Empty
strings are valid. The next backtick closes the string; backslashes have no
escape meaning. Contents, including Unicode and unusual whitespace, are
literal data. The strict whitespace rules above apply outside strings.

Strings may span lines. LF, CR, and CRLF each advance the line once, preserving
the original contents. A string token records its opening line; subsequent
tokens use the updated line. Reaching EOF before a closing backtick raises
`unterminated string on line N`, where N is the opening line.

Outside strings, `--` begins a comment that is ignored through the end of the
line or file. Comment contents are not tokenized or validated. The comment
scan stops before CR or LF, leaving the existing newline handling to count LF,
CR, and CRLF exactly once. `--` inside a backtick string remains literal text.

The punctuation table maps characters to token types.

| Characters | Types |
| --- | --- |
| `{` and `}` | `left-brace` and `right-brace` |
| `(` and `)` | `left-paren` and `right-paren` |
| `[` and `]` | `left-bracket` and `right-bracket` |
| `,` | `comma` |
| `:` | `colon` |
| `;` | `semicolon` |

Symbolic operators use these token types. Values preserve the source lexeme.

| Operator | Type |
| --- | --- |
| `+` | `plus` |
| `-` | `minus` |
| `*` | `multiply` |
| `/` | `divide` |
| `==` | `equal` |
| `/=` | `not-equal` |
| `<` | `less-than` |
| `<=` | `less-than-or-equal` |
| `>` | `greater-than` |
| `>=` | `greater-than-or-equal` |
| `=>` | `assign` |
| `~` | `concat` |

Two-character operators are matched before single-character tokens. Lookahead
stops at the end of the source and never crosses whitespace or line breaks.
A standalone `=` is unsupported. Repeated `+` characters produce separate
tokens. Minus signs separated by whitespace remain operators; adjacent minus
signs start a comment outside strings. Operator recognition does not validate
expressions or operands.

## Synthesis decision

Two independent candidates compared string indexing and input-port scanning.
An independent cross-judge supported string indexing for direct slicing and
explicit newline handling. All reviewers used the inherited model, so there
was no model diversity. The implementation uses a punctuation table and local
index, line, and output accumulator. The existing token structure is unchanged.

| Alternative | Tradeoff |
| --- | --- |
| String indexing, selected | Direct lexeme slices with explicit newline handling. |
| Input port | Built-in cursor tracking, but requires lexeme buffering for string input. |

For operators, two independent sketches compared a single string-keyed lexeme
table with separate character and two-character tables. The separate tables
preserve existing character dispatch with the smaller change. Both designs
support longest matching; the implementation checks two-character operators
first, then the shared single-character table for punctuation and operators.

For numeric literals, two independent sketches compared a whole/fraction state
machine with a digit-run helper reused for both parts. Both favored the helper
for these two fixed forms. Bounds-checked lookahead decides whether the integer
run continues into a fractional run. The scanner interface and token record
remain unchanged.

For strings, two independent sketches compared an inline local scan loop with
a private helper returning the end position and line. Both favored the local
loop for this single caller. It tracks the position and current line, emits
the full substring at the closing backtick, and resumes the existing scanner.

For comments, two independent sketches compared an inline scan loop with a
helper returning the comment end. The local loop keeps the single-use scan
together. It stops before the line ending and resumes outer scanning without
changing the line number, so existing newline handling remains the sole owner
of line counting after comments.

Model the Domain places punctuation rules in one table. Laziness Protocol keeps
one public function. Prove It Works and Test Behavior, Not Implementation drive
the public scanner with exact expected records and observable errors.

## Verification

Run from the project root.

```sh
racket -l raco -- test tests/scanner-test.rkt
```
