#lang racket/base

(require "token.rkt")

(provide parse-program
         parse-expression
         (struct-out program)
         (struct-out var-declaration)
         (struct-out routine-declaration)
         (struct-out formal-parameter)
         (struct-out assignment-statement)
         (struct-out invoke-statement)
         (struct-out yield-statement)
         (struct-out empty-statement)
         (struct-out choose-statement)
         (struct-out loop-statement)
         (struct-out identifier-expression)
         (struct-out literal-expression)
         (struct-out unary-expression)
         (struct-out binary-expression))

(struct program (name declarations statements) #:transparent)
(struct var-declaration (names type) #:transparent)
(struct routine-declaration (name parameters return-type declarations statements) #:transparent)
(struct formal-parameter (name type) #:transparent)

(struct assignment-statement (expression target) #:transparent)
(struct invoke-statement (name arguments target) #:transparent)
(struct yield-statement (expression) #:transparent)
(struct empty-statement () #:transparent)
(struct choose-statement (condition match-statements otherwise-statements) #:transparent)
(struct loop-statement (condition statements) #:transparent)

(struct identifier-expression (name) #:transparent)
(struct literal-expression (type value) #:transparent)
(struct unary-expression (operator operand) #:transparent)
(struct binary-expression (operator left right) #:transparent)

(struct exn:fail:parser-syntax exn:fail (remaining-count))

(define (parse-program tokens)
  (parse tokens 'parse-program))

(define (parse-expression tokens)
  (parse tokens 'parse-expression))

(define (parse tokens entry)
  (unless (and (list? tokens) (andmap token? tokens))
    (raise-argument-error entry "(listof token?)" tokens))
  (define remaining tokens)
  (define last-consumed-line 1)
  (define (syntax-failure format-string . arguments)
    (raise
     (exn:fail:parser-syntax
      (string-append (symbol->string entry) ": "
                     (apply format format-string arguments))
      (current-continuation-marks)
      (length remaining))))
  (define (at? type [lexeme #f])
    (and (pair? remaining)
         (eq? (token-type (car remaining)) type)
         (or (not lexeme) (string=? (token-value (car remaining)) lexeme))))
  (define (expect! type [lexeme #f])
    (define expected (if lexeme (format "~s" lexeme) (symbol->string type)))
    (when (null? remaining)
      (syntax-failure
             "Syntax error on line ~a: expected ~a, found EOF"
             last-consumed-line expected))
    (define current (car remaining))
    (unless (and (eq? (token-type current) type)
                 (or (not lexeme) (string=? (token-value current) lexeme)))
      (syntax-failure
             "Syntax error on line ~a: expected ~a, found ~a ~s"
             (token-line current) expected
             (token-type current) (token-value current)))
    (set! remaining (cdr remaining))
    (set! last-consumed-line (token-line current))
    current)
  (define (parse-identifier-list!)
    (define first-name (token-value (expect! 'identifier)))
    (let loop ([names (list first-name)])
      (if (at? 'comma)
          (begin
            (expect! 'comma)
            (loop (cons (token-value (expect! 'identifier)) names)))
          (reverse names))))
  (define (parse-type!)
    (define current (expect! 'identifier))
    (unless (member (token-value current) '("int" "real" "bool" "string"))
      (syntax-failure
             "Syntax error on line ~a: expected type int, real, bool, or string, found ~a ~s"
             (token-line current) (token-type current) (token-value current)))
    (string->symbol (token-value current)))
  (define (parse-var-declaration!)
    (expect! 'identifier "decl")
    (define names (parse-identifier-list!))
    (expect! 'identifier "as")
    (define type (parse-type!))
    (expect! 'semicolon)
    (var-declaration names type))
  (define (parse-formal-parameter!)
    (define name (token-value (expect! 'identifier)))
    (expect! 'colon)
    (formal-parameter name (parse-type!)))
  (define (parse-formal-parameters!)
    (expect! 'left-paren)
    (define parameters
      (if (at? 'right-paren)
          '()
          (let loop ([parameters (list (parse-formal-parameter!))])
            (if (at? 'comma)
                (begin
                  (expect! 'comma)
                  (loop (cons (parse-formal-parameter!) parameters)))
                (reverse parameters)))))
    (expect! 'right-paren)
    parameters)
  (define (parse-routine-declaration!)
    (expect! 'identifier "routine")
    (define name (token-value (expect! 'identifier)))
    (define parameters (parse-formal-parameters!))
    (expect! 'identifier "returns")
    (define return-type (parse-type!))
    (define-values (declarations statements) (parse-block!))
    (routine-declaration name parameters return-type declarations statements))
  (define (parse-actual-parameters!)
    (expect! 'left-paren)
    (define arguments
      (if (at? 'right-paren)
          '()
          (let loop ([arguments (list (parse-expression!))])
            (if (at? 'comma)
                (begin
                  (expect! 'comma)
                  (loop (cons (parse-expression!) arguments)))
                (reverse arguments)))))
    (expect! 'right-paren)
    arguments)
  (define (parse-invoke-statement!)
    (expect! 'identifier "invoke")
    (define name (token-value (expect! 'identifier)))
    (define arguments (parse-actual-parameters!))
    (define target
      (and (at? 'assign)
           (begin
             (expect! 'assign)
             (token-value (expect! 'identifier)))))
    (invoke-statement name arguments target))
  (define (assignment-ahead?)
    (let loop ([tokens remaining])
      (cond
        [(null? tokens) #f]
        [(memq (token-type (car tokens)) '(semicolon left-brace right-brace)) #f]
        [(eq? (token-type (car tokens)) 'assign) #t]
        [else (loop (cdr tokens))])))
  (define (parse-choose-statement!)
    (expect! 'identifier "choose")
    (expect! 'left-bracket)
    (define condition (parse-expression!))
    (expect! 'right-bracket)
    (expect! 'identifier "match")
    (define match-statements (parse-statement-block!))
    (define otherwise-statements
      (and (at? 'identifier "otherwise")
           (begin
             (expect! 'identifier "otherwise")
             (parse-statement-block!))))
    (choose-statement condition match-statements otherwise-statements))
  (define (parse-loop-statement!)
    (expect! 'identifier "loop")
    (expect! 'identifier "until")
    (expect! 'left-bracket)
    (define condition (parse-expression!))
    (expect! 'right-bracket)
    (expect! 'identifier "do")
    (loop-statement condition (parse-statement-block!)))
  (define (parse-statement!)
    (define statement
      (cond
        [(at? 'semicolon) (empty-statement)]
        [(and (at? 'identifier "choose") (not (assignment-ahead?)))
         (parse-choose-statement!)]
        [(and (at? 'identifier "loop") (not (assignment-ahead?)))
         (parse-loop-statement!)]
        [(and (at? 'identifier "invoke")
              (pair? (cdr remaining))
              (pair? (cddr remaining))
              (eq? (token-type (cadr remaining)) 'identifier)
              (eq? (token-type (caddr remaining)) 'left-paren))
         (parse-invoke-statement!)]
        [(and (at? 'identifier "yield") (not (assignment-ahead?)))
         (expect! 'identifier "yield")
         (yield-statement (parse-expression!))]
        [(or (at? 'identifier "decl")
             (and (at? 'identifier "routine") (not (assignment-ahead?))))
         (syntax-failure
                "Syntax error on line ~a: declarations must precede statements and variables must precede routines"
                (token-line (car remaining)))]
        [else
         (define expression (parse-expression!))
         (expect! 'assign)
         (assignment-statement expression (token-value (expect! 'identifier)))]))
    (expect! 'semicolon)
    statement)
  (define (parse-statement-list!)
    (let loop ([statements '()])
      (if (or (null? remaining) (at? 'right-brace))
          (reverse statements)
          (loop (cons (parse-statement!) statements)))))
  (define (parse-statement-block!)
    (expect! 'left-brace)
    (define statements (parse-statement-list!))
    (expect! 'right-brace)
    statements)
  (define (parse-block!)
    (expect! 'left-brace)
    (define variables
      (let loop ([declarations '()])
        (if (at? 'identifier "decl")
            (loop (cons (parse-var-declaration!) declarations))
            (reverse declarations))))
    (define routines
      (let loop ([declarations '()])
        (if (and (at? 'identifier "routine") (not (assignment-ahead?)))
            (loop (cons (parse-routine-declaration!) declarations))
            (reverse declarations))))
    (define statements (parse-statement-list!))
    (expect! 'right-brace)
    (values (append variables routines) statements))
  (define (parse-program!)
    (expect! 'identifier "program")
    (define name (token-value (expect! 'identifier)))
    (define-values (declarations statements) (parse-block!))
    (program name declarations statements))
  (define (parse-factor! continue)
    (cond
      [(at? 'left-paren)
       (expect! 'left-paren)
       (parse-expression!
        (lambda (expression)
          (expect! 'right-paren)
          (continue expression)))]
      [(at? 'identifier)
       (define name (token-value (expect! 'identifier)))
       (cond
         [(string=? name "not")
          (define saved-remaining remaining)
          (define saved-line last-consumed-line)
          (with-handlers
              ([exn:fail:parser-syntax?
                (lambda (unary-failure)
                  (set! remaining saved-remaining)
                  (set! last-consumed-line saved-line)
                  (with-handlers
                      ([exn:fail:parser-syntax?
                        (lambda (identifier-failure)
                          (raise
                           (if (<= (exn:fail:parser-syntax-remaining-count unary-failure)
                                   (exn:fail:parser-syntax-remaining-count identifier-failure))
                               unary-failure
                               identifier-failure)))])
                    (continue (identifier-expression name))))])
            (parse-factor!
             (lambda (operand)
               (continue (unary-expression 'not operand)))))]
         [(member name '("yes" "no" "maybe"))
          (continue (literal-expression 'bool-literal name))]
         [else (continue (identifier-expression name))])]
      [(or (at? 'int-literal) (at? 'real-literal) (at? 'string-literal))
       (define current (expect! (token-type (car remaining))))
       (continue (literal-expression (token-type current) (token-value current)))]
      [else
       (expect! 'identifier)]))
  (define (peek-operator types [word #f])
    (and (pair? remaining)
         (let ([current (car remaining)])
           (cond
             [(memq (token-type current) types) (token-type current)]
             [(and word (at? 'identifier word)) (string->symbol word)]
             [else #f]))))
  (define (parse-term! continue)
    (parse-factor!
     (lambda (left)
       (define operator (peek-operator '(multiply divide) "and"))
       (if operator
           (begin
             (expect! (token-type (car remaining)))
             (parse-term!
              (lambda (right)
                (continue (binary-expression operator left right)))))
           (continue left)))))
  (define (parse-simple-expression! continue)
    (parse-term!
     (lambda (left)
       (define operator (peek-operator '(plus minus concat) "or"))
       (if operator
           (begin
             (expect! (token-type (car remaining)))
             (parse-simple-expression!
              (lambda (right)
                (continue (binary-expression operator left right)))))
           (continue left)))))
  (define (expression-boundary! expression)
    (unless (or (null? remaining)
                (memq (token-type (car remaining))
                      '(comma right-paren right-bracket assign semicolon right-brace)))
      (define current (car remaining))
      (syntax-failure
       "Syntax error on line ~a: expected expression boundary, found ~a ~s"
       (token-line current) (token-type current) (token-value current)))
    expression)
  (define (expect-eof! result)
    (unless (null? remaining)
      (define current (car remaining))
      (syntax-failure
       "Syntax error on line ~a: expected EOF, found ~a ~s"
       (token-line current) (token-type current) (token-value current)))
    result)
  (define (parse-expression! [continue expression-boundary!])
    (parse-simple-expression!
     (lambda (left)
       (define operator
         (peek-operator '(equal not-equal less-than less-than-or-equal
                               greater-than greater-than-or-equal)))
       (if operator
           (begin
             (expect! (token-type (car remaining)))
             (parse-simple-expression!
              (lambda (right)
                (continue (binary-expression operator left right)))))
           (continue left)))))
  (define result
    (case entry
      [(parse-program) (parse-program!)]
      [(parse-expression) (parse-expression! expect-eof!)]))
  (expect-eof! result))
