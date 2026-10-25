#lang racket/base

(provide (struct-out token))

(struct token (type value line) #:transparent)
