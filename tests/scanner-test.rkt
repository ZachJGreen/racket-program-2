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
    (for ([source '("@" "123" "_name" "a_b" "caf\u00e9" "a+" "--comment")])
      (check-exn #rx"unsupported character .* on line 1"
                 (lambda () (scan source))))
    (check-exn #rx"unsupported character .* on line 3"
               (lambda () (scan "ok\r\n\n@"))))

  (test-case "scan rejects non-string input at its boundary"
    (check-exn exn:fail:contract? (lambda () (scan #f)))))
