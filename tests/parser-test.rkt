#lang racket/base

(require rackunit
         "../src/parser.rkt"
         "../src/scanner.rkt"
         "../src/token.rkt")

(define (parse-source source)
  (parse-program (scan source)))

(module+ test
  (test-case "program shell consumes scanner output and returns its name"
    (check-equal? (parse-source "program Demo {}") (program "Demo" '()))
    (check-equal?
     (parse-program (list (token 'identifier "program" 1)
                          (token 'identifier "Direct" 1)
                          (token 'left-brace "{" 1)
                          (token 'right-brace "}" 1)))
     (program "Direct" '())))

  (test-case "comments and supported line endings connect scanner to parser"
    (check-equal?
     (parse-source "-- header\r\nprogram -- keyword\rName\n{-- body comment\r\n-- another\n}-- EOF")
     (program "Name" '())))

  (test-case "context-sensitive words can be program names"
    (for ([name '("program" "decl" "until" "match")])
      (check-equal? (parse-source (string-append "program " name " {}"))
                    (program name '()))))

  (test-case "program keyword must be the first token and match case"
    (for ([source '("Demo {}" "Program Demo {}" "x program Demo {}")])
      (check-exn #rx"Syntax error on line 1"
                 (lambda () (parse-source source))))
    (check-exn #rx"Syntax error on line 2"
               (lambda () (parse-source "-- comment\nDemo {}"))))

  (test-case "program name must be an identifier"
    (for ([source '("program 123 {}" "program `Demo` {}" "program {}")])
      (check-exn #rx"Syntax error on line 1"
                 (lambda () (parse-source source))))
    (check-exn #rx"Syntax error on line 2"
               (lambda () (parse-source "program\n123 {}"))))

  (test-case "opening and closing braces are required in order"
    (for ([source '("program Demo []" "program Demo }{" "program Demo {{}}"
                    "program Demo {;}")])
      (check-exn #rx"Syntax error on line 1"
                 (lambda () (parse-source source))))
    (check-exn #rx"Syntax error on line 2"
               (lambda () (parse-source "program Demo\n[}")))
    (check-exn #rx"Syntax error on line 3"
               (lambda () (parse-source "program Demo\n{\n]"))))

  (test-case "unexpected EOF uses the last available token line"
    (check-exn #rx"Syntax error on line 1"
               (lambda () (parse-source "")))
    (for ([source '("program" "program Demo" "program Demo {")])
      (check-exn #rx"Syntax error on line 1"
                 (lambda () (parse-source source))))
    (check-exn #rx"Syntax error on line 3"
               (lambda () (parse-source "program\nDemo\n{\n"))))

  (test-case "tokens after the closing brace are rejected"
    (for ([source '("program Demo {} extra" "program Demo {} program Other {}")])
      (check-exn #rx"Syntax error on line 1"
                 (lambda () (parse-source source))))
    (check-exn #rx"Syntax error on line 2"
               (lambda () (parse-source "program Demo {}\n}"))))

  (test-case "a single variable declaration is retained in the program"
    (check-equal? (parse-source "program Demo { decl count as int; }")
                  (program "Demo" (list (var-declaration '("count") 'int)))))

  (test-case "identifier lists and all four types preserve declaration order"
    (check-equal?
     (parse-source "program Demo { decl a,b,c as int; decl r as real; decl flag as bool; decl text as string; }")
     (program "Demo" (list (var-declaration '("a" "b" "c") 'int)
                           (var-declaration '("r") 'real)
                           (var-declaration '("flag") 'bool)
                           (var-declaration '("text") 'string)))))

  (test-case "contextual words and type names remain legal variable names"
    (check-equal?
     (parse-source "program decl { decl decl,as,int,real,bool,string,program as string; }")
     (program "decl"
              (list (var-declaration '("decl" "as" "int" "real" "bool" "string" "program")
                                     'string))))
    (check-equal? (parse-source "program Demo { decl as as int; }")
                  (program "Demo" (list (var-declaration '("as") 'int)))))

  (test-case "comments and line breaks may separate declaration components"
    (check-equal?
     (parse-source "program Demo {\r\ndecl -- names\ra,-- continuation\nb as -- type\r\nint; -- tail\ndecl c as bool;\n}")
     (program "Demo" (list (var-declaration '("a" "b") 'int)
                           (var-declaration '("c") 'bool)))))

  (test-case "identifier lists require names and commas in the right positions"
    (for ([body '("decl as int;" "decl ,x as int;" "decl x, as int;"
                  "decl x,,y as int;" "decl x y as int;" "decl 7 as int;"
                  "decl `x` as int;")])
      (check-exn #rx"Syntax error on line 1"
                 (lambda () (parse-source (string-append "program Demo { " body " }"))))))

  (test-case "declarations require decl as and a semicolon"
    (for ([body '("Decl x as int;" "decl x int;" "decl x: int;"
                  "decl x as int" "decl x as int;;")])
      (check-exn #rx"Syntax error on line 1"
                 (lambda () (parse-source (string-append "program Demo { " body " }"))))))

  (test-case "only the four exact data type spellings are accepted"
    (for ([type '("integer" "boolean" "Int" "Real" "BOOL" "String" "unknown"
                  "1" "`int`")])
      (check-exn #rx"Syntax error on line 1"
                 (lambda ()
                   (parse-source (string-append "program Demo { decl x as " type "; }"))))))

  (test-case "declaration errors retain offending-token and EOF line numbers"
    (check-exn #rx"Syntax error on line 3"
               (lambda () (parse-source "program Demo {\ndecl x as\nunknown;\n}")))
    (check-exn #rx"Syntax error on line 3"
               (lambda () (parse-source "program Demo {\ndecl x as int\n}")))
    (check-exn #rx"Syntax error on line 3"
               (lambda () (parse-source "program Demo {\ndecl x,\n; }")))
    (for ([source '("program Demo {\ndecl" "program Demo {\ndecl x,"
                    "program Demo {\ndecl x as" "program Demo {\ndecl x as int"
                    "program Demo {\ndecl x as int;")])
      (check-exn #rx"Syntax error on line 2"
                 (lambda () (parse-source source)))))

  (test-case "statements and trailing input remain outside this parser"
    (for ([source '("program Demo { decl x as int; 1=>x; }"
                    "program Demo { decl x as int; } extra")])
      (check-exn #rx"Syntax error on line 1"
                 (lambda () (parse-source source)))))

  (test-case "parser boundary requires a list of tokens"
    (check-exn exn:fail:contract? (lambda () (parse-program "program Demo {}")))
    (check-exn exn:fail:contract? (lambda () (parse-program '(program Demo))))))
