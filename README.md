# Running the Program

Requires [Racket](https://racket-lang.org/) to be installed.

## Run the tests

From the project root:

```
raco test tests
```

To run a single suite:

```
raco test tests/scanner-test.rkt
raco test tests/parser-test.rkt
```

## Scan and parse a source file

From the project root:

```
racket -e '(require racket/file "src/scanner.rkt" "src/parser.rkt") (parse-program (scan (file->string "tests_text/Testfile-1.txt")))'
```

Replace `tests_text/Testfile-1.txt` with the path to your own source file.
