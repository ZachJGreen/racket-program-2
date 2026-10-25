# ScopeCheck — Sample Code (Scope Rules)

```text
program ScopeCheck {
    decl globalVar as int;

    routine Outer() returns int {
        decl outerVar as int;         -- 1. Outer's variables

        routine Inner() returns int {
            decl innerVar as int;     -- 2. Inner's variables

            -- Inner's statements
            5 => innerVar;
            yield innerVar;
        }                             -- 3. End of Inner's declaration

        -- Outer's statements
        invoke Inner() => outerVar;
        yield outerVar;
    }                                 -- 4. End of Outer's declaration

    -- Module statements
    invoke Outer() => globalVar;
}
```
