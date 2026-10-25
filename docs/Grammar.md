# The Grammar

```bnf
<program>          ::= "program" <identifier> "{" <declaration_list> <statement_list> "}"

<declaration_list> ::= <var_decl_list> <proc_decl_list>

<var_decl_list>     ::= <var_declaration> <var_decl_list> | ""
<var_declaration>   ::= "decl" <identifier_list> "as" <type> ";"

<proc_decl_list>   ::= <proc_declaration> <proc_decl_list> | ""
<proc_declaration> ::= "routine" <identifier> <formal_params> "returns" <type> "{" <declaration_list> <statement_list> "}"

<identifier_list>   ::= <identifier> | <identifier> "," <identifier_list>
<type>              ::= "int" | "real" | "bool" | "string"

<formal_params>     ::= "(" <param_list> ")" | "()"
<param_list>        ::= <param> | <param> "," <param_list>
<param>             ::= <identifier> ":" <type>

<statement_list>    ::= <statement> ";" <statement_list> | <statement> ";"

<statement>         ::= <assignment_stmt>
                      | <conditional_stmt>
                      | <loop_stmt>
                      | <call_stmt>
                      | <return_stmt>
                      | <empty_stmt>

<assignment_stmt>   ::= <expression> "=>" <identifier>

<conditional_stmt> ::= "choose" "[" <expression> "]" "match" "{" <statement_list> "}" "otherwise" "{" <statement_list> "}"
                     | "choose" "[" <expression> "]" "match" "{" <statement_list> "}"

<loop_stmt>        ::= "loop" "until" "[" <expression> "]" "do" "{" <statement_list> "}"

<call_stmt>         ::= "invoke" <identifier> <actual_params>
<actual_params>     ::= "(" <expression_list> ")" | "()"
<expression_list>   ::= <expression> | <expression> "," <expression_list>

<return_stmt>       ::= "yield" <expression>
<empty_stmt>        ::= ""

<expression>        ::= <simple_expr> | <simple_expr> <relop> <simple_expr>
<simple_expr>       ::= <term> | <term> <addop> <simple_expr>
<term>              ::= <factor> | <factor> <mulop> <term>
<factor>            ::= <identifier>
                      | <int_literal>
                      | <real_literal>
                      | <bool_literal>
                      | <string_literal>
                      | "(" <expression> ")"
                      | "not" <factor>

<relop>             ::= "==" | "/=" | "<" | "<=" | ">" | ">="
<addop>             ::= "+" | "-" | "or" | "~"
<mulop>             ::= "*" | "/" | "and"

<bool_literal>      ::= "yes" | "no" | "maybe"
<int_literal>       ::= <digit> <digit_list>
<real_literal>      ::= <digit> <digit_list> "." <digit> <digit_list>
<string_literal>    ::= "`" <character_list> "`"

<identifier>        ::= <letter> <alphanumeric_list>
```
