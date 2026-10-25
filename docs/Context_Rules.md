# Context Rules

The primary change is simple: Keywords are not reserved words. This means that if
a keyword (decl, until, do, etc) appears in a place where that keyword would be
an error, then that keyword is just an identifier.
   • decl is only a keyword if it appears at the beginning of a statement or
      declaration block; otherwise it's a normal identifier.
          o decl decl as int; -- Legal! Declares a variable named 'decl'
          o decl = 5;               -- Syntax Error (decl is keyword here)
          o 5 => decl;           -- Legal! Assigns 5 to the variable named 'decl'

   •   The token match is only a keyword if the parser is currently inside an
       active choose statement and has just closed the condition bracket ]. In all
       other contexts (including inside the statement blocks themselves), match
       is a normal variable identifier.
           o decl match as bool; yes => match;                -- Legal variable use
           o choose [match] match {
                        no => match;         -- The second 'match' is the keyword;
                        };                   -- the others are variables!

   •   until is only a keyword if it immediately follows the keyword loop. do is
       only a keyword if it immediately follows the closing bracket ] of a loop
       condition.
          o decl until, do as int;
             10 => until;
             20 => do;
          o loop until [until < do] do {
                      until + 1 => until;
             };

   •   returns is only a keyword if the parser is currently processing a routine
       signature and has just parsed the parameter list closure ).
          o decl returns as string;
               `yes` => returns;

          o routine check() returns bool
                { yield yes;
             }
   •   The keyword program is only a keyword if it appears as the ﬁrst
       meaningful (non-comment) token in the file. In any other context,
       program is just an identifier.
           o   program Demo2 {
                    decl program as real;                   -- Legal; program is a variable here.


Handling Context
To make this work, your compiler cannot use a ‘dumb’ isolated lexer. You have
two options, about equally challenging:
   • A Stateful Lexer: The parser calls the lexer when it’s ready for the next
      token. The lexer maintains a communication channel with the parser.
      When the parser enters a choose statement, it sets a flag
      expecting_match_keyword = true, which tells the lexer how to classify the
      next match string it sees.
   • Parser-Level Demotion: The lexer treats all context-sensitive words as
      identifiers by default (or as soft-keywords). The parser then explicitly
      checks both the token type and the string value when matching structure.
      For example, when looking for the loop boundary, it validates if
      (current_token.value == "until").
Test String
choose [choose == match] match { yes => choose; };



Other Functionality
   •   String comparisons are case-sensitive by default.
   •   In the event of a syntax error, the parser should return a statement giving
       the line number: Syntax error on line 15. Describing the error, or
       showing what was encountered, would be helpful but is not required.
           o  The simplest way to handle this is for the lexer to return the line
              number as part of each token; this is mostly ignored by the parser,
              but is there if needed.
