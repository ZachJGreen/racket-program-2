#lang racket/base

(require rackunit
         "../src/scanner.rkt"
         "../src/token.rkt")

(module+ test
  (test-case "empty and whitespace-only input produce no tokens"
    (check-equal? (scan "") '())
    (check-equal? (scan " \t\n\r\n\r") '()))

  (test-case "spaces and tabs separate tokens without changing lines"
    (check-equal? (scan " \talpha\t beta \t")
                  (list (token 'identifier "alpha" 1)
                        (token 'identifier "beta" 1))))

  (test-case "other whitespace raises unsupported character errors"
    (for ([ch '(#\u000B #\u000C #\u0085 #\u00A0 #\u1680
                #\u2003 #\u2028 #\u2029 #\u202F #\u3000)])
      (check-exn #rx"unsupported character .* on line 1"
                 (lambda () (scan (string ch))))
      (check-exn #rx"unsupported character .* on line 2"
                 (lambda () (scan (string-append "alpha\r\n" (string ch) "beta"))))))

  (test-case "identifiers consume ASCII letters and trailing digits"
    (check-equal? (scan "a Z abc123 A0z9 Alpha alpha")
                  (list (token 'identifier "a" 1)
                        (token 'identifier "Z" 1)
                        (token 'identifier "abc123" 1)
                        (token 'identifier "A0z9" 1)
                        (token 'identifier "Alpha" 1)
                        (token 'identifier "alpha" 1))))

  (test-case "every requested punctuation mark works without spaces"
    (check-equal? (scan "{}()[],:;")
                  (list (token 'left-brace "{" 1)
                        (token 'right-brace "}" 1)
                        (token 'left-paren "(" 1)
                        (token 'right-paren ")" 1)
                        (token 'left-bracket "[" 1)
                        (token 'right-bracket "]" 1)
                        (token 'comma "," 1)
                        (token 'colon ":" 1)
                        (token 'semicolon ";" 1))))

  (test-case "identifiers and punctuation preserve source order and lines"
    (check-equal? (scan "Outer(x,y:int){\n\tchoose[match];\n}")
                  (list (token 'identifier "Outer" 1)
                        (token 'left-paren "(" 1)
                        (token 'identifier "x" 1)
                        (token 'comma "," 1)
                        (token 'identifier "y" 1)
                        (token 'colon ":" 1)
                        (token 'identifier "int" 1)
                        (token 'right-paren ")" 1)
                        (token 'left-brace "{" 1)
                        (token 'identifier "choose" 2)
                        (token 'left-bracket "[" 2)
                        (token 'identifier "match" 2)
                        (token 'right-bracket "]" 2)
                        (token 'semicolon ";" 2)
                        (token 'right-brace "}" 3))))

  (test-case "LF CR and CRLF each count as one newline"
    (check-equal? (scan "\n\r\n\rfirst\nsecond\rthird\r\nfourth\n\n;")
                  (list (token 'identifier "first" 4)
                        (token 'identifier "second" 5)
                        (token 'identifier "third" 6)
                        (token 'identifier "fourth" 7)
                        (token 'semicolon ";" 9)))
    (check-equal? (scan "last\r") (list (token 'identifier "last" 1)))
    (check-equal? (scan "\r") '()))

  (test-case "keyword spellings remain identifiers"
    (check-equal? (scan "program decl until match")
                  (list (token 'identifier "program" 1)
                        (token 'identifier "decl" 1)
                        (token 'identifier "until" 1)
                        (token 'identifier "match" 1))))

  (test-case "unsupported characters report their source line"
    (for ([source '("@" "_name" "a_b" "caf\u00e9")])
      (check-exn #rx"unsupported character .* on line 1"
                 (lambda () (scan source))))
    (check-exn #rx"unsupported character .* on line 3"
               (lambda () (scan "ok\r\n\n@"))))

  (test-case "every symbolic operator is recognized at end of input"
    (for ([entry '(("+" plus) ("-" minus) ("*" multiply) ("/" divide)
                   ("==" equal) ("/=" not-equal) ("<" less-than)
                   ("<=" less-than-or-equal) (">" greater-than)
                   (">=" greater-than-or-equal) ("=>" assign) ("~" concat))])
      (check-equal? (scan (car entry))
                    (list (token (cadr entry) (car entry) 1)))))

  (test-case "operators separate identifiers without whitespace"
    (check-equal? (scan "a+b-c*d/e~f=>result;")
                  (list (token 'identifier "a" 1)
                        (token 'plus "+" 1)
                        (token 'identifier "b" 1)
                        (token 'minus "-" 1)
                        (token 'identifier "c" 1)
                        (token 'multiply "*" 1)
                        (token 'identifier "d" 1)
                        (token 'divide "/" 1)
                        (token 'identifier "e" 1)
                        (token 'concat "~" 1)
                        (token 'identifier "f" 1)
                        (token 'assign "=>" 1)
                        (token 'identifier "result" 1)
                        (token 'semicolon ";" 1))))

  (test-case "overlapping operators use the longest matching lexeme"
    (check-equal? (scan "===>/=/<=<>=")
                  (list (token 'equal "==" 1)
                        (token 'assign "=>" 1)
                        (token 'not-equal "/=" 1)
                        (token 'divide "/" 1)
                        (token 'less-than-or-equal "<=" 1)
                        (token 'less-than "<" 1)
                        (token 'greater-than-or-equal ">=" 1))))

  (test-case "operator recognition preserves whitespace and newline boundaries"
    (check-equal? (scan "<\t> /\n=>\r\n~\r+")
                  (list (token 'less-than "<" 1)
                        (token 'greater-than ">" 1)
                        (token 'divide "/" 1)
                        (token 'assign "=>" 2)
                        (token 'concat "~" 3)
                        (token 'plus "+" 4))))

  (test-case "equals must belong to a complete two-character operator"
    (for ([source '("=" "a=" "===" "=>=" "< =" "/\t=" "!=" "<\n=")])
      (check-exn #rx"unsupported character"
                 (lambda () (scan source))))
    (check-exn #rx"unsupported character .* on line 2"
               (lambda () (scan "<\n="))))

  (test-case "plus signs and separated minus signs remain operators"
    (check-equal? (scan "a++b- -c")
                  (list (token 'identifier "a" 1)
                        (token 'plus "+" 1)
                        (token 'plus "+" 1)
                        (token 'identifier "b" 1)
                        (token 'minus "-" 1)
                        (token 'minus "-" 1)
                        (token 'identifier "c" 1))))

  (test-case "integer literals preserve their exact digit strings"
    (check-equal? (scan "0 007 42 123456789012345678901234567890")
                  (list (token 'int-literal "0" 1)
                        (token 'int-literal "007" 1)
                        (token 'int-literal "42" 1)
                        (token 'int-literal "123456789012345678901234567890" 1))))

  (test-case "real literals require and preserve digits on both sides"
    (check-equal? (scan "0.0 00.050 12.34")
                  (list (token 'real-literal "0.0" 1)
                        (token 'real-literal "00.050" 1)
                        (token 'real-literal "12.34" 1))))

  (test-case "numeric signs and adjacent operators remain separate tokens"
    (check-equal? (scan "-12+0.5=>x;")
                  (list (token 'minus "-" 1)
                        (token 'int-literal "12" 1)
                        (token 'plus "+" 1)
                        (token 'real-literal "0.5" 1)
                        (token 'assign "=>" 1)
                        (token 'identifier "x" 1)
                        (token 'semicolon ";" 1)))
    (check-equal? (scan "[1,2.0]<=3")
                  (list (token 'left-bracket "[" 1)
                        (token 'int-literal "1" 1)
                        (token 'comma "," 1)
                        (token 'real-literal "2.0" 1)
                        (token 'right-bracket "]" 1)
                        (token 'less-than-or-equal "<=" 1)
                        (token 'int-literal "3" 1))))

  (test-case "numbers stop at identifier boundaries"
    (check-equal? (scan "abc123 123abc")
                  (list (token 'identifier "abc123" 1)
                        (token 'int-literal "123" 1)
                        (token 'identifier "abc" 1))))

  (test-case "numeric literals preserve line tracking"
    (check-equal? (scan "\n1\r2.0\r\n3")
                  (list (token 'int-literal "1" 2)
                        (token 'real-literal "2.0" 3)
                        (token 'int-literal "3" 4))))

  (test-case "incomplete decimals and non-ASCII digits are unsupported"
    (for ([source '("." ".5" "1." "1..2" "1.2.3" "1. 2" "1.\n2"
                    "\u0661" "\uFF11")])
      (check-exn #rx"unsupported character .* on line 1"
                 (lambda () (scan source))))
    (check-exn #rx"unsupported character .* on line 2"
               (lambda () (scan "ok\n12."))))

  (test-case "backtick strings preserve delimiters and allow empty contents"
    (check-equal? (scan "`hello` ``")
                  (list (token 'string-literal "`hello`" 1)
                        (token 'string-literal "``" 1)))
    (check-equal? (scan "````")
                  (list (token 'string-literal "``" 1)
                        (token 'string-literal "``" 1))))

  (test-case "string contents are literal instead of scanner tokens"
    (check-equal? (scan "`123 + {x} /= @ \"quoted\"`")
                  (list (token 'string-literal "`123 + {x} /= @ \"quoted\"`" 1)))
    (check-equal? (scan "`\u03b1\t\u000B\u000C\u00A0`")
                  (list (token 'string-literal "`\u03b1\t\u000B\u000C\u00A0`" 1))))

  (test-case "strings stop at the next backtick without escape processing"
    (check-equal? (scan "`a\\n\\t`")
                  (list (token 'string-literal "`a\\n\\t`" 1)))
    (check-equal? (scan "`a\\`tail")
                  (list (token 'string-literal "`a\\`" 1)
                        (token 'identifier "tail" 1))))

  (test-case "strings compose with concatenation assignment and numbers"
    (check-equal? (scan "`x`~`y`=>result;")
                  (list (token 'string-literal "`x`" 1)
                        (token 'concat "~" 1)
                        (token 'string-literal "`y`" 1)
                        (token 'assign "=>" 1)
                        (token 'identifier "result" 1)
                        (token 'semicolon ";" 1)))
    (check-equal? (scan "prefix`x`123")
                  (list (token 'identifier "prefix" 1)
                        (token 'string-literal "`x`" 1)
                        (token 'int-literal "123" 1))))

  (test-case "unterminated strings report the opening line"
    (for ([source '("`" "`open")])
      (check-exn #rx"unterminated string.*line 1"
                 (lambda () (scan source))))
    (check-exn #rx"unterminated string.*line 2"
               (lambda () (scan "before\r\n`open")))
    (check-exn #rx"unterminated string.*line 2"
               (lambda () (scan "before\n`open\r\nmore\n"))))

  (test-case "multiline strings preserve contents and track following tokens"
    (check-equal? (scan "\n`a\nb\rc\r\nd` next\n42")
                  (list (token 'string-literal "`a\nb\rc\r\nd`" 2)
                        (token 'identifier "next" 5)
                        (token 'int-literal "42" 6)))
    (check-equal? (scan "`\r\n`;")
                  (list (token 'string-literal "`\r\n`" 1)
                        (token 'semicolon ";" 2))))

  (test-case "invalid characters after a closed string use the current line"
    (check-exn #rx"unsupported character .* on line 2"
               (lambda () (scan "`a\nb`@")))
    (check-exn #rx"unsupported character .* on line 1"
               (lambda () (scan "`x`\u00A0"))))

  (test-case "comments are ignored through end of file"
    (check-equal? (scan "--") '())
    (check-equal? (scan "-- comment at EOF") '())
    (check-equal? (scan "name-- comment at EOF")
                  (list (token 'identifier "name" 1))))

  (test-case "comments leave LF CR and CRLF counting to the scanner"
    (for ([newline '("\n" "\r" "\r\n")])
      (check-equal?
       (scan (string-append "before-- first" newline "-- second" newline "after"))
       (list (token 'identifier "before" 1)
             (token 'identifier "after" 3)))))

  (test-case "comment contents are ignored without lexical validation"
    (check-equal? (scan "x-- `unclosed @ \u000B\u00A0\u2028hidden\ny")
                  (list (token 'identifier "x" 1)
                        (token 'identifier "y" 2))))

  (test-case "comment markers inside strings are preserved"
    (check-equal? (scan "`-- text`-- ignored\nnext")
                  (list (token 'string-literal "`-- text`" 1)
                        (token 'identifier "next" 2)))
    (check-equal? (scan "`a\n-- b`-- ignored\r\nnext")
                  (list (token 'string-literal "`a\n-- b`" 1)
                        (token 'identifier "next" 3))))

  (test-case "tokens around comments keep their source lines"
    (check-equal? (scan "\n42;-- tail\r\n\n-- full line\r`ok`-1")
                  (list (token 'int-literal "42" 2)
                        (token 'semicolon ";" 2)
                        (token 'string-literal "`ok`" 5)
                        (token 'minus "-" 5)
                        (token 'int-literal "1" 5)))
    (check-exn #rx"unsupported character .* on line 2"
               (lambda () (scan "-- ignored\r\n@"))))

  (test-case "scan rejects non-string input at its boundary"
    (check-exn exn:fail:contract? (lambda () (scan #f)))))
