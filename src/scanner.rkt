#lang racket/base

(require "token.rkt")

(provide scan)

(define single-character-tokens
  (hash #\{ 'left-brace
        #\} 'right-brace
        #\( 'left-paren
        #\) 'right-paren
        #\[ 'left-bracket
        #\] 'right-bracket
        #\, 'comma
        #\: 'colon
        #\; 'semicolon
        #\+ 'plus
        #\- 'minus
        #\* 'multiply
        #\/ 'divide
        #\< 'less-than
        #\> 'greater-than
        #\~ 'concat))

(define two-character-operators
  (hash "==" 'equal
        "/=" 'not-equal
        "<=" 'less-than-or-equal
        ">=" 'greater-than-or-equal
        "=>" 'assign))

(define (scan source)
  (unless (string? source)
    (raise-argument-error 'scan "string?" source))
  (define source-length (string-length source))
  (define (ascii-letter? ch)
    (or (char<=? #\A ch #\Z)
        (char<=? #\a ch #\z)))
  (define (ascii-digit? ch)
    (char<=? #\0 ch #\9))
  (define (digit-run-end start)
    (let loop ([next start])
      (if (and (< next source-length)
               (ascii-digit? (string-ref source next)))
          (loop (add1 next))
          next)))
  (let loop ([index 0] [line 1] [output '()])
    (cond
      [(= index source-length)
       (reverse output)]
      [else
       (define ch (string-ref source index))
       (cond
         [(char=? ch #\return)
          (define next (add1 index))
          (loop (if (and (< next source-length)
                         (char=? (string-ref source next) #\newline))
                    (add1 next)
                    next)
                (add1 line)
                output)]
         [(char=? ch #\newline)
          (loop (add1 index) (add1 line) output)]
         [(or (char=? ch #\space) (char=? ch #\tab))
          (loop (add1 index) line output)]
         [(char=? ch #\`)
          (let string-loop ([next-index (add1 index)] [current-line line])
            (cond
              [(= next-index source-length)
               (error 'scan "unterminated string on line ~a" line)]
              [else
               (define next-ch (string-ref source next-index))
               (cond
                 [(char=? next-ch #\`)
                  (loop (add1 next-index)
                        current-line
                        (cons (token 'string-literal
                                     (substring source index (add1 next-index))
                                     line)
                              output))]
                 [(char=? next-ch #\return)
                  (define next (add1 next-index))
                  (string-loop
                   (if (and (< next source-length)
                            (char=? (string-ref source next) #\newline))
                       (add1 next)
                       next)
                   (add1 current-line))]
                 [(char=? next-ch #\newline)
                  (string-loop (add1 next-index) (add1 current-line))]
                 [else
                  (string-loop (add1 next-index) current-line)])]))]
         [(and (char=? ch #\-)
               (< (add1 index) source-length)
               (char=? (string-ref source (add1 index)) #\-))
          (let comment-loop ([comment-index (+ index 2)])
            (cond
              [(or (= comment-index source-length)
                   (char=? (string-ref source comment-index) #\return)
                   (char=? (string-ref source comment-index) #\newline))
               (loop comment-index line output)]
              [else
               (comment-loop (add1 comment-index))]))]
         [(and (<= (+ index 2) source-length)
               (hash-ref two-character-operators
                         (substring source index (+ index 2))
                         #f))
          => (lambda (type)
               (loop (+ index 2)
                     line
                     (cons (token type
                                  (substring source index (+ index 2))
                                  line)
                           output)))]
         [(hash-ref single-character-tokens ch #f)
          => (lambda (type)
               (loop (add1 index)
                     line
                     (cons (token type (string ch) line) output)))]
         [(ascii-letter? ch)
          (define end
            (let identifier-end ([next (add1 index)])
              (cond
                [(= next source-length) next]
                [else
                 (define next-ch (string-ref source next))
                 (if (or (ascii-letter? next-ch)
                         (ascii-digit? next-ch))
                     (identifier-end (add1 next))
                     next)])))
          (loop end
                line
                (cons (token 'identifier
                             (substring source index end)
                             line)
                      output))]
         [(ascii-digit? ch)
          (define integer-end (digit-run-end index))
          (define real?
            (and (< (add1 integer-end) source-length)
                 (char=? (string-ref source integer-end) #\.)
                 (ascii-digit? (string-ref source (add1 integer-end)))))
          (define end
            (if real?
                (digit-run-end (add1 integer-end))
                integer-end))
          (loop end
                line
                (cons (token (if real? 'real-literal 'int-literal)
                             (substring source index end)
                             line)
                      output))]
         [else
          (error 'scan "unsupported character ~s on line ~a" ch line)])])))
