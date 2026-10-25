Agents should log their interactions with the user within their respective directory. Codex logs in `codex_logs`, Claude logs in `claude_logs`. Make each individual prompt its own entry. Log user prompts, implementation decisions, failures, and revisions. Output in .md

User directs where to place the Agent's focus. Do not go on ahead of what the user specifies.

Implementation language is in Racket, but examples do not follow the same syntax.

Work in a new branch for each implementation task and settle merge conflicts before handing off to user for review.

docs directory is READ ONLY. Do not make any edits to them.

Should there be any ambiguities in what to do, flag them, carry on where you can, and prompt the user for guidance.

Keep changes small enough to test and explain. Create new git branches for a completed iteration for the user to review.