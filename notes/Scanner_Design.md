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

The punctuation table maps characters to token types.

| Characters | Types |
| --- | --- |
| `{` and `}` | `left-brace` and `right-brace` |
| `(` and `)` | `left-paren` and `right-paren` |
| `[` and `]` | `left-bracket` and `right-bracket` |
| `,` | `comma` |
| `:` | `colon` |
| `;` | `semicolon` |

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

Model the Domain places punctuation rules in one table. Laziness Protocol keeps
one public function. Prove It Works and Test Behavior, Not Implementation drive
the public scanner with exact expected records and observable errors.

## Verification

Run from the project root.

```sh
racket -l raco -- test tests/scanner-test.rkt
```
