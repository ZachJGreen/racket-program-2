#lang racket/base

(require rackunit
         "../src/parser.rkt"
         "../src/scanner.rkt")

(define (parse-source source)
  (parse-program (scan source)))

(module+ test
  (test-case "empty routines accept each return type and preserve sibling order"
    (check-equal?
     (parse-source "program P { routine a() returns int {} routine b() returns real {} routine c() returns bool {} routine d() returns string {} }")
     (program "P" (list (routine-declaration "a" '() 'int '())
                        (routine-declaration "b" '() 'real '())
                        (routine-declaration "c" '() 'bool '())
                        (routine-declaration "d" '() 'string '())))))

  (test-case "formal parameters retain names types and order"
    (check-equal?
     (parse-source "program P { routine f(a:int,b:real,c:bool,d:string) returns int {} }")
     (program "P"
              (list (routine-declaration
                     "f" (list (formal-parameter "a" 'int)
                               (formal-parameter "b" 'real)
                               (formal-parameter "c" 'bool)
                               (formal-parameter "d" 'string))
                     'int '())))))

  (test-case "nested routine and variable declarations stay in their own blocks"
    (check-equal?
     (parse-source "program P { decl global as int; routine Outer(p:int) returns real { decl x,y as bool; routine Inner() returns string { decl local as real; routine Leaf() returns int {} } } routine Sibling() returns bool {} }")
     (program "P"
              (list
               (var-declaration '("global") 'int)
               (routine-declaration
                "Outer" (list (formal-parameter "p" 'int)) 'real
                (list (var-declaration '("x" "y") 'bool)
                      (routine-declaration
                       "Inner" '() 'string
                       (list (var-declaration '("local") 'real)
                             (routine-declaration "Leaf" '() 'int '())))))
               (routine-declaration "Sibling" '() 'bool '())))))

  (test-case "context words and type spellings remain legal routine and parameter names"
    (check-equal?
     (parse-source "program routine { routine routine(returns:int,decl:real,as:bool,string:string) returns string { decl routine as int; } }")
     (program "routine"
              (list (routine-declaration
                     "routine" (list (formal-parameter "returns" 'int)
                                     (formal-parameter "decl" 'real)
                                     (formal-parameter "as" 'bool)
                                     (formal-parameter "string" 'string))
                     'string (list (var-declaration '("routine") 'int)))))))

  (test-case "comments and line endings may separate signature and block tokens"
    (check-equal?
     (parse-source "program P { routine -- name\r\nf( -- parameters\na:-- type\rint) -- signature\nreturns -- type\r\nbool { -- body\ndecl x as int; -- end\r\n} }")
     (program "P"
              (list (routine-declaration
                     "f" (list (formal-parameter "a" 'int)) 'bool
                     (list (var-declaration '("x") 'int)))))))

  (test-case "formal parameters require parentheses names colons types and commas"
    (for ([routine '("routine f returns int {}"
                     "routine () returns int {}"
                     "routine 7() returns int {}"
                     "routine f(a int) returns int {}"
                     "routine f(:int) returns int {}"
                     "routine f(7:int) returns int {}"
                     "routine f(a:integer) returns int {}"
                     "routine f(a:Int) returns int {}"
                     "routine f(a:1) returns int {}"
                     "routine f(a:int,) returns int {}"
                     "routine f(,a:int) returns int {}"
                     "routine f(a,b:int) returns int {}"
                     "routine f(a:int b:bool) returns int {}"
                     "routine f(a:int,,b:bool) returns int {}"
                     "routine f(a:int returns int {}")])
      (check-exn #rx"Syntax error on line 1"
                 (lambda () (parse-source (string-append "program P { " routine " }"))))))

  (test-case "routine headers require exact keywords and valid return types"
    (for ([routine '("Routine f() returns int {}"
                     "routine f() int {}"
                     "routine f() Returns int {}"
                     "routine f() returns {}"
                     "routine f() returns integer {}"
                     "routine f() returns Int {}"
                     "routine f() returns 1 {}"
                     "routine f() returns `int` {}")])
      (check-exn #rx"Syntax error on line 1"
                 (lambda () (parse-source (string-append "program P { " routine " }"))))))

  (test-case "routine blocks require braces and have no semicolon terminator"
    (for ([source '("program P { routine f() returns int [] }"
                    "program P { routine f() returns int {} ; }"
                    "program P { routine f() returns int { ] }"
                    "program P { routine f() returns int { {} } }")])
      (check-exn #rx"Syntax error on line 1"
                 (lambda () (parse-source source)))))

  (test-case "variables must precede routines in every declaration block"
    (for ([source '("program P { routine f() returns int {} decl x as int; }"
                    "program P { routine f() returns int { routine g() returns int {} decl x as int; } }")])
      (check-exn #rx"Syntax error on line 1"
                 (lambda () (parse-source source)))))

  (test-case "routine errors use offending token lines and the existing EOF convention"
    (check-exn #rx"Syntax error on line 3"
               (lambda () (parse-source "program P {\nroutine f(a:\nunknown) returns int {} }")))
    (check-exn #rx"Syntax error on line 3"
               (lambda () (parse-source "program P {\nroutine f() returns\nunknown {} }")))
    (check-exn #rx"Syntax error on line 4"
               (lambda () (parse-source "program P {\nroutine f() returns int {\ndecl x as int;\n] }")))
    (for ([source '("program P {\nroutine" "program P {\nroutine f("
                    "program P {\nroutine f(a:" "program P {\nroutine f(a:int,"
                    "program P {\nroutine f() returns" "program P {\nroutine f() returns int"
                    "program P {\nroutine f() returns int {"
                    "program P {\nroutine f() returns int {}")])
      (check-exn #rx"Syntax error on line 2"
                 (lambda () (parse-source source)))))

  (test-case "statements inside routines remain outside the declaration parser"
    (for ([source '("program P { routine f() returns int { yield 1; } }"
                    "program P { routine f() returns int { decl x as int; 1=>x; } }")])
      (check-exn #rx"Syntax error on line 1"
                 (lambda () (parse-source source))))))
