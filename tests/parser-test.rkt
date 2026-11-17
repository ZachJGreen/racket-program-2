#lang racket/base

(require rackunit
         racket/file
         racket/list
         racket/runtime-path
         "../src/parser.rkt"
         "../src/scanner.rkt"
         "../src/token.rkt")

(define (parse-source source)
  (parse-program (scan source)))

(define (parse-expression-source source)
  (parse-expression (scan source)))

(define (parse-body body)
  (parse-source (string-append "program P { " body " }")))

(define (parse-statements body)
  (program-statements (parse-body body)))

(define-runtime-path project-root "..")

(define one (literal-expression 'int-literal "1"))
(define a (identifier-expression "a"))
(define b (identifier-expression "b"))
(define c (identifier-expression "c"))
(define d (identifier-expression "d"))

(define words
  '("program" "decl" "as" "int" "real" "bool" "string" "routine" "returns"
    "choose" "match" "otherwise" "loop" "until" "do" "invoke" "yield"
    "not" "and" "or" "yes" "no" "maybe"))

(module+ test
  (test-case "program shell consumes scanner output and returns its name"
    (check-equal? (parse-source "program Demo {}") (program "Demo" '() '()))
    (check-equal?
     (parse-program (list (token 'identifier "program" 1)
                          (token 'identifier "Direct" 1)
                          (token 'left-brace "{" 1)
                          (token 'right-brace "}" 1)))
     (program "Direct" '() '())))

  (test-case "comments and supported line endings connect scanner to parser"
    (check-equal?
     (parse-source "-- header\r\nprogram -- keyword\rName\n{-- body comment\r\n-- another\n}-- EOF")
     (program "Name" '() '())))

  (test-case "context-sensitive words can be program names"
    (for ([name '("program" "decl" "until" "match")])
      (check-equal? (parse-source (string-append "program " name " {}"))
                    (program name '() '()))))

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
    (for ([source '("program Demo []" "program Demo }{" "program Demo {{}}")])
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
                  (program "Demo" (list (var-declaration '("count") 'int)) '())))

  (test-case "identifier lists and all four types preserve declaration order"
    (check-equal?
     (parse-source "program Demo { decl a,b,c as int; decl r as real; decl flag as bool; decl text as string; }")
     (program "Demo" (list (var-declaration '("a" "b" "c") 'int)
                           (var-declaration '("r") 'real)
                           (var-declaration '("flag") 'bool)
                           (var-declaration '("text") 'string)) '())))

  (test-case "contextual words and type names remain legal variable names"
    (check-equal?
     (parse-source "program decl { decl decl,as,int,real,bool,string,program as string; }")
     (program "decl"
              (list (var-declaration '("decl" "as" "int" "real" "bool" "string" "program")
                                     'string)) '()))
    (check-equal? (parse-source "program Demo { decl as as int; }")
                  (program "Demo" (list (var-declaration '("as") 'int)) '())))

  (test-case "comments and line breaks may separate declaration components"
    (check-equal?
     (parse-source "program Demo {\r\ndecl -- names\ra,-- continuation\nb as -- type\r\nint; -- tail\ndecl c as bool;\n}")
     (program "Demo" (list (var-declaration '("a" "b") 'int)
                           (var-declaration '("c") 'bool)) '())))

  (test-case "identifier lists require names and commas in the right positions"
    (for ([body '("decl as int;" "decl ,x as int;" "decl x, as int;"
                  "decl x,,y as int;" "decl x y as int;" "decl 7 as int;"
                  "decl `x` as int;")])
      (check-exn #rx"Syntax error on line 1"
                 (lambda () (parse-source (string-append "program Demo { " body " }"))))))

  (test-case "declarations require decl as and a semicolon"
    (for ([body '("Decl x as int;" "decl x int;" "decl x: int;"
                  "decl x as int")])
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

  (test-case "trailing input remains outside the program"
    (for ([source '("program Demo { decl x as int; } extra")])
      (check-exn #rx"Syntax error on line 1"
                 (lambda () (parse-source source)))))

  (test-case "parser boundary requires a list of tokens"
    (check-exn exn:fail:contract? (lambda () (parse-program "program Demo {}")))
    (check-exn exn:fail:contract? (lambda () (parse-program '(program Demo)))))

  (test-case "empty routines accept each return type and preserve sibling order"
    (check-equal?
     (parse-source "program P { routine a() returns int {} routine b() returns real {} routine c() returns bool {} routine d() returns string {} }")
     (program "P" (list (routine-declaration "a" '() 'int '() '())
                        (routine-declaration "b" '() 'real '() '())
                        (routine-declaration "c" '() 'bool '() '())
                        (routine-declaration "d" '() 'string '() '())) '())))

  (test-case "formal parameters retain names types and order"
    (check-equal?
     (parse-source "program P { routine f(a:int,b:real,c:bool,d:string) returns int {} }")
     (program "P"
              (list (routine-declaration
                     "f" (list (formal-parameter "a" 'int)
                               (formal-parameter "b" 'real)
                               (formal-parameter "c" 'bool)
                               (formal-parameter "d" 'string))
                     'int '() '())) '())))

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
                             (routine-declaration "Leaf" '() 'int '() '())) '())) '())
               (routine-declaration "Sibling" '() 'bool '() '())) '())))

  (test-case "context words and type spellings remain legal routine and parameter names"
    (check-equal?
     (parse-source "program routine { routine routine(returns:int,decl:real,as:bool,string:string) returns string { decl routine as int; } }")
     (program "routine"
              (list (routine-declaration
                     "routine" (list (formal-parameter "returns" 'int)
                                     (formal-parameter "decl" 'real)
                                     (formal-parameter "as" 'bool)
                                     (formal-parameter "string" 'string))
                     'string (list (var-declaration '("routine") 'int)) '())) '())))

  (test-case "comments and line endings may separate signature and block tokens"
    (check-equal?
     (parse-source "program P { routine -- name\r\nf( -- parameters\na:-- type\rint) -- signature\nreturns -- type\r\nbool { -- body\ndecl x as int; -- end\r\n} }")
     (program "P"
              (list (routine-declaration
                     "f" (list (formal-parameter "a" 'int)) 'bool
                     (list (var-declaration '("x") 'int)) '())) '())))

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

  (test-case "routine blocks require braces"
    (for ([source '("program P { routine f() returns int [] }"
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

  (test-case "bare calls and blocks inside routines are rejected"
    (for ([source '("program P { routine f() returns int { f(); } }"
                    "program P { routine f() returns int { {;} } }")])
      (check-exn #rx"Syntax error on line 1"
                 (lambda () (parse-source source)))))

  (test-case "identifier factors preserve names and contextual words"
    (for ([name '("x" "abc123" "program" "decl" "match" "returns" "Yes" "notable")])
      (check-equal? (parse-expression-source name) (identifier-expression name)))
    (check-equal? (parse-expression (list (token 'identifier "direct" 7)))
                  (identifier-expression "direct")))

  (test-case "integer real and string literals preserve token lexemes"
    (check-equal? (parse-expression-source "007") (literal-expression 'int-literal "007"))
    (check-equal? (parse-expression-source "00.050") (literal-expression 'real-literal "00.050"))
    (check-equal? (parse-expression-source "`hello`")
                  (literal-expression 'string-literal "`hello`"))
    (check-equal? (parse-expression-source "``") (literal-expression 'string-literal "``")))

  (test-case "all three boolean literals are distinct"
    (for ([value '("yes" "no" "maybe")])
      (check-equal? (parse-expression-source value) (literal-expression 'bool-literal value))))

  (test-case "parentheses group factors without adding AST nodes"
    (check-equal? (parse-expression-source "(((x)))") (identifier-expression "x"))
    (check-equal? (parse-expression-source "(12.30)") (literal-expression 'real-literal "12.30"))
    (check-equal? (parse-expression-source "(`-- literal`)")
                  (literal-expression 'string-literal "`-- literal`")))

  (test-case "not recursively wraps factors and grouped expressions"
    (check-equal? (parse-expression-source "not x")
                  (unary-expression 'not (identifier-expression "x")))
    (check-equal? (parse-expression-source "not not (maybe)")
                  (unary-expression 'not
                                    (unary-expression 'not
                                                      (literal-expression 'bool-literal "maybe"))))
    (check-equal? (parse-expression-source "(not (not no))")
                  (unary-expression 'not
                                    (unary-expression 'not
                                                      (literal-expression 'bool-literal "no")))))

  (test-case "bare not follows the contextual identifier rule"
    (check-equal? (parse-expression-source "not") (identifier-expression "not"))
    (check-equal? (parse-expression-source "(not)") (identifier-expression "not"))
    (check-equal? (parse-expression-source "not not")
                  (unary-expression 'not (identifier-expression "not")))
    (check-equal? (parse-expression-source "not 0")
                  (unary-expression 'not (literal-expression 'int-literal "0"))))

  (test-case "boolean and not spellings remain valid declaration names"
    (check-equal?
     (parse-program (scan "program not { decl not,yes,no,maybe as bool; }"))
     (program "not" (list (var-declaration '("not" "yes" "no" "maybe") 'bool)) '())))

  (test-case "comments and supported line breaks separate expression tokens"
    (check-equal? (parse-expression-source "-- header\r\nnot-- operand\r(\nmaybe\r\n)-- EOF")
                  (unary-expression 'not (literal-expression 'bool-literal "maybe"))))

  (test-case "missing factors and parentheses report syntax errors"
    (for ([source '("" "()" "(" "(x" "not (" "(not x" ")" "+" "-1")])
      (check-exn #rx"Syntax error on line 1"
                 (lambda () (parse-expression-source source)))))

  (test-case "standalone expression parsing rejects unconsumed tokens"
    (for ([source '("x y" "yes no" "x)" "1;" "f()" "not x y")])
      (check-exn #rx"Syntax error on line 1"
                 (lambda () (parse-expression-source source)))))

  (test-case "expression errors use token and last-available EOF lines"
    (check-exn #rx"Syntax error on line 3"
               (lambda () (parse-expression-source "(\nx\n]")))
    (check-exn #rx"Syntax error on line 2"
               (lambda () (parse-expression-source "(\n12\n")))
    (check-exn #rx"Syntax error on line 3"
               (lambda () (parse-expression-source "not\n(\n;"))))

  (test-case "expression boundary accepts only token lists"
    (check-exn exn:fail:contract? (lambda () (parse-expression "x")))
    (check-exn exn:fail:contract? (lambda () (parse-expression '(x)))))

  (test-case "bare expressions do not form statements"
    (check-exn #rx"Syntax error on line 1"
               (lambda () (parse-program (scan "program P { not yes; }")))))

  (test-case "every binary operator produces its canonical AST operator"
    (for ([entry '(("+" plus) ("-" minus) ("*" multiply) ("/" divide)
                   ("and" and) ("or" or) ("~" concat) ("==" equal)
                   ("/=" not-equal) ("<" less-than) ("<=" less-than-or-equal)
                   (">" greater-than) (">=" greater-than-or-equal))])
      (check-equal? (parse-expression-source (string-append "a " (car entry) " b"))
                    (binary-expression (cadr entry) a b))))

  (test-case "multiplication and division bind above addition and subtraction"
    (check-equal? (parse-expression-source "a+b*c")
                  (binary-expression 'plus a (binary-expression 'multiply b c)))
    (check-equal? (parse-expression-source "a/b-c")
                  (binary-expression 'minus (binary-expression 'divide a b) c)))

  (test-case "not consumes a factor rather than the whole expression"
    (check-equal? (parse-expression-source "not a and b")
                  (binary-expression 'and (unary-expression 'not a) b))
    (check-equal? (parse-expression-source "not (a and b)")
                  (unary-expression 'not (binary-expression 'and a b))))

  (test-case "logical operators occupy the grammar's arithmetic levels"
    (check-equal? (parse-expression-source "a or b and c")
                  (binary-expression 'or a (binary-expression 'and b c)))
    (check-equal? (parse-expression-source "a*b and c")
                  (binary-expression 'multiply a (binary-expression 'and b c)))
    (check-equal? (parse-expression-source "a and b*c")
                  (binary-expression 'and a (binary-expression 'multiply b c))))

  (test-case "concatenation shares the addition and or level"
    (check-equal? (parse-expression-source "a~b+c")
                  (binary-expression 'concat a (binary-expression 'plus b c)))
    (check-equal? (parse-expression-source "a+b~c")
                  (binary-expression 'plus a (binary-expression 'concat b c)))
    (check-equal? (parse-expression-source "a~b or c")
                  (binary-expression 'concat a (binary-expression 'or b c))))

  (test-case "comparisons bind below both simple expression operands"
    (check-equal? (parse-expression-source "a+b<c*d")
                  (binary-expression 'less-than
                                     (binary-expression 'plus a b)
                                     (binary-expression 'multiply c d)))
    (check-equal? (parse-expression-source "a or b == c and d")
                  (binary-expression 'equal
                                     (binary-expression 'or a b)
                                     (binary-expression 'and c d))))

  (test-case "right-recursive grammar makes same-level chains right associative"
    (check-equal? (parse-expression-source "a-b-c")
                  (binary-expression 'minus a (binary-expression 'minus b c)))
    (check-equal? (parse-expression-source "a/b/c")
                  (binary-expression 'divide a (binary-expression 'divide b c)))
    (check-equal? (parse-expression-source "a or b or c")
                  (binary-expression 'or a (binary-expression 'or b c))))

  (test-case "parentheses override precedence and permit grouped comparisons"
    (check-equal? (parse-expression-source "(a-b)-c")
                  (binary-expression 'minus (binary-expression 'minus a b) c))
    (check-equal? (parse-expression-source "a*(b+c)")
                  (binary-expression 'multiply a (binary-expression 'plus b c)))
    (check-equal? (parse-expression-source "(a<b)==(c>=d)")
                  (binary-expression 'equal
                                     (binary-expression 'less-than a b)
                                     (binary-expression 'greater-than-or-equal c d))))

  (test-case "literal operands preserve their existing representation"
    (check-equal? (parse-expression-source "yes or no and maybe")
                  (binary-expression 'or
                                     (literal-expression 'bool-literal "yes")
                                     (binary-expression 'and
                                                        (literal-expression 'bool-literal "no")
                                                        (literal-expression 'bool-literal "maybe"))))
    (check-equal? (parse-expression-source "`a`~`b`")
                  (binary-expression 'concat
                                     (literal-expression 'string-literal "`a`")
                                     (literal-expression 'string-literal "`b`"))))

  (test-case "logical word operators remain contextual and case sensitive"
    (check-equal? (parse-expression-source "and + or")
                  (binary-expression 'plus (identifier-expression "and")
                                     (identifier-expression "or")))
    (check-equal? (parse-expression-source "not + a")
                  (binary-expression 'plus (identifier-expression "not") a))
    (for ([source '("a AND b" "a OR b" "a andb")])
      (check-exn #rx"Syntax error on line 1" (lambda () (parse-expression-source source)))))

  (test-case "incomplete expressions chains and assignment are rejected"
    (for ([source '("a +" "a and" "a ==" "a~" "a + * b" "a or b and"
                    "a<b<c" "a==b==c" "a=>b")])
      (check-exn #rx"Syntax error on line 1" (lambda () (parse-expression-source source)))))

  (test-case "comments and errors retain scanner token lines"
    (check-equal? (parse-expression-source "a + -- ignored\r\nb *\rc")
                  (binary-expression 'plus a (binary-expression 'multiply b c)))
    (for ([source '("a +\n* b" "a\n+\n" "a<b\n<c")])
      (check-exn #rx"Syntax error on line 2" (lambda () (parse-expression-source source)))))

  (test-case "keyword spellings name programs variables routines parameters and targets"
    (for ([word words])
      (check-equal?
       (parse-source (string-append "program " word " { decl " word " as int; routine "
                                    word "(" word ":int) returns int { 1=>" word
                                    "; } invoke " word "(); }"))
       (program word
                (list (var-declaration (list word) 'int)
                      (routine-declaration word (list (formal-parameter word 'int)) 'int '()
                                           (list (assignment-statement
                                                  (literal-expression 'int-literal "1") word))))
                (list (invoke-statement word '() #f))))))

  (test-case "nonliteral keywords can start assignment expressions"
    (for ([word words] #:unless (member word '("yes" "no" "maybe" "decl")))
      (check-equal?
       (program-statements (parse-source (string-append "program P { " word "+1=>x; }")))
       (list (assignment-statement
              (binary-expression 'plus (identifier-expression word)
                                 (literal-expression 'int-literal "1")) "x")))))

  (test-case "match has a keyword role only after the choose condition"
    (check-equal?
     (program-statements
      (parse-source "program P { decl match as bool; yes=>match; choose [match] match {no=>match;}; }"))
     (list (assignment-statement (literal-expression 'bool-literal "yes") "match")
           (choose-statement (identifier-expression "match")
                              (list (assignment-statement (literal-expression 'bool-literal "no")
                                                          "match")) #f))))

  (test-case "until and do retain ordinary names inside loop expressions"
    (check-equal?
     (program-statements
      (parse-source "program P { decl until,do as int; loop until [until<do] do {until+1=>until;}; }"))
     (list (loop-statement
            (binary-expression 'less-than (identifier-expression "until") (identifier-expression "do"))
            (list (assignment-statement
                   (binary-expression 'plus (identifier-expression "until")
                                      (literal-expression 'int-literal "1")) "until"))))))

  (test-case "not falls back to an identifier when its keyword interpretation cannot parse"
    (check-equal? (parse-expression-source "not and x")
                  (binary-expression 'and (identifier-expression "not") (identifier-expression "x")))
    (check-equal? (parse-expression-source "not or x")
                  (binary-expression 'or (identifier-expression "not") (identifier-expression "x")))
    (check-equal? (parse-expression-source "not and or")
                  (binary-expression 'and (identifier-expression "not") (identifier-expression "or")))
    (check-equal? (parse-expression-source "not not and x")
                  (binary-expression 'and (unary-expression 'not (identifier-expression "not"))
                                     (identifier-expression "x"))))

  (test-case "decl retains its keyword role at statement and declaration-block start"
    (for ([source '("program P { decl=>x; }" "program P { ; decl+1=>x; }"
                    "program P { routine f() returns int { decl=>x; } }"
                    "program P { choose [yes] match { decl=>x; }; }")])
      (check-exn #rx"Syntax error on line 1" (lambda () (parse-source source)))))

  (test-case "decl is still a normal name outside statement-start positions"
    (check-equal?
     (program-statements
      (parse-source "program P { decl decl as int; 5=>decl; yield decl; (decl)=>x; 1+decl=>x; }"))
     (list (assignment-statement (literal-expression 'int-literal "5") "decl")
           (yield-statement (identifier-expression "decl"))
           (assignment-statement (identifier-expression "decl") "x")
           (assignment-statement (binary-expression 'plus (literal-expression 'int-literal "1")
                                                    (identifier-expression "decl")) "x"))))

  (test-case "valid not operator interpretations keep priority over identifier alternatives"
    (check-equal? (parse-expression-source "not and or x")
                  (binary-expression 'or (unary-expression 'not (identifier-expression "and"))
                                     (identifier-expression "x")))
    (check-equal? (parse-expression-source "not or and x")
                  (binary-expression 'and (unary-expression 'not (identifier-expression "or"))
                                     (identifier-expression "x")))
    (check-equal? (parse-expression-source "not and")
                  (unary-expression 'not (identifier-expression "and"))))

  (test-case "contextual expression choices work at nested and statement boundaries"
    (check-equal?
     (program-statements
      (parse-source "program P { invoke f((not and x),not and or); choose [not or x] match {yield not and x;}; }"))
     (list
      (invoke-statement "f"
                         (list (binary-expression 'and (identifier-expression "not")
                                                  (identifier-expression "x"))
                               (binary-expression 'and (identifier-expression "not")
                                                  (identifier-expression "or"))) #f)
      (choose-statement
       (binary-expression 'or (identifier-expression "not") (identifier-expression "x"))
       (list (yield-statement (binary-expression 'and (identifier-expression "not")
                                                (identifier-expression "x")))) #f))))

  (test-case "separate not occurrences may choose different roles in one expression"
    (check-equal?
     (parse-expression-source "not and x or not and or y")
     (binary-expression
      'or
      (binary-expression 'and (identifier-expression "not") (identifier-expression "x"))
      (binary-expression 'or (unary-expression 'not (identifier-expression "and"))
                         (identifier-expression "y")))))

  (test-case "required keyword positions and case sensitivity remain strict"
    (for ([source '("Program P {}" "program P { loop do [yes] do {}; }"
                    "program P { choose [yes] otherwise {}; }"
                    "program P { routine f() int {} }"
                    "program P { decl x int; }")])
      (check-exn #rx"Syntax error on line 1" (lambda () (parse-source source)))))

  (test-case "failed keyword alternatives retain syntax error source lines"
    (check-exn #rx"Syntax error on line 3"
               (lambda () (parse-expression-source "not and\nx\n]")))
    (check-exn #rx"Syntax error on line 2"
               (lambda () (parse-expression-source "not and\n(x")))
    (check-exn #rx"Syntax error on line 2"
               (lambda () (parse-expression-source "not and\n*"))))

  (test-case "assignment statements retain expression precedence and target names"
    (check-equal?
     (program-statements (parse-body "a+2*3=>x;"))
     (list (assignment-statement
            (binary-expression 'plus (identifier-expression "a")
                               (binary-expression 'multiply
                                                  (literal-expression 'int-literal "2")
                                                  (literal-expression 'int-literal "3")))
            "x"))))

  (test-case "yield statements reuse the expression parser"
    (check-equal?
     (program-statements (parse-body "yield not (yes or no);"))
     (list (yield-statement
            (unary-expression 'not
                              (binary-expression 'or
                                                 (literal-expression 'bool-literal "yes")
                                                 (literal-expression 'bool-literal "no")))))))

  (test-case "each standalone semicolon produces one empty statement"
    (check-equal? (program-statements (parse-body ";;;"))
                  (list (empty-statement) (empty-statement) (empty-statement)))
    (check-equal? (parse-body "") (program "P" '() '())))

  (test-case "mixed statements preserve source order"
    (check-equal?
     (program-statements (parse-body "1=>x; yield x; ; 2=>y;"))
     (list (assignment-statement one "x")
           (yield-statement (identifier-expression "x"))
           (empty-statement)
           (assignment-statement (literal-expression 'int-literal "2") "y"))))

  (test-case "nested routines and the program retain their own statements"
    (check-equal?
     (parse-source "program P { decl global as int; routine Outer(x:int) returns int { decl local as int; routine Inner() returns int { yield 1; } x=>local; yield local; } 2=>global; }")
     (program
      "P"
      (list (var-declaration '("global") 'int)
            (routine-declaration
             "Outer" (list (formal-parameter "x" 'int)) 'int
             (list (var-declaration '("local") 'int)
                   (routine-declaration "Inner" '() 'int '() (list (yield-statement one))))
             (list (assignment-statement (identifier-expression "x") "local")
                   (yield-statement (identifier-expression "local")))))
      (list (assignment-statement (literal-expression 'int-literal "2") "global")))))

  (test-case "semicolons after declarations belong to the enclosing block"
    (check-equal? (parse-body "routine f() returns int {} ;")
                  (program "P" (list (routine-declaration "f" '() 'int '() '()))
                           (list (empty-statement))))
    (check-equal? (parse-body "decl x as int;;;")
                  (program "P" (list (var-declaration '("x") 'int))
                           (list (empty-statement) (empty-statement)))))

  (test-case "yield remains contextual in assignment expressions and targets"
    (check-equal?
     (program-statements (parse-body "yield=>x; yield+1=>y; yield and x=>z; 1=>yield; yield yield;"))
     (list (assignment-statement (identifier-expression "yield") "x")
           (assignment-statement (binary-expression 'plus (identifier-expression "yield") one) "y")
           (assignment-statement (binary-expression 'and (identifier-expression "yield")
                                                    (identifier-expression "x")) "z")
           (assignment-statement one "yield")
           (yield-statement (identifier-expression "yield")))))

  (test-case "assignment targets may use contextual words and boolean spellings"
    (check-equal?
     (program-statements (parse-body "1=>decl; 1=>yes; 1=>and;"))
     (list (assignment-statement one "decl")
           (assignment-statement one "yes")
           (assignment-statement one "and"))))

  (test-case "decl is an identifier outside statement-start keyword positions"
    (check-equal?
     (program-statements (parse-body "(decl)=>x; routine+1=>y;"))
     (list (assignment-statement (identifier-expression "decl") "x")
           (assignment-statement (binary-expression 'plus (identifier-expression "routine") one) "y")))
    (check-equal?
     (program-statements (parse-body "routine=>x; (decl)+1=>y;"))
     (list (assignment-statement (identifier-expression "routine") "x")
           (assignment-statement (binary-expression 'plus (identifier-expression "decl") one) "y"))))

  (test-case "contextual declaration words may start assignments in routine bodies"
    (for ([names '(("decl" "routine") ("routine" "decl"))])
      (define parsed
        (parse-body (string-append "routine f() returns int { (" (car names)
                                   ")=>x; ; (" (cadr names) ")+1=>y; }")))
      (check-equal?
       (routine-declaration-statements (car (program-declarations parsed)))
       (list (assignment-statement (identifier-expression (car names)) "x")
             (empty-statement)
             (assignment-statement
              (binary-expression 'plus (identifier-expression (cadr names)) one) "y")))))

  (test-case "comments and string contents cannot split or reclassify statements"
    (check-equal?
     (program-statements (parse-body "`a=>b;yield`-- ignored\r\n=>text; yield -- expression\n `=>;{}`;"))
     (list (assignment-statement (literal-expression 'string-literal "`a=>b;yield`") "text")
           (yield-statement (literal-expression 'string-literal "`=>;{}`")))))

  (test-case "assignment yield and semicolon requirements are enforced"
    (for ([body '("=>x;" "1=>;" "1=>2;" "1=>x" "yield;" "yield 1" "yield +;"
                  "x;" "1;" "yield 1=>x;" "1=>x=>y;" "1=>x y;")])
      (check-exn #rx"Syntax error on line 1" (lambda () (parse-body body)))))

  (test-case "declarations cannot follow statements"
    (for ([body '("; decl x as int;" "1=>x; routine f() returns int {}"
                  "routine f() returns int { yield 1; decl x as int; }")])
      (check-exn #rx"Syntax error on line 1" (lambda () (parse-body body)))))

  (test-case "statement diagnostics retain offending token and EOF lines"
    (for ([body '("1=>\n2;" "yield\n;" "1=>x\n")])
      (check-exn #rx"Syntax error on line 2" (lambda () (parse-body body))))
    (for ([source '("program P {\n1=>x;" "program P {\nyield" "program P {\n1=>")])
      (check-exn #rx"Syntax error on line 2" (lambda () (parse-source source))))
    (check-exn #rx"Syntax error on line 3"
               (lambda () (parse-source "program P {\nyield (\n1"))))

  (test-case "bare blocks are not standalone statements"
    (for ([body '("{;}" "{};")])
      (check-exn #rx"Syntax error on line 1" (lambda () (parse-body body)))))

  (test-case "invoke accepts empty and single-argument lists"
    (check-equal? (program-statements (parse-body "invoke f();"))
                  (list (invoke-statement "f" '() #f)))
    (check-equal? (program-statements (parse-body "invoke f(x);"))
                  (list (invoke-statement "f" (list (identifier-expression "x")) #f))))

  (test-case "actual arguments preserve order and literal lexemes"
    (check-equal?
     (program-statements (parse-body "invoke f(x,007,1.20,maybe,`a,b`);"))
     (list (invoke-statement "f"
                             (list (identifier-expression "x")
                                   (literal-expression 'int-literal "007")
                                   (literal-expression 'real-literal "1.20")
                                   (literal-expression 'bool-literal "maybe")
                                   (literal-expression 'string-literal "`a,b`")) #f))))

  (test-case "arguments use full expression precedence and grouping"
    (check-equal?
     (program-statements (parse-body "invoke f(a+b*c,(a+b)*c,not yes,x<y);"))
     (list (invoke-statement
            "f"
            (list (binary-expression 'plus (identifier-expression "a")
                                     (binary-expression 'multiply (identifier-expression "b")
                                                        (identifier-expression "c")))
                  (binary-expression 'multiply
                                     (binary-expression 'plus (identifier-expression "a")
                                                        (identifier-expression "b"))
                                     (identifier-expression "c"))
                  (unary-expression 'not (literal-expression 'bool-literal "yes"))
                  (binary-expression 'less-than (identifier-expression "x")
                                     (identifier-expression "y"))) #f))))

  (test-case "nested routines retain invokes in their own statement lists"
    (check-equal?
     (parse-source "program P { routine Outer() returns int { routine Inner() returns int { invoke Inner(); } invoke Inner(1); } invoke Outer(); }")
     (program
      "P"
      (list (routine-declaration
             "Outer" '() 'int
             (list (routine-declaration "Inner" '() 'int '()
                                        (list (invoke-statement "Inner" '() #f))))
             (list (invoke-statement "Inner" (list (literal-expression 'int-literal "1")) #f))))
      (list (invoke-statement "Outer" '() #f)))))

  (test-case "invoke is contextual in callee names and assignments"
    (check-equal?
     (program-statements (parse-body "invoke invoke(); invoke yield(not); invoke=>x; invoke+1=>y; invoke and x=>z; 1=>invoke;"))
     (list (invoke-statement "invoke" '() #f)
           (invoke-statement "yield" (list (identifier-expression "not")) #f)
           (assignment-statement (identifier-expression "invoke") "x")
           (assignment-statement (binary-expression 'plus (identifier-expression "invoke")
                                                    (literal-expression 'int-literal "1")) "y")
           (assignment-statement (binary-expression 'and (identifier-expression "invoke")
                                                    (identifier-expression "x")) "z")
           (assignment-statement (literal-expression 'int-literal "1") "invoke"))))

  (test-case "comments and literal punctuation do not alter argument boundaries"
    (check-equal?
     (program-statements (parse-body "invoke-- keyword\nf(-- args\r\nx,-- comma\ry); invoke f(`=>;{}`,invoke);"))
     (list (invoke-statement "f" (list (identifier-expression "x") (identifier-expression "y")) #f)
           (invoke-statement "f" (list (literal-expression 'string-literal "`=>;{}`")
                                       (identifier-expression "invoke")) #f))))

  (test-case "invoke consumes exactly one statement semicolon"
    (check-equal?
     (program-statements (parse-body "invoke f(); 1=>x; yield x; ; invoke g(x);"))
     (list (invoke-statement "f" '() #f)
           (assignment-statement (literal-expression 'int-literal "1") "x")
           (yield-statement (identifier-expression "x"))
           (empty-statement)
           (invoke-statement "g" (list (identifier-expression "x")) #f))))

  (test-case "invoke requires a name parentheses comma-separated expressions and semicolon"
    (for ([body '("invoke;" "invoke ();" "invoke 7();" "invoke f;" "invoke f(;"
                  "invoke f(,x);" "invoke f(x,);" "invoke f(x,,y);" "invoke f(x y);"
                  "invoke f(x:int);" "invoke f([]);" "invoke f()" "Invoke f();")])
      (check-exn #rx"Syntax error on line 1" (lambda () (parse-body body)))))

  (test-case "calls may capture results while remaining statements"
    (check-equal?
     (program-statements (parse-body "invoke f()=>x; invoke g(1,a+b)=>yield;"))
     (list (invoke-statement "f" '() "x")
           (invoke-statement "g"
                             (list (literal-expression 'int-literal "1")
                                   (binary-expression 'plus (identifier-expression "a")
                                                      (identifier-expression "b")))
                             "yield")))
    (for ([body '("f();" "invoke f(g());" "invoke f(invoke g());" "yield invoke f();")])
      (check-exn #rx"Syntax error on line 1" (lambda () (parse-body body)))))

  (test-case "invoke identifier parenthesis prefix selects calls before assignment fallback"
    (check-equal?
     (program-statements (parse-body "invoke and(x)=>y; invoke and x=>z; invoke=>target;"))
     (list (invoke-statement "and" (list (identifier-expression "x")) "y")
           (assignment-statement (binary-expression 'and (identifier-expression "invoke")
                                                    (identifier-expression "x")) "z")
           (assignment-statement (identifier-expression "invoke") "target"))))

  (test-case "capture accepts comments and consumes only the shared statement semicolon"
    (check-equal?
     (program-statements (parse-body "invoke -- callee\nf(1)-- target\r\n=>-- name\rx;;"))
     (list (invoke-statement "f" (list (literal-expression 'int-literal "1")) "x")
           (empty-statement))))

  (test-case "capture requires an identifier target and a terminating semicolon"
    (for ([body '("invoke f()=>;" "invoke f()=>1;" "invoke f()=>`x`;"
                  "invoke f()=>x" "invoke f()=>x=>y;" "invoke f()=>x,y;")])
      (check-exn #rx"Syntax error on line 1" (lambda () (parse-body body))))
    (check-exn #rx"Syntax error on line 2"
               (lambda () (parse-source "program P { invoke f()=>\n1; }")))
    (check-exn #rx"Syntax error on line 2"
               (lambda () (parse-source "program P {\ninvoke f()=>"))))

  (test-case "Demo and ScopeCheck parse without modification"
    (for ([path '("docs/Demo.md" "docs/ScopeCheck.md")])
      (define raw (file->string (build-path project-root path)))
      (define block (regexp-match #px"(?s:```text\r?\n(.*?)\r?\n```)" raw))
      (check-true (program? (parse-source (if block (cadr block) raw))) path)))

  (for ([fixture '(("Testfile-1.txt" "CustomDemo" ("score" "x"))
                   ("Testfile-2.txt" "KeywordAsVariable" ("score" "x"))
                   ("Testfile-3.txt" "Comparison" ("x" "score")))])
    (test-case (string-append (car fixture) " parses with its captured invoke")
      (define parsed
        (parse-source (file->string (build-path project-root "tests_text" (car fixture)))))
      (check-equal? (program-name parsed) (cadr fixture))
      (define loop-node (findf loop-statement? (program-statements parsed)))
      (check-equal? (car (loop-statement-statements loop-node))
                    (invoke-statement "calculateBonus"
                                      (map identifier-expression (caddr fixture)) "score"))))

  (test-case "Testfile-4 reports its missing declaration semicolon"
    (check-exn #rx"Syntax error on line 7: expected semicolon"
               (lambda ()
                 (parse-source (file->string (build-path project-root "tests_text" "Testfile-4.txt"))))))

  (test-case "Testfile-5 fails scanning before parsing its incomplete program"
    (check-exn #rx"scan: unterminated string on line 25"
               (lambda ()
                 (parse-source (file->string (build-path project-root "tests_text" "Testfile-5.txt"))))))

  (test-case "invoke diagnostics preserve offending-token and EOF lines"
    (check-exn #rx"Syntax error on line 3"
               (lambda () (parse-source "program P {\ninvoke\n7(); }")))
    (check-exn #rx"Syntax error on line 3"
               (lambda () (parse-source "program P { invoke f(\nx,\n); }")))
    (check-exn #rx"Syntax error on line 3"
               (lambda () (parse-source "program P {\ninvoke f()\n}")))
    (for ([source '("program P {\ninvoke" "program P {\ninvoke f("
                    "program P {\ninvoke f(x," "program P {\ninvoke f(x)"
                    "program P {\ninvoke f();")])
      (check-exn #rx"Syntax error on line 2" (lambda () (parse-source source)))))

  (test-case "choose without otherwise retains its condition and match statements"
    (check-equal?
     (parse-statements "choose [flag] match {1=>x;};")
     (list (choose-statement (identifier-expression "flag")
                              (list (assignment-statement one "x")) #f))))

  (test-case "otherwise is optional and an empty branch is distinct from absence"
    (check-equal?
     (parse-statements "choose [yes] match {yield 1;} otherwise {;};")
     (list (choose-statement (literal-expression 'bool-literal "yes")
                              (list (yield-statement one)) (list (empty-statement)))))
    (check-equal? (parse-statements "choose [yes] match {};")
                  (list (choose-statement (literal-expression 'bool-literal "yes") '() #f)))
    (check-equal? (parse-statements "choose [yes] match {} otherwise {};")
                  (list (choose-statement (literal-expression 'bool-literal "yes") '() '()))))

  (test-case "loop retains its until condition without negation"
    (check-equal?
     (parse-statements "loop until [x>=10] do {x+1=>x;};")
     (list (loop-statement
            (binary-expression 'greater-than-or-equal (identifier-expression "x")
                               (literal-expression 'int-literal "10"))
            (list (assignment-statement
                   (binary-expression 'plus (identifier-expression "x") one) "x")))))
    (check-equal? (parse-statements "loop until [maybe] do {};")
                  (list (loop-statement (literal-expression 'bool-literal "maybe") '()))))

  (test-case "conditions use full expression precedence"
    (check-equal?
     (parse-statements "choose [a+b*c<d or e] match {;};")
     (list (choose-statement
            (binary-expression
             'less-than
             (binary-expression 'plus (identifier-expression "a")
                                (binary-expression 'multiply (identifier-expression "b")
                                                   (identifier-expression "c")))
             (binary-expression 'or (identifier-expression "d") (identifier-expression "e")))
            (list (empty-statement)) #f)))
    (check-equal?
     (parse-statements "loop until [not x and y] do {;};")
     (list (loop-statement
            (binary-expression 'and (unary-expression 'not (identifier-expression "x"))
                               (identifier-expression "y"))
            (list (empty-statement))))))

  (test-case "nested controls keep their bodies otherwise branches and following statements"
    (check-equal?
     (parse-statements "choose [outer] match {loop until [done] do {choose [inner] match {invoke f();} otherwise {yield 1;};};} otherwise {invoke g();}; 2=>x;")
     (list
      (choose-statement
       (identifier-expression "outer")
       (list (loop-statement
              (identifier-expression "done")
              (list (choose-statement
                     (identifier-expression "inner")
                     (list (invoke-statement "f" '() #f))
                     (list (yield-statement one))))))
       (list (invoke-statement "g" '() #f)))
      (assignment-statement (literal-expression 'int-literal "2") "x"))))

  (test-case "routine bodies share control-flow parsing"
    (check-equal?
     (parse-source "program P { routine f() returns int { loop until [maybe] do {yield 1;}; choose [x] match {;}; } invoke f(); }")
     (program "P"
              (list (routine-declaration
                     "f" '() 'int '()
                     (list (loop-statement (literal-expression 'bool-literal "maybe")
                                           (list (yield-statement one)))
                           (choose-statement (identifier-expression "x")
                                             (list (empty-statement)) #f))))
              (list (invoke-statement "f" '() #f)))))

  (test-case "all control words remain contextual assignment names"
    (for ([name '("choose" "match" "otherwise" "loop" "until" "do")])
      (check-equal? (parse-statements (string-append name "=>x;"))
                    (list (assignment-statement (identifier-expression name) "x"))))
    (check-equal?
     (parse-statements "choose+1=>x; loop and x=>y;")
     (list (assignment-statement (binary-expression 'plus (identifier-expression "choose") one) "x")
           (assignment-statement (binary-expression 'and (identifier-expression "loop")
                                                    (identifier-expression "x")) "y"))))

  (test-case "header conditions and body statements may use control word identifiers"
    (check-equal?
     (parse-statements "choose [choose==match] match {yes=>choose; otherwise=>match;}; loop until [until<do] do {loop=>until; do=>otherwise;};")
     (list
      (choose-statement
       (binary-expression 'equal (identifier-expression "choose") (identifier-expression "match"))
       (list (assignment-statement (literal-expression 'bool-literal "yes") "choose")
             (assignment-statement (identifier-expression "otherwise") "match")) #f)
      (loop-statement
       (binary-expression 'less-than (identifier-expression "until") (identifier-expression "do"))
       (list (assignment-statement (identifier-expression "loop") "until")
             (assignment-statement (identifier-expression "do") "otherwise"))))))

  (test-case "otherwise after a completed statement is an ordinary identifier"
    (check-equal?
     (parse-statements "choose [x] match {}; otherwise=>x;")
     (list (choose-statement (identifier-expression "x") '() #f)
           (assignment-statement (identifier-expression "otherwise") "x"))))

  (test-case "comments and strings do not interfere with control syntax"
    (check-equal?
     (parse-statements "choose-- keyword\r\n[-- condition\nflag]-- header\rmatch {invoke f(`loop until [x] do {;};`);} otherwise {;};")
     (list (choose-statement
            (identifier-expression "flag")
            (list (invoke-statement "f"
                                     (list (literal-expression 'string-literal "`loop until [x] do {;};`")) #f))
            (list (empty-statement))))))

  (test-case "choose requires exact keywords delimiters and statement semicolons"
    (for ([body '("choose yes match {;};" "choose [] match {;};"
                  "choose [yes match {;};" "choose [yes] {;};" "choose [yes] Match {;};"
                  "choose [yes] match [;];" "choose [yes] match {;}"
                  "choose [yes] match {yield 1};" "choose [yes] match {;}; otherwise {;};"
                  "choose [yes] match {;} otherwise;" "choose [yes] match {;} otherwise {;}"
                  "choose [yes] match {;} Otherwise {;};"
                  "choose [yes] match {;} otherwise {;} otherwise {;};")])
      (check-exn #rx"Syntax error on line 1" (lambda () (parse-statements body)))))

  (test-case "loop requires exact keywords delimiters and statement semicolons"
    (for ([body '("loop [yes] do {;};" "loop Until [yes] do {;};" "loop until yes do {;};"
                  "loop until [] do {;};" "loop until [yes] {;};" "loop until [yes] Do {;};"
                  "loop until [yes] do [;];" "loop until [yes] do {yield 1};"
                  "loop until [yes] do {;}")])
      (check-exn #rx"Syntax error on line 1" (lambda () (parse-statements body)))))

  (test-case "control-flow bodies do not permit declaration blocks"
    (for ([body '("choose [yes] match {decl x as int;};"
                  "choose [yes] match {} otherwise {decl x as int;};"
                  "loop until [yes] do {routine f() returns int {}};")])
      (check-exn #rx"Syntax error on line 1" (lambda () (parse-statements body)))))

  (test-case "control-flow errors retain offending token and EOF lines"
    (for ([source '("program P {\nchoose [yes]\nwrong {;}; }"
                    "program P {\nloop until [yes]\nwrong {;}; }"
                    "program P { choose [yes] match {\nyield 1\n}; }")])
      (check-exn #rx"Syntax error on line 3" (lambda () (parse-source source))))
    (for ([tail '("choose" "choose [" "choose [yes] match {" "choose [yes] match {} otherwise {"
                  "loop" "loop until [" "loop until [yes] do {" "loop until [yes] do {}")])
      (check-exn #rx"Syntax error on line 2"
                 (lambda () (parse-source (string-append "program P {\n" tail)))))))
