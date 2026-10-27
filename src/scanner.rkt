#lang racket/base

(require "token.rkt")

(provide scan)

(define punctuation
  (hash #\{ 'left-brace
        #\} 'right-brace
        #\( 'left-paren
        #\) 'right-paren
        #\[ 'left-bracket
        #\] 'right-bracket
        #\, 'comma
        #\: 'colon
        #\; 'semicolon))

(define (scan source)
  (unless (string? source)
    (raise-argument-error 'scan "string?" source))
  (define source-length (string-length source))
  (define (ascii-letter? ch)
    (or (char<=? #\A ch #\Z)
        (char<=? #\a ch #\z)))
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
         [(hash-ref punctuation ch #f)
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
                         (char<=? #\0 next-ch #\9))
                     (identifier-end (add1 next))
                     next)])))
          (loop end
                line
                (cons (token 'identifier
                             (substring source index end)
                             line)
                      output))]
         [else
          (error 'scan "unsupported character ~s on line ~a" ch line)])])))
